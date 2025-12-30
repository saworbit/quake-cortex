# Stream Mode (Experimental)

Stream mode replaces File IPC with a local stream so the Brain can both:
- receive telemetry (NDJSON), and
- send control commands back to Quake.

This is required for RL training (`train_cortex.py` / `cortex_env.py`).

Default URI (set automatically by `scripts\\run_quake_tcp.bat`):
- `ws://127.0.0.1:26000/`

If you want to force raw sockets (not recommended on current Windows FTE builds), use:
- `tcp://127.0.0.1:26000`

If your engine build wraps streams in WebSocket framing, use (default):
- `ws://127.0.0.1:26000/`

Overrides:
- Force raw TCP once: `scripts\\run_quake_tcp.bat tcp`
- Set an explicit URI: `set CORTEX_STREAM_URI=ws://127.0.0.1:26000/` (or `tcp://...`) then run `scripts\\run_quake_tcp.bat`

## Prerequisites

- Build the mod: `scripts\\build.bat`
- Provide Quake data: `Game\\id1\\PAK0.PAK`
- Provide engine binary: `Game\\fteqw64.exe`

## Idiot-Proof Launch (Recommended)

### Debug logger (no installs)

Run this once and it opens two windows (Brain server + Quake client):
```
scripts\\run_mode_b_debug.bat
```

### Training (creates a Python 3.11 venv)

Run this once and it will:
- build QuakeC,
- create `.venv_tcp` using Python 3.11,
- install deps into that venv,
- launch Quake in a new window,
- run training in the current window.
```
scripts\\run_mode_b_train.bat
```

## Important Security Setting (`pr_enable_uriget`)

FTE gates URI streams (including `ws://` and `tcp://`) behind `pr_enable_uriget`.

TCP mode will not work unless:
```
pr_enable_uriget 1
```

`scripts\\run_quake_tcp.bat` sets this automatically.

## Manual Start (Debug Logger)

Terminal 1:
```
scripts\\run_brain_tcp.bat
```

Terminal 2:
```
scripts\\run_quake_tcp.bat
```

Success looks like:
- Python prints a client connection and then periodic `POS x=... y=... z=...`
- Quake console prints `CORTEX: Connected Cortex stream (ws://)` (or `tcp://` if you forced raw sockets)

## Manual Start (RL Training / Stable Baselines 3)

Install deps:
```
pip install -r python/requirements.txt
```

Terminal 1:
```
scripts\\run_quake_tcp.bat
```

Terminal 2:
```
python train_cortex.py
```

Notes:
- TCP training uses `cortex_enable_controls 1` so Quake applies the latest command every frame.
- The environment is a local TCP server that Quake connects to.
- If you are on a very new Python version and installs fail, use Python 3.11/3.12.

## Controls Protocol (Current)

Brain -> Quake (one JSON object per line):
```
{"aim":[yaw_delta,pitch_delta],"move":[forward,side],"buttons":N}
```

- `buttons` is a bitmask: `1=attack`, `2=jump`
- Values are interpreted as degrees (aim deltas) and Quake-units/sec-ish (move vectors), then applied each frame.

## Debugging

### Reduce background network noise (local testing)

When iterating locally, keep the engine from advertising/querying masters:
- `sv_public 0`
- `cl_master ""`

Both `scripts\\run_quake.bat` and `scripts\\run_quake_tcp.bat` set these automatically.

### Quake shows a black screen then closes

This usually means the engine aborted during startup. Start by checking the console log:
- `Game\\cortex\\qconsole.log` (some builds write `Game\\qconsole.log`)

Common causes (not Cortex-specific):
- Missing `Game\\id1\\PAK0.PAK`
- Engine can't initialize video/audio on your system
- Mod failed to load `progs.dat`

What to check:
- `scripts\\run_quake_tcp.bat` prints an exit code and points at the log file.
- Try File IPC mode to confirm the engine works at all: `scripts\\run_quake.bat`
- If Quake works in File IPC but exits in TCP mode, search `qconsole.log` for:
  - `qcfopen("ws://..."): Access denied` (that build blocked/mis-parsed `ws://`; use `tcp://` or update)
  - `CORTEX: Stream connect failed ...` (Brain not running or URI streams blocked)
  - OpenSSL/TLS errors near Cortex init (see TLS note below)

### Python shows `utf-8 codec can't decode ...`

This is handled in current builds (TCP brain decodes bytes per-line with replacement), but if you still see issues:
- Confirm you pulled latest `main`
- Use `scripts\\run_brain_tcp.bat` (not older copies)

### Brain logs `Detected TLS client hello`

Some FTE builds initiate a TLS handshake even when using `tcp://`.

If you see these errors, your engine is doing TLS verification against a self-signed localhost cert:
- Brain: `TLSV1_ALERT_UNKNOWN_CA`
- Quake: `X509_V_ERR_DEPTH_ZERO_SELF_SIGNED_CERT`

Workarounds:
- Prefer a newer FTEQW build where `tcp://` opens a raw TCP socket and `tls://` is the explicit TLS scheme.
- Use `ws://127.0.0.1:26000/` (default in `scripts\\run_quake_tcp.bat`) to avoid TLS negotiation entirely.
- If you must use `tcp://`, upgrade FTEQW (this is an engine behavior/bug, not a Python-side fix).

### Avoid weird float formatting in JSON

Some engine/printf implementations may emit scientific notation (e.g. `1e-6`) for very small/large floats.

Recommendations:
- Don’t send timestamps/IDs as floats.
- Keep numeric ranges “Quake-ish” (health/ammo/pos/vel) and clamp/round where reasonable.

### TCP connects, but controls don't work

Controls require extra QuakeC string builtins on some engines (`FTE_STRINGS`).

If your engine doesn't provide them, Quake will print:
- `CORTEX: Controls disabled (missing FTE_STRINGS)`

Workarounds:
- Use File IPC mode for telemetry-only workflows
- Swap to an FTE build with `FTE_STRINGS` enabled
- Temporarily disable control mode: set `cortex_enable_controls 0`
