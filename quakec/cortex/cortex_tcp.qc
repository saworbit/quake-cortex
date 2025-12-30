/*
    cortex_tcp.qc - Cortex Stream Abstraction (File or TCP)

    In Phase 1, Project Cortex used file I/O because some FTE builds restrict
    network access from QuakeC by default.

    FTE's `fopen` also supports URI streams when called with `fmode < 0`
    (see engine builtin `PF_fopen`), including `tcp://...`.

    This file provides small wrappers so the rest of the Cortex code can treat
    the output as a single "socket-like" handle regardless of whether we're
    writing to a file or a TCP stream.
*/

// Wrapper functions using file I/O
float(string hostname) TCP_Connect =
{
    local float handle;
    local float is_tcp;

    // URI streams: `fopen("tcp://127.0.0.1:26000", -1)` returns a STREAM handle.
    is_tcp =
        (strncmp(hostname, "tcp://", 6) == 0) ||
        (strncmp(hostname, "tls://", 6) == 0) ||
        (strncmp(hostname, "ws:", 3) == 0) ||
        (strncmp(hostname, "wss:", 4) == 0);

    if (is_tcp)
        handle = fopen(hostname, -1);
    else
    {
        // File writes are restricted to the mod's `data/` folder.
        // So this typically ends up at: `Game/cortex/data/<hostname>`
        handle = fopen(hostname, FILE_APPEND);
    }

    if (handle < 0)
        return -1;

    fputs(handle, "--- CORTEX SESSION START ---\n");
    return handle;
};

void(float socket, string buffer) TCP_Send =
{
    if (socket >= 0)
        fputs(socket, buffer);
};

void(float socket) TCP_Close =
{
    if (socket < 0)
        return;

    fputs(socket, "--- CORTEX SESSION END ---\n");
    fclose(socket);
};
