# Project Cortex - Quick Setup Guide

Project Cortex supports two modes:
- **File IPC (default)**: QuakeC appends telemetry to `data/cortex_telemetry.txt`, Python tails it.
- **TCP Stream (experimental)**: QuakeC connects to `tcp://127.0.0.1:26000` and exchanges NDJSON for telemetry + controls.

📚 **See Also**:
- [README.md](README.md) - Project overview and current status
- [KNOWN_ISSUES.md](KNOWN_ISSUES.md) - Detailed troubleshooting
- [NEXT_STEPS.md](NEXT_STEPS.md) - What to try next

---

## Mode A: File IPC (Recommended)

Recommended launch:
- `scripts\\run_brain.bat`
- `scripts\\run_quake.bat`

If you run things manually, follow these steps:

### 1. Open Quake Console
- Press **Shift+Esc** (or just **`** on some keyboards)

### 2. Enable File Access (If Needed)
```
sv_progsaccess 2
```
This allows the Cortex AI to write telemetry data to files.

WASD bindings are now provided by `Game/cortex/default.cfg`, so you typically do **not** need to `exec default.cfg` manually.

### 4. Close Console
- Press **Esc**

### 5. Start New Game
- Click: **Single Player** → **New Game**
- Select any episode (e1m1 recommended for testing)
  - Or just use `map start` from the console
  - Note: telemetry won't appear until you're actually in a map (menus don't run QuakeC)

### 6. Test Movement
- **WASD**: Move around
- **Mouse**: Look around
- **Space**: Jump

You should see telemetry flowing in the Python brain window!

Telemetry format: newline-delimited JSON (NDJSON). The tools also accept the older `POS: 'x y z'` format.

---

## What You Should See

### In Quake Console
Look for these messages when the map loads:
```
CORTEX: Initializing AI Bridge...
CORTEX: Telemetry file opened!
```

### In Python Brain Window
```
[BRAIN] BOOT | logger_initialized | {"log_file":"...\\.cortex\\logs\\cortex_brain_<timestamp>.log"}
[BRAIN] IO | monitoring_telemetry_file | {"path":"...\\Game\\cortex\\data\\cortex_telemetry.txt",...}
```

---

## Troubleshooting

### "Unknown command 'sv_progsaccess'"
- You typed it in the wrong place. Must be in the **console** (Shift+Esc), not the menu.

### WASD doesn't work
- Verify `Game/cortex/default.cfg` exists (it provides bindings for fresh mod folders)
- If you have a custom `config.cfg` overriding binds, re-bind keys or temporarily `exec default.cfg`

### No CORTEX messages in console
- Did you set `sv_progsaccess 2`?
- Check that `Game/cortex/progs.dat` exists (~350KB)
- Try typing `version` in console - should show "FTEQW" or "FTE"
- If you see `CORTEX: Engine reports NO FRIK_FILE support`, this engine build won't allow QuakeC file I/O

### No telemetry in Python
- Did you start a **NEW** game? (not load a save)
- Is the Python brain running?
- Move around in-game to generate position updates
- Confirm the telemetry file exists at `Game/cortex/data/cortex_telemetry.txt`

---

## Mode B: TCP Stream + Control Input (Experimental)

Use this for RL training and bidirectional control.

Full guide: `docs/TCP_MODE.md`

### Recommended: idiot-proof launcher (debug)

This starts both windows (Brain + Quake) and does not require any pip installs:
- `scripts\\run_mode_b_debug.bat`

### Training / RL

If you are training (SB3 / Gymnasium), install deps first:
```
pip install -r python/requirements.txt
```

Then:
- Quake: `scripts\\run_quake_tcp.bat`
- Brain/training: `python train_cortex.py`

This enables:
- `pr_enable_uriget 1` (required for `fopen("tcp://...", -1)` in FTE)
- `cortex_use_tcp 1` (switch Cortex from file IPC to TCP stream)
- `cortex_enable_controls 1` (allow Brain -> Body control updates)

If Quake crashes on launch in TCP mode, try disabling controls first to isolate stream issues:
- Set `cortex_enable_controls 0` (or temporarily edit `scripts\\run_quake_tcp.bat`)

### If you get a black screen then Quake exits

Check `Game\\cortex\\qconsole.log` (some builds write `Game\\qconsole.log`) and the latest `.cortex\\logs\\cortex_brain_tcp_*.log` for the exact failure reason.

---

## Quick Test Command

Run this to launch everything:
```bash
python test_cortex_connection.py
```

The script will guide you through the manual setup steps!
