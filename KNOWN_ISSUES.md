# Known Issues & Challenges

This document tracks the technical challenges encountered during Project Cortex
development, the root causes, workarounds, and current status.

**Last Updated**: January 1, 2026  
**Project Phase**: 1 - Telemetry Pipeline Setup (verified)

---

## Critical Issues (Blocking Progress)

### 1. Player Cannot Move in Pure Mode (WASD Unresponsive)

**Status**: OPEN  
**Priority**: P0 - Blocks basic testing  
**First Observed**: December 31, 2025

#### Symptoms

- Mouse look and firing work, but W/A/S/D does nothing.
- Repro in both `scripts\\run_pure_qc.bat` and `scripts\\run_pure_debug.bat`.

#### Likely Cause

- Movement binds or speed cvars are not being applied for `-game cortex_pure`
  in some FTEQW setups.

#### Workaround

- In the console:
  - `exec autoexec.cfg`
  - `bind w +forward`
  - `bind a +moveleft`
  - `bind s +back`
  - `bind d +moveright`
  - `cl_forwardspeed 400`
  - `cl_sidespeed 400`
  - `cl_backspeed 400`
  - `cl_upspeed 200`

---

### 2. Bot Spawns But Does Not Move

**Status**: OPEN  
**Priority**: P0 - Blocks AI validation  
**First Observed**: December 31, 2025

#### Symptoms

- Bot appears but remains in place or only jitters/jumps.
- Logs show `MOVE` entries with `0 0 0` movement vectors.

#### Suspected Cause

- Movement goal is resolving to the bot's current position (AI target selection
  or navigation fallback). Needs further inspection with debug logs.

#### Workaround

- No reliable workaround yet; capture `MOVE`/`STATE` logs for debugging.

---

### 3. Bot Death Animation Does Not Play

**Status**: OPEN  
**Priority**: P1 - Visual regression  
**First Observed**: December 31, 2025

#### Symptoms

- Bot dies but skips the death animation or floats briefly.

#### Suspected Cause

- Botclient respawn path may bypass the normal death think loop.

#### Workaround

- Increase the respawn delay so the death animation can play:
  - `cortex_bot_respawn_delay 1.0`

---

## Medium Priority Issues

### 3. No Telemetry Until a Map Is Loaded

**Status**: EXPECTED (engine behavior)  
**Priority**: P2 - Confusing during first setup

#### Symptoms (Menus)

- Python prints `waiting_for_quake` while Quake is on the title
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

- `python/` contains multiple modules; the repo-root entrypoints (`cortex_brain.py` / `cortex_visualizer.py`) are for File IPC, while `train_cortex.py` / `python/cortex_env.py` are for TCP stream mode.

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

### 8. Pure Botclient Ignores Movement Input Without Player Physics Hook

**Status**: RESOLVED  
**Priority**: P0 (bot appears frozen)

#### Symptoms (Pure Botclient)

- `MOVE` logs show non-zero movement, but the bot stays in place.

#### Root Cause (Pure Botclient)

- Botclients rely on player physics; direct movement input is ignored unless
  `SV_PlayerPhysics` is wired and `pr_no_playerphysics 0` allows the hook.

#### Solution (Pure Botclient)

- Implemented `SV_PlayerPhysics` to apply `self.movement` to the engine.
- `scripts/run_pure_debug.bat` forces `pr_no_playerphysics 0`.

### 9. Hybrid Stream Noise in Pure Mode Logs

**Status**: RESOLVED  
**Priority**: P2 (log noise only)

#### Symptoms (Pure Mode)

- `telemetry_stream_connect_failed` or `qcfopen("ws://...")` messages in logs.

#### Root Cause (Pure Mode)

- Hybrid TCP/file telemetry cvars were left enabled while running pure QuakeC.

#### Solution (Pure Mode)

- `Game/cortex/autoexec.cfg` forces `cortex_pure_mode 1`, `cortex_use_tcp 0`,
  `cortex_enable_controls 0`, and `cortex_track_bot 0`.
- `scripts/run_pure_debug.bat` also enforces those cvars for debug runs.

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

## Archived Issues (Legacy / Not in Active Use)

### A1. TCP Stream Mode Requires `pr_enable_uriget 1`

**Status**: ARCHIVED (TCP stream mode not in active use)  
**Priority**: P1 (historical)  
**First Observed**: December 30, 2025

#### Symptoms (TCP Mode)

- Quake prints `CORTEX: Stream connect failed...`
- Training/env or TCP brain server never sees a connection

#### Root Cause (TCP Mode)

- FTE gates URI streams (including `tcp://`) behind `pr_enable_uriget`.
- Project Cortex uses `fopen("tcp://...", -1)` for TCP stream mode.

#### Workaround (TCP Mode)

- Use `scripts\\run_quake_tcp.bat` (it sets `pr_enable_uriget 1` and switches Cortex to TCP mode).
- If a build hard-disables URI streams, use File IPC mode (`scripts\\run_quake.bat`) instead.

#### Related: Some Builds Use TLS on `tcp://`

**Symptoms**:
- Quake may show a black screen then exit shortly after.
- Brain log shows `Detected TLS client hello` / `TLS handshake ...`
- `Game\\cortex\\qconsole.log` may contain `X509_V_ERR_DEPTH_ZERO_SELF_SIGNED_CERT`.

**Root Cause**:
- Some FTE builds initiate a TLS handshake even when the URI is `tcp://...`.

**Fix**:
- Prefer `ws://127.0.0.1:26000/` (default in `scripts\\run_quake_tcp.bat`) to avoid TLS negotiation entirely.
- If your build is doing TLS on `tcp://`, Cortex cannot reliably override the engine's cert verification; upgrade FTEQW (where `tcp://` is plain TCP and TLS is only used with `tls://`).
- If you want to investigate anyway: the TCP brain can generate a local dev cert under `.cortex\\tls\\` via `scripts\\generate_cortex_tls_cert.ps1`, but some builds will still reject it as `unknown ca`.

---

### A2. FTEQW File I/O Access Requires Enabling Progs File Access

**Status**: ARCHIVED (file IPC not in active use while focusing on pure QuakeC bot)  
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
