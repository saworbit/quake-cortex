# Known Issues & Challenges

This document tracks all the technical challenges encountered during Project Cortex development, their root causes, attempted solutions, and current status.

**Last Updated**: December 29, 2025
**Project Phase**: 1 - Telemetry Pipeline Setup

---

## 🔴 Critical Issues (Blocking Progress)

### 1. Telemetry Pipeline Not Working Reliably

**Status**: FIXED IN CODE (NEEDS VERIFICATION)
**Priority**: P0 - Blocks all further development
**First Observed**: December 29, 2025

#### Symptoms (WASD Controls)
- Python brain runs but receives no telemetry data
- `cortex_telemetry.txt` file may not be created
- No "CORTEX: Initializing AI Bridge..." message in Quake console
- Console shows "Project Cortex: File access enabled for AI brain" but CORTEX functions don't run

#### Root Causes Identified
1. **sv_progsaccess Not Set Properly**
   - QuakeC cannot access files without `sv_progsaccess 2`
   - This cvar controls sandbox restrictions (0=none, 1=read, 2=full)
   - Without it, `fopen()` calls silently fail

2. **Command Line Parameter Doesn't Work**
   - Attempted to use `fteqw64.exe -game cortex +sv_progsaccess 2`
   - FTEQW shows: `Unknown command "sv_progsaccess"`
   - This cvar CANNOT be set via command line startup parameters
   - MUST be set in the console after engine starts

3. **default.cfg Execution Timing**
   - `Game/cortex/default.cfg` contains `sv_progsaccess 2`
   - Config file IS being executed (echo message appears)
   - But sv_progsaccess may not take effect before worldspawn runs
   - Or the command is failing silently from config files

4. **Telemetry File Location Mismatch**
   - FTEQW writes QuakeC-created files into the mod's `data/` folder
   - Telemetry file is typically: `Game/cortex/data/cortex_telemetry.txt`
   - Earlier Python scripts were watching `Game/cortex/cortex_telemetry.txt` instead

5. **Wrong Brain Entrypoint**
   - `scripts/run_brain.bat` previously launched `python/python/cortex_brain.py` (TCP server)
   - The QuakeC implementation was already file-based, so nothing ever connected

6. **Telemetry Emission Disabled**
   - `StartFrame` had the `Cortex_Think()` call commented out, so only the session header was written

#### Attempted Solutions
- ❌ Used `+sv_progsaccess 2` command line parameter → Doesn't work
- ❌ Set in default.cfg → Doesn't seem to take effect
- ⚠️ Manual console entry → Not yet fully tested
- ✅ Added `Game/cortex/autoexec.cfg` to re-assert `sv_progsaccess 2`

#### Current Workaround
Run the scripts:
1. `scripts\\run_brain.bat`
2. `scripts\\run_quake.bat`

If you see `CORTEX: Telemetry disabled...`, open the Quake console and set `sv_progsaccess 2`.

#### Next Steps to Try
1. Verify telemetry lines are appended to `Game/cortex/data/cortex_telemetry.txt`
2. Confirm Quake console prints `CORTEX: Telemetry file opened!`
3. If needed, try a different FTEQW build (stable vs dev) for sv_progsaccess behavior

---

### 2. WASD Controls Don't Work in New Mod

**Status**: RESOLVED
**Priority**: P1 - Major usability issue
**First Observed**: December 29, 2025

#### Symptoms
- Player can look around with mouse
- Cannot move with WASD keys
- Jump/attack keys also don't work
- Only affects `cortex` mod, vanilla Quake works fine

#### Root Cause (WASD Controls)
- **New mod folders don't inherit keybindings from base game**
- Each mod has isolated configuration
- FTEQW doesn't copy `config.cfg` from `id1/` to `cortex/`
- This is standard Quake behavior, not a bug

#### Solution (WASD Controls)
`Game/cortex/default.cfg` now includes minimal WASD/mouse bindings for fresh mod folders.

#### Why This Happens
From Raven67854's FTEQW setup guide:
> "This is a classic 'New Mod' problem - fresh mod folders start with zero configuration, including no keybinds. You must restore them manually."

#### Future Improvement
Could create a custom `config.cfg` in `cortex/` folder with all bindings pre-configured, but users would still need to run it once.

---

## 🟡 Medium Priority Issues

### 3. QuakeWorld Source Incompatible with Single-Player

**Status**: RESOLVED
**Priority**: P0 (was blocking, now fixed)
**First Observed**: December 28, 2025
**Resolved**: December 29, 2025

#### Problem (QuakeWorld vs Single-Player)
- Initial implementation used QuakeWorld (multiplayer) source code
- WASD input didn't work at all in single-player mode
- Mouse look worked, but player couldn't move

#### Root Cause (QuakeWorld vs Single-Player)
QuakeWorld source (`lib/Quake-master/QW/progs/`) is designed for multiplayer:
- Uses different client/server architecture
- Input handling optimized for network play
- Single-player movement code is stubbed out or different

#### Solution (QuakeWorld vs Single-Player)
Switched to official single-player Quake source:
- Downloaded from [maddes-b/QuakeC-releases](https://github.com/maddes-b/QuakeC-releases/)
- Updated `progs.src` to use `lib/QuakeC-releases/progs/*` files
- Rewrote `cortex_world.qc` to match single-player world.qc structure
- Fixed compilation errors (PRINT_HIGH, InitBodyQueue vs InitBodyQue)

#### Files Changed (QuakeWorld vs Single-Player)
- [quakec/progs.src](quakec/progs.src) - Updated all source file paths
- [quakec/cortex/cortex_world.qc](quakec/cortex/cortex_world.qc) - Completely rewritten
- [quakec/cortex/cortex_bridge.qc](quakec/cortex/cortex_bridge.qc) - Removed PRINT_HIGH

#### Result (QuakeWorld vs Single-Player)
- Compiles successfully: `progs.dat` is 350KB
- Should work with single-player input (pending testing)

---

### 4. PRINT_HIGH Constant Doesn't Exist in Single-Player

**Status**: RESOLVED
**Priority**: P2 - Compilation error
**Resolved**: December 29, 2025

#### Problem (PRINT_HIGH)
Compilation errors:
```
cortex_bridge.qc:27: error: Unknown value 'PRINT_HIGH'
```

#### Root Cause (PRINT_HIGH)
- `PRINT_HIGH` is a QuakeWorld-specific constant
- Used for `bprint(PRINT_HIGH, "message")` to control message visibility
- Single-player Quake doesn't have print level constants
- Single-player `bprint()` only takes one string parameter

#### Solution (PRINT_HIGH)
Removed PRINT_HIGH from all bprint() calls:
```c
// Before (QuakeWorld)
bprint(PRINT_HIGH, "CORTEX: Initializing...\n");

// After (Single-player)
bprint("CORTEX: Initializing...\n");
```

#### Files Changed (PRINT_HIGH)
- [quakec/cortex/cortex_bridge.qc](quakec/cortex/cortex_bridge.qc) - Lines 27, 34, 38, 61, 65, 110

---

### 5. InitBodyQueue vs InitBodyQue Naming Inconsistency

**Status**: RESOLVED
**Priority**: P2 - Compilation error
**Resolved**: December 29, 2025

#### Problem (InitBodyQueue Naming)
Compilation error:
```
cortex_world.qc:182: error: Unknown value 'InitBodyQue'
```

#### Root Cause (InitBodyQueue Naming)
- QuakeWorld uses abbreviated name: `InitBodyQue()`
- Single-player uses full name: `InitBodyQueue()`
- We used the QuakeWorld variant when writing cortex_world.qc

#### Solution (InitBodyQueue Naming)
Changed function call to match single-player naming:
```c
// Before
InitBodyQue();

// After
InitBodyQueue();
```

#### Files Changed (InitBodyQueue Naming)
- [quakec/cortex/cortex_world.qc](quakec/cortex/cortex_world.qc:182)

---

## 🟢 Resolved Historical Issues

### Unicode BOM in Source Files
**Status**: RESOLVED (December 27, 2025)
**Issue**: FTEQCC couldn't parse files with UTF-8 BOM
**Solution**: Saved all .qc files as UTF-8 without BOM

### File Access Permissions
**Status**: RESOLVED (switched to file-based IPC)
**Issue**: TCP sockets blocked by FTEQW security
**Solution**: Use file I/O (`fopen`/`fputs`) instead of network calls

### Game Freezing on Telemetry
**Status**: RESOLVED (disabled Cortex_Think in StartFrame)
**Issue**: Calling Cortex_Think() every frame caused freezing
**Solution**: Temporarily disabled while debugging; will re-enable after connection works

---

## 📋 Testing Checklist

When attempting to fix the telemetry pipeline, verify ALL of these:

### Pre-Launch Checks
- [ ] `Game/cortex/progs.dat` exists and is ~350KB
- [ ] `Game/id1/PAK0.PAK` exists (Quake game data)
- [ ] `fteqw64.exe` exists in `Game/` folder
- [ ] Python 3.7+ installed

### Launch Sequence
- [ ] Start `cortex_brain.py` FIRST
- [ ] Python shows it is monitoring `Game/cortex/data/cortex_telemetry.txt`
- [ ] Launch Quake: `scripts\\run_quake.bat` (or `fteqw64.exe -game cortex +map start`)
- [ ] Open console (Shift+Esc)
- [ ] Type: `sv_progsaccess 2` and press Enter
- [ ] Verify no error message appears
- [ ] Optional: `exec default.cfg` (re-applies default binds)
- [ ] Close console (Esc)
- [ ] Start new game: Single Player → New Game → Episode 1

### In-Game Verification
- [ ] Quake console shows: `CORTEX: Initializing AI Bridge...`
- [ ] Quake console shows: `CORTEX: Telemetry file opened!`
- [ ] Can move with WASD keys
- [ ] Can look around with mouse
- [ ] Python shows: `[POS] X=... Y=... Z=...`
- [ ] Coordinates change when moving in-game

### Troubleshooting
If CORTEX messages don't appear:
- [ ] Check `sv_progsaccess` value: type `sv_progsaccess` in console (should show `2`)
- [ ] Try setting it again: `sv_progsaccess 2`
- [ ] Check for errors: look for red text in console
- [ ] Verify progs.dat loaded: type `version` (should mention FTEQW)

If WASD doesn't work:
- [ ] Run `exec default.cfg` (re-applies default binds)
- [ ] Check bindings: type `bind w` (should show `+forward`)
- [ ] Manually bind: `bind w +forward`, `bind a +moveleft`, etc.

---

## 🔬 Research Questions

Questions that need investigation:

1. **Why doesn't sv_progsaccess work from command line?**
   - Is this an FTEQW limitation?
   - Is there a different syntax we should use?
   - Are there startup scripts that run before default.cfg?

2. **Can sv_progsaccess be set from config files at all?**
   - Maybe it's a security restriction
   - Perhaps it can only be set in console or .ini files
   - Need to check FTEQW documentation

3. **Is there an alternative to sv_progsaccess?**
   - Can we use a different file I/O method?
   - Are there FTEQW extensions that provide unrestricted file access?
   - Could we use shared memory or other IPC?

4. **Why is worldspawn called before config files execute?**
   - Order of initialization in FTEQW
   - When exactly do config files run?
   - Can we delay Cortex_Init() until after configs?

5. **Does Cortex_Init() actually get called?**
   - Add more debug output
   - Try using dprint() instead of bprint()
   - Check if worldspawn() itself is running

---

## 📚 References

- [FTEQW Documentation](https://fte.triptohell.info/)
- [Raven67854's FTEQW Setup Guide](https://www.youtube.com/watch?v=Raven67854)
- [QuakeC Language Reference](https://github.com/id-Software/Quake-Tools)
- [maddes-b Single-Player Source](https://github.com/maddes-b/QuakeC-releases/)

---

## 💡 Potential Solutions to Explore

### For sv_progsaccess Issue
1. **Try autoexec.cfg instead of default.cfg**
   - autoexec.cfg runs after default.cfg
   - Might execute at a better time

2. **Use FTEQW .ini config**
   - Some cvars may need to be in fteqw.ini
   - Located in user profile directory

3. **Delay Cortex initialization**
   - Don't call Cortex_Init() in worldspawn
   - Call it on first StartFrame instead
   - Config files might be loaded by then

4. **Use different file access method**
   - Research FTEQW builtin functions
   - Check if there's a "safe" file I/O that doesn't need sv_progsaccess
   - Look into FTEQW's plugin system

5. **Create batch file with console commands**
   - Use FTEQW's `+exec` to run a script
   - Script contains sv_progsaccess and map load commands
   - Might work better than +cvar syntax

---

**End of Known Issues Document**
