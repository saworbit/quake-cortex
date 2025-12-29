# Project Cortex - Quick Start (File IPC)

## 30-Second Setup

### Step 1: Build the Mod

`scripts\\build.bat`

### Step 2: Start the Brain

`scripts\\run_brain.bat`

You should see:
```
[CORTEX BRAIN] Monitoring telemetry file: ...Game/cortex/data/cortex_telemetry.txt
[CORTEX BRAIN] Waiting for Quake to write data...
```

### Step 3: Launch Quake

`scripts\\run_quake.bat`

If Quake prints `CORTEX: Telemetry disabled...`, open the console and run:
```
sv_progsaccess 2
```

### Step 4: Verify Telemetry

- Quake console: `CORTEX: Telemetry file opened! (data/cortex_telemetry.txt)`
- Python: `[POS] X=... Y=... Z=...` while you move around

Note: telemetry won’t appear until you’re in an actual map (menus don’t run QuakeC). Use `map start`/`map e1m1` if needed.

## Visual Debug Mode (Optional)

`scripts\\run_visualizer.bat`

Requires:
`pip install pygame`

## Common Issues

**No `progs.dat` / mod doesn’t load**
- Confirm `Game/cortex/progs.dat` exists and is recent

**No telemetry file created**
- Confirm you’re running `-game cortex`
- Set `sv_progsaccess 2` in console

**Python shows no data**
- Ensure you’re in a map: `map start`
- Check `Game/cortex/data/cortex_telemetry.txt`
