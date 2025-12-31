/*
    cortex_bridge.qc - Main Communication Bridge

    Handles TCP connection to the Python brain and manages
    the sensor data stream.
*/

// Global state
float cortex_socket;
float cortex_retry_time;
float cortex_enabled;

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

    bprint(PRINT_HIGH, "CORTEX: Initializing AI Bridge...\n");
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
        bprint(PRINT_HIGH, "CORTEX: Connected to Python Brain!\n");
    }
    else
    {
        bprint(PRINT_HIGH, "CORTEX: Searching for Brain...\n");
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

    // Exit if disabled
    if (!cortex_enabled) return;

    // Try to connect if not connected
    if (cortex_socket < 0)
    {
        Cortex_Connect();
        return;
    }

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
        bprint(PRINT_HIGH, "CORTEX: Disconnected from Brain\n");
    }
};