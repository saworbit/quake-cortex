/*
    cortex_bridge.qc - Main Communication Bridge

    Handles TCP connection to the Python brain and manages
    the sensor data stream.
*/

// Global state
float cortex_socket;
float cortex_retry_time;
float cortex_enabled;
float cortex_last_send;  // Last time we sent telemetry
float cortex_initialized;
float cortex_warn_time;  // Avoid spamming setup hints
float cortex_ext_checked;

// Latest control command received from the Brain (TCP stream mode).
vector cortex_cmd_move;     // x=forward, y=side
vector cortex_cmd_aim;      // x=pitch_delta, y=yaw_delta
float cortex_cmd_buttons;   // bit0=attack, bit1=jump
float cortex_cmd_time;      // last time we applied an update

// Extension detection (TCP/control mode needs extra builtins on some engines).
float cortex_stream_ext_checked;
float cortex_has_cvar_string;
float cortex_has_strings;
float cortex_warned_missing_cvar_string;
float cortex_warned_missing_strings;
float cortex_warned_uriget_disabled;

void() Cortex_Frame;
void() Cortex_EnsureTelemetryOpen;
void() Cortex_PrintFileSupportStatus;
void() Cortex_PrintStreamSupportStatus;
void() Cortex_PollControls;
void() Cortex_ApplyControls;

/*
=================
Cortex_Init

Called when the map loads. Sets up initial state.
=================
*/
void() Cortex_Init =
{
    cortex_socket = -1;
    cortex_retry_time = 0;  // Reused for file open retry throttle
    cortex_enabled = 1;
    cortex_warn_time = 0;
    cortex_last_send = -9999;
    cortex_ext_checked = 0;

    bprint("CORTEX: Initializing AI Bridge...\n");
    CortexLog(LOG_info, "BRIDGE", "init");

    // Don't assume sv_progsaccess is already enabled; we'll retry from StartFrame.
    Cortex_EnsureTelemetryOpen();
};

/*
=================
Cortex_PrintFileSupportStatus

Prints engine capability hints for file I/O (FRIK_FILE/checkextension).
Runs at most once per map to avoid spamming.
=================
*/
void() Cortex_PrintFileSupportStatus =
{
    local float has_checkextension;
    local float has_frik_file;

    if (cortex_ext_checked) return;
    cortex_ext_checked = 1;

    // FTE exposes a read-only cvar that indicates whether checkextension builtin exists.
    has_checkextension = cvar("pr_checkextension");

    if (!has_checkextension)
    {
        bprint("CORTEX: Note: checkextension unavailable (cvar pr_checkextension = 0)\n");
        CortexLog(LOG_warning, "CAPS", "checkextension_unavailable");
        return;
    }

    has_frik_file = checkextension("FRIK_FILE");
    if (has_frik_file)
    {
        bprint("CORTEX: Engine reports FRIK_FILE support (fopen/fputs/fclose should exist)\n");
        CortexLog(LOG_info, "CAPS", "frik_file_available");
    }
    else
    {
        bprint("CORTEX: Engine reports NO FRIK_FILE support (file I/O will not work)\n");
        CortexLog(LOG_error, "CAPS", "frik_file_missing");
    }
};

/*
=================
Cortex_PrintStreamSupportStatus

URI streams (`tcp://`, `tls://`, `ws:`, `wss:`) are opened via `fopen(uri, -1)`.
FTE gates this behind `pr_enable_uriget` for safety.
=================
*/
void() Cortex_PrintStreamSupportStatus =
{
    if (!cvar("pr_enable_uriget") && !cortex_warned_uriget_disabled)
    {
        cortex_warned_uriget_disabled = 1;
        bprint("CORTEX: Note: URI streams disabled (set `pr_enable_uriget 1` to allow tcp://)\n");
        CortexLog(LOG_warning, "CAPS", "uriget_disabled");
    }

    if (!cortex_stream_ext_checked)
    {
        cortex_stream_ext_checked = 1;
        cortex_has_cvar_string = checkextension("DP_QC_CVAR_STRING");
        cortex_has_strings = checkextension("FTE_STRINGS");
    }

    if (!cortex_has_cvar_string && !cortex_warned_missing_cvar_string)
    {
        cortex_warned_missing_cvar_string = 1;
        bprint("CORTEX: Note: DP_QC_CVAR_STRING missing (TCP URI cvar overrides disabled)\n");
        CortexLog(LOG_warning, "CAPS", "dp_qc_cvar_string_missing");
    }

    if (!cortex_has_strings && !cortex_warned_missing_strings)
    {
        cortex_warned_missing_strings = 1;
        bprint("CORTEX: Note: FTE_STRINGS missing (Brain->Body control parsing disabled)\n");
        CortexLog(LOG_warning, "CAPS", "fte_strings_missing");
    }
};

/*
=================
Cortex_EnsureTelemetryOpen

Opens the telemetry file once file access is available.
Retries periodically so the user can set sv_progsaccess without restarting the map.
=================
*/
void() Cortex_EnsureTelemetryOpen =
{
    local float use_tcp;
    local string target;
    local string fallback;

    if (cortex_socket >= 0) return;

    use_tcp = cvar("cortex_use_tcp");

    // Retry occasionally to avoid console spam.
    if (time < cortex_retry_time) return;
    cortex_retry_time = time + (use_tcp ? 3 : 1);

    if (use_tcp)
        Cortex_PrintStreamSupportStatus();
    else
        Cortex_PrintFileSupportStatus();

    if (use_tcp)
    {
        if (!cortex_stream_ext_checked)
            Cortex_PrintStreamSupportStatus();

        if (cortex_has_cvar_string)
            target = cvar_string("cortex_tcp_uri");
        else
            target = "";

        // Default to raw TCP; some builds may present websocket framing, which the Python side can handle.
        if (target == "") target = "tcp://127.0.0.1:26000";
    }
    else
    {
        if (checkextension("DP_QC_CVAR_STRING"))
            target = cvar_string("cortex_telemetry_file");
        else
            target = "";

        if (target == "") target = "cortex_telemetry.txt";
    }

    if (use_tcp)
        cortex_socket = TCP_ConnectStream(target);
    else
        cortex_socket = TCP_ConnectFile(target);

    // Fallback: if ws:// was configured but blocked/mis-parsed, try tcp://.
    if (use_tcp && cortex_socket < 0)
    {
        fallback = "tcp://127.0.0.1:26000";
        if (target != fallback)
        {
            cortex_socket = TCP_ConnectStream(fallback);
            if (cortex_socket >= 0)
                target = fallback;
        }
    }

    if (cortex_socket >= 0)
    {
        if (use_tcp)
        {
            if (strncmp(target, "ws", 2) == 0)
                bprint("CORTEX: Connected Cortex stream (ws://)\n");
            else
                bprint("CORTEX: Connected Cortex stream (tcp://)\n");
        }
        else
            bprint("CORTEX: Telemetry file opened! (data/cortex_telemetry.txt)\n");

        CortexLogData(
            LOG_info,
            "IO",
            use_tcp ? "telemetry_stream_connected" : "telemetry_file_opened",
            strcat("{\"target\":\"", target, "\"}")
        );
        return;
    }

    // Helpful hint, but don't spam.
    if (time >= cortex_warn_time)
    {
        cortex_warn_time = time + 5;
        if (use_tcp)
        {
            bprint("CORTEX: Stream connect failed (check Python server + `pr_enable_uriget 1`)\n");
            CortexLogData(LOG_error, "IO", "telemetry_stream_connect_failed", strcat("{\"target\":\"", target, "\"}"));
        }
        else
        {
            bprint("CORTEX: Telemetry disabled (try `sv_progsaccess 2` in console)\n");
            CortexLogData(LOG_error, "IO", "telemetry_file_open_failed", strcat("{\"target\":\"", target, "\"}"));
        }
    }
};

float(string s, float start) Cortex_ParseJsonNumber =
{
    local float len;
    local float c;
    local float end;

    len = strlen(s);

    // Skip whitespace and common separators.
    while (start < len)
    {
        c = str2chr(s, start);
        if (c == 32 || c == 9 || c == 10 || c == 13 || c == 58)
            start = start + 1;
        else
            break;
    }

    end = start;
    while (end < len)
    {
        c = str2chr(s, end);
        if ((c >= 48 && c <= 57) || c == 45 || c == 46 || c == 43 || c == 69 || c == 101)
            end = end + 1;
        else
            break;
    }

    return stof(substring(s, start, end - start));
};

void(string line) Cortex_ParseControlLine =
{
    local float ofs;
    local float start;
    local float comma;
    local float a0;
    local float a1;

    // Expect JSON object.
    if (line == "") return;
    if (str2chr(line, 0) != 123) return; // '{'

    // Parse: "move":[forward,side]
    ofs = strstrofs(line, "\"move\":[", 0);
    if (ofs >= 0)
    {
        start = ofs + strlen("\"move\":[");
        cortex_cmd_move_x = Cortex_ParseJsonNumber(line, start);
        comma = strstrofs(line, ",", start);
        if (comma >= 0)
            cortex_cmd_move_y = Cortex_ParseJsonNumber(line, comma + 1);
    }

    // Parse: "aim":[yaw_delta,pitch_delta]
    ofs = strstrofs(line, "\"aim\":[", 0);
    if (ofs >= 0)
    {
        start = ofs + strlen("\"aim\":[");
        a0 = Cortex_ParseJsonNumber(line, start);
        comma = strstrofs(line, ",", start);
        if (comma >= 0)
            a1 = Cortex_ParseJsonNumber(line, comma + 1);
        else
            a1 = 0;

        // Store as pitch/yaw deltas for easy application later.
        cortex_cmd_aim_x = a1;
        cortex_cmd_aim_y = a0;
    }

    // Parse: "buttons":N
    ofs = strstrofs(line, "\"buttons\":", 0);
    if (ofs >= 0)
    {
        start = ofs + strlen("\"buttons\":");
        cortex_cmd_buttons = Cortex_ParseJsonNumber(line, start);
    }

    cortex_cmd_time = time;
};

void() Cortex_PollControls =
{
    local string line;
    local float i;

    if (cortex_socket < 0) return;
    if (!cvar("cortex_use_tcp")) return;
    if (!cvar("cortex_enable_controls")) return;

    if (!cortex_stream_ext_checked)
        Cortex_PrintStreamSupportStatus();

    if (!cortex_has_strings)
    {
        if (!cortex_warned_missing_strings)
        {
            cortex_warned_missing_strings = 1;
            bprint("CORTEX: Controls disabled (missing FTE_STRINGS)\n");
        }
        return;
    }

    // Drain a few lines per frame (non-blocking on FTE tcp streams).
    for (i = 0; i < 8; i = i + 1)
    {
        line = fgets(cortex_socket);
        if (line == "") return;
        Cortex_ParseControlLine(line);
    }
};

void() Cortex_ApplyControls =
{
    local float attack;
    local float jump;
    local float vz;

    if (!cvar("cortex_use_tcp")) return;
    if (!cvar("cortex_enable_controls")) return;

    // Safety: don't keep applying stale commands forever.
    if (time > cortex_cmd_time + 0.25)
        return;

    // Aim deltas (degrees).
    self.v_angle_x = self.v_angle_x + cortex_cmd_aim_x;
    self.v_angle_y = self.v_angle_y + cortex_cmd_aim_y;

    if (self.v_angle_x > 80) self.v_angle_x = 80;
    if (self.v_angle_x < -70) self.v_angle_x = -70;

    // Keep the model facing the view yaw.
    self.angles_y = self.v_angle_y;

    // Movement: override horizontal velocity while preserving vertical.
    vz = self.velocity_z;
    makevectors(self.v_angle);
    self.velocity = (v_forward * cortex_cmd_move_x) + (v_right * cortex_cmd_move_y);
    self.velocity_z = vz;

    // Buttons (bitmask).
    attack = (cortex_cmd_buttons & 1) ? 1 : 0;
    jump = (cortex_cmd_buttons & 2) ? 1 : 0;
    self.button0 = attack;
    self.button2 = jump;
};

/*
=================
Cortex_Connect

Attempts to connect to the Python brain server.
Only retries every 3 seconds to avoid spam.
=================
*/
void() Cortex_Connect =
{
    // Don't spam connect attempts (every 3 seconds)
    if (time < cortex_retry_time) return;
    cortex_retry_time = time + 3;

    // Try to connect to Python on Localhost Port 26000
    cortex_socket = TCP_Connect("tcp://127.0.0.1:26000");

    if (cortex_socket >= 0)
    {
        bprint("CORTEX: Connected to Python Brain!\n");
    }
    else
    {
        bprint("CORTEX: Searching for Brain...\n");
    }
};

/*
=================
Cortex_Think

Main loop - runs every frame for bot entities.
Sends sensor data to Python brain.
=================
*/
void() Cortex_Think =
{
    local string packet;
    local float interval;

    // Exit if disabled or not connected
    if (!cortex_enabled) return;

    // File not open yet (eg sv_progsaccess not set); retry until it works.
    Cortex_EnsureTelemetryOpen();
    if (cortex_socket < 0) return;

    // Throttle updates (default 10Hz; override via `cortex_send_interval`).
    interval = cvar("cortex_send_interval");
    if (interval <= 0) interval = 0.1;
    if (time < cortex_last_send + interval) return;
    cortex_last_send = time;

    // Build and send sensor packet
    packet = Cortex_BuildSensorPacket();
    TCP_Send(cortex_socket, packet);

    // TODO Phase 2: Receive control inputs from Python
    // TODO Phase 3: Apply inputs to bot movement
};

/*
=================
Cortex_Shutdown

Called when map ends or bot is removed.
=================
*/
void() Cortex_Shutdown =
{
    if (cortex_socket >= 0)
    {
        TCP_Close(cortex_socket);
        cortex_socket = -1;
        bprint("CORTEX: Disconnected from Brain\n");
    }
};

/*
=================
Cortex_Frame

Entry point called from StartFrame to initialize and emit telemetry.
=================
*/
void() Cortex_Frame =
{
    local entity old_self;
    local float interval;

    if (!cortex_initialized)
    {
        cortex_initialized = 1;
        Cortex_Init();
    }

    // If file access isn't available yet, don't waste time searching entities.
    Cortex_EnsureTelemetryOpen();
    if (cortex_socket < 0) return;

    // If running in TCP stream mode, poll control commands every frame.
    Cortex_PollControls();

    // Avoid the per-frame entity lookup if we won't send yet.
    interval = cvar("cortex_send_interval");
    if (interval <= 0) interval = 0.1;
    if (time < cortex_last_send + interval) return;

    old_self = self;
    self = find(world, classname, "player");
    if (self)
        Cortex_Think();
    self = old_self;
};
