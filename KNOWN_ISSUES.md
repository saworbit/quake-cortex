# Known Issues & Challenges

This document tracks the technical challenges encountered during Project Cortex
development, the root causes, workarounds, and current status.

**Last Updated**: December 30, 2025  
**Project Phase**: 1 - Telemetry Pipeline Setup (verified)

---

## Critical Issues (Blocking Progress)

### 1. FTEQW File I/O Access Requires Enabling Progs File Access

**Status**: OPEN (engine/security behavior varies by build)  
**Priority**: P0 - Can block telemetry entirely  
**First Observed**: December 29, 2025

#### Symptoms (File Access)

- Quake prints Cortex init messages, but telemetry never appears in Python
- `Game/cortex/data/cortex_telemetry.txt` is not created or never grows
- Quake console may show `fopen` failures (when `developer 1` is enabled)

#### Root Cause (File Access)

- FTEQW restricts QuakeC progs from reading/writing files unless explicitly
  allowed.
- Project Cortex uses the `FRIK_FILE` extension (`checkextension("FRIK_FILE")`) and
  `fopen`/`fputs` for file-based IPC.

#### Workaround (File Access)

- Prefer config-based setup (persistent):
  - `Game/cortex/autoexec.cfg` sets `sv_progsaccess 2`, `pr_checkextension 1`,
    and `developer 1`.
  - `Game/cortex/default.cfg` provides minimal keybinds so the mod is playable.
- If file access is still blocked, set it manually in the Quake console before
  starting a map:
  - `sv_progsaccess 2`
- If you don't see debug output, enable:
  - `developer 1`
  - `pr_checkextension 1`

#### Notes (Command Line)

- Some FTEQW builds treat `+sv_progsaccess 2` as a *command* (and log
  `Unknown command "sv_progsaccess"`).
- When supported, prefer `+set sv_progsaccess 2` over `+sv_progsaccess 2`.
- Manual console entry may still be required on some builds.

---

## Medium Priority Issues

### 2. No Telemetry Until a Map Is Loaded

**Status**: EXPECTED (engine behavior)  
**Priority**: P2 - Confusing during first setup

#### Symptoms (Menus)

- Python prints “Waiting for Quake to write data...” while Quake is on the title
  screen / main menus.

#### Root Cause (Menus)

- QuakeC `StartFrame` only runs once a server is active (i.e., a map is loaded).

#### Solution (Menus)

- Load a map: `map start` or `map e1m1`.

---

## Resolved Issues

### 3. Telemetry File Location Mismatch (`data/` Folder)

**Status**: RESOLVED  
**Priority**: P1 (was blocking initial verification)

#### Symptoms (Telemetry Path)

- Python watches `Game/cortex/cortex_telemetry.txt` but nothing appears.

#### Root Cause (Telemetry Path)

- FTEQW writes QuakeC-created files into the mod’s `data/` folder by default.

#### Solution (Telemetry Path)

- Canonical telemetry path is `Game/cortex/data/cortex_telemetry.txt`.
- Repo-root `cortex_brain.py` and `cortex_visualizer.py` default to that path.

### 4. Wrong Python Entrypoint (Legacy TCP Prototype)

**Status**: RESOLVED  
**Priority**: P1 (looked like “telemetry broken”)

#### Root Cause (Entrypoint)

- `python/` contains legacy TCP prototypes; the QuakeC side is file-based.

#### Solution (Entrypoint)

- `scripts/run_brain.bat` launches the repo-root `cortex_brain.py`.
- `scripts/run_visualizer.bat` launches the repo-root `cortex_visualizer.py`.

### 5. Telemetry Emission Disabled / Not Called Every Frame

**Status**: RESOLVED  
**Priority**: P0 (no data)

#### Root Cause (Emission)

- Telemetry emission was disabled while debugging initialization.

#### Solution (Emission)

- Telemetry is emitted from `StartFrame` via `Cortex_Frame()` with throttling.

### 6. Missing Default Keybinds in Fresh Mod Folder

**Status**: RESOLVED  
**Priority**: P1 (major usability issue)

#### Symptoms (Keybinds)

- Mouse look works, but movement/jump/attack are unbound.

#### Root Cause (Keybinds)

- New mod folders don’t inherit binds from `id1/` automatically.

#### Solution (Keybinds)

- `Game/cortex/default.cfg` includes minimal WASD + mouse binds.

### 7. QuakeC Compilation Failed (Missing `defs.qc` in CI / Fresh Checkout)

**Status**: RESOLVED  
**Priority**: P0 (build break)

#### Root Cause (QuakeC Build)

- `quakec/progs.src` references the single-player base from
  `quakec/lib/QuakeC-releases/progs/`, but those files weren’t present in some
  checkouts.

#### Solution (QuakeC Build)

- Vendored `quakec/lib/QuakeC-releases/progs/` into the repo so CI and clean
  clones can compile without extra steps.

---

## Testing Checklist

### Pre-Launch Checks (Local)

- [ ] `Game/cortex/progs.dat` exists and is >100KB (or run `scripts\\build.bat`)
- [ ] `Game/id1/PAK0.PAK` exists (legal Quake game data)
- [ ] `Game/fteqw64.exe` exists (FTEQW engine binary)
- [ ] Python is installed (3.11+ recommended)

### Launch Sequence (End-to-End)

- [ ] Start Python: `scripts\\run_brain.bat`
- [ ] Start Quake: `scripts\\run_quake.bat`
- [ ] Load a map: `map start` or `map e1m1`
- [ ] If needed, enable file access: `sv_progsaccess 2`
- [ ] Verify Quake prints: `CORTEX: Telemetry file opened!`
- [ ] Verify Python prints: `[POS] X=... Y=... Z=...` and values change when
      moving

### Troubleshooting (Quick)

- [ ] Confirm telemetry file grows: `Game/cortex/data/cortex_telemetry.txt`
- [ ] Enable debug prints: `developer 1`
- [ ] Confirm extension support: `pr_checkextension 1` then watch for
      `FRIK_FILE` messages in the Quake console

---

## References

- [FTEQW Documentation](https://fte.triptohell.info/)
- [QuakeC Language Reference](https://github.com/id-Software/Quake-Tools)
- [maddes-b Single-Player Source](https://github.com/maddes-b/QuakeC-releases/)

---

**End of Known Issues Document**
