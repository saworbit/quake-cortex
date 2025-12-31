# Project Cortex - FTEQW Hybrid

Experimental hybrid implementation where QuakeC provides sensors/actuators and Python makes decisions.

## Features

- **File IPC**: QuakeC writes telemetry to file, Python tails it
- **TCP Stream**: Direct WebSocket connection for RL training
- **Shared Bot AI**: Can run pure QuakeC bot OR Python-controlled bot

## Structure

- **quakec/** - Hybrid QuakeC code (symlinked to `../quakec/`)
- **python/streams/** - Python brain implementations
  - `file/` - File-based IPC (default)
  - `tcp/` - TCP stream for RL training
- **scripts/** - Build and run scripts
- **Game/cortex/** - Compiled mod output

## Running

### File IPC Mode
```bash
scripts\run_quake.bat   # Terminal 1: Launch FTEQW
scripts\run_brain.bat   # Terminal 2: Launch Python brain
```

### TCP Stream Mode (RL Training)
```bash
scripts\run_quake_tcp.bat   # Launch FTEQW with TCP
python train_cortex.py      # Run RL training
```

## Building

```bash
scripts\build.bat
```

Compiles `hybrids/quakec/progs.src` to `Game/cortex/progs.dat`.

## Requirements

- FTEQW engine (required for TCP mode)
- Python 3.8+
- QuakeC compiler (fteqcc64.exe)
