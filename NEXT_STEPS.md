# Roadmap & Next Steps for Project Cortex (Pure QuakeC Bot)

**Last Updated**: 2026-01-01
**Current Focus**: Pure bot stabilization (movement, navigation, and debugging)

---

## Phase 1: Movement + Navigation (Now)

- Ensure player/bot movement works in pure mode across FTEQW builds
- Fix bot goal selection so targets are not resolved to the current position
- Add stuck detection + recovery (repath, jump, or turn)
- Improve pathfinding debug output (target, path node count, fallback reasons)
- Validate death animation timing before respawn

## Phase 2: Combat + Tactics

- Weapon selection based on range and ammo
- Aim smoothing and reaction delay for readable behavior
- Strafe and cover choices during fights
- Basic threat evaluation (distance, health, line of sight)

## Phase 3: Multi-Bot + Arena Behavior

- Consistent multi-bot spawn/cleanup helpers
- Target selection across multiple enemies
- Item control (health/armor/ammo pickup priorities)

## Phase 4: Performance + Debugging

- Budget sensor work per frame (time-slice scans)
- Add clear debug toggles for pathing, perception, and combat
- Keep log noise low while preserving critical state dumps

---

## Non-Negotiables

- Pure QuakeC only (no Python, IPC, or networking)
- Do not block frame updates; all logic must be tick-safe
- Prefer simple, debuggable behaviors over complex black boxes

---

## Immediate Next PRs (Suggested)

1. Fix bot movement target selection + stuck recovery
2. Stabilize spawn/death behavior (respawn timing)
3. Add pathing debug toggles and clearer log messages
