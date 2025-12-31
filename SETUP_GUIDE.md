# Project Cortex - Pure Bot Setup Guide

This guide covers the pure QuakeC bot only (no Python). Archived hybrid experiments live in `hybrids/`.

## Quick Start

- `scripts\build_pure.bat`
- `scripts\run_pure_qc.bat`
- `scripts\run_pure_debug.bat`

## In-Game Basics

- Load a map: `map dm3` or `map start`
- Enable the bot: `cortex_bot_enable 1`
- Auto-spawn: `cortex_spawn_bot 1` (or use `impulse 200`)
- Default binds: `Game\cortex_pure\default.cfg`

## Troubleshooting

**WASD does not work**
- Confirm `Game\cortex_pure\default.cfg` exists
- The pure launchers set binds automatically

**Bot does not spawn**
- Make sure you are in a map (menus do not run QuakeC)
- Verify `cortex_bot_enable 1`

**Bot does not move**
- Ensure `pr_no_playerphysics 0`
- Use `scripts\run_pure_debug.bat` to force the setting

**Logs**
- Check `Game\cortex_pure\qconsole.log`

## See Also

- `docs/BOTS_GUIDE.md`
- `docs/DEBUGGING_PURE_BOT.md`
- `KNOWN_ISSUES.md`
