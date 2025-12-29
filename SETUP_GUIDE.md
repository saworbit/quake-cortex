# Project Cortex - Quick Setup Guide

⚠️ **Current Status**: Telemetry pipeline is still being debugged. This guide documents the manual setup process.

📚 **See Also**:
- [README.md](README.md) - Project overview and current status
- [KNOWN_ISSUES.md](KNOWN_ISSUES.md) - Detailed troubleshooting
- [NEXT_STEPS.md](NEXT_STEPS.md) - What to try next

---

## First-Time Setup (Every Time You Launch)

When you run the test harness or manually launch Quake, follow these steps:

### 1. Open Quake Console
- Press **Shift+Esc** (or just **`** on some keyboards)

### 2. Enable File Access
```
sv_progsaccess 2
```
This allows the Cortex AI to write telemetry data to files.

### 3. Restore Controls
```
exec default.cfg
```
This restores WASD movement controls (new mod folders don't inherit keybindings).

### 4. Close Console
- Press **Esc**

### 5. Start New Game
- Click: **Single Player** → **New Game**
- Select any episode (e1m1 recommended for testing)

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
🧠 Cortex Brain: Monitoring telemetry file...
📨 Telemetry received: Player Location: (x, y, z)
```

---

## Troubleshooting

### "Unknown command 'sv_progsaccess'"
- You typed it in the wrong place. Must be in the **console** (Shift+Esc), not the menu.

### WASD doesn't work
- Run `exec default.cfg` in the console
- Make sure you pressed the correct keys (not arrow keys)

### No CORTEX messages in console
- Did you set `sv_progsaccess 2`?
- Check that `Game/cortex/progs.dat` exists (~350KB)
- Try typing `version` in console - should show "FTEQW" or "FTE"

### No telemetry in Python
- Did you start a **NEW** game? (not load a save)
- Is the Python brain running?
- Move around in-game to generate position updates

---

## Quick Test Command

Run this to launch everything:
```bash
python test_cortex_connection.py
```

The script will guide you through the manual setup steps!
