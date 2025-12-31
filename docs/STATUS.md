# Project Cortex - Implementation Status

**Last Updated**: 2026-01-01
**Current Phase**: Pure bot stabilization (movement + behavior)

## What Works

### Pure QuakeC Bot
- [x] QuakeC compiles to `Game/cortex_pure/progs.dat`
- [x] Internal bot AI stack behind `cortex_bot_enable 1`
- [x] Sensor suite (raycasts, proprioception, enemy detection)
- [x] World integration hooks
- [x] Runs on FTEQW engine

## Known Gaps (Active)

- [ ] Movement binds not applied in some pure mode setups
- [ ] Bot movement target selection can resolve to zero vector
- [ ] Death animation can be skipped on respawn

## File Manifest (Pure)

| Path | Purpose |
| --- | --- |
| `quakec/cortex/bot/cortex_bot.qc` | Main bot AI logic |
| `quakec/cortex/bot/cortex_pathfinding.qc` | Navigation + pathfinding |
| `quakec/cortex/common/cortex_sensor.qc` | Sensors + world probes |
| `quakec/cortex/common/cortex_world.qc` | World integration hooks |
| `quakec/progs.src` | Build manifest |
| `scripts/build_pure.bat` | Compile pure QuakeC mod |
| `scripts/run_pure_qc.bat` | Launch pure bot |
| `scripts/run_pure_debug.bat` | Launch pure bot with debug logs |
| `Game/cortex_pure/default.cfg` | Default binds |
| `docs/DEBUGGING_PURE_BOT.md` | Pure bot debugging guide |

## Next Steps

- Fix pure-mode binds and movement cvars across FTEQW builds
- Improve bot goal selection + stuck recovery
- Stabilize respawn timing so death animations can play
