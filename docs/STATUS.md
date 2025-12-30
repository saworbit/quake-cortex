# Project Cortex - Implementation Status

**Last Updated**: 2025-12-30
**Current Phase**: Phase 2 - Telemetry + Control Loop (File IPC + optional TCP)

## What Works

### Sidecar Architecture
- [x] QuakeC emits telemetry to a file (FTEQW `FRIK_FILE` builtins)
- [x] Python tails telemetry and writes structured logs (Brain timeline)
- [x] Optional pygame visualizer

### Sensor Suite (Current Output)
- [x] NDJSON telemetry (`health/armor/ammo/pos/vel/lidar/enemies`) at configurable rate (`cortex_send_interval`)

### QuakeC Integration
- [x] Initialization moved to StartFrame (avoids cfg timing issues)
- [x] Automatic retry loop until file access is enabled
- [x] Engine capability hints printed (`FRIK_FILE` / `pr_checkextension`)
- [x] Optional TCP stream transport (`cortex_use_tcp 1`, requires `pr_enable_uriget 1`)
- [x] Optional Brain -> Body controls over TCP (`cortex_enable_controls 1`)

### Usability / Automation
- [x] Default keybinds provided in `Game/cortex/default.cfg`
- [x] `sv_progsaccess 2` re-asserted in `Game/cortex/autoexec.cfg` (may still require manual console entry depending on engine build)
- [x] `scripts\\run_quake.bat` launches into `map start`
- [x] `scripts\\run_quake_tcp.bat` launches TCP stream mode
- [x] `scripts\\run_train.bat` runs a Stable-Baselines training loop

## File Manifest (Current)

| Path | Purpose |
| --- | --- |
| `cortex_brain.py` | File telemetry brain (tail + parse) |
| `cortex_visualizer.py` | File telemetry visualizer (pygame/text) |
| `cortex_env.py` | Gymnasium environment wrapper (TCP server) |
| `train_cortex.py` | PPO training entrypoint (SB3) |
| `quakec/cortex/cortex_bridge.qc` | Telemetry driver / init + retry |
| `quakec/cortex/cortex_tcp.qc` | File/TCP stream wrappers (FTE `fopen`) |
| `quakec/cortex/cortex_sensor.qc` | Sensors (emits NDJSON) |
| `quakec/cortex/cortex_world.qc` | Hooks StartFrame to emit telemetry |
| `Game/cortex/default.cfg` | Default binds + sv_progsaccess |
| `Game/cortex/autoexec.cfg` | Post-config overrides (sv_progsaccess) |
| `scripts/build.bat` | Compile QuakeC (`progs.dat`) |
| `scripts/run_brain.bat` | Run `cortex_brain.py` |
| `scripts/run_visualizer.bat` | Run `cortex_visualizer.py` |
| `scripts/run_quake.bat` | Launch FTEQW with the mod |
| `scripts/run_quake_tcp.bat` | Launch FTEQW in TCP stream mode |
| `scripts/run_train.bat` | Run training loop |

## Data Flow (Current)

```
QuakeC (StartFrame) ──fopen/fputs──▶ Game/cortex/data/cortex_telemetry.txt ──tail──▶ Python
```

## Next Steps

- [ ] Add protocol version + sequence IDs for robust control/telemetry sync
- [ ] Add smoothing / rate limiting for aim and movement (cerebellum)
- [ ] Improve reward shaping + episode handling for training

- [ ] Validate behavior across multiple FTEQW builds (sv_progsaccess behavior differs)
- [ ] Re-enable richer telemetry (velocity/state/raycasts) once stable
- [ ] Phase 2: Control input stream (Python → Quake)
