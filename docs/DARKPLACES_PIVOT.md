# DarkPlaces Pivot (RCON IPC) - Detailed Spec

Project CORTEX is a "sidecar" AI architecture for Quake 1:
- QuakeC (the body) emits telemetry and applies control inputs.
- Python (the brain) reads telemetry, decides actions, and sends control commands back.

This pivot targets the DarkPlaces engine and shifts Phase 2 control IPC to UDP RCON, while keeping file-based telemetry as a fallback.

## Why DarkPlaces

- Engine features: realtime lighting (`.rtlights`), fog, skyboxes, higher limits, good performance.
- Modding/debugging: PRVM tools (e.g. `prvm_edicts`, profiling) help iterate on bot code.
- IPC: DarkPlaces exposes RCON over UDP, enabling low-latency "set cvar / query state" loops without file tail latency.
- Future-proofing: open-source, broadly compatible with Quake mods, provides QC extension surface (documented in `dpextensions.qc`).

## Prerequisites

- DarkPlaces engine binary
  - Place it at `Game\\darkplaces.exe`.
  - (This repo does not distribute engine binaries.)
- Quake 1 game data
  - Provide `Game\\id1\\PAK0.PAK` (and optionally `PAK1.PAK`) from a legal copy.
- QuakeC compiler
  - This repo uses `quakec\\fteqcc64.exe` (already present) to build `Game\\cortex\\progs.dat`.
  - You can switch to `gmqcc` later; keep that change isolated and test carefully.

## Updated Runtime/Source Layout

Key DarkPlaces-related additions:
- `Game\\darkplaces.exe` (you provide)
- `Game\\cortex\\cortex_darkplaces.cfg` (engine defaults for this mode)
- `scripts\\run_darkplaces.bat` (launcher)
- `scripts\\run_brain_rcon.bat` (RCON brain starter)
- `python\\darkplaces_rcon\\brain_rcon.py` (implementation) and `cortex_rcon.py` (entrypoint)
- `quakec\\lib\\dpextensions.qc` (DarkPlaces extension definitions)

## QuakeC Adaptations

### Extension Header

`quakec\\progs.src` includes `quakec\\lib\\dpextensions.qc` so QuakeC builds against the DarkPlaces extension surface (string ops, `checkextension`, file I/O builtins, etc).

### File I/O (Fallback Path)

The file telemetry path remains:
- QuakeC writes to `Game\\cortex\\data\\cortex_telemetry.txt`.
- Python tails it via `cortex_brain.py` / `scripts\\run_brain.bat`.

Engines vary in which file extensions they advertise. The bridge prints capability hints:
- `DP_QC_FS` (DarkPlaces-style file I/O)
- `FRIK_FILE` (common "file I/O builtin set" name used by several engines)

### RCON-Controlled Bot Entity (`cortex_bot`)

DarkPlaces RCON is good at setting cvars. To bridge that into QC-controlled movement, this branch adds a minimal server-side entity:
- Implemented in `quakec\\cortex\\bot\\cortex_bot.qc`
- Spawned when `cortex_spawn_bot 1`
- Updated every think by reading control cvars (see "Control Cvars")

The telemetry driver can target this entity instead of a player by setting:
- `cortex_track_bot 1`

Note: `cortex_bot` is a physics entity, not a true network client. It will not behave like a full player for weapons/items until additional QuakeC work is done.

## IPC Pivot: Files -> RCON

### RCON Basics (DarkPlaces)

- Transport: UDP
- Port: same as server port (default `26000`; this repo forces `-port 26000` for consistency)
- Auth: `rcon_password`

### Data Flow

- Telemetry (Quake -> Python):
  - Python queries `prvm_edicts sv` and parses entity blocks (players + `cortex_bot`).
- Control (Python -> Quake):
  - Python sends `rcon ... set <cvar> <value>` to update movement/aim inputs.
  - QuakeC bot reads those cvars and applies them every think.

### Latency/Rate

Start with 20Hz (`--hz 20`) and tune upward cautiously. Localhost UDP is typically sub-ms, but `prvm_edicts sv` output can become large on busy maps.

## Control Cvars

Lifecycle / tuning:
- `cortex_spawn_bot` = 1 spawns the bot entity (default 0)
- `cortex_track_bot` = 1 makes telemetry follow `cortex_bot` (default 0)
- `cortex_bot_think_interval` = bot think interval seconds (default 0.02)

World-space controls (read by `cortex_bot`):
- `bot_vel_x`, `bot_vel_y`, `bot_vel_z` (units/sec)
- `bot_yaw`, `bot_pitch` (degrees; clamped to Quake-ish pitch limits)
- `bot_attack`, `bot_jump` (0/1; best-effort)

## How To Run (DarkPlaces + RCON)

1. Build QuakeC:
   - `scripts\\build.bat`

2. Launch DarkPlaces (listen server + RCON password):
   - `scripts\\run_darkplaces.bat`

3. Start the Python RCON loop:
   - `scripts\\run_brain_rcon.bat`

Defaults (configurable via CLI args in `cortex_rcon.py`):
- Host/port: `127.0.0.1:26000`
- Password: `cortex_secret`

## Python RCON Client

Implementation:
- `python\\darkplaces_rcon\\brain_rcon.py` implements a minimal DarkPlaces RCON client:
  - Sends `getchallenge`
  - Sends `rcon <challenge> <password> <command>`
  - Parses `prvm_edicts sv` to locate `cortex_bot` and nearest `player`
  - Sets `bot_vel_*` and `bot_yaw` to chase a target

CLI:
- `python cortex_rcon.py --host 127.0.0.1 --port 26000 --password cortex_secret --hz 20 --speed 300`

## Testing / Validation Checklist

- Build: `scripts\\build.bat` produces `Game\\cortex\\progs.dat`
- DarkPlaces boots: `scripts\\run_darkplaces.bat` launches into `map start`
- RCON works:
  - In Python, `scripts\\run_brain_rcon.bat` runs without timeouts.
  - In-game, setting velocities visibly moves `cortex_bot`.
- Telemetry target:
  - Set `cortex_track_bot 1` (the RCON brain loop does this automatically) and confirm telemetry updates correspond to the bot position if you are also tailing the file.

## Security Notes

- Keep `rcon_password` for dev on localhost only.
- Do not expose the UDP port to the internet on an untrusted network.
