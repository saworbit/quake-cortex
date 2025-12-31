# Debugging the Pure QuakeC Bot

This guide explains how to debug the Cortex Pure QuakeC bot using the built-in logging system.

## Quick Start

### Running in Debug Mode

```batch
scripts\run_pure_debug.bat
```

This script will:
1. Build the latest pure bot code
2. Launch FTEQW with full debug logging enabled
3. Auto-spawn a bot
4. Force botclient physics via `pr_no_playerphysics 0`
5. Log everything to `Game/cortex_pure/qconsole.log` (rotated into `Game/cortex_pure/logs/`)

### Viewing Logs

After quitting the game, check the logs:
```batch
type Game\cortex_pure\qconsole.log
```

Or use tail to see the latest entries:
```bash
tail -100 Game/cortex_pure/qconsole.log
```

---

## Logging System Implementation

### Architecture

The Cortex bot uses a structured logging system defined in `quakec/cortex/common/cortex_logging.qc`:

**Log Levels:**
- `LOG_info` (0) - Important events, always visible
- `LOG_warning` (1) - Warnings and issues
- `LOG_error` (2) - Errors
- `LOG_debug` (3) - Verbose debug output (requires `developer 1`)

**Log Format:**
```
[TIME] | [LEVEL] | [SYSTEM] | [MESSAGE]
```

Example:
```
[5.123] | [INFO] | [STATE] | Bot state: EXPLORE | Enemy: 0 | Pickup: 1
```

### Key Logging Functions

```c
// Basic log entry
CortexLog(LOG_info, "SYSTEM", "Message");

// Log with additional data
CortexLogData(LOG_info, "SYSTEM", "Message", "data");

// Broadcast print (always visible)
bprint("Message\n");

// Developer-only print (requires developer 1)
dprint("Debug message\n");
```

---

## Debug Flags

The debug script sets these cvars automatically:

| Cvar | Value | Purpose |
|------|-------|---------|
| `cortex_debug` | 1 | Enables Cortex debug logging |
| `developer` | 1 | Shows engine debug messages |
| `cortex_log_level` | 3 | Maximum log verbosity |
| `cortex_bot_enable` | 1 | Enables bot AI |
| `cortex_spawn_bot` | 1 | Auto-spawns bot on map start |
| `pr_no_playerphysics` | 0 | Allows `SV_PlayerPhysics` to drive botclient movement |
| `cortex_pure_mode` | 1 | Forces pure bot mode |

You can also set these manually in-game via the console:
```
developer 1
cortex_debug 1
cortex_log_level 3
```

---

## What to Look For in Logs

### 1. Bot Spawn Sequence

**Expected log sequence when bot spawns:**

```
======================================
    PROJECT CORTEX - Pure QuakeC Bot
======================================

Quick Start:
  Press ~ to open console
  Type: impulse 200  (spawn a bot)
  Type: impulse 203  (show status)

DEBUG: Cortex_BotSpawn called
CortexBot entered the game
DEBUG: Bot think scheduled for time 0.15 (botclient mode)
```

**What this means:**
- ✅ Cortex mod loaded successfully
- ✅ Bot entity created
- ✅ Think loop initialized

**If you see:**
- ❌ No welcome message → Cortex mod not loading (check progs.dat location)
- ❌ No "Cortex_BotSpawn called" → Spawn function not executing
- ❌ No "Bot think scheduled" → Think function not set up (critical bug!)

---

### 2. Think Loop Activity

**Expected: Continuous think logs every 0.02 seconds**

```
[0.15] | [INFO] | [THINK] | Bot think at time 0.15
[0.15] | [INFO] | [AI] | Running AI
[0.17] | [INFO] | [THINK] | Bot think at time 0.17
[0.17] | [INFO] | [AI] | Running AI
[0.19] | [INFO] | [THINK] | Bot think at time 0.19
[0.19] | [INFO] | [AI] | Running AI
```

**What this means:**
- ✅ Think loop running at correct interval (0.02s = 50 times per second)
- ✅ AI function being called every frame

**If you see:**
- ❌ No think logs → Think function not assigned (bot will be frozen)
- ❌ Think logs stop after a few frames → Think loop broke (nextthink not set)
- ❌ Think logs but no AI logs → AI disabled or early return in think

---

### 3. Bot State and Decision Making

**Expected: State logs showing bot's current behavior**

```
[5.123] | [INFO] | [STATE] | Bot state: EXPLORE | Enemy: 0 | Pickup: 0
[5.145] | [INFO] | [STATE] | Bot state: COLLECT | Enemy: 0 | Pickup: 1
[8.234] | [INFO] | [STATE] | Bot state: CHASE | Enemy: 1 | Pickup: 0
[8.456] | [INFO] | [STATE] | Bot state: ATTACK | Enemy: 1 | Pickup: 0
```

**Bot States:**
- `EXPLORE` - Wandering, looking for items/enemies
- `COLLECT` - Moving to pick up item
- `CHASE` - Pursuing enemy
- `ATTACK` - Engaging enemy in combat
- `FLEE` - Low health, retreating

**What this means:**
- `Enemy: 0` = No enemy detected
- `Enemy: 1` = Enemy detected
- `Pickup: 0` = No item targeted
- `Pickup: 1` = Item targeted for pickup

---

### 4. Movement Commands

**Expected: Velocity being set when bot decides to move**

```
[5.123] | [INFO] | [MOVE] | Set velocity to '-243.2 156.8 0.0' (speed=320)
[5.145] | [INFO] | [MOVE] | Set velocity to '189.5 -267.3 0.0' (speed=320)
[8.234] | [INFO] | [MOVE] | Set velocity to '0.0 380.0 0.0' (speed=380)
```

**What this means:**
- Bot is attempting to move in direction `(x, y, z)`
- Speed varies by state (320=explore, 380=chase, 420=flee)
- Z component is usually 0 (horizontal movement only)

**If you see:**
- ✅ Velocity changing frequently → Bot AI is working
- ✅ Velocity magnitude matches speed → Movement calculation correct
- ❌ No MOVE logs at all → Movement function not being called
- ❌ Velocity always '0.0 0.0 0.0' → Direction calculation broken

**Critical Issue:** If you see MOVE logs with non-zero movement but the bot still doesn't move, botclient physics isn't being applied. Ensure `SV_PlayerPhysics` is wired and `pr_no_playerphysics 0` is set (the debug script does this).

---

## Common Issues and Diagnostics

### Issue: Bot Spawns But Is Frozen (AI Disabled)

If the status block shows `Bot AI enabled: 0`, the bot will spawn but never think or move.

**Fix (console):**
```
cortex_bot_enable 1
restart
impulse 200
```

**Note:** `scripts\\run_pure_qc.bat`, `scripts\\run_pure_debug.bat`, and
`Game/cortex_pure/default.cfg` already set `cortex_bot_enable 1` automatically.

### Issue: Bot Spawns But Doesn't Move

**Diagnostic checklist:**

1. **Check think loop is running:**
   ```
   grep "THINK" Game/cortex_pure/qconsole.log | tail -10
   ```
   - Should show continuous entries

2. **Check AI is executing:**
   ```
   grep "Running AI" Game/cortex_pure/qconsole.log | tail -10
   ```
   - Should show continuous entries

3. **Check bot state selection:**
   ```
   grep "STATE" Game/cortex_pure/qconsole.log | tail -10
   ```
   - Should show valid states (EXPLORE, COLLECT, etc.)
   - Should show state transitions

4. **Check movement commands:**
   ```
   grep "MOVE" Game/cortex_pure/qconsole.log | tail -10
   ```
   - Should show velocity being set
   - Velocity should be non-zero

**If all checks pass but bot still doesn't move:**
Set `pr_no_playerphysics 0` so `SV_PlayerPhysics` can apply botclient movement.

**Quick fix (pure bot):**
```
cortex_bot_enable 1
pr_no_playerphysics 0
restart
impulse 200
```

---

### Issue: qcfopen Access Denied (Legacy Hybrid Warning)

If you see `qcfopen("ws://...")` in logs while running pure mode, it is legacy
hybrid code and can be ignored. Pure mode does not use streams.

---

### Issue: No Logs Appearing

**Possible causes:**

1. **Wrong progs.dat location:**
   - Check: `dir Game\cortex_pure\progs.dat`
   - Should exist and be recent (check timestamp)
   - If missing: Build script outputting to wrong directory

2. **Old build loaded:**
   - Solution: Delete `Game\cortex_pure\progs.dat` and rebuild
   - Check file timestamp matches current time

3. **Cortex mod not loading:**
   - Check for welcome message in logs
   - If missing: progs.dat path mismatch with `-game` parameter

4. **Debug flags not set:**
   - Check in-game: Type `developer` in console
   - Should show: `"developer" is "1"`
   - If "0": Debug script didn't set it correctly

---

### Issue: Duplicate Log Entries

**Example:**
```
[5.123] | [INFO] | [THINK] | Bot think at time 5.123
[5.123] | [INFO] | [THINK] | Bot think at time 5.123
```

**Cause:** Think function being called twice per frame

**Impact:** Performance overhead but not critical

**Investigation needed:** Check for multiple `self.think = Cortex_BotThink` assignments

---

## Log File Locations

### Default Locations

| Mode | Log Path |
|------|----------|
| Pure QuakeC | `Game/cortex_pure/qconsole.log` |

### Log File Management

`scripts\run_pure_debug.bat` automatically rotates `qconsole.log` into `Game/cortex_pure/logs/` and keeps the newest 5.

**Clearing old logs:**
```batch
del Game\cortex_pure\qconsole.log
```

**Archiving logs:**
```batch
copy Game\cortex_pure\qconsole.log logs\debug_%date%.log
```

**Real-time monitoring (PowerShell):**
```powershell
Get-Content Game\cortex_pure\qconsole.log -Wait -Tail 50
```

---

## Advanced Debugging

### Adding Custom Logs

To add logging to any QuakeC function:

```c
if (cvar("cortex_debug"))
    CortexLog(LOG_info, "MYSYSTEM", "My debug message");
```

With data:
```c
if (cvar("cortex_debug"))
{
    local string msg;
    msg = strcat("Value: ", ftos(my_value));
    CortexLog(LOG_info, "MYSYSTEM", msg);
}
```

### Verbose Movement Debugging

Add to `Cortex_Bot_RunAI` (after state selection):

```c
if (cvar("cortex_debug"))
{
    local string debug;
    debug = strcat("Pos: ", vtos(self.origin));
    debug = strcat(debug, " | Vel: ", vtos(self.velocity));
    debug = strcat(debug, " | Health: ", ftos(self.health));
    CortexLog(LOG_info, "DEBUG", debug);
}
```

### Performance Analysis

Count think calls per second:
```bash
grep "THINK" Game/cortex_pure/qconsole.log | wc -l
```

Expected: ~50 per second (0.02s interval = 50 FPS)

---

## Known Issues

### Botclient Movement System

**Problem:** Botclient entities spawned with `spawnclient()` ignore direct `self.velocity` writes unless the player physics hook is enabled.

**Symptoms:**
- ✅ Think loop runs
- ✅ AI executes
- ✅ MOVE logs show velocity being set
- ❌ Bot doesn't physically move in-game

**Root Cause:** Botclients use the player movement system which expects:
- `self.movement` vector (forward/side/up input)
- Engine applies physics based on movement input
- `SV_PlayerPhysics` must be callable and `pr_no_playerphysics` must be `0`

**Solution:** Convert bot AI to use `self.movement`, and ensure the physics hook is enabled:

```c
// Current (broken for botclients):
self.velocity = dir * speed;

// Fixed (works for botclients):
// Calculate forward/side components relative to bot's angles
local float forward, side;
// Set movement input
self.movement = '0 0 0';
self.movement_x = forward * 320;  // Forward speed
self.movement_y = side * 320;     // Strafe speed
```

The pure debug script forces `pr_no_playerphysics 0` for botclient movement.

---

## Impulse Commands for Manual Testing

Use these in the console while playing:

| Impulse | Command | Purpose |
|---------|---------|---------|
| 200 | `impulse 200` | Spawn a bot manually |
| 201 | `impulse 201` | Remove all bots |
| 202 | `impulse 202` | List all bots |
| 203 | `impulse 203` | Show bot status |
| 204 | `impulse 204` | Toggle debug mode |
| 205 | `impulse 205` | Show help |

---

## See Also

- [cortex_logging.qc](../quakec/cortex/common/cortex_logging.qc) - Logging system implementation
- [cortex_bot.qc](../quakec/cortex/bot/cortex_bot.qc) - Bot AI implementation
- [cortex_console.qc](../quakec/cortex/common/cortex_console.qc) - Console commands
- [run_pure_debug.bat](../scripts/run_pure_debug.bat) - Debug launcher script
