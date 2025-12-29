# Project Cortex - Implementation Status

**Last Updated**: 2025-12-30
**Current Phase**: Phase 1 - Telemetry Pipeline (File IPC)

## What Works

### Sidecar Architecture
- [x] QuakeC emits telemetry to a file (FTEQW `FRIK_FILE` builtins)
- [x] Python tails telemetry and prints parsed position lines
- [x] Optional pygame visualizer

### Sensor Suite (Current Output)
- [x] Position telemetry (`POS: 'x y z'`) at ~10Hz
- [ ] Full JSON sensor packet (implemented but currently disabled in `quakec/cortex/cortex_sensor.qc`)

### QuakeC Integration
- [x] Initialization moved to StartFrame (avoids cfg timing issues)
- [x] Automatic retry loop until file access is enabled
- [x] Engine capability hints printed (`FRIK_FILE` / `pr_checkextension`)

### Usability / Automation
- [x] Default keybinds provided in `Game/cortex/default.cfg`
- [x] `sv_progsaccess 2` re-asserted in `Game/cortex/autoexec.cfg` (may still require manual console entry depending on engine build)
- [x] `scripts\\run_quake.bat` launches into `map start`

## File Manifest (Current)

| Path | Purpose |
| --- | --- |
| `cortex_brain.py` | File telemetry brain (tail + parse) |
| `cortex_visualizer.py` | File telemetry visualizer (pygame/text) |
| `quakec/cortex/cortex_bridge.qc` | Telemetry driver / init + retry |
| `quakec/cortex/cortex_tcp.qc` | File I/O wrappers (fopen/fputs) |
| `quakec/cortex/cortex_sensor.qc` | Sensors (currently emits POS lines) |
| `quakec/cortex/cortex_world.qc` | Hooks StartFrame to emit telemetry |
| `Game/cortex/default.cfg` | Default binds + sv_progsaccess |
| `Game/cortex/autoexec.cfg` | Post-config overrides (sv_progsaccess) |
| `scripts/build.bat` | Compile QuakeC (`progs.dat`) |
| `scripts/run_brain.bat` | Run `cortex_brain.py` |
| `scripts/run_visualizer.bat` | Run `cortex_visualizer.py` |
| `scripts/run_quake.bat` | Launch FTEQW with the mod |

## Data Flow (Current)

```
QuakeC (StartFrame) ──fopen/fputs──▶ Game/cortex/data/cortex_telemetry.txt ──tail──▶ Python
```

## Next Steps

- [ ] Validate behavior across multiple FTEQW builds (sv_progsaccess behavior differs)
- [ ] Re-enable richer telemetry (velocity/state/raycasts) once stable
- [ ] Phase 2: Control input stream (Python → Quake)
