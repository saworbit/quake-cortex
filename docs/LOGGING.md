# Cortex Black Box Logging

Project Cortex produces two primary logs (Body + Brain) that you can hand to a human or an LLM to reconstruct *why* a bad outcome happened.

## Where Logs Land

### Brain (Python)

- **File**: `cortex_brain_<unix_ts>.log`
  - Location: the current working directory you launched `python cortex_brain.py` from
  - If you use `scripts\\run_brain.bat`, that is the repo root (`C:\\ProjectCortex\\`)
- **Console**: structured INFO/ERROR lines prefixed with `[BRAIN]`

The file log is **DEBUG** and contains the high-volume timeline (telemetry packets, decisions, etc). The console is **INFO** to avoid noise.

### Body (Quake / FTEQW)

- **Console log file**: `Game\\qconsole.log` (some builds write to `Game\\cortex\\qconsole.log`)
  - Enabled via `+set condebug 1` (already set in `scripts\\run_quake.bat` and `scripts\\run_quake_tcp.bat`)
- **Telemetry file (File IPC mode)**: `Game\\cortex\\data\\cortex_telemetry.txt`

QuakeC structured log format (captured in `qconsole.log`):
`[TIME] | [LEVEL] | [SYSTEM] | [MESSAGE] | [OPTIONAL_DATA]`

## Snapshot / Dump State

A built-in dump is bound to **impulse 199**:

- Bind a key in the Quake console: `bind F7 "impulse 199"`
- When pressed in-game, it prints a structured STATE packet into `qconsole.log`

## Recommended Workflow

1. Run `scripts\\run_brain.bat` (Brain log file appears in repo root).
2. Run `scripts\\run_quake.bat` (Body console log appears at `Game\\qconsole.log`).
3. Reproduce the issue, then press your dump-state key (e.g. F7) at the failure moment.
4. Share:
   - `cortex_brain_*.log`
   - the relevant section of `Game\\qconsole.log`
