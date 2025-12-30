# Idiot-Proof Cortex Bot Spawning Guide

Use this guide to spawn, manage, and tweak Cortex bots without editing QuakeC—just drop a config file, use console commands, and paste the provided snippets if you ever want faster hacks.

## TL;DR Keybinds (after `exec cortex_bots.cfg`)
| Key | Action |
| --- | --- |
| `b` | Spawn 1 smart bot (feedback printed) |
| `Shift+B` | Spawn +4 bots at once |
| `n` | Nuke every bot |
| `h` | Print the bot help cheat sheet |
| `F1` / `F2` | Set skill to 0.5 / 1.0 |
| `F3` | Switch to aggressive style |
| `MOUSE4` | Add one bot (side button) |

## Step 1: Launch Quake with the Cortex mod
Copy-paste this into a terminal that is already in `Game/`:

### FTEQW (current default)
```
fteqw64.exe -game cortex +map dm3 +deathmatch 1 +sv_cheats 1 +skill 3
```

### DarkPlaces (recommended pivot)
```
darkplaces.exe -game cortex +map dm3 +deathmatch 1 +sv_cheats 1 +skill 3 +rcon_password cortex_secret
```

`dm3` is the default deathmatch map; swap to `dm4`, `start`, etc. Save either command as `scripts/run_cortex_bots.bat` for one-click launches.

## Step 2: Auto-setup keybinds & help menu (one-time)
In the Quake console (`~`), execute:
```
exec cortex_bots.cfg
```
If the file does not exist yet, create it under `Game/cortex/` using the snippet below. The console printouts confirm bot controls are loaded.

## Step 3: Core console commands
All commands begin with `cortex_` and print `DONE!` or an error when you run them:

| Command | Description | Example |
| --- | --- | --- |
| `cortex_bot_help` | Print this cheat sheet | `cortex_bot_help` |
| `cortex_spawn_bot` | Spawn a single smart bot at a DM spawn | `cortex_spawn_bot` |
| `cortex_add_bots N` | Add N more bots, capped at 16 | `cortex_add_bots 8` |
| `cortex_remove_bots` | Remove every Cortex bot immediately | `cortex_remove_bots` |
| `cortex_bot_list` | List active bots and stats | `cortex_bot_list` |
| `cortex_set_skill X` | Set all bots’ skill (0–1) | `cortex_set_skill 0.7` |
| `cortex_set_style S` | Personality: 0=cautious → 3=reckless | `cortex_set_style 2` |
| `cortex_respawn_bots` | Revive all bots | `cortex_respawn_bots` |
| `cortex_toggle_bots` | Toggles bots; spawns 4 if none | `cortex_toggle_bots` |

Examples:
```
cortex_add_bots 6
cortex_set_skill 0.7
cortex_bot_list
```
Output: `6 Cortex bots spawned! Skill: 70% | Bot1: 5 frags | Bot2: Alive...` or a helpful error (e.g., “Max bots reached!”).

## Step 4: The auto-config file
Create `Game/cortex/cortex_bots.cfg` with this content:

```
// Idiot-Proof Cortex Bot Controls
echo "^2=== CORTEX BOTS LOADED! ^3b=Add1 ^4Shift+B=Add4 ^5n=Nuke ^6h=Help ^7==="

alias cortex_spawn_bot "cortex_spawn_bot; echo ^2Bot spawned! Use b for more."
alias cortex_add_bots "cortex_add_bots $1; echo ^2$1 bots added! Total: $cortex_bot_count"
alias cortex_remove_bots "cortex_remove_bots; echo ^1ALL BOTS NUKED!"
alias cortex_bot_list "cortex_bot_list"
alias cortex_set_skill "cortex_set_skill $1; echo ^3All bots skill: $1 (0=newb,1=pro)"
alias cortex_set_style "cortex_set_style $1; echo ^3Style: $1 (0=safe,3=crazy)"
alias cortex_respawn_bots "cortex_respawn_bots; echo ^2Bots revived!"
alias cortex_toggle_bots "cortex_toggle_bots; echo ^3Bots toggled!"

bind b "cortex_spawn_bot"
bind "MOUSE4" "cortex_add_bots 1"
bind n "cortex_remove_bots"
bind h "cortex_bot_help"
bind F1 "cortex_set_skill 0.5"
bind F2 "cortex_set_skill 1.0"
bind F3 "cortex_set_style 2"

echo "^2Keybinds ready! Press h anytime."
```

Then `exec cortex_bots.cfg` to load it again.

## Step 5: Optional QuakeC helpers (copy into `quakec/cortex/bot/cortex_bot.qc`)
Add these definitions **before** `Cortex_SpawnBot()` if you want dedicated console commands and multi-bot tracking. They layer on top of the existing bot logic (no external edits otherwise).

```qc
#define MAX_BOTS 16
entity cortex_bots[MAX_BOTS];
float cortex_bot_count;
float cortex_global_skill = 0.8;
float cortex_global_style = 1.0;

void() cortex_bot_help =
{
    print("CORTEX HELP:\n"
          "cortex_spawn_bot - 1 bot\n"
          "cortex_add_bots N - up to 16\n"
          "cortex_remove_bots - delete all\n"
          "cortex_set_skill X - skill 0..1\n"
          "cortex_bot_list - stats\n");
};

void() cortex_remove_bots =
{
    for (float i = 0; i < cortex_bot_count; i++)
        if (cortex_bots[i]) remove(cortex_bots[i]);
    cortex_bot_count = 0;
    print("ALL BOTS REMOVED!\n");
};

void() cortex_bot_list =
{
    print(sprintf("BOTS: %g | Skill: %.1f | Style: %g\n",
                  cortex_bot_count, cortex_global_skill, cortex_global_style));
    for (float i = 0; i < cortex_bot_count; i++)
        if (cortex_bots[i])
            print(sprintf("Bot%g: %g frags | HP:%g\n",
                          i, cortex_bots[i].frags, cortex_bots[i].health));
};

void() cortex_set_skill =
{
    cortex_global_skill = bound(0, stof(argv(1)), 1);
    print(sprintf("Skill set to %.1f\n", cortex_global_skill));
};

void() cortex_set_style =
{
    cortex_global_style = bound(0, stof(argv(1)), 3);
    print(sprintf("Style set to %g\n", cortex_global_style));
};

void() cortex_spawn_bot =
{
    if (cortex_bot_count >= MAX_BOTS) { print("MAX BOTS!\n"); return; }
    local entity newbot = spawn();
    newbot.bot_index = cortex_bot_count;
    newbot.skill = cortex_global_skill;
    newbot.style = cortex_global_style;
    cortex_bots[cortex_bot_count++] = newbot;
    newbot.think = Cortex_BotThink;
    newbot.nextthink = time + 0.1;
    print("BOT SPAWNED!\n");
};

void() cortex_add_bots =
{
    local float num = bound(1, stof(argv(1)), MAX_BOTS - cortex_bot_count);
    repeat(num) cortex_spawn_bot();
};

void() cortex_respawn_bots =
{
    cortex_remove_bots();
    cortex_add_bots(4);
};

void() cortex_toggle_bots =
{
    if (cortex_bot_count > 0) cortex_remove_bots();
    else cortex_add_bots(4);
};
```

Recompile with `scripts/build.bat` after adding the snippet.

## Step 6: Bonus tips
- `cortex_spawn_bot` and `cortex_add_bots` do not require Python—just make sure `cortex_bot_enable 1` (for pure QuakeC) or `cortex_spawn_bot 1` (for RCON) is set.
- Keep `cortex_bot_count` under 16 to avoid hitting engine limits.
- Use `cortex_bot_list` to monitor performance (frags, HP, skill).

Enjoy spawning crafty Cortex bots with zero QuakeC know-how! Paste `cortex_bots.cfg` once and rely on the console for everything. If you do edit QuakeC, drop the snippet above into `quakec/cortex/bot/cortex_bot.qc` and rebuild.

Hosting a multiplayer server? Pair this cfg with `docs/MULTI_SERVER.md` to bind server helpers and keep console commands handy for running listen/dedicated matches.
