# PROJECT CORTEX

Project Cortex is an experimental “sidecar” AI architecture for Quake 1:
- QuakeC emits telemetry (sensor data)
- Python tails a telemetry file and prints/visualizes it

Default mode is **file-based** IPC because QuakeC networking is often restricted in FTEQW. An experimental TCP stream mode is also supported for RL training/control loops.

## Architecture

```
┌───────────────┐          appends lines          ┌────────────────────┐
│   QUAKE/FTEQW  │ ─────────────────────────────▶ │       PYTHON        │
│ (QuakeC progs) │   Game/cortex/data/*.txt       │ (brain/visualizer)  │
└───────────────┘                                 └────────────────────┘
```

Telemetry file (expected):
- `Game/cortex/data/cortex_telemetry.txt`

TCP stream (experimental):
- QuakeC connects to `tcp://127.0.0.1:26000` (requires `pr_enable_uriget 1`)
- Python runs a local server (`python train_cortex.py` or `scripts\\run_brain_tcp.bat`)

Note: FTEQW typically restricts QuakeC file writes to the mod’s `data/` folder, even if QuakeC opens `"cortex_telemetry.txt"` directly.

## How to Run

### 1) Build QuakeC

`scripts\\build.bat`

This produces `Game/cortex/progs.dat`.

### 2) Start Python (choose one)

- Logger: `scripts\\run_brain.bat`
- Visualizer: `scripts\\run_visualizer.bat` (requires `pip install pygame`)
- TCP logger (experimental): `scripts\\run_brain_tcp.bat`

### 3) Launch Quake

`scripts\\run_quake.bat`

Or TCP stream mode:

`scripts\\run_quake_tcp.bat`

Expected Quake console messages:
- `CORTEX: Initializing AI Bridge...`
- `CORTEX: Telemetry file opened! (data/cortex_telemetry.txt)`

Expected Python output:
- `[CORTEX] --- CORTEX SESSION START ---`
- `[POS] X=... Y=... Z=...`

## Troubleshooting

### `CORTEX: Telemetry disabled...`

- Open the Quake console and run `sv_progsaccess 2`
  - Some FTEQW builds do not honor cfg/`+set` for this cvar
- If Quake prints `CORTEX: Engine reports NO FRIK_FILE support`, that engine build won’t allow QuakeC file I/O

### Python shows no data

- Ensure you’re actually in a map (menus don’t run QuakeC): `map start` or `map e1m1`
- Verify the file exists and changes: `Game/cortex/data/cortex_telemetry.txt`

## Python Modules

The repo-root entrypoints are `cortex_brain.py` and `cortex_visualizer.py`. The `python/` package contains RL/training modules (including `python/cortex_env.py`) and a simple TCP debug server (`python/cortex_brain.py`).

## Archive

- Development notes: `docs/archive/SESSION_SUMMARY_2025-12-29.md`
