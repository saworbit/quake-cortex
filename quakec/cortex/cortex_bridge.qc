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

/*
=================
Cortex_Init

Called when the map loads. Sets up initial state.
=================
*/
void() Cortex_Init =
{
    cortex_socket = -1;
    cortex_retry_time = 0;
    cortex_enabled = 1;

    bprint("CORTEX: Initializing AI Bridge...\n");

    // Open telemetry file immediately (not in a loop)
    cortex_socket = TCP_Connect("cortex_telemetry.txt");

    if (cortex_socket >= 0)
    {
        bprint("CORTEX: Telemetry file opened!\n");
    }
    else
    {
        bprint("CORTEX: Warning - Could not open telemetry file\n");
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
    if (cortex_socket < 0) return;  // File not open, skip

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