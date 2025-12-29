/*
    cortex_tcp.qc - File-based Communication Bridge

    Uses file I/O instead of TCP to avoid FTEQW security restrictions.
    QuakeC writes telemetry to a file, Python reads it in real-time.
*/

// File handle for telemetry output
float telemetry_file;
string TELEMETRY_PATH = "cortex_telemetry.txt";

// Wrapper functions using file I/O
float(string hostname) TCP_Connect =
{
    // Open file for writing telemetry
    // Use FILE_APPEND to keep adding data
    telemetry_file = fopen(TELEMETRY_PATH, FILE_WRITE);

    if (telemetry_file >= 0)
    {
        // Write header to indicate new session
        fputs(telemetry_file, "--- CORTEX SESSION START ---\n");
        return telemetry_file;  // Return handle to indicate success
    }

    return -1;  // Failed to open file
};

void(float socket, string buffer) TCP_Send =
{
    if (telemetry_file >= 0)
    {
        fputs(telemetry_file, buffer);
        // Note: File is flushed automatically by FTEQW
    }
};

void(float socket) TCP_Close =
{
    if (telemetry_file >= 0)
    {
        fputs(telemetry_file, "--- CORTEX SESSION END ---\n");
        fclose(telemetry_file);
        telemetry_file = -1;
    }
};
