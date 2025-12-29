# Roadmap & Next Steps for Project Cortex

Project Cortex uses a "Brain-Body" architecture:
- **Body (QuakeC/FTEQW)**: perception + actuation at game tick rate (must never block)
- **Brain (Python)**: cognition + learning + memory (can use modern ML tooling)

This split is the foundation for embodied AI experimentation: Quake becomes a fast simulator; Python becomes the research stack.

**Last Updated**: 2025-12-30  
**Current Focus**: Phase 2 control loop + persistence foundations

---

## Research Context

This "Brain-Body" split is the standard move in modern embodied AI (separating simulator/embodiment from learning/cognition). It positions Project Cortex to evolve from classic scripted game AI into a reusable agent platform (similar in spirit to large-scale FPS research setups like Quake III CTF work).

---

## Current State (Phase 1: Telemetry, File IPC)

- **Telemetry path**: `Game/cortex/data/cortex_telemetry.txt`
- **Entrypoints**: `cortex_brain.py` / `cortex_visualizer.py` (repo root)
- **Startup**: `scripts\\build.bat`, `scripts\\run_brain.bat`, `scripts\\run_quake.bat`
- **Important**: telemetry won't appear until a map is loaded (`map start` / `map e1m1`) because menus don't run QuakeC
- **FTEQW file access**: some builds require manually setting `sv_progsaccess 2` in the console

Success looks like:
- Quake: `CORTEX: Telemetry file opened! (data/cortex_telemetry.txt)`
- Python: `[POS] X=... Y=... Z=...`

---

## Phase 2: Close the Feedback Loop (Brain -> Body)

### 2A. Identity Handshake ("The Soul in the File")

Problem: bots are "amnesiacs" today - no persistent identity between runs.

Goal: the Body introduces itself so the Brain can load a persistent profile:
- Body -> Brain: `HELLO name=<Reaper> session=<timestamp> map=<mapname>`
- Brain behavior:
  - If `brains/reaper.*` exists: load it
  - Else: load a shared baseline and start a new profile

### 2B. Non-Blocking Control Stream

Design rule: **the Body executes the last known command until a new one arrives**. The game loop must not wait on the Brain.

Concrete steps:
- Define a minimal action set: move/strafe/turn/fire/jump
- Send control outputs at a fixed lower rate (e.g., 10-20Hz)
- Apply commands smoothly (hold durations, deadzones, clamp values)

### 2B.1. "Cerebellum" Smoothing (Motor Control in the Body)

Goal: pass the "movement Turing Test" - does the agent move like a machine or a master?

Problem: if the Brain runs at 10Hz and the game runs at 60Hz, direct per-update snaps (especially view angles) will look like a strobe: snap, hold for ~6 frames, snap again.

Approach: keep high-level intent in Python ("turn toward X", "move forward"), but do *smoothing and rate limiting in QuakeC* so the game tick stays fluid.

Concrete steps:
- Body accepts targets, not hard-set state (for example: `cortex_target_yaw`, `cortex_target_pitch`, `cortex_target_move`)
- Slew-rate limit rotation (cap degrees-per-frame) and normalize wrap-around (0-360)
- Interpolate/extrapolate between Brain updates: continue last command until replaced; avoid "stop dead" when packets/files are late
- Keep Brain faster when possible (try 20Hz+), but treat smoothing as mandatory even at higher rates

### 2C. Protocol Standardization (Start Debuggable -> Get Efficient)

Text is fine for bring-up, but long-term throughput matters.

Plan:
- Add `PacketType`, `ProtocolVersion`, `SequenceId` to every message
- Keep parsing resilient (ignore partial lines / duplicates)
- Upgrade to packed/binary formats only when engine extensions support it
  - If/when moving back to sockets, consider latency impacts (TCP acking/Nagle) and evaluate UDP/shared memory for fast-paced play

### 2D. RL-Friendly API (Gym-like)

Goal: make the Brain logic compatible with standard RL trainers (PPO/DQN/etc).

Concrete steps:
- Define an `env.step(action) -> (observation, reward, done, info)` loop in Python
- Keep a clean separation between "data ingestion" and "policy"
- Start with simple shaped rewards (survival/time moving/not stuck) before combat rewards

---

## Phase 3: The First Brain (Navigation Before Combat)

Goal: teach the agent to move reliably before it fights.

Concrete steps:
- Implement "wander + wall avoidance" using LiDAR-like rays
- Add "stuck detection" + recovery
- Time-slice sensors (don't do full 360 degree scans every frame; build a scan over N frames)
- Standardize a "state tensor" (example fields):
  - health/armor/ammo
  - velocity/speed
  - yaw/pitch
  - LiDAR scan array (distances + semantic tags)

Success metric:
- survives and traverses for X seconds without sticking or freezing

---

## Spectator / Observer Mode (Cinematic Debugging)

Goal: make it easy to watch bots and diagnose behavior without playing yourself.

Concrete ideas:
- Provide a dedicated "observer" setup (spectator slot / config) so you can direct the action
- Add an auto-director that switches view to "most interesting" bot (low health, near enemy, currently fighting)
- Option: allow the Python Brain to also steer the spectator camera (for example: "track bot_a" when a fight is about to happen)

---

## Phase 4: Persistent Identity (Hive + Ego)

### 4A. Hive Mind (Base Skillset)

Shared base model (competence):
- navigation primitives
- basic aiming fundamentals
- item pickup priorities

Example: `brains/hive_v1.*`

### 4B. Ego (Personality Delta)

Per-bot "delta" model:
- aggression vs caution
- aim jitter / reaction delay
- preferred weapons / risk tolerance

Example: `brains/reaper.json` + `brains/reaper_weights.*`

Suggested "DNA" format:
- JSON for metadata/traits + separate weights file

---

## Phase 5: Asynchronous Dreaming (Episodic Learning)

Keep gameplay smooth by separating:
- **Inference (live)**: fast decisions during play
- **Dreaming (offline)**: at intermission/end-of-match, replay a buffer, update weights, save the soul file

---

## Phase 6: Community Learning (Federated Hive Updates)

Long-term (optional):
- people train locally (their egos learn map-specific tricks)
- share ego deltas
- maintainer script merges/averages deltas into `hive_v2.*`

---

## Phase 7: Better Perception (Semantic LiDAR + Mapping)

Upgrade sensors so the Brain can reason, not just react:
- semantic LiDAR: distance + surface/material + entity type (enemy/item/hazard)
- build a lightweight occupancy grid / top-down map (SLAM-like) in Python

### Visualizer Upgrade (Debugging the Invisible)

Enhance `cortex_visualizer.py` to render:
- a point cloud / top-down ray plot for semantic LiDAR
- an occupancy grid as it forms

If the visualizer looks like a usable map, you know sensors + parsing are correct.

---

## Phase 8: Headless Training (Future)

Once stable:
- run Quake in a headless/low-render configuration
- accelerate simulation (timescale) for faster data collection
- train overnight and save updated hive/ego files

---

## Performance Guidelines (Non-Negotiables)

- Never block Quake frames waiting for Brain I/O
- Budget raycasts; time-slice sensors
- Brain tick rate can be lower than game tick; Body holds last command
- Prefer small, versioned packets over verbose text/JSON when throughput becomes a bottleneck
- Consider separate trace modes for sensors:
  - "navigation" traces (collisions/blocked movement)
  - "vision" traces (ignore transparent volumes like water as needed)

---

## Immediate Next PRs (Suggested)

1. Add identity handshake + `brains/` directory conventions
2. Add Brain -> Body control channel (minimal action set)
3. Add a versioned message header (`ProtocolVersion`, `SequenceId`)
4. Add time-sliced sensor mode + stuck recovery
5. Add persistence stubs (load/save "soul" at match start/end)
