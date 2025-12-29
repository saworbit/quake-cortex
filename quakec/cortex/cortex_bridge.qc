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

void() Cortex_Frame;
void() Cortex_EnsureTelemetryOpen;
void() Cortex_PrintFileSupportStatus;

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
        return;
    }

    has_frik_file = checkextension("FRIK_FILE");
    if (has_frik_file)
        bprint("CORTEX: Engine reports FRIK_FILE support (fopen/fputs/fclose should exist)\n");
    else
        bprint("CORTEX: Engine reports NO FRIK_FILE support (file I/O will not work)\n");
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
    if (cortex_socket >= 0) return;

    // Retry at most once per second.
    if (time < cortex_retry_time) return;
    cortex_retry_time = time + 1;

    Cortex_PrintFileSupportStatus();

    cortex_socket = TCP_Connect("cortex_telemetry.txt");

    if (cortex_socket >= 0)
    {
        bprint("CORTEX: Telemetry file opened! (data/cortex_telemetry.txt)\n");
        return;
    }

    // Helpful hint, but don't spam.
    if (time >= cortex_warn_time)
    {
        cortex_warn_time = time + 5;
        bprint("CORTEX: Telemetry disabled (try `sv_progsaccess 2` in console)\n");
    }
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

    // Try to connect to Python on Localhost Port 5000
    cortex_socket = TCP_Connect("tcp://127.0.0.1:5000");

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

    // Exit if disabled or not connected
    if (!cortex_enabled) return;

    // File not open yet (eg sv_progsaccess not set); retry until it works.
    Cortex_EnsureTelemetryOpen();
    if (cortex_socket < 0) return;

    // Throttle to 10 updates per second (every 0.1 seconds)
    if (time < cortex_last_send + 0.1) return;
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

    if (!cortex_initialized)
    {
        cortex_initialized = 1;
        Cortex_Init();
    }

    // If file access isn't available yet, don't waste time searching entities.
    Cortex_EnsureTelemetryOpen();
    if (cortex_socket < 0) return;

    // Avoid the per-frame entity lookup if we won't send yet.
    if (time < cortex_last_send + 0.1) return;

    old_self = self;
    self = find(world, classname, "player");
    if (self)
        Cortex_Think();
    self = old_self;
};
