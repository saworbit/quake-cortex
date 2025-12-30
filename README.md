# PROJECT CORTEX

**AI Agent for Quake 1 using Reinforcement Learning**

*"Do not cheat. Perceive, Predict, Perform."*

[![Build QuakeC](https://github.com/saworbit/quake-cortex/actions/workflows/build-quakec.yml/badge.svg?branch=main)](https://github.com/saworbit/quake-cortex/actions/workflows/build-quakec.yml)
[![Documentation Check](https://github.com/saworbit/quake-cortex/actions/workflows/docs-check.yml/badge.svg?branch=main)](https://github.com/saworbit/quake-cortex/actions/workflows/docs-check.yml)
[![Python Code Quality](https://github.com/saworbit/quake-cortex/actions/workflows/python-lint.yml/badge.svg?branch=main)](https://github.com/saworbit/quake-cortex/actions/workflows/python-lint.yml)

## Quick Start

```bash
# 1. Build the QuakeC mod
scripts\build.bat

# 2. Start the Python brain (file telemetry tail, in one terminal)
scripts\run_brain.bat

# 3. Launch Quake (file IPC mode, in another terminal)
scripts\run_quake.bat
```

**Expected Result**: Quake console shows `CORTEX: Telemetry file opened!` and Python creates `cortex_brain_<timestamp>.log` in the repo root (via `scripts\\run_brain.bat`).

Telemetry format: newline-delimited JSON (NDJSON). The tools also accept the older `POS: 'x y z'` format.

Entrypoints: `cortex_brain.py` and `cortex_visualizer.py` in the repo root.

### Experimental: TCP Stream + RL Training

This uses `tcp://` telemetry + control input instead of file IPC.

```bash
pip install -r python/requirements.txt
scripts\\run_quake_tcp.bat   # Quake connects out to a local TCP server
python train_cortex.py
```

Notes:
- Requires `pr_enable_uriget 1` (see `scripts/run_quake_tcp.bat`).
- For a simple TCP logger (no training), use `scripts\\run_brain_tcp.bat`.
- Guide: `docs/TCP_MODE.md`

## Project Structure

```
ProjectCortex/
├── cortex_brain.py             # Brain (file-based telemetry tail)
├── cortex_visualizer.py        # Visualizer (file-based telemetry)
├── cortex_env.py               # Gymnasium env wrapper (TCP server)
├── train_cortex.py             # Stable-Baselines training entrypoint
├── test_cortex_connection.py   # Guided end-to-end test
│
├── 📁 docs/                    # Documentation
│   ├── README.md              # Full technical documentation
│   ├── QUICKSTART.md          # Quick setup guide
│   └── STATUS.md              # Implementation status
│
├── 📁 python/                  # Python AI Brain
│   ├── cortex_env.py          # Gymnasium env (TCP server)
│   ├── cortex_brain.py        # TCP telemetry logger (debug)
│   └── requirements.txt       # Python dependencies
│
├── 📁 quakec/                  # QuakeC Source Code
│   ├── 📁 cortex/             # Cortex mod code
│   │   ├── cortex_sensor.qc   # Sensor suite (raycasts, state)
│   │   ├── cortex_bridge.qc   # Telemetry + control driver
│   │   ├── cortex_tcp.qc      # File/TCP stream wrappers (FTE `fopen`)
│   │   ├── cortex_config.qc   # Compiler configuration
│   │   └── cortex_world.qc    # Game loop integration
│   ├── 📁 lib/                # Third-party libraries
│   │   ├── Quake-master/      # Base QuakeWorld source
│   │   └── fteqw-master/      # FTEQW engine source
│   ├── progs.src              # Compiler manifest
│   └── fteqcc64.exe           # QuakeC compiler
│
├── 📁 Game/                    # Quake Runtime Environment
│   ├── fteqw64.exe            # FTEQW engine (⚠️ you must provide)
│   ├── 📁 cortex/             # Cortex mod runtime
│   │   └── progs.dat          # Compiled QuakeC (generated)
│   └── 📁 id1/                # Base Quake data (⚠️ you must provide)
│       ├── PAK0.PAK           # From legal Quake copy
│       └── PAK1.PAK           # From legal Quake copy
│
├── 📁 scripts/                 # Build & Run Scripts
│   ├── build.bat              # Compile QuakeC
│   ├── run_brain.bat          # Start Python brain
│   ├── run_brain_tcp.bat      # Start TCP debug brain
│   ├── run_visualizer.bat     # Start visual debugger
│   ├── run_quake.bat          # Launch Quake client
│   ├── run_quake_tcp.bat      # Launch Quake (TCP stream mode)
│   └── run_train.bat          # Train PPO agent
│
└── README.md                   # This file
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
scripts\run_visualizer.bat # Terminal 1 (requires pygame)
scripts\run_quake.bat      # Terminal 2
```

### Editing Code

**QuakeC (Game Logic)**:
- Edit files in [quakec/cortex/](quakec/cortex/)
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

**Design Philosophy**: Quake is a "dumb terminal" that collects sensor data. Python is the "brain" that makes all decisions. This allows us to use modern ML frameworks without being limited by QuakeC.

## Key Files

| File | Purpose | Lines |
| --- | --- | --- |
| [cortex_brain.py](cortex_brain.py) | Brain (file-based telemetry) | ~120 |
| [cortex_visualizer.py](cortex_visualizer.py) | Telemetry visualizer (file-based) | ~200 |
| [quakec/cortex/cortex_sensor.qc](quakec/cortex/cortex_sensor.qc) | Sensor suite | ~180 |
| [quakec/cortex/cortex_bridge.qc](quakec/cortex/cortex_bridge.qc) | Telemetry driver (file IPC) | ~120 |
| [quakec/progs.src](quakec/progs.src) | Build manifest | ~35 |

## Documentation

- **[docs/README.md](docs/README.md)** - Full technical documentation
- **[docs/QUICKSTART.md](docs/QUICKSTART.md)** - 30-second setup guide
- **[docs/STATUS.md](docs/STATUS.md)** - Implementation status & roadmap

## Requirements

**QuakeC Compilation**:
- FTEQW compiler (✅ included: `quakec/fteqcc64.exe`)

**Python**:
- Python 3.7+ (no dependencies for basic mode)
- Optional: `pygame` for visual debugger

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
- Look for `CORTEX: Engine reports FRIK_FILE support` (if it says NO FRIK_FILE, file I/O won't work)

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

- Brain (Python): `cortex_brain_<unix_ts>.log` (DEBUG, created in the working directory)
- Body (Quake): `Game\\qconsole.log` (enable `condebug 1`, already set in `scripts\\run_quake.bat`)
- Guide: `docs/LOGGING.md`

## Contributing

This is an experimental research project. The codebase is organized for clarity:

- **Add new sensors**: Edit [quakec/cortex/cortex_sensor.qc](quakec/cortex/cortex_sensor.qc)
- **Modify communication**: Edit [quakec/cortex/cortex_bridge.qc](quakec/cortex/cortex_bridge.qc)
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
