# PROJECT CORTEX

**AI Agent for Quake 1 using Reinforcement Learning**

*"Do not cheat. Perceive, Predict, Perform."*

[![Build QuakeC](https://github.com/saworbit/quake-cortex/actions/workflows/build-quakec.yml/badge.svg?branch=main)](https://github.com/saworbit/quake-cortex/actions/workflows/build-quakec.yml)
[![Documentation Check](https://github.com/saworbit/quake-cortex/actions/workflows/docs-check.yml/badge.svg?branch=main)](https://github.com/saworbit/quake-cortex/actions/workflows/docs-check.yml)
[![Python Code Quality](https://github.com/saworbit/quake-cortex/actions/workflows/python-lint.yml/badge.svg?branch=main)](https://github.com/saworbit/quake-cortex/actions/workflows/python-lint.yml)

## Quick Start (Pick a Mode)

```bash
# 1) Build the QuakeC mod (all modes)
scripts\build.bat
```

### Pure QuakeC Bot (no Python)

```bash
scripts\run_pure_qc.bat
```

### Hybrid FTEQW + Python (File IPC)

```bash
scripts\run_brain.bat
scripts\run_quake.bat
```

### Hybrid FTEQW + Python (Stream + RL)

```bash
pip install -r python/requirements.txt
scripts\run_quake_tcp.bat
python train_cortex.py
```

### Hybrid DarkPlaces + Python (RCON)

```bash
scripts\run_darkplaces.bat
scripts\run_brain_rcon.bat
```

Details: `docs/MODES.md`

**Expected Result (File IPC)**: Quake console shows `CORTEX: Telemetry file opened!` and Python creates `.cortex\logs\cortex_brain_<timestamp>.log`.

Telemetry format: newline-delimited JSON (NDJSON). The tools also accept the older `POS: 'x y z'` format.

Engines: tested with **FTEQW** (`Game\fteqw64.exe`) and **DarkPlaces** (`Game\darkplaces.exe`). Stream mode is primarily FTEQW-focused; RCON mode is primarily DarkPlaces-focused.

Entrypoints: `cortex_brain.py` / `cortex_visualizer.py` (File IPC), `train_cortex.py` (stream + RL), `cortex_rcon.py` (DarkPlaces RCON), `scripts\run_pure_qc.bat` (pure QuakeC bot).

## Project Structure

```text
ProjectCortex/
  cortex_brain.py              # File IPC brain entrypoint (wrapper)
  cortex_visualizer.py         # File IPC visualizer entrypoint (wrapper)
  cortex_env.py                # RL env entrypoint (wrapper)
  cortex_rcon.py               # DarkPlaces RCON entrypoint (wrapper)
  train_cortex.py              # RL training entrypoint (stream mode)
  docs/                        # Mode docs + deep dives
  python/                      # Python implementations (per mode)
    file_ipc/                  # file tail + visualizer
    fteqw_stream/              # ws/tcp stream + env
    darkplaces_rcon/           # UDP RCON control loop
  quakec/                      # QuakeC sources
    cortex/
      common/                  # sensors + world integration
      hybrid/                  # file/stream IPC driver
      bot/                     # pure-QuakeC bot AI stack
    progs.src
  Game/                        # runtime (you provide engine + PAKs)
  scripts/                     # build/run helpers per mode
```


## Current Status: Phase 2 - Telemetry + Control Loop

**What Works:**
- ✅ QuakeC code compiles successfully
- ✅ Switched from QuakeWorld to single-player Quake source
- ✅ NDJSON telemetry emitted (health/armor/ammo/pos/vel/lidar/enemies)
- ✅ File IPC mode (default) + optional TCP stream mode (`pr_enable_uriget 1`)
- ✅ Minimal Brain → Body control loop over TCP (`cortex_enable_controls 1`)
- ✅ Gymnasium env wrapper + SB3 training entrypoint (`train_cortex.py`)
- ✅ Automated test harness created

**Current Blockers:**
- ⚠️ Episode/reset semantics for RL training (Quake is not yet headless/episodic)
- ⚠️ Protocol version + sequence IDs (robust sync)
- ⚠️ Smoothing/rate limiting for more human-like movement

**See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) for detailed troubleshooting**

**Next Steps:**
- See the roadmap in [NEXT_STEPS.md](NEXT_STEPS.md)
- Run `python test_cortex_connection.py` to validate the pipeline
- If telemetry is missing, confirm the file exists at `Game/cortex/data/cortex_telemetry.txt`
- Try TCP stream mode: `scripts\\run_quake_tcp.bat` + `python train_cortex.py`

## Development Workflow

### Building the Mod

```bash
cd ProjectCortex
scripts\build.bat
```

This compiles `quakec/**/*.qc` → `Game/cortex/progs.dat`

### Running the System

**Option 1: Simple Logger**
```bash
scripts\run_brain.bat      # Terminal 1
scripts\run_quake.bat      # Terminal 2
```

**Option 2: Visual Debugger**
```bash
scripts\run_visualizer.bat # Terminal 1 (requires `pip install -r python/requirements-visualizer.txt`; fallback: `python cortex_visualizer.py --text`)
scripts\run_quake.bat      # Terminal 2
```

### Editing Code

**QuakeC (Game Logic)**:
- Edit files in [quakec/cortex/](quakec/cortex/) (see `common/`, `hybrid/`, `bot/`)
- Run [scripts/build.bat](scripts/build.bat) to recompile
- Restart Quake to load new progs.dat

**Python (AI Brain)**:
- Edit files in [python/](python/)
- Restart the Python script
- No Quake restart needed

## Architecture

```
┌──────────────────┐         ┌──────────────────┐
│   QUAKE CLIENT   │  FILE   │   PYTHON BRAIN   │
│   (The Body)     │ ◄────►  │   (The Mind)     │
│                  │  JSON   │                  │
│  • Raycasts      │         │  • Neural Nets   │
│  • Velocity      │         │  • Decision AI   │
│  • Health/Ammo   │         │  • LLM Chat      │
└──────────────────┘         └──────────────────┘
     60 Hz updates              <1ms latency
```

**Design Philosophy**: Cortex supports both:
- a **pure QuakeC bot** (decisions inside QuakeC, zero external dependencies), and
- **hybrid modes** where QuakeC acts as the ?body? (sensors + actuation) and Python is the ?brain? (decision-making, logging, RL training).

## Key Files

| File | Purpose | Lines |
| --- | --- | --- |
| [cortex_brain.py](cortex_brain.py) | File IPC brain entrypoint | ~20 |
| [python/file_ipc/brain.py](python/file_ipc/brain.py) | File IPC implementation | ~200 |
| [cortex_visualizer.py](cortex_visualizer.py) | File IPC visualizer entrypoint | ~20 |
| [python/file_ipc/visualizer.py](python/file_ipc/visualizer.py) | File IPC visualizer implementation | ~200 |
| [python/fteqw_stream/env.py](python/fteqw_stream/env.py) | RL env (stream mode) | ~250 |
| [python/fteqw_stream/brain_tcp.py](python/fteqw_stream/brain_tcp.py) | Stream logger (debug) | ~350 |
| [python/darkplaces_rcon/brain_rcon.py](python/darkplaces_rcon/brain_rcon.py) | DarkPlaces RCON loop | ~200 |
| [quakec/cortex/common/cortex_sensor.qc](quakec/cortex/common/cortex_sensor.qc) | Sensor suite | ~200 |
| [quakec/cortex/hybrid/cortex_bridge.qc](quakec/cortex/hybrid/cortex_bridge.qc) | Hybrid telemetry/control driver | ~200 |
| [quakec/cortex/bot/cortex_bot.qc](quakec/cortex/bot/cortex_bot.qc) | Pure QuakeC bot AI | ~1400 |
| [quakec/progs.src](quakec/progs.src) | Build manifest | ~35 |


## Documentation

- **[docs/MULTI_SERVER.md](docs/MULTI_SERVER.md)** - Multiplayer server hosting primer
- **[docs/ARENA.md](docs/ARENA.md)** - Bot-vs-bot arena + spectator system
- **[docs/MODES.md](docs/MODES.md)** - Choose a mode + repo layout
- **[docs/README.md](docs/README.md)** - Full technical documentation
- **[docs/QUICKSTART.md](docs/QUICKSTART.md)** - 30-second setup guide
- **[docs/STATUS.md](docs/STATUS.md)** - Implementation status & roadmap

## Requirements

**QuakeC Compilation**:
- FTEQW compiler (✅ included: `quakec/fteqcc64.exe`)

**Python**:
- Core telemetry/brain scripts: Python 3.11+ recommended (no dependencies for basic mode)
- Optional: `pygame` for visual debugger (install via `python/requirements-visualizer.txt`; use Python 3.11/3.12 on Windows if wheels are missing)

**Quake Runtime** (⚠️ **YOU MUST PROVIDE**):
- **FTEQW Engine**: Download from [https://fte.triptohell.info/](https://fte.triptohell.info/)
  - Extract `fteqw64.exe` (or `fteqw` on Linux) to the `Game/` directory
- **Quake PAK Files**: Obtain from a legal copy of Quake 1
  - Steam: [https://store.steampowered.com/app/2310/](https://store.steampowered.com/app/2310/)
  - GOG: [https://www.gog.com/game/quake_the_offering](https://www.gog.com/game/quake_the_offering)
  - Or use the shareware `pak0.pak` from [https://www.quaddicted.com/](https://www.quaddicted.com/)
  - Place `PAK0.PAK` (and optionally `PAK1.PAK`) in `Game/id1/` directory

**Note**: Due to licensing, we cannot distribute Quake's game data or engine binaries. You must provide your own legally obtained copies.

## Troubleshooting

**Quake shows `CORTEX: Telemetry disabled...`**
- Open console and run `sv_progsaccess 2` (some builds don't honor cfg/`+set`)
- Look for `CORTEX: Engine reports DP_QC_FS` or `CORTEX: Engine reports FRIK_FILE` (if it says NO DP_QC_FS/FRIK_FILE, file I/O won't work)

**Build fails with "error" messages**
- Check that `quakec/lib/Quake-master/` exists
- Verify `quakec/fteqcc64.exe` is present
- See full error output in console

**No sensor data in Python**
- QuakeC (and telemetry) only runs once a map is loaded (menus won’t emit telemetry)
- Make sure you're IN a map (not in menu): `map start` or `map e1m1`
- Try moving around in-game
- Confirm the telemetry file exists and is growing: `Game/cortex/data/cortex_telemetry.txt`

## Cortex Black Box Logs

- Brain (Python): `.cortex\logs\cortex_brain_<timestamp>.log` (File IPC) / `.cortex\logs\cortex_brain_tcp_<timestamp>.log` (Stream)
- Body (Quake): `Game\\cortex\\qconsole.log` (some builds write `Game\\qconsole.log`; enabled via `-condebug`, already set in `scripts\\run_quake.bat`)
- Guide: `docs/LOGGING.md`

## Contributing

This is an experimental research project. The codebase is organized for clarity:

- **Add new sensors**: Edit [quakec/cortex/common/cortex_sensor.qc](quakec/cortex/common/cortex_sensor.qc)
- **Modify hybrid IPC**: Edit [quakec/cortex/hybrid/cortex_bridge.qc](quakec/cortex/hybrid/cortex_bridge.qc) and [python/file_ipc/brain.py](python/file_ipc/brain.py)
- **Hack the pure bot AI**: Edit [quakec/cortex/bot/cortex_bot.qc](quakec/cortex/bot/cortex_bot.qc)
- **Add AI features**: Edit [cortex_brain.py](cortex_brain.py)
- **Update build process**: Edit [scripts/build.bat](scripts/build.bat)

## License

- QuakeC code: GPLv2 (based on id Software's release)
- Python code: MIT License
- Documentation: CC BY 4.0

---

**Status**: Phase 2 - Telemetry + Control Loop (File IPC + optional TCP)
**Last Updated**: 2025-12-30
**Version**: 0.1.0
