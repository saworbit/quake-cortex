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

### 2. TCP Stream Mode Requires `pr_enable_uriget 1`

**Status**: OPEN (engine/security behavior varies by build)  
**Priority**: P1 - Blocks TCP telemetry/control mode  
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
- If your build is doing TLS on `tcp://`, Cortex cannot reliably override the engine’s cert verification; upgrade FTEQW (where `tcp://` is plain TCP and TLS is only used with `tls://`).
- If you want to investigate anyway: the TCP brain can generate a local dev cert under `.cortex\\tls\\` via `scripts\\generate_cortex_tls_cert.ps1`, but some builds will still reject it as `unknown ca`.

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
