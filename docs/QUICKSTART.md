# Project Cortex - Quick Start (Pure QuakeC Bot)

1. Build: `scripts\build_pure.bat`
2. Run: `scripts\run_pure_qc.bat` (default `deathmatch 1` + `map dm3`)
3. Debug: `scripts\run_pure_debug.bat`

Tip: you can override the map or deathmatch settings with extra args, for example:
```
scripts\run_pure_qc.bat +set deathmatch 1 +map dm4
```

## Common Issues

**Bot does not spawn**
- Make sure you are in a map (menus do not run QuakeC)
- Verify `cortex_bot_enable 1`

**Bot does not move**
- Ensure `pr_no_playerphysics 0` (pure launchers set this)

**Movement keys do not work**
- Confirm `Game\cortex_pure\default.cfg` exists
- The pure launchers apply basic binds automatically

## Archived Hybrid Modes

Hybrid Python/IPC modes are archived and not the current focus. See `hybrids/README.md` if you need legacy notes.
