# TCP Stream Mode (Experimental)

TCP stream mode replaces File IPC with a local `tcp://` stream so the Brain can both:
- receive telemetry (NDJSON), and
- send control commands back to Quake.

This is required for RL training (`train_cortex.py` / `python/cortex_env.py`).

## Prerequisites

- Build the mod: `scripts\\build.bat`
- Provide Quake data: `Game\\id1\\PAK0.PAK`
- Provide engine binary: `Game\\fteqw64.exe`

## Important Security Setting (`pr_enable_uriget`)

FTE gates URI streams (including `tcp://`) behind `pr_enable_uriget`.

TCP mode will not work unless:
```
pr_enable_uriget 1
```

`scripts\\run_quake_tcp.bat` sets this automatically.

## Quick Start (TCP Debug Logger)

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
- Quake console prints `CORTEX: Connected Cortex stream (tcp://)`

## RL Training (Stable Baselines 3)

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

## Controls Protocol (Current)

Brain -> Quake (one JSON object per line):
```
{"aim":[yaw_delta,pitch_delta],"move":[forward,side],"buttons":N}\n
```

- `buttons` is a bitmask: `1=attack`, `2=jump`
- Values are interpreted as degrees (aim deltas) and Quake-units/sec-ish (move vectors), then applied each frame.

## Debugging

### Quake shows a black screen then closes

Common causes:
- Missing `Game\\id1\\PAK0.PAK`
- Engine can’t initialize video/audio on your system
- Mod failed to load `progs.dat`

What to check:
- `scripts\\run_quake_tcp.bat` prints an exit code and points at `Game\\qconsole.log` (if created)
- Try File IPC mode to confirm the engine works at all: `scripts\\run_quake.bat`

### Python shows `utf-8 codec can't decode ...`

This is handled in current builds (TCP brain decodes bytes per-line with replacement), but if you still see issues:
- Confirm you pulled latest `main`
- Use `scripts\\run_brain_tcp.bat` (not older copies)

### TCP connects, but controls don’t work

Controls require extra QuakeC string builtins on some engines (`FTE_STRINGS`).

If your engine doesn’t provide them, Quake will print:
- `CORTEX: Controls disabled (missing FTE_STRINGS)`

Workarounds:
- Use File IPC mode for telemetry-only workflows
- Swap to an FTE build with `FTE_STRINGS` enabled
- Temporarily disable control mode: set `cortex_enable_controls 0`

