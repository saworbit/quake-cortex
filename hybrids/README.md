# Project Cortex - Hybrid Implementations

This directory contains **experimental** hybrid implementations where QuakeC acts as the "body" (sensors/actuators) and Python acts as the "brain" (decision-making).

**Note:** The main Project Cortex is a pure QuakeC bot. These hybrids are secondary experiments.

## Directory Structure

- **quakec/** - Shared hybrid QuakeC code (bridge, TCP abstraction)
- **fteqw/** - FTEQW hybrid implementation (file IPC + TCP stream)
- **darkplaces/** - DarkPlaces hybrid implementation (RCON control)
- **shared/** - Shared Python utilities (visualizer, brain base)

## Quick Start

### FTEQW Hybrid
```bash
cd hybrids/fteqw
scripts\build.bat      # Build hybrid mod
scripts\run_quake.bat  # Run with file IPC
scripts\run_brain.bat  # Run Python brain (separate terminal)
```

### DarkPlaces Hybrid
```bash
cd hybrids/darkplaces
scripts\build.bat              # Build hybrid mod
scripts\run_darkplaces.bat     # Run DarkPlaces
scripts\run_brain_rcon.bat     # Run Python brain via RCON
```

## Documentation

- FTEQW: See `fteqw/README.md`
- DarkPlaces: See `darkplaces/README.md`
