/*
    cortex_tcp.qc - TCP Socket Extensions for FTEQW

    These are FTEQW-specific builtins for TCP socket communication.
    They're not in the standard fteextensions.qc but are available in FTEQW.
*/

// TCP Socket builtins (FTEQW extension)
float(string hostname) TCP_Connect = #220;
void(float socket, string buffer) TCP_Send = #221;
void(float socket) TCP_Close = #222;

// Note: These builtin numbers may vary by FTEQW version.
// If compilation fails, these functions might not be available or
// use different builtin numbers.
