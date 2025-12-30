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
string(string s) Cortex_TrimUriString =
{
    local float len;
    local float start;
    local float end;
    local float c;

    len = strlen(s);
    start = 0;
    end = len;

    // Trim leading whitespace.
    while (start < end)
    {
        c = str2chr(s, start);
        if (c == 32 || c == 9 || c == 10 || c == 13)
            start = start + 1;
        else
            break;
    }

    // Trim trailing whitespace.
    while (end > start)
    {
        c = str2chr(s, end - 1);
        if (c == 32 || c == 9 || c == 10 || c == 13)
            end = end - 1;
        else
            break;
    }

    s = substring(s, start, end - start);

    // Strip a single pair of surrounding quotes if present.
    len = strlen(s);
    if (len >= 2)
    {
        if ((str2chr(s, 0) == 34 && str2chr(s, len - 1) == 34) ||
            (str2chr(s, 0) == 39 && str2chr(s, len - 1) == 39))
            s = substring(s, 1, len - 2);
    }

    return s;
};

float(string hostname) TCP_Connect =
{
    local float handle;
    local float is_tcp;
    local float has_scheme;

    hostname = Cortex_TrimUriString(hostname);

    // URI streams: `fopen("tcp://127.0.0.1:26000", -1)` returns a STREAM handle.
    is_tcp =
        (strncmp(hostname, "tcp://", 6) == 0) ||
        (strncmp(hostname, "tls://", 6) == 0) ||
        (strncmp(hostname, "ws:", 3) == 0) ||
        (strncmp(hostname, "wss:", 4) == 0);

    // Extra safety: treat any value containing "://" as a stream URI.
    has_scheme = (strstrofs(hostname, "://", 0) >= 0) ? 1 : 0;
    if (has_scheme)
        is_tcp = 1;

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

float(string uri) TCP_ConnectStream =
{
    local float handle;

    uri = Cortex_TrimUriString(uri);
    handle = fopen(uri, -1);
    if (handle < 0)
        return -1;

    fputs(handle, "--- CORTEX SESSION START ---\n");
    return handle;
};

float(string filename) TCP_ConnectFile =
{
    local float handle;

    filename = Cortex_TrimUriString(filename);
    handle = fopen(filename, FILE_APPEND);
    if (handle < 0)
        return -1;

    fputs(handle, "--- CORTEX SESSION START ---\n");
    return handle;
};

float(string filename) TCP_ConnectFileNoMarker =
{
    local float handle;

    filename = Cortex_TrimUriString(filename);
    handle = fopen(filename, FILE_APPEND);
    if (handle < 0)
        return -1;

    return handle;
};

void(float socket, string buffer) TCP_Send =
{
    if (socket >= 0)
        fputs(socket, buffer);
};

void(float socket) TCP_CloseQuiet =
{
    if (socket < 0)
        return;

    fclose(socket);
};

void(float socket) TCP_Close =
{
    if (socket < 0)
        return;

    fputs(socket, "--- CORTEX SESSION END ---\n");
    fclose(socket);
};
