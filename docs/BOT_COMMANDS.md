# Cortex Bot Commands & Controls

Quick reference for managing Cortex bots in-game.

## Console Commands (Impulses)

Open the console with `~` and type these commands:

| Command | Description |
|---------|-------------|
| `impulse 200` | Spawn a bot at your location |
| `impulse 201` | Remove all bots |
| `impulse 202` | List all active bots (with stats) |
| `impulse 203` | Show Cortex status (settings & bot count) |
| `impulse 204` | Toggle debug mode on/off |
| `impulse 205` | Show help menu (full command list) |

**Quick spawn:** `bind b "impulse 200"` - Press B to spawn a bot!

## Console Variables (CVars)

Set these before starting the map or change them on the fly:

### Bot Control
```
cortex_bot_enable <0|1>      Enable/disable bot AI (default: 1)
cortex_spawn_bot <0|1>       Auto-spawn bot on map start (default: 1)
cortex_bot_skill <0-3>       Bot difficulty: 0=easy, 1=normal, 2=hard, 3=expert (default: 1)
```

### Debugging
```
cortex_debug <0|1>           Enable detailed debug output (default: 0)
cortex_log_level <0-3>       Logging verbosity:
                             0 = INFO only
                             1 = INFO + WARNINGS
                             2 = INFO + WARNINGS + ERRORS
                             3 = ALL (includes DEBUG)
developer <0|1>              Show QuakeC debug logs (required for DEBUG level)
```

### Example Usage
```
// Enable debug mode
set cortex_debug 1
set developer 1

// Spawn 3 bots manually
impulse 200
impulse 200
impulse 200

// Check status
impulse 203

// Remove all bots
impulse 201
```

## Keyboard Shortcuts

You can bind keys for quick access:

```
bind h "impulse 205"     // H = Show help
bind b "impulse 200"     // B = Spawn bot
bind n "impulse 201"     // N = Remove all bots
bind m "impulse 202"     // M = List bots
bind j "impulse 203"     // J = Status
```

Add these to your `autoexec.cfg` to make them permanent.

## Debugging Bot Behavior

### Enable Full Debug Output
```
set developer 1
set cortex_debug 1
set cortex_log_level 3
```

### View Console Log
- Console log is automatically saved to: `Game/cortex/qconsole.log`
- View it with: `condump mylog.txt` (saves to `Game/cortex/mylog.txt`)

### Debug Information Shown
When `cortex_debug 1`, you'll see:
- **BOT_AI**: Decision making and reasoning
- **PERCEPTION**: What the bot sees/detects
- **MOVEMENT**: Navigation and pathfinding
- **COMBAT**: Combat actions and targeting
- **PERF**: Performance statistics

### Dump Bot State
Create a detailed snapshot of bot status:
```
// This will be exposed via impulse in future updates
// For now, check console output when cortex_debug is enabled
```

## Troubleshooting

### Bot doesn't spawn
1. Check that you're in a map (not menu): `map dm3`
2. Verify bot is enabled: `set cortex_bot_enable 1`
3. Try manual spawn: `impulse 200`
4. Check console for error messages

### No debug output
1. Enable developer mode: `set developer 1`
2. Enable debug flag: `set cortex_debug 1`
3. Set log level high: `set cortex_log_level 3`

### Bot behaves strangely
1. Check skill level: `cortex_bot_skill`
2. Dump bot state: `impulse 202` (shows health, armor, weapon)
3. Enable debug: `set cortex_debug 1`
4. Watch console for decision logs

### Console log file missing
- Ensure you launched with `-condebug` flag
- Check both `Game/cortex/qconsole.log` and `Game/qconsole.log`
- The launch script automatically enables `-condebug`

## Advanced Usage

### Performance Monitoring
```
set cortex_debug 1
// Watch for "PERF" messages showing bot think times
// High values (>10ms) indicate performance issues
```

### Custom Bot Configuration
Create a file `Game/cortex/bot.cfg`:
```
// My custom bot settings
set cortex_bot_skill 2
set cortex_spawn_bot 1
set cortex_debug 0
set cortex_log_level 1

// Auto-bind keys
bind b "impulse 200"
bind n "impulse 201"
bind h "impulse 205"

echo "Bot configuration loaded"
```

Then execute with: `exec bot.cfg`

### Launch with Custom Settings
```
scripts\run.bat +set cortex_bot_skill 3 +set cortex_debug 1 +map dm3
```

## Log Format

Structured logs use pipe-delimited format:
```
[TIME] | [LEVEL] | [SYSTEM] | [MESSAGE] | [DATA]
```

Example:
```
[5.2] | [INFO] | [BOT_AI] | Decision: attack | Reason: enemy in range
[5.3] | [DBUG] | [COMBAT] | Combat[SHOOT]: target=monster @ '100 200 50'
[5.4] | [WARN] | [BOT_WARN] | Low health | Suggestion: find armor
```

Filter logs by searching for specific systems:
- `PERCEPTION` - Bot vision and sensing
- `MOVEMENT` - Pathfinding and navigation
- `COMBAT` - Fighting behavior
- `BOT_AI` - Decision making
- `PERF` - Performance metrics

## See Also

- [BOTS_GUIDE.md](BOTS_GUIDE.md) - Comprehensive bot guide
- [README.md](../README.md) - Project overview
- [STATUS.md](STATUS.md) - Implementation status
