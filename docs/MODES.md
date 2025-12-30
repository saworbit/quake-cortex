# Cortex Modes (Repo Organization)

This repo contains three “tracks” that share the same QuakeC mod:

1. **Pure QuakeC bot** (no Python): bot logic runs inside QuakeC.
2. **Hybrid FTEQW + Python**: QuakeC emits telemetry and (optionally) accepts controls from Python.
3. **Hybrid DarkPlaces + Python (RCON)**: Python drives a server-side `cortex_bot` via UDP RCON.

## 1) Pure QuakeC Bot (no Python)

Run:
- `scripts\\build.bat`
- `scripts\\run_pure_qc.bat`

Key cvars:
- `cortex_bot_enable 1` (enable internal AI)
- `cortex_spawn_bot 1` (spawn bot entity/client slot depending on engine support)

Code:
- QuakeC AI: `quakec/cortex/bot/`
- Sensors/world hooks: `quakec/cortex/common/`

## 2) Hybrid FTEQW + Python

### A) File IPC (default)

Run:
- `scripts\\build.bat`
- Terminal 1: `scripts\\run_brain.bat`
- Terminal 2: `scripts\\run_quake.bat`

Code:
- QuakeC telemetry + integration: `quakec/cortex/hybrid/` + `quakec/cortex/common/`
- Python file-tail brain: `python/streams/file/` (repo-root `cortex_brain.py` is a wrapper)

### B) Stream mode (ws:// / tcp://) + RL (experimental)

Run:
- `pip install -r python/requirements.txt`
- Terminal 1: `scripts\\run_quake_tcp.bat`
- Terminal 2: `python train_cortex.py`

Debug logger only (no training):
- `scripts\\run_mode_b_debug.bat` (or `scripts\\run_brain_tcp.bat` + `scripts\\run_quake_tcp.bat`)

Code:
- Python stream logger: `python/streams/tcp/brain_tcp.py`
- Gymnasium env: `python/streams/tcp/env.py`

Key cvars (set by `scripts\\run_quake_tcp.bat`):
- `pr_enable_uriget 1`
- `cortex_use_tcp 1`
- `cortex_enable_controls 1`

## 3) Hybrid DarkPlaces + Python (RCON)

Run:
- `scripts\\build.bat`
- Terminal 1: `scripts\\run_darkplaces.bat`
- Terminal 2: `scripts\\run_brain_rcon.bat`

Docs:
- `docs/DARKPLACES_PIVOT.md`

Code:
- Python RCON loop: `python/streams/rcon/brain_rcon.py` (repo-root `cortex_rcon.py` is the entrypoint)
- QuakeC bot entity: `quakec/cortex/bot/cortex_bot.qc`

