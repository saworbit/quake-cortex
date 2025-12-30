# Cortex Black Box Logging

Project Cortex produces two primary logs (Body + Brain) that you can hand to a human or an LLM to reconstruct *why* a bad outcome happened.

## Where Logs Land

### Brain (Python)

- **File**: `.cortex\\logs\\cortex_brain_<unix_ts>.log` (when using `scripts\\run_brain.bat`)
- **Stream mode file**: `.cortex\\logs\\cortex_brain_tcp_<YYYYMMDD_HHMMSS>.log` (when using `scripts\\run_brain_tcp.bat`)
- **Console**: structured INFO/ERROR lines prefixed with `[BRAIN]`

The file log is **DEBUG** and contains the high-volume timeline (telemetry packets, decisions, etc). The console is **INFO** to avoid noise.

Stream mode may also create `.cortex\\tls\\` (dev TLS certs) on some engine builds.

### Body (Quake / FTEQW)

- **Console log file**: `Game\\cortex\\qconsole.log` (some builds write to `Game\\qconsole.log`)
  - Enabled via `-condebug` (already set in `scripts\\run_quake.bat` and `scripts\\run_quake_tcp.bat`)
- **Telemetry file (File IPC mode)**: `Game\\cortex\\data\\cortex_telemetry.txt`
  - If you see delayed/batched updates on Windows, QuakeC periodically closes/reopens the file to force flush.
  - Tune via `cortex_file_flush_interval` (seconds): `0` = default `0.25`, `<0` disables.

QuakeC structured log format (captured in `qconsole.log`):
`[TIME] | [LEVEL] | [SYSTEM] | [MESSAGE] | [OPTIONAL_DATA]`

## Snapshot / Dump State

A built-in dump is bound to **impulse 199**:

- Bind a key in the Quake console: `bind F7 "impulse 199"`
- When pressed in-game, it prints a structured STATE packet into `qconsole.log`

## Recommended Workflow

1. Run `scripts\\run_brain.bat` (Brain log file appears under `.cortex\\logs\\`).
2. Run `scripts\\run_quake.bat` (Body console log appears at `Game\\cortex\\qconsole.log`).
3. Reproduce the issue, then press your dump-state key (e.g. F7) at the failure moment.
4. Share:
   - `.cortex\\logs\\cortex_brain_*.log`
   - the relevant section of `Game\\cortex\\qconsole.log` (or `Game\\qconsole.log`)

Quick sanity check (prints tails of the latest logs):
`scripts\\check_logs.bat`

Tip: for local testing, `scripts\\run_quake.bat`/`scripts\\run_quake_tcp.bat` set `sv_public 0` and `cl_master ""` to reduce background network noise.
