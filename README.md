# PROJECT CORTEX

**Pure QuakeC Bot for Quake 1**

*"Do not cheat. Perceive, Predict, Perform."*

[![Build QuakeC](https://github.com/saworbit/quake-cortex/actions/workflows/build-quakec.yml/badge.svg?branch=main)](https://github.com/saworbit/quake-cortex/actions/workflows/build-quakec.yml)
[![Documentation Check](https://github.com/saworbit/quake-cortex/actions/workflows/docs-check.yml/badge.svg?branch=main)](https://github.com/saworbit/quake-cortex/actions/workflows/docs-check.yml)
[![Python Code Quality](https://github.com/saworbit/quake-cortex/actions/workflows/python-lint.yml/badge.svg?branch=main)](https://github.com/saworbit/quake-cortex/actions/workflows/python-lint.yml)

## Quick Start

```bash
# Build the pure QuakeC bot
scripts\build.bat

# Run the bot (requires FTEQW engine)
scripts\run.bat
```

**Main Focus**: Pure QuakeC bot with zero external dependencies. All AI logic runs inside QuakeC.

**Experimental**: Hybrid implementations (Python + QuakeC) are available in the `hybrids/` directory.

Details: `docs/BOTS_GUIDE.md`

## Project Structure

```text
ProjectCortex/                 # Main - Pure QuakeC Bot
  quakec/                      # QuakeC source code
    cortex/
      common/                  # Sensors + world integration
      bot/                     # Pure QuakeC bot AI (10 modules)
    lib/                       # Base Quake source
    progs.src                  # Main build manifest
  scripts/                     # Build and run scripts
    build.bat                  # Build pure bot
    run.bat                    # Run pure bot
  Game/cortex/                 # Compiled mod output
  docs/                        # Documentation

  hybrids/                     # Experimental hybrid implementations
    quakec/                    # Shared hybrid QuakeC code
      cortex/hybrid/           # Bridge + TCP IPC code
      progs.src                # Hybrid build manifest
    fteqw/                     # FTEQW hybrid (Python brain)
      python/streams/          # File + TCP implementations
      scripts/                 # FTEQW build/run scripts
      Game/cortex/             # FTEQW output
    darkplaces/                # DarkPlaces hybrid (RCON)
      python/streams/rcon/     # RCON implementation
      scripts/                 # DarkPlaces scripts
      Game/cortex/             # DarkPlaces output
    shared/                    # Shared Python utilities
```

## Current Status

**Pure QuakeC Bot:**
- ✅ QuakeC code compiles successfully
- ✅ Based on single-player Quake source
- ✅ 10-module bot AI stack (pathfinding, perception, tactics, combat, etc.)
- ✅ Sensor suite (raycasts, proprioception, enemy detection)
- ✅ World integration hooks
- ✅ Runs on FTEQW engine

**Experimental Hybrids** (see `hybrids/` directory):
- ✅ FTEQW hybrid with File/TCP IPC
- ✅ DarkPlaces hybrid with RCON control
- ✅ Python brain implementations
- ⚠️ Not the main focus

**See [docs/STATUS.md](docs/STATUS.md) for detailed roadmap**

## Development Workflow

### Building the Mod

```bash
scripts\build.bat
```

This compiles `quakec/progs.src` → `Game/cortex/progs.dat`

### Running the Bot

```bash
scripts\run.bat
```

This builds the mod and launches FTEQW with the bot enabled.

### Editing Code

**QuakeC (Bot Logic)**:
- Edit files in [quakec/cortex/](quakec/cortex/)
  - `common/` - Sensors, logging, world hooks
  - `bot/` - 10-module bot AI stack
- Run [scripts/build.bat](scripts/build.bat) to recompile
- Restart Quake to load new progs.dat

**For Hybrid Modes** (experimental):
- See [hybrids/README.md](hybrids/README.md)

## Architecture

**Pure QuakeC Bot:**

```
┌──────────────────────────────────┐
│      QUAKE + CORTEX BOT          │
│                                  │
│  • Sensors (raycasts, etc.)      │
│  • Pathfinding                   │
│  • Perception                    │
│  • Tactics & Combat              │
│  • Team Coordination             │
│  • Memory & Opponent Modeling    │
│  • Monte Carlo Tree Search       │
│                                  │
│  All running in QuakeC           │
└──────────────────────────────────┘
     100% self-contained
```

**Design Philosophy**:
- **Main focus**: Pure QuakeC bot with all AI logic inside QuakeC
- **No external dependencies**: Zero Python, zero IPC, zero networking
- **Experimental hybrids**: Available in `hybrids/` for those who want Python integration

## Key Files

| File | Purpose | Lines |
| --- | --- | --- |
| [quakec/cortex/bot/cortex_bot.qc](quakec/cortex/bot/cortex_bot.qc) | Main bot AI logic | ~1,400 |
| [quakec/cortex/bot/cortex_pathfinding.qc](quakec/cortex/bot/cortex_pathfinding.qc) | Navigation & pathfinding | ~200 |
| [quakec/cortex/bot/cortex_perception.qc](quakec/cortex/bot/cortex_perception.qc) | Environmental awareness | ~150 |
| [quakec/cortex/bot/cortex_tactics.qc](quakec/cortex/bot/cortex_tactics.qc) | Tactical decision-making | ~200 |
| [quakec/cortex/bot/cortex_combat.qc](quakec/cortex/bot/cortex_combat.qc) | Combat behavior | ~250 |
| [quakec/cortex/bot/cortex_mcts.qc](quakec/cortex/bot/cortex_mcts.qc) | Monte Carlo Tree Search | ~300 |
| [quakec/cortex/common/cortex_sensor.qc](quakec/cortex/common/cortex_sensor.qc) | Sensor suite | ~290 |
| [quakec/cortex/common/cortex_world.qc](quakec/cortex/common/cortex_world.qc) | World integration hooks | ~425 |
| [quakec/progs.src](quakec/progs.src) | Build manifest | ~58 |
| [hybrids/README.md](hybrids/README.md) | Experimental hybrids info | - |

## Documentation

- **[docs/BOTS_GUIDE.md](docs/BOTS_GUIDE.md)** - Pure QuakeC bot guide
- **[docs/README.md](docs/README.md)** - Full technical documentation
- **[docs/STATUS.md](docs/STATUS.md)** - Implementation status & roadmap
- **[hybrids/README.md](hybrids/README.md)** - Experimental hybrid implementations

## Requirements

**QuakeC Compilation**:
- FTEQW compiler (✅ included: `quakec/fteqcc64.exe`)

**Quake Runtime** (⚠️ **YOU MUST PROVIDE**):
- **FTEQW Engine**: Download from [https://fte.triptohell.info/](https://fte.triptohell.info/)
  - Extract `fteqw64.exe` (or `fteqw` on Linux) to the `Game/` directory
- **Quake PAK Files**: Obtain from a legal copy of Quake 1
  - Steam: [https://store.steampowered.com/app/2310/](https://store.steampowered.com/app/2310/)
  - GOG: [https://www.gog.com/game/quake_the_offering](https://www.gog.com/game/quake_the_offering)
  - Or use the shareware `pak0.pak` from [https://www.quaddicted.com/](https://www.quaddicted.com/)
  - Place `PAK0.PAK` (and optionally `PAK1.PAK`) in `Game/id1/` directory

**Note**: Due to licensing, we cannot distribute Quake's game data or engine binaries. You must provide your own legally obtained copies.

## Troubleshooting

**Build fails**:
- Check that `quakec/lib/QuakeC-releases/` exists
- Verify `quakec/fteqcc64.exe` is present
- See full error output in console

**Bot doesn't spawn**:
- Make sure you're in a map (not menu): `map start` or `map e1m1`
- Check console for bot spawn messages
- Verify `cortex_bot_enable 1` is set

## Contributing

This is an experimental research project. The codebase is organized for clarity:

**Pure QuakeC Bot:**
- **Add new sensors**: Edit [quakec/cortex/common/cortex_sensor.qc](quakec/cortex/common/cortex_sensor.qc)
- **Improve bot AI**: Edit [quakec/cortex/bot/cortex_bot.qc](quakec/cortex/bot/cortex_bot.qc) and related modules
- **Update build process**: Edit [scripts/build.bat](scripts/build.bat)

**Experimental Hybrids:**
- See [hybrids/README.md](hybrids/README.md)

## License

- QuakeC code: GPLv2 (based on id Software's release)
- Python code: MIT License
- Documentation: CC BY 4.0

---

**Status**: Pure QuakeC bot with 10-module AI stack
**Last Updated**: 2025-12-31
**Version**: 0.2.0
