# Project Cortex - DarkPlaces Hybrid

Experimental hybrid implementation using DarkPlaces engine with RCON for Python control.

## Features

- **RCON Control**: Python sends commands via UDP RCON
- **File Telemetry**: QuakeC writes sensor data to file (optional)
- **DarkPlaces Engine**: Uses DP's file I/O extensions

## Structure

- **quakec/** - Hybrid QuakeC code (symlinked to `../quakec/`)
- **python/streams/rcon/** - RCON-based brain implementation
- **scripts/** - Build and run scripts
- **Game/** - DarkPlaces game directory
  - `cortex/` - Compiled mod
  - `cortex_darkplaces.cfg` - DarkPlaces config

## Running

```bash
scripts\run_darkplaces.bat     # Terminal 1: Launch DarkPlaces
scripts\run_brain_rcon.bat     # Terminal 2: Launch Python brain
```

## Building

```bash
scripts\build.bat
```

Compiles `hybrids/quakec/progs.src` to `Game/cortex/progs.dat`.

**Note:** The same progs.dat works for both FTEQW and DarkPlaces hybrids.

## Control CVars

The Python brain controls the bot via RCON cvars:

- `bot_vel_x`, `bot_vel_y`, `bot_vel_z` - World-space velocity
- `bot_yaw`, `bot_pitch` - Aim angles
- `bot_attack`, `bot_jump` - Actions
- `cortex_spawn_bot 1` - Spawn bot entity
- `cortex_track_bot 1` - Enable telemetry tracking

## Requirements

- DarkPlaces engine
- Python 3.8+
- QuakeC compiler (fteqcc64.exe)
