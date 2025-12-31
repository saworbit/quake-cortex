# Cortex Bot Arena: Bot-vs-Bot Deathmatch Spectator System

Run a DarkPlaces dedicated server where 16 Cortex bots frag each other while you spectate in a chase cam. The setup auto-rotates dm1-dm6, prints stats, lets you tune skill mid-fight, and keeps chaos contained.

## Step 1: One-click BAT files (put in `Game/`)
Run `arena_server.bat` first, then `spectator_client.bat`.

### `arena_server.bat` (DarkPlaces dedicated bot fight)
```
@echo off
echo Starting Cortex Bot Arena Server...
darkplaces-server.exe -game cortex +map dm3 +deathmatch 2 +dedicated 1 +maxclients 17 +sv_cheats 1 +fraglimit 50 +timelimit 15 +cortex_add_bots 16 +exec arena_server.cfg
pause
```

### `spectator_client.bat` (chase cam viewer)
```
@echo off
echo Connecting to Bot Arena...
darkplaces.exe -game cortex +connect localhost:26000 +chase_active 1 +chase_back 120 +chase_up 32 +exec spectator.cfg
```

Bots auto respawn, fraglimit 50 / timelimit 15 → map list dm1->dm6 cycle. Spec slot is free; chase cam toggles via binds.

## Step 2: Config files (create `Game/cortex_pure/arena_server.cfg` & `spectator.cfg`)

### `arena_server.cfg`
```
deathmatch 2
fraglimit 50
timelimit 15
maxclients 17
sv_cheats 1
maplist "dm1 dm2 dm3 dm4 dm5 dm6"

cortex_bot_enable 1
cortex_add_bots 16
cortex_set_skill 0.85
cortex_set_style 2

say "^2=== CORTEX BOT ARENA LIVE! 16 bots fragging! Spectate on localhost:26000 ==="
alias next_map "changelevel $1; cortex_respawn_bots"
echo "^3Arena ready! Fraglimit 50 -> auto next map!"
```

### `spectator.cfg`
```
chase_active 1
chase_back 120
chase_up 32
chase_right 0

bind 1 "chase_next; sayteam Watching next bot!"
bind 2 "chase_prev; sayteam Watching previous bot!"
bind 3 "chase_free 1"
bind 4 "chase_free 0"
bind MOUSE3 "toggle chase_free"
bind TAB "cortex_arena_stats"

fov 110
crosshair 0
cl_thirdperson 0

echo "^2=== SPECTATOR READY! 1=Next Bot 2=Prev 3=FreeCam 4=LockCam TAB=Stats ==="
```

## Step 3: Arena console commands (server or spectator)

| Command | Action |
| --- | --- |
| `cortex_arena N` | Nuke bots, spawn N new ones, reset limits |
| `cortex_arena_stats` | Print top fraggers (frags + HP) |
| `cortex_next_map` | Force next map (dm1-dm6 loop) + respawn bots |
| `cortex_set_skill S` | Set skill 0.1..1.0 |
| `cortex_pause_bots 1/0` | Freeze/unfreeze bots |
| `cortex_respawn_bots` | Revive everybody |
| `cortex_set_style` | Aggressive/risk style |

Spectator extras: `1/2` chase next/prev, `TAB` = stats, `MOUSE3` toggles free cam. For the cinematic ghost cam, follow `docs/ARENA_CAM.md`.

## Step 4: Optional QuakeC snippet (`quakec/cortex/bot/cortex_bot.qc`)
Add arena globals inside the bot file:
```qc
string map_rotation[6] = {"dm1","dm2","dm3","dm4","dm5","dm6"};
float current_map_idx = 2;

void() cortex_arena =
{
    local float num = bound(1, stof(argv(1)), 16);
    cortex_remove_bots();
    cortex_add_bots(num);
    cbuf_addtext("fraglimit 50; timelimit 15\n");
    print(sprintf("^2ARENA STARTED: %g bots! Fraglimit 50 -> auto next map\n", num));
};

void() cortex_next_map =
{
    current_map_idx = (current_map_idx + 1) % 6;
    cbuf_addtext(sprintf("changelevel %s; ", map_rotation[current_map_idx]));
    cortex_respawn_bots();
    print(sprintf("^2NEXT MAP: %s (bots respawned)\n", map_rotation[current_map_idx]));
};

void() cortex_arena_stats =
{
    local float top_frags = 0, top_idx = 0;
    print("^3=== ARENA TOP FRAGS ===\n");
    for (float i = 0; i < cortex_bot_count; i++)
        if (cortex_bots[i])
        {
            print(sprintf("Bot%g: %g frags | HP:%g\n", i, cortex_bots[i].frags, cortex_bots[i].health));
            if (cortex_bots[i].frags > top_frags) { top_frags = cortex_bots[i].frags; top_idx = i; }
        }
    print(sprintf("^1LEADER: Bot%g (%g frags)\n", top_idx, top_frags));
};

void() cortex_pause_bots =
{
    cvar_set("cortex_pause_bots", argv(1));
};
```
In `Cortex_BotThink`, skip movement/fire when `cvar("cortex_pause_bots")` is `1`.

Rebuild via `scripts/build_pure.bat`. After adding the snippet, the arena commands are available console-wide.

## Step 5: Launch sequence
1. Double-click `arena_server.bat` → console shows arena ready, fraglimit/timelimit enforced.
2. Double-click `spectator_client.bat` → auto-connects, chase cam ready (use 1/2/TAB).
3. Watch 16 bots frag each other; on fraglimit/time, the map rotates automatically through dm1–dm6.

## Troubleshooting
- `cortex_arena 16` if bots didn’t spawn.
- Lower bots to 12 for smoother fights (`cortex_add_bots 12`).
- Use `cortex_set_skill 0.6` to dial back difficulty.
- Swap to `fteqw64.exe`/`fteqw-sv64.exe` if you prefer FTEQW; chase cam works via `+chase_active 1`.
- Missing maps? Add `pak1.pak` to `Game/id1/`.
- Run server in windowed mode (`-width 1920 -height 1080 -window`) to monitor logs + start spectator.

## Bonus
- Record matches: `record arena_demo1`.
- For persistent Q-learning, the bot code already saves per-map stats (see `quakec/cortex/bot/cortex_memory.qc`).
- Invite players via your public IP + port 26000 once ports/firewall are open.

Enjoy chaotic bot carnage—16 intelligent Cortex bots, persistent learning, chase cam spectacle!
