# PROJECT CORTEX (Current: File-Based IPC)

Project Cortex is an experimental “sidecar” AI architecture for Quake 1:
- QuakeC emits telemetry (sensor data)
- Python tails a telemetry file and prints/visualizes it

This repo previously contained a TCP/JSON prototype; the current implementation is **file-based** because QuakeC networking is heavily restricted in FTEQW.

## Architecture

```
┌───────────────┐          appends lines          ┌────────────────────┐
│   QUAKE/FTEQW  │ ─────────────────────────────▶ │       PYTHON        │
│ (QuakeC progs) │   Game/cortex/data/*.txt       │ (brain/visualizer)  │
└───────────────┘                                 └────────────────────┘
```

Telemetry file (expected):
- `Game/cortex/data/cortex_telemetry.txt`

Note: FTEQW typically restricts QuakeC file writes to the mod’s `data/` folder, even if QuakeC opens `"cortex_telemetry.txt"` directly.

## How to Run

### 1) Build QuakeC

`scripts\\build.bat`

This produces `Game/cortex/progs.dat`.

### 2) Start Python (choose one)

- Logger: `scripts\\run_brain.bat`
- Visualizer: `scripts\\run_visualizer.bat` (requires `pip install pygame`)

### 3) Launch Quake

`scripts\\run_quake.bat`

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

- Ensure you’re actually in a map: `map start`
- Verify the file exists and changes: `Game/cortex/data/cortex_telemetry.txt`

## Legacy TCP Prototype

The `python/` folder contains older TCP-based scripts (`python/cortex_brain.py`, `python/cortex_visualizer.py`). The current entrypoints are the repo-root `cortex_brain.py` and `cortex_visualizer.py`.
