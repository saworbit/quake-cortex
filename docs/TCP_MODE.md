# Stream Mode (Experimental)

Stream mode replaces File IPC with a local stream so the Brain can both:
- receive telemetry (NDJSON), and
- send control commands back to Quake.

This is required for RL training (`train_cortex.py` / `python/cortex_env.py`).

Default URI (set automatically by `scripts\\run_quake_tcp.bat`):
- `tcp://127.0.0.1:26000`

If your engine build wraps streams in WebSocket framing, use:
- `ws://127.0.0.1:26000/`

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

### Training (creates a Python 3.12 venv)

Run this once and it will:
- build QuakeC,
- create `.venv_tcp` using Python 3.12,
- install deps into that venv,
- launch Quake in a new window,
- run training in the current window.
```
scripts\\run_mode_b_train.bat
```

## Important Security Setting (`pr_enable_uriget`)

FTE gates URI streams (including `tcp://`) behind `pr_enable_uriget`.

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
- Quake console prints `CORTEX: Connected Cortex stream (tcp://)` (or `ws://` if you force websocket framing)

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
- If you are on a very new Python version and installs fail, use Python 3.12.

## Controls Protocol (Current)

Brain -> Quake (one JSON object per line):
```
{"aim":[yaw_delta,pitch_delta],"move":[forward,side],"buttons":N}
```

- `buttons` is a bitmask: `1=attack`, `2=jump`
- Values are interpreted as degrees (aim deltas) and Quake-units/sec-ish (move vectors), then applied each frame.

## Debugging

### Quake shows a black screen then closes

Common causes:
- Missing `Game\\id1\\PAK0.PAK`
- Engine can't initialize video/audio on your system
- Mod failed to load `progs.dat`

What to check:
- `scripts\\run_quake_tcp.bat` prints an exit code and points at `Game\\cortex\\qconsole.log` (some builds write `Game\\qconsole.log`)
- Try File IPC mode to confirm the engine works at all: `scripts\\run_quake.bat`

### Python shows `utf-8 codec can't decode ...`

This is handled in current builds (TCP brain decodes bytes per-line with replacement), but if you still see issues:
- Confirm you pulled latest `main`
- Use `scripts\\run_brain_tcp.bat` (not older copies)

### TCP connects, but controls don't work

Controls require extra QuakeC string builtins on some engines (`FTE_STRINGS`).

If your engine doesn't provide them, Quake will print:
- `CORTEX: Controls disabled (missing FTE_STRINGS)`

Workarounds:
- Use File IPC mode for telemetry-only workflows
- Swap to an FTE build with `FTE_STRINGS` enabled
- Temporarily disable control mode: set `cortex_enable_controls 0`
