# PROJECT CORTEX

Project Cortex is an experimental AI sandbox for Quake 1.

It supports three tracks (all share the same QuakeC mod):
- **Pure QuakeC bot**: decisions inside QuakeC (no Python)
- **Hybrid FTEQW + Python**: file IPC (default) or stream mode (experimental)
- **Hybrid DarkPlaces + Python**: UDP RCON control loop (experimental)

Start here: `docs/MODES.md`

## Primary Docs

- `docs/MULTI_SERVER.md` - Multiplayer server hosting primer
- `docs/ARENA.md` - Bot-vs-bot spectator arena
- `docs/QUICKSTART.md` - fast start (hybrid + experimental modes)
- `docs/TCP_MODE.md` - FTEQW stream mode (ws:// / tcp://)
- `docs/DARKPLACES_PIVOT.md` - DarkPlaces RCON mode
- `docs/LOGGING.md` - logs and debugging
- `docs/COMPATIBILITY.md` - engine quirks / compatibility notes

## Code Locations

- QuakeC:
  - `quakec/cortex/common/` (sensors + world integration)
  - `quakec/cortex/hybrid/` (file/stream IPC driver)
  - `quakec/cortex/bot/` (pure-QuakeC bot AI stack)
- Python:
  - `python/streams/file/` (file tail + visualizer)
  - `python/streams/tcp/` (ws/tcp stream + Gymnasium env)
  - `python/streams/rcon/` (DarkPlaces RCON loop)
