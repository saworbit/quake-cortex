# Project Cortex - Quick Start

## 30-Second Setup (File IPC)

### Step 1: Build the Mod

`scripts\\build.bat`

### Step 2: Start the Brain

`scripts\\run_brain.bat`

You should see:
```
[BRAIN] BOOT | logger_initialized | {"log_file":"...\\cortex_brain_<timestamp>.log"}
[BRAIN] IO | monitoring_telemetry_file | {"path":"...\\Game\\cortex\\data\\cortex_telemetry.txt",...}
[BRAIN] IO | waiting_for_quake
```

### Step 3: Launch Quake

`scripts\\run_quake.bat`

If Quake prints `CORTEX: Telemetry disabled...`, open the console and run:
```
sv_progsaccess 2
```

### Step 4: Verify Telemetry

- Quake console: `CORTEX: Telemetry file opened! (data/cortex_telemetry.txt)`
- Python: check the generated `cortex_brain_<timestamp>.log` for NDJSON packets / parsed telemetry

Note: telemetry won’t appear until you’re in an actual map (menus don’t run QuakeC). Use `map start`/`map e1m1` if needed.

Telemetry format: newline-delimited JSON (NDJSON). The tools also accept the older `POS: 'x y z'` format.

## TCP Stream + RL (Experimental)

1. Install deps: `pip install -r python/requirements.txt`
2. Launch Quake: `scripts\\run_quake_tcp.bat`
3. Train: `python train_cortex.py`

Guide: `docs/TCP_MODE.md`

If Quake shows a black screen and exits in TCP mode, check:
- `Game\\cortex\\qconsole.log` (some builds write `Game\\qconsole.log`)
- the latest `cortex_brain_tcp_*.log`

## Visual Debug Mode (Optional)

`scripts\\run_visualizer.bat`

Requires:
`pip install pygame`

If `pip install pygame` fails (common on very new Python versions that don't have wheels yet), run in text mode instead:
`python cortex_visualizer.py --text`

## Common Issues

**No `progs.dat` / mod doesn't load**
- Confirm `Game/cortex/progs.dat` exists and is recent

**No telemetry file created**
- Confirm you're running `-game cortex`
- Set `sv_progsaccess 2` in console

**Python shows no data**
- Ensure you're in a map: `map start`
- Check `Game/cortex/data/cortex_telemetry.txt`
