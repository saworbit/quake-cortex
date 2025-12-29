# Project Cortex - Quick Start Guide

## 30-Second Setup

### Step 1: Build the Mod
```bash
build.bat
```

### Step 2: Start the Brain
```bash
python cortex_brain.py
```

Leave this running. You should see:
```
[CORTEX BRAIN] Listening on 127.0.0.1:5000
[CORTEX BRAIN] Waiting for Quake client to connect...
```

### Step 3: Launch Quake
```bash
cd Game
fteqw64.exe -game cortex +map dm4
```

### Step 4: Verify Connection

In Quake's console, you should see:
```
CORTEX: Initializing AI Bridge...
CORTEX: Connected to Python Brain!
```

In Python terminal, you should see data streaming:
```
[12:34:56.789] {"type":"sensor_update", "time":123.45, ...}
```

**Success!** The data pipeline is working.

## Visual Debug Mode

For a prettier view, use the visualizer:

```bash
python cortex_visualizer.py
```

This shows:
- Real-time position & velocity
- Health/armor bars
- Top-down raycast radar
- Requires: `pip install pygame`

## Testing Checklist

Once connected, try these in Quake:

- [ ] Walk around - watch position update in Python
- [ ] Jump - see `grounded` flip to `false`
- [ ] Take damage - see `health` decrease
- [ ] Pick up items - see `ammo` or `armor` increase
- [ ] Face different directions - watch `yaw` change
- [ ] Bunny hop - see `velocity.speed` go above 320

## Common Issues

**"ModuleNotFoundError: No module named 'pygame'"**
```bash
pip install pygame
```

**Quake says "Couldn't spawn server" or can't find maps**

The game is looking for maps in `id1/maps/`. Standard Quake maps:
- dm4 (The Bad Place)
- dm6 (The Dark Zone)
- e1m1 (The Slipgate Complex)

**Python shows no data**

1. Check Quake console for "CORTEX: Connected" message
2. Make sure you're actually IN a map (not in menu)
3. Try moving around

**Compilation errors about "unknown builtin"**

Make sure you're using FTEQW's `fteqcc`, not standard Quake compilers.

## What's Next?

Once you verify the data pipeline works, you're ready for **Phase 2**:

1. Add control input stream (Python sends movement commands)
2. Implement movement policy neural network
3. Train the bot to bunny hop

See [README.md](README.md) for the full roadmap.
