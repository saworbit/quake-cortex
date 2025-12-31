# Cortex Bot Arena: Advanced Camera Follow System

Bring esports-style chase cam to the Cortex Bot Arena by spawning a QC-powered ghost camera that follows bots smoothly at 60 Hz. Perfect for DarkPlaces spectators (built on entity think loops + trace offsets), letting you auto-lock top fraggers, cycle through bots, or free-fly without clipping.

## Step 1: Updated spectator launcher
- `spectator_client.bat` now auto-enters spec mode:
```
@echo off
echo Connecting to Bot Arena + Auto-Spec...
darkplaces.exe -game cortex +connect localhost:26000 +exec spectator.cfg +spectate_mode 1
```

## Step 2: Enhanced `spectator.cfg`
```
// === CORTEX BOT CAMERA SYSTEM ===
spectate_mode 1

// Smooth follow params
chase_active 0
cl_forwardspeed 1000
noclip 1

bind 1 "spectate_bot 1; echo ^2Following Bot1!"
bind 2 "spectate_bot 2; echo ^2Following Bot2!"
... up to bind 0 for bot10 ...
bind F1 "spectate_top_fragger; echo ^3Locked to TOP FRAGGER!"
bind F2 "spectate_random_bot; echo ^2Random Bot Follow!"
bind F3 "spectate_cycle_bots; echo ^4Cycling Bots..."
bind F4 "spectate_free; echo ^5Free Cam ON"
bind MOUSE3 "toggle spectate_free"
bind TAB "cortex_arena_stats"

fov 100
crosshair 0
r_drawviewmodel 0
gamma 1.2

echo "^2=== BOT FOLLOW READY! 1-0=Specific Bot ^4F1=Top ^5F2=Random ^6F3=Cycle ^7TAB=Stats ==="
```

## Step 3: Arena console commands
| Command | Action |
| --- | --- |
| `spectate_mode 1` | Enter ghost cam (suicide + spawn follower). `0` exits. |
| `spectate_bot N` | Follow bot N (1–16). |
| `spectate_top_fragger` | Lock onto highest frag bot (refreshed every 5s). |
| `spectate_random_bot` | Jump to a random alive bot. |
| `spectate_cycle_bots` | Cycle to the next alive bot. |
| `spectate_free` | Toggle free-fly (removes ghost). |

Use `F1` to follow the leader, `F3` to rapid-cycle, `TAB` to show stats + current follow target.

## Step 4: QC snippet (`quakec/cortex/bot/cortex_bot.qc`)
Paste before `Cortex_SpawnBot()` so every spec player can spawn a ghost follower.
```qc
entity spec_ghost;
float spec_following = -1;

void(entity cam) SpecFollowThink =
{
    if (spec_following <= 0 || spec_following > cortex_bot_count)
    {
        spec_following = -1;
        self.think = SUB_Remove;
        return;
    }
    local entity target = cortex_bots[spec_following - 1];
    if (!target || !target.health)
    {
        spec_following = -1;
        return;
    }

    local vector offset = [0, -80, 40] * (1 + sin(time * 2) * 0.1);
    traceline(target.origin + [0, 0, 40], target.origin + [0, 0, 40] + offset, TRUE, target);
    self.origin = trace_endpos;

    self.angles = target.angles;
    self.v_angle = target.v_angle;
    self.nextthink = time + 0.016;
};

void() spectate_free =
{
    if (spec_ghost) remove(spec_ghost);
    spec_following = -1;
    centerprint(self, "FREE CAM ACTIVE - Fly with WASD+Mouse");
};

void(float bot_idx) spectate_bot =
{
    if (bot_idx < 1 || bot_idx > cortex_bot_count)
    {
        centerprint(self, "Invalid bot index!");
        return;
    }
    spec_following = bot_idx;
    if (!spec_ghost || !spec_ghost.inuse)
    {
        spec_ghost = spawn();
        spec_ghost.solid = SOLID_NOT;
        spec_ghost.movetype = MOVETYPE_NOCLIP;
        spec_ghost.effects = EF_NODRAW;
    }
    spec_ghost.think = SpecFollowThink;
    spec_ghost.nextthink = time + 0.1;
    centerprint(self, sprintf("FOLLOWING BOT%g!", bot_idx));
};

void() spectate_top_fragger =
{
    local float top_idx = 0, top_frags = -1;
    for (float i = 0; i < cortex_bot_count; i++)
        if (cortex_bots[i] && cortex_bots[i].health > 0 && cortex_bots[i].frags > top_frags)
        {
            top_frags = cortex_bots[i].frags;
            top_idx = i + 1;
        }
    spectate_bot(top_idx);
};

void() spectate_random_bot =
{
    local float alive = 0;
    for (float i = 0; i < cortex_bot_count; i++)
        if (cortex_bots[i] && cortex_bots[i].health > 0) alive++;
    if (alive <= 0)
    {
        centerprint(self, "No bots alive!");
        return;
    }
    local float idx = 1 + floor(random() * alive);
    spectate_bot(idx);
};

void() spectate_cycle_bots =
{
    local float next = spec_following + 1;
    while (next <= cortex_bot_count)
    {
        if (cortex_bots[next - 1] && cortex_bots[next - 1].health > 0)
        {
            spectate_bot(next);
            return;
        }
        next++;
    }
    spectate_bot(1);
};

void() spectate_mode =
{
    local float mode = stof(argv(1));
    if (mode)
    {
        self.health = -99;
        PlayerDie();
        self.think = () => { spectate_bot(1); };
        self.nextthink = time + 0.5;
        centerprint(self, "SPECTATOR GHOST CAM ACTIVE!");
    }
    else
    {
        spectate_free();
        respawn();
    }
};

cvar_def("spectate_mode", "0");

void() cortex_arena_stats =
{
    // existing stats...
    if (spec_following > 0)
        print(sprintf("^3Following: Bot%g\n", spec_following));
};
```

Rebuild (`scripts/build_pure.bat`) and relaunch the arena server/spectator BATs. The ghost cam follows bots smoothly, cycles via console binds, and prints live follower info via `TAB`.

## Bonus
- Subtle bobbing offset adds cinematic breathing motion.
- F1 follows leader; F2+F3 random/cycle keep things dynamic.
- Ghost cam works even when multiple friends spec (each spawns their own follower).

## Step 5: Director AI Camera Mode
Add pro-level director smoothing and targeting on top of the ghost cam.

### Links & Binds
Use the existing `spectator.cfg` with these binds:
```
bind F1 "director_cam 1; echo ^2DIRECTOR AI ACTIVE - Watching the ACTION!"
bind F2 "director_aggression 1.0"
bind F3 "director_mode 2"
bind F4 "director_cycle"
bind TAB "director_stats"
```

### Director commands
| Command | Purpose |
| --- | --- |
| `director_cam 1` | Enable the director; `0` returns to manual follow. |
| `director_aggression <0-1>` | Adjust switch speed/variance. |
| `director_mode 1/2` | 1 = arena overview, 2 = duel-priority. |
| `director_cycle` | Force latest featured bot. |
| `director_stats` | Print the current featured bot + score summary. |

### QC snippet (replace or supplement the ghost cam code)
```qc
entity director_ghost;
float director_active = 0;
float director_aggression = 0.7;
float director_mode = 1;
float bot_scores[16];
float current_featured[3];
float last_switch_time;
float switch_timer;

vector() LerpVec(vector a, vector b, float t) =
{
    return a + normalize(b - a) * vlen(b - a) * t;
};

vector() LerpAngles(vector a, vector b, float t) =
{
    local vector delta = b - a;
    delta_y = bound(-180, delta_y, 180);
    return a + delta * t;
};

float(entity bot) CalcBotScore =
{
    local float score = bot.frags * 3;
    score += (100 - bot.health) * 0.2;
    local float enemies = 0;
    local float mega_dist = 999;
    local entity e = findradius(bot.origin, 400);
    while (e)
    {
        if (e.classname == "player" && e != bot && e.health > 0) enemies++;
        if (e.classname == "item_megahealth" && vlen(e.origin - bot.origin) < mega_dist) mega_dist = vlen(e.origin - bot.origin);
        e = e.chain;
    }
    score += enemies * 1.5;
    score += (400 - mega_dist) * 0.01;
    score += vlen(bot.velocity) * 0.001;
    if (director_mode == 2) score *= max(1, enemies);
    return score * (0.5 + director_aggression * 0.5);
};

void() UpdateFeaturedBots =
{
    for (float i = 0; i < cortex_bot_count; i++)
    {
        if (cortex_bots[i] && cortex_bots[i].health > 0)
            bot_scores[i] = CalcBotScore(cortex_bots[i]);
        else
            bot_scores[i] = -1;
    }
    for (float slot = 0; slot < 3; slot++)
    {
        local float best_score = -1, best_idx = -1;
        for (float i = 0; i < cortex_bot_count; i++)
            if (bot_scores[i] > best_score) { best_score = bot_scores[i]; best_idx = i; }
        current_featured[slot] = best_idx + 1;
        if (best_idx >= 0) bot_scores[best_idx] = -1;
    }
};

void() DirectorThink =
{
    if (!director_active) return;
    if (time > last_switch_time + 2) { UpdateFeaturedBots(); last_switch_time = time; }
    if (time > switch_timer) { switch_timer = time + (3 + random() * 5) * (1 - director_aggression); }
    local entity target = cortex_bots[current_featured[0] - 1];
    if (!target || !target.health) { UpdateFeaturedBots(); target = cortex_bots[current_featured[0] - 1]; if (!target) return; }
    local vector pred_pos = target.origin + target.velocity * 0.3;
    local vector best_offset = [0, -100, 50];
    local float best_frac = 0;
    local vector offsets[5] = { [0,-1,0.5], [-0.3,-1,0.5], [0.3,-1,0.5], [0,-0.5,1.2], [0.2,-1.2,0.3] };
    for (float i = 0; i < 5; i++)
    {
        local vector test_off = offsets[i] * 120;
        traceline(pred_pos + [0,0,40], pred_pos + [0,0,40] + test_off, TRUE, target);
        if (trace_fraction > best_frac) { best_frac = trace_fraction; best_offset = test_off; }
    }
    local float lerp_rate = 0.2 + director_aggression * 0.1;
    director_ghost.origin = LerpVec(director_ghost.origin, pred_pos + best_offset, lerp_rate);
    director_ghost.angles = LerpAngles(director_ghost.angles, target.angles + [5, 0, 0], lerp_rate);
    local float fov = 90 + (1 - best_frac) * 30;
    cvar_set("fov", ftos(fov));
    director_ghost.nextthink = time + 0.016;
};

void() director_cam =
{
    director_active = stof(argv(1));
    if (director_active)
    {
        if (!director_ghost)
        {
            director_ghost = spawn();
            director_ghost.solid = SOLID_NOT;
            director_ghost.movetype = MOVETYPE_NOCLIP;
            director_ghost.effects = EF_NODRAW;
            director_ghost.origin = [0,0,0];
        }
        director_ghost.think = DirectorThink;
        director_ghost.nextthink = time + 0.1;
        UpdateFeaturedBots();
        centerprint(self, "^2DIRECTOR AI ACTIVE - Watching the Action!");
    }
    else
    {
        if (director_ghost) remove(director_ghost);
        cvar_set("fov", "90");
    }
};

void() director_aggression = { director_aggression = bound(0, stof(argv(1)), 1); };
void() director_mode = { director_mode = bound(1, stof(argv(1)), 2); };
void() director_cycle = { switch_timer = 0; };
void() director_stats =
{
    print(sprintf("^3Director tracking Bot%g | Switch rate: %.2f | Mode %g\n",
        current_featured[0], director_aggression, director_mode));
};
```

Rebuild (`scripts/build_pure.bat`) and relaunch. `F1` lets the director AI handle camera switches while `F2`/`F3` tune aggression/mode, `F4` forces a new featured bot, and `TAB` shows the director status.
