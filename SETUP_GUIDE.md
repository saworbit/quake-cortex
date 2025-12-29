# Project Cortex - Quick Setup Guide

**Current Status**: Telemetry is file-based and should work end-to-end; some FTEQW builds still require manually setting `sv_progsaccess 2` in the console.

📚 **See Also**:
- [README.md](README.md) - Project overview and current status
- [KNOWN_ISSUES.md](KNOWN_ISSUES.md) - Detailed troubleshooting
- [NEXT_STEPS.md](NEXT_STEPS.md) - What to try next

---

## First-Time Setup (Each Launch)

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
[CORTEX BRAIN] Monitoring telemetry file: ...Game/cortex/data/cortex_telemetry.txt
[POS] X=... Y=... Z=...
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

## Quick Test Command

Run this to launch everything:
```bash
python test_cortex_connection.py
```

The script will guide you through the manual setup steps!
