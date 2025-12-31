# Cortex Modes (Pure Focus)

Project Cortex currently focuses on a single mode: the pure QuakeC bot (no Python).

## Pure QuakeC Bot (No Python)

Run:
- `scripts\run_pure_qc.bat` (builds and launches)
- `scripts\run_pure_debug.bat` (full logs + rotation)

Key cvars:
- `cortex_bot_enable 1`
- `cortex_spawn_bot 1`
- `cortex_pure_mode 1`
- `pr_no_playerphysics 0`

Code locations:
- Bot AI: `quakec/cortex/bot/`
- Sensors + world hooks: `quakec/cortex/common/`

## Archived Hybrid Experiments

Hybrid Python/IPC modes are archived and not the current focus. See:
- `hybrids/README.md`
- `docs/TCP_MODE.md`
- `docs/DARKPLACES_PIVOT.md`
