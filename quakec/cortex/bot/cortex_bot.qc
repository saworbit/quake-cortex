/*
    cortex_bot.qc - Cortex Bot (Pure QuakeC)

    Pure QuakeC AI: a lightweight utility-based FSM (U-FSM) that selects between
    Explore / Collect / Chase / Attack / Flee based on simple needs and perception.

    Notes/limits:
    - If DP_SV_BOTCLIENT is available, the bot uses a real client slot (spawnclient),
      allowing normal player physics, item pickup, and weapon firing.
    - Without DP_SV_BOTCLIENT, the bot falls back to a server-side step entity and
      uses best-effort projectile firing (no inventory/item pickup).
*/

entity cortex_bot;

void() Cortex_BotThink;
void(entity targ, entity attacker) Cortex_BotOnObituary;
void() Cortex_PathInitMaybe;
vector(entity mover, vector goalpos) Cortex_PathNextWaypoint;
vector(entity mover, entity enemy) Cortex_PathAmbushSpot;
void(entity bot) Cortex_Opp_Frame;
void(entity bot, entity victim, entity killer) Cortex_Opp_OnKill;
float(entity bot, entity enemy, vector goal, float allow_rocketjump) Cortex_MCTS_SelectAction;
float(entity bot, entity enemy, vector goal, float allow_rocketjump, float state) Cortex_MCTS_SelectActionMem;
void() CortexMem_Init;
string(string mapname, entity enemy) CortexMem_KeyFor;
void(string key) CortexMem_LoadKey;
float(entity bot, entity enemy, float visible_count) CortexMem_State;
void(float state, float mcts_action, float reward) CortexMem_QUpdate;
void() CortexMem_FlushMaybe;
void(entity bot) Cortex_Perception_Update;
vector(entity bot) Cortex_Team_SeparationSteer;
void(entity bot, entity enemy) Cortex_Combat_MaybeSwitchWeapon;

// FTEQW player physics hook (botclient input)
float input_timelength;
vector input_angles;
vector input_movevalues;
float input_buttons;
float input_impulse;
void(entity ent) runstandardplayerphysics = #347;

// Late-bound (defined in base progs later in progs.src)
void() ClientConnect;
void() PutClientInServer;
void() W_SetCurrentAmmo;
void() respawn;
void() W_FireRocket;
float() crandom;
void() SUB_regen;
void() item_megahealth_rot;

vector() Cortex_Bot_FindSpawnOrigin =
{
    local entity spot;

    spot = find(world, classname, "info_player_deathmatch");
    if (!spot)
        spot = find(world, classname, "info_player_start");

    if (spot)
        return spot.origin;

    return '0 0 0';
};

// ---------------------------------------------------------------------------
// Cvars
// ---------------------------------------------------------------------------
void() Cortex_BotInitCvars =
{
    // Only initialize defaults once per session.
    // Note: QuakeC doesn't have a reliable "cvar exists?" check; this marker cvar is our guard.
    if (cvar("cortex_bot_cvars_initialized"))
        return;

    cvar_set("cortex_bot_cvars_initialized", "1");

    // Bot lifecycle (defaults for pure QuakeC mode)
    cvar_set("cortex_spawn_bot", "1");           // 1 to spawn a controllable bot entity
    cvar_set("cortex_bot_think_interval", "0.02"); // seconds

    // Pure QuakeC bot logic
    cvar_set("cortex_bot_enable", "1");          // 1 to enable internal AI (also spawns bot)
    cvar_set("cortex_bot_aggression", "1.0");    // base aggression multiplier (0.5..2)
    cvar_set("cortex_bot_debug", "0");           // 1 to print occasional state/target info
    cvar_set("cortex_log_level", "3");           // log verbosity (0=info only, 3=all)
    cvar_set("cortex_skill", "0.7");             // 0=newbie, 1=pro (scales reaction + aim jitter)
    cvar_set("cortex_style", "2");               // 0=cautious..3=reckless (risk-taking)
    cvar_set("cortex_bot_nav_enable", "0");      // 1 to enable lightweight nav graph pathing
    cvar_set("cortex_bot_nav_link_radius", "600"); // max link distance between nav nodes
    cvar_set("cortex_bot_nav_direct_check_radius", "1200"); // prefer direct LOS within this distance
    cvar_set("cortex_bot_allow_strafejump", "0");
    cvar_set("cortex_bot_allow_dodge", "1");
    cvar_set("cortex_bot_allow_rocketjump", "0");
    cvar_set("cortex_bot_start_with_rl", "0");   // 1 to spawn with RL+rockets (testing)
    cvar_set("cortex_bot_persist", "1");
    cvar_set("cortex_bot_respawn_delay", "1.0");
    cvar_set("cortex_bot_fov_deg", "200");
    cvar_set("cortex_bot_enemy_memory", "2.5");
    cvar_set("cortex_bot_retaliate_time", "1.5");
    cvar_set("cortex_bot_weapon_switch_cooldown", "0.35");
    cvar_set("cortex_bot_respawn_grace", "0.5");
    cvar_set("cortex_bot_wall_avoid", "1");
    cvar_set("cortex_bot_wall_avoid_dist", "64");
    cvar_set("cortex_bot_mcts_rollouts", "8");
    cvar_set("cortex_bot_react_min", "0.05");
    cvar_set("cortex_bot_react_max", "0.15");
    cvar_set("cortex_bot_aim_jitter_deg", "1.5");
    cvar_set("cortex_bot_fatigue_enable", "1");
    cvar_set("cortex_bot_taunt", "0");
    cvar_set("cortex_bot_item_deny_enable", "1");
    cvar_set("cortex_bot_deny_radius", "300");
    cvar_set("cortex_bot_mega_rush_window", "5");
    if (cvar_string("cortex_pure_mode") == "") cvar_set("cortex_pure_mode", "1");   // 1 when running pure QuakeC bot mode
};

// ---------------------------------------------------------------------------
// Botclient helpers (DP_SV_BOTCLIENT)
// ---------------------------------------------------------------------------
float cortex_bot_is_botclient;

float() Cortex_Bot_HasBotClientSupport =
{
    if (!cvar("pr_checkextension"))
        return 0;
    return checkextension("DP_SV_BOTCLIENT");
};

float() Cortex_Bot_HasDropClientSupport =
{
    if (!cvar("pr_checkextension"))
        return 0;
    return checkextension("DP_SV_DROPCLIENT");
};

void() Cortex_Bot_EquipDefaults =
{
    // Optional deterministic loadout (useful for testing); otherwise let normal spawn parms apply.
    if (!cvar("cortex_bot_start_with_rl"))
        return;

    self.items = self.items | IT_ROCKET_LAUNCHER;
    self.weapon = IT_ROCKET_LAUNCHER;
    if (self.ammo_rockets < 10)
        self.ammo_rockets = 10;
    self.currentammo = self.ammo_rockets;
    W_SetCurrentAmmo();
};

void() Cortex_Bot_Die;
void() Cortex_BotOnRespawn;

void() Cortex_Bot_HookClient =
{
    // Ensure a stable bot loop regardless of respawns.
    self.think = Cortex_BotThink;
    if (self.nextthink < time + 0.01)
        self.nextthink = time + 0.05;

    Cortex_Bot_EquipDefaults();
};

void() Cortex_Bot_SpawnClient =
{
    local entity oldself;

    oldself = self;
    self = spawnclient();
    if (!self || self == world)
    {
        self = oldself;
        bprint("CORTEX: bot spawn failed (server full)\n");
        return;
    }

    cortex_bot = self;
    cortex_bot_is_botclient = 1;

    self.netname = "CortexBot";
    self.clientcolors = 12 * 16 + 4;

    ClientConnect();
    PutClientInServer();

    Cortex_Bot_HookClient();

    self = oldself;
};

// ---------------------------------------------------------------------------
// Pure QuakeC AI (utility-based FSM)
// ---------------------------------------------------------------------------
#define BOT_STATE_EXPLORE 0
#define BOT_STATE_COLLECT 1
#define BOT_STATE_CHASE   2
#define BOT_STATE_ATTACK  3
#define BOT_STATE_FLEE    4

#define BOT_ENEMY_SCAN_RADIUS 1200
#define BOT_PICKUP_SCAN_RADIUS 1200

float cortex_bot_state;
float cortex_bot_recent_kills;
float cortex_bot_recent_deaths;
float cortex_bot_last_decay;
float cortex_bot_next_attack;
float cortex_bot_next_rocketjump;
float cortex_bot_next_weapon_switch;
float cortex_bot_respawn_grace_until;
vector cortex_bot_wander_goal;
float cortex_bot_wander_until;
vector cortex_bot_last_origin;
float cortex_bot_stuck_since;
float cortex_bot_next_decision;
float cortex_bot_selected_action;
float cortex_bot_feint_until;
float cortex_bot_next_taunt;
float cortex_bot_fatigue;
float cortex_bot_visible_enemies;
float cortex_bot_tactic_mode; // 1=1v1, 2=balanced, 3=multi
float cortex_bot_last_think_time;
float cortex_bot_respawn_at;
float cortex_bot_idle_since;
float cortex_bot_idle_until;
vector cortex_bot_idle_dir;
float cortex_bot_wall_sign;
float cortex_bot_wall_until;

float cortex_mem_last_state;
float cortex_mem_last_mcts_action;

// Pseudo-learning: tiny "Q" values for a few high-skill actions.
#define CX_ACT_NONE        0
#define CX_ACT_WALK        1
#define CX_ACT_STRAFEJUMP  2
#define CX_ACT_DODGE       3
#define CX_ACT_ROCKETJUMP  4

float cortex_q_walk;
float cortex_q_strafejump;
float cortex_q_dodge;
float cortex_q_rocketjump;
float cortex_bot_last_action;

float cortex_bot_dodge_until;
float cortex_bot_dodge_sign;

float(float v, float lo, float hi) Cortex_Clamp =
{
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
};

float(entity it) Cortex_Bot_ItemTimeToRespawn =
{
    if (!it) return 0;
    if (it.solid != SOLID_NOT) return 0;
    if (it.model != string_null) return 0;
    if (it.nextthink <= time) return 0;

    if (it.think == SUB_regen)
        return it.nextthink - time;

    if (it.think == item_megahealth_rot)
        return (it.nextthink - time) + 20;

    return 0;
};

float() Cortex_Bot_EffectiveAggression =
{
    local float base;
    local float learned;
    local float style;
    local float bot_skill;

    base = cvar("cortex_bot_aggression");
    if (base <= 0) base = 1;

    learned = 1 + (cortex_bot_recent_kills - cortex_bot_recent_deaths) * 0.1;
    learned = Cortex_Clamp(learned, 0.5, 2.0);

    style = cvar("cortex_style");
    if (style < 0) style = 0;
    if (style > 3) style = 3;

    bot_skill = cvar("cortex_skill");
    if (bot_skill < 0) bot_skill = 0;
    if (bot_skill > 1) bot_skill = 1;

    // Style/skill shaping:
    // - cautious style reduces aggression, reckless increases it
    // - low skill also reduces aggression to avoid "robot rush" at beginner settings
    return Cortex_Clamp(base * learned * (0.65 + style * 0.15) * (0.70 + bot_skill * 0.30), 0.5, 2.0);
};

float() Cortex_Bot_HasCvarStringSupport =
{
    if (!cvar("pr_checkextension"))
        return 0;
    return checkextension("DP_QC_CVAR_STRING");
};

string() Cortex_Bot_QCvarName =
{
    return strcat("cortex_q_", mapname);
};

float(string haystack, string key, float def) Cortex_Bot_ParseKeyFloat =
{
    local float k;
    local float start;
    local float end;
    local string sub;

    k = strstrofs(haystack, key, 0);
    if (k < 0) return def;

    start = k + strlen(key);
    end = strstrofs(haystack, ";", start);
    if (end < 0) end = strlen(haystack);

    sub = substring(haystack, start, end - start);
    if (sub == "") return def;

    return stof(sub);
};

void() Cortex_Bot_LoadPersistentQ =
{
    local string name;
    local string s;

    if (!cvar("cortex_bot_persist")) return;
    if (!Cortex_Bot_HasCvarStringSupport()) return;

    name = Cortex_Bot_QCvarName();
    s = cvar_string(name);
    if (s == "") return;

    cortex_q_walk = Cortex_Bot_ParseKeyFloat(s, "w=", cortex_q_walk);
    cortex_q_strafejump = Cortex_Bot_ParseKeyFloat(s, "sj=", cortex_q_strafejump);
    cortex_q_dodge = Cortex_Bot_ParseKeyFloat(s, "d=", cortex_q_dodge);
    cortex_q_rocketjump = Cortex_Bot_ParseKeyFloat(s, "rj=", cortex_q_rocketjump);
};

void() Cortex_Bot_SavePersistentQ =
{
    local string name;
    local string s;

    if (!cvar("cortex_bot_persist")) return;

    name = Cortex_Bot_QCvarName();
    s = "";
    s = strcat(s, "w=", ftos(cortex_q_walk), ";");
    s = strcat(s, "sj=", ftos(cortex_q_strafejump), ";");
    s = strcat(s, "d=", ftos(cortex_q_dodge), ";");
    s = strcat(s, "rj=", ftos(cortex_q_rocketjump), ";");

    cvar_set(name, s);
};

void() Cortex_Bot_DecayAdaptation =
{
    if (time < cortex_bot_last_decay + 1)
        return;

    cortex_bot_last_decay = time;
    cortex_bot_recent_kills = cortex_bot_recent_kills * 0.90;
    cortex_bot_recent_deaths = cortex_bot_recent_deaths * 0.90;
};

float(float action) Cortex_Bot_QGet =
{
    if (action == CX_ACT_WALK) return cortex_q_walk;
    if (action == CX_ACT_STRAFEJUMP) return cortex_q_strafejump;
    if (action == CX_ACT_DODGE) return cortex_q_dodge;
    if (action == CX_ACT_ROCKETJUMP) return cortex_q_rocketjump;
    return 0.5;
};

void(float action, float reward) Cortex_Bot_QUpdate =
{
    local float alpha;

    alpha = 0.10;

    if (action == CX_ACT_WALK)
        cortex_q_walk = Cortex_Clamp(cortex_q_walk + alpha * (reward - cortex_q_walk), -2, 2);
    else if (action == CX_ACT_STRAFEJUMP)
        cortex_q_strafejump = Cortex_Clamp(cortex_q_strafejump + alpha * (reward - cortex_q_strafejump), -2, 2);
    else if (action == CX_ACT_DODGE)
        cortex_q_dodge = Cortex_Clamp(cortex_q_dodge + alpha * (reward - cortex_q_dodge), -2, 2);
    else if (action == CX_ACT_ROCKETJUMP)
        cortex_q_rocketjump = Cortex_Clamp(cortex_q_rocketjump + alpha * (reward - cortex_q_rocketjump), -2, 2);
};

entity(float radius) Cortex_Bot_FindNearestVisibleEnemy =
{
    return Cortex_Perception_FindNearestVisibleEnemy(self, radius);
};

float(float radius) Cortex_Bot_CountVisibleEnemies =
{
    return Cortex_Perception_CountVisibleEnemies(self, radius);
};

// Mega/event inference now lives in `cortex_perception.qc`.

entity(float radius) Cortex_Bot_FindBestPickup =
{
    local entity head;
    local entity best;
    local entity deny_enemy;
    local float best_score;
    local float score;
    local float dist;
    local float need_health;
    local float need_ammo;
    local float want_rl;
    local float deny_r;
    local float ttr;
    local float mega_window;

    best_score = 0;

    need_health = (self.health < 80) ? 1 : 0;
    need_ammo = (self.ammo_rockets < 5) ? 1 : 0;
    want_rl = ((self.items & IT_ROCKET_LAUNCHER) ? 0 : 1);
    deny_r = cvar("cortex_bot_deny_radius");
    if (deny_r <= 0) deny_r = 300;
    mega_window = cvar("cortex_bot_mega_rush_window");
    if (mega_window <= 0) mega_window = 5;

    // Global priorities (map-wide): megahealth + rocket launcher denial.
    // Megahealth is `item_health` with mdl `maps/b_bh100.bsp`.
    head = find(world, classname, "item_health");
    while (head)
    {
        if (head.mdl == "maps/b_bh100.bsp")
        {
            score = 0;
            dist = vlen(head.origin - self.origin);
            ttr = Cortex_Bot_ItemTimeToRespawn(head);

            if (head.solid != SOLID_NOT)
            {
                if (self.health < 150) score = 140;
                else if (self.health < 200) score = 110;
                else score = 40;
            }
            else if (ttr > 0 && ttr < mega_window)
            {
                // Camp/rush mega as it respawns.
                score = 130 - ttr * 8;
            }

            // If we "heard" an enemy mega pickup recently, prioritize denying the next mega cycle.
            if (time < cortex_percept_enemy_mega_heard_until)
                score = score + 60;

            if (score > 0)
            {
                score = score - dist * 0.03;
                if (score > best_score)
                {
                    best = head;
                    best_score = score;
                }
            }
        }

        head = find(head, classname, "item_health");
    }

    // Rocket Launcher (weapon_rocketlauncher) acquisition/deny.
    head = find(world, classname, "weapon_rocketlauncher");
    while (head)
    {
        score = 0;
        dist = vlen(head.origin - self.origin);
        ttr = Cortex_Bot_ItemTimeToRespawn(head);

        if (head.solid != SOLID_NOT)
        {
            score = want_rl ? 160 : 60;
        }
        else if (ttr > 0 && ttr < 5 && cvar("cortex_bot_item_deny_enable"))
        {
            // Camp the respawn to deny.
            score = want_rl ? 140 : 95;
        }

        // Deny if an enemy is near the RL spot.
        if (cvar("cortex_bot_item_deny_enable"))
        {
            deny_enemy = Cortex_Bot_FindNearestVisibleEnemy(deny_r);
            if (deny_enemy && vlen(deny_enemy.origin - head.origin) < deny_r)
                score = score + 80;
        }

        if (score > 0)
        {
            score = score - dist * 0.03;
            if (score > best_score)
            {
                best = head;
                best_score = score;
            }
        }

        head = find(head, classname, "weapon_rocketlauncher");
    }

    head = findradius(self.origin, radius);
    while (head)
    {
        score = 0;
        if (need_health && head.classname == "item_health") score = 80;
        else if (need_health && (head.classname == "item_armorInv" || head.classname == "item_armor2")) score = 60;
        else if (need_health && head.classname == "item_armor1") score = 40;
        else if (need_ammo && head.classname == "item_rockets") score = 80;
        else if (want_rl && head.classname == "weapon_rocketlauncher") score = 140;
        else if (self.currentammo < 1 && head.classname == "item_shells") score = 30;

        if (score > 0)
        {
            dist = vlen(head.origin - self.origin);
            score = score - (dist * 0.05);
            if (score > best_score)
            {
                best = head;
                best_score = score;
            }
        }

        head = head.chain;
    }

    return best;
};

float(entity enemy) Cortex_Bot_Utility_Attack =
{
    local float dist;
    local float aggr;

    if (!enemy) return 0;
    dist = vlen(enemy.origin - self.origin);
    if (dist > 700) return 0;

    aggr = Cortex_Bot_EffectiveAggression();
    return Cortex_Clamp((90 - dist * 0.08) * aggr, 0, 100);
};

float(entity enemy) Cortex_Bot_Utility_Chase =
{
    local float dist;
    local float aggr;

    if (!enemy) return 0;
    dist = vlen(enemy.origin - self.origin);
    if (dist < 250) return 0;

    aggr = Cortex_Bot_EffectiveAggression();
    return Cortex_Clamp((70 - dist * 0.03) * aggr, 0, 100);
};

float() Cortex_Bot_Utility_Flee =
{
    if (self.health < 30) return 95;
    return 0;
};

float(entity pickup) Cortex_Bot_Utility_Collect =
{
    local float u;
    local float ttr;
    local float mega_window;

    u = 10;
    if (self.health < 50) u = 90;
    else if (self.health < 80) u = 60;
    else if (self.ammo_rockets < 5) u = 40;

    if (pickup)
    {
        mega_window = cvar("cortex_bot_mega_rush_window");
        if (mega_window <= 0) mega_window = 5;

        // Mega/RL denial can be strategically important even when we're "fine".
        if (pickup.classname == "weapon_rocketlauncher" && !(self.items & IT_ROCKET_LAUNCHER))
            u = 85;

        if (pickup.mdl == "maps/b_bh100.bsp")
        {
            ttr = Cortex_Bot_ItemTimeToRespawn(pickup);
            if (pickup.solid != SOLID_NOT || (ttr > 0 && ttr < mega_window) || time < cortex_percept_enemy_mega_heard_until)
                u = 80;
        }
    }

    if (!pickup) u = u * 0.25;
    return u;
};

float() Cortex_Bot_Utility_Explore =
{
    return 20;
};

float(entity enemy, entity pickup) Cortex_Bot_SelectState =
{
    local float u_explore, u_collect, u_chase, u_attack, u_flee;
    local float best_u;
    local float best_state;

    u_explore = Cortex_Bot_Utility_Explore();
    u_collect = Cortex_Bot_Utility_Collect(pickup);
    u_chase = Cortex_Bot_Utility_Chase(enemy);
    u_attack = Cortex_Bot_Utility_Attack(enemy);
    u_flee = Cortex_Bot_Utility_Flee();

    best_u = u_explore;
    best_state = BOT_STATE_EXPLORE;

    if (u_collect > best_u) { best_u = u_collect; best_state = BOT_STATE_COLLECT; }
    if (u_chase > best_u)   { best_u = u_chase;   best_state = BOT_STATE_CHASE; }
    if (u_attack > best_u)  { best_u = u_attack;  best_state = BOT_STATE_ATTACK; }
    if (u_flee > best_u)    { best_u = u_flee;    best_state = BOT_STATE_FLEE; }

    return best_state;
};

void(vector dir, float speed) Cortex_Bot_MoveDir =
{
    local vector start;
    local vector endpos;
    local vector angles;
    local float vz;
    local float fat;
    local float forward;
    local float side;
    local float avoid_dist;

    if (vlen(dir) < 0.01)
        return;

    dir_z = 0;
    dir = normalize(dir);

    // Simple obstacle check: if a short forward trace hits, try a sidestep.
    if (!cvar("cortex_bot_nav_enable") && cvar("cortex_bot_wall_avoid"))
    {
        start = self.origin + '0 0 16';
        avoid_dist = cvar("cortex_bot_wall_avoid_dist");
        if (avoid_dist <= 0) avoid_dist = 64;
        endpos = start + dir * avoid_dist;
        traceline(start, endpos, TRUE, self);
        if (trace_fraction < 1)
        {
            angles = vectoangles(dir);
            makevectors(angles);
            if (time > cortex_bot_wall_until)
            {
                if (random() < 0.5)
                    cortex_bot_wall_sign = -cortex_bot_wall_sign;
                cortex_bot_wall_until = time + 0.35 + random() * 0.35;
            }
            if (cortex_bot_wall_sign > 0)
                dir = normalize(dir * 0.35 + v_right);
            else
                dir = normalize(dir * 0.35 - v_right);
        }
    }

    fat = 1;
    if (cvar("cortex_bot_fatigue_enable"))
    {
        fat = 1 - Cortex_Clamp(cortex_bot_fatigue, 0, 0.30);
    }

    if (self.flags & FL_CLIENT)
    {
        makevectors(self.v_angle);
        forward = dir * v_forward;
        side = dir * v_right;
        self.movement_x = forward * (speed * fat);
        self.movement_y = side * (speed * fat);
        self.movement_z = 0;
    }
    else
    {
        // Preserve vertical velocity (falling/jumping).
        vz = self.velocity_z;
        self.velocity = dir * (speed * fat);
        self.velocity_z = vz;
    }

    if (cvar("cortex_debug"))
    {
        if (self.flags & FL_CLIENT)
            CortexLog(LOG_info, "MOVE", strcat("Set movement to ", vtos(self.movement), " (speed=", ftos(speed), ")"));
        else
            CortexLog(LOG_info, "MOVE", strcat("Set velocity to ", vtos(self.velocity), " (speed=", ftos(speed), ")"));
    }
};

void(vector target, float speed) Cortex_Bot_MoveTo =
{
    Cortex_Bot_MoveDir(target - self.origin, speed);
};

float(float weapon) Cortex_Bot_WeaponHasAmmo =
{
    if (weapon == IT_AXE) return 1;
    if (weapon == IT_SHOTGUN) return (self.ammo_shells >= 1);
    if (weapon == IT_SUPER_SHOTGUN) return (self.ammo_shells >= 2);
    if (weapon == IT_NAILGUN) return (self.ammo_nails >= 1);
    if (weapon == IT_SUPER_NAILGUN) return (self.ammo_nails >= 2);
    if (weapon == IT_GRENADE_LAUNCHER) return (self.ammo_rockets >= 1);
    if (weapon == IT_ROCKET_LAUNCHER) return (self.ammo_rockets >= 1);
    if (weapon == IT_LIGHTNING) return (self.ammo_cells >= 1);
    return 0;
};

float(float weapon) Cortex_Bot_CanUseWeapon =
{
    if (!(self.items & weapon)) return 0;
    return Cortex_Bot_WeaponHasAmmo(weapon);
};

float(entity enemy) Cortex_Bot_SelectWeapon =
{
    local float dist;

    if (!enemy) return 0;
    dist = vlen(enemy.origin - self.origin);

    if (dist < 180)
    {
        if (Cortex_Bot_CanUseWeapon(IT_LIGHTNING)) return IT_LIGHTNING;
        if (Cortex_Bot_CanUseWeapon(IT_SUPER_SHOTGUN)) return IT_SUPER_SHOTGUN;
        if (Cortex_Bot_CanUseWeapon(IT_SHOTGUN)) return IT_SHOTGUN;
        if (Cortex_Bot_CanUseWeapon(IT_SUPER_NAILGUN)) return IT_SUPER_NAILGUN;
        if (Cortex_Bot_CanUseWeapon(IT_NAILGUN)) return IT_NAILGUN;
        if (Cortex_Bot_CanUseWeapon(IT_ROCKET_LAUNCHER)) return IT_ROCKET_LAUNCHER;
        if (Cortex_Bot_CanUseWeapon(IT_GRENADE_LAUNCHER)) return IT_GRENADE_LAUNCHER;
        return IT_AXE;
    }

    if (dist < 600)
    {
        if (Cortex_Bot_CanUseWeapon(IT_ROCKET_LAUNCHER)) return IT_ROCKET_LAUNCHER;
        if (Cortex_Bot_CanUseWeapon(IT_GRENADE_LAUNCHER)) return IT_GRENADE_LAUNCHER;
        if (Cortex_Bot_CanUseWeapon(IT_SUPER_NAILGUN)) return IT_SUPER_NAILGUN;
        if (Cortex_Bot_CanUseWeapon(IT_NAILGUN)) return IT_NAILGUN;
        if (Cortex_Bot_CanUseWeapon(IT_SUPER_SHOTGUN)) return IT_SUPER_SHOTGUN;
        if (Cortex_Bot_CanUseWeapon(IT_SHOTGUN)) return IT_SHOTGUN;
        if (Cortex_Bot_CanUseWeapon(IT_LIGHTNING)) return IT_LIGHTNING;
        return IT_AXE;
    }

    if (Cortex_Bot_CanUseWeapon(IT_ROCKET_LAUNCHER)) return IT_ROCKET_LAUNCHER;
    if (Cortex_Bot_CanUseWeapon(IT_SUPER_NAILGUN)) return IT_SUPER_NAILGUN;
    if (Cortex_Bot_CanUseWeapon(IT_NAILGUN)) return IT_NAILGUN;
    if (Cortex_Bot_CanUseWeapon(IT_GRENADE_LAUNCHER)) return IT_GRENADE_LAUNCHER;
    if (Cortex_Bot_CanUseWeapon(IT_SHOTGUN)) return IT_SHOTGUN;
    return IT_AXE;
};

float(float weapon) Cortex_Bot_WeaponImpulse =
{
    if (weapon == IT_AXE) return 1;
    if (weapon == IT_SHOTGUN) return 2;
    if (weapon == IT_SUPER_SHOTGUN) return 3;
    if (weapon == IT_NAILGUN) return 4;
    if (weapon == IT_SUPER_NAILGUN) return 5;
    if (weapon == IT_GRENADE_LAUNCHER) return 6;
    if (weapon == IT_ROCKET_LAUNCHER) return 7;
    if (weapon == IT_LIGHTNING) return 8;
    return 0;
};

void(entity enemy) Cortex_Bot_MaybeSwitchWeapon =
{
    local float desired;
    local float impulse;
    local float cooldown;

    if (!enemy) return;
    if (!(self.flags & FL_CLIENT)) return;
    if (time < cortex_bot_next_weapon_switch) return;

    desired = Cortex_Bot_SelectWeapon(enemy);
    if (!desired) desired = W_BestWeapon();
    if (desired == self.weapon) return;

    impulse = Cortex_Bot_WeaponImpulse(desired);
    if (!impulse) return;

    cooldown = cvar("cortex_bot_weapon_switch_cooldown");
    if (cooldown < 0) cooldown = 0;
    cortex_bot_next_weapon_switch = time + cooldown;
    self.impulse = impulse;
};

void(float speed) Cortex_Bot_FallbackRoam =
{
    local vector dir;

    if (time > cortex_bot_idle_until)
    {
        dir_x = crandom();
        dir_y = crandom();
        dir_z = 0;
        if (vlen(dir) < 0.1)
            dir = '1 0 0';
        cortex_bot_idle_dir = normalize(dir);
        cortex_bot_idle_until = time + 1.5 + random() * 1.5;
    }

    Cortex_Bot_MoveDir(cortex_bot_idle_dir, speed);
    cortex_bot_last_action = CX_ACT_WALK;

    if (cvar("cortex_debug"))
        CortexLog(LOG_info, "MOVE", "Fallback roam applied");
};

vector(vector dir) Cortex_Bot_Perp2D =
{
    local vector perp;
    perp_x = -dir_y;
    perp_y = dir_x;
    perp_z = 0;
    if (vlen(perp) < 0.01)
        return '0 0 0';
    return normalize(perp);
};

float() Cortex_Bot_RocketJumpSimScore =
{
    local vector start;
    local vector endpos;

    if (!(self.flags & FL_ONGROUND))
        return -20;

    if (self.health < 60)
        return -30;

    if (self.ammo_rockets < 2)
        return -30;

    // Simple safety: if there's low ceiling, avoid.
    start = self.origin + '0 0 24';
    endpos = start + '0 0 96';
    traceline(start, endpos, TRUE, self);
    if (trace_fraction < 1)
        return -25;

    return 15;
};

void() Cortex_Bot_DoRocketJump =
{
    if (!cvar("cortex_bot_allow_rocketjump"))
        return;

    if (time < cortex_bot_next_rocketjump)
        return;

    if (Cortex_Bot_RocketJumpSimScore() < 0)
        return;

    // Aim at feet and fire; jump same tick.
    self.v_angle_x = 90;
    self.angles_y = self.v_angle_y;
    self.button0 = 1;
    self.button2 = 1;

    if (!(self.flags & FL_CLIENT) && (self.flags & FL_ONGROUND))
        self.velocity_z = 270;

    cortex_bot_next_rocketjump = time + 1.25;
    cortex_bot_last_action = CX_ACT_ROCKETJUMP;
};

void(vector move_dir) Cortex_Bot_DoStrafeJump =
{
    local vector dir;
    local vector perp;
    local vector aim;

    if (!cvar("cortex_bot_allow_strafejump"))
        return;

    if (!(self.flags & FL_ONGROUND))
        return;

    dir = move_dir;
    dir_z = 0;
    if (vlen(dir) < 0.01)
        return;
    dir = normalize(dir);

    perp = Cortex_Bot_Perp2D(dir);
    if (mod(floor(time * 6), 2)) // alternate direction for acceleration
        perp = perp * -1;

    self.button2 = 1;
    dir = normalize(dir + perp * 0.35);
    aim = normalize(dir + perp * 0.15);
    self.v_angle = vectoangles(aim);
    self.angles_y = self.v_angle_y;
    if (self.flags & FL_CLIENT)
    {
        makevectors(self.v_angle);
        self.movement_x = (dir * v_forward) * 480;
        self.movement_y = (dir * v_right) * 480;
        self.movement_z = 0;
    }
    else
    {
        self.velocity = dir * 480;
    }

    cortex_bot_last_action = CX_ACT_STRAFEJUMP;
};

void(vector to_enemy) Cortex_Bot_MaybeStartDodge =
{
    local float chance;

    if (!cvar("cortex_bot_allow_dodge"))
        return;

    if (time < cortex_bot_dodge_until)
        return;

    chance = 0.18 * Cortex_Bot_EffectiveAggression();
    if (random() > chance)
        return;

    cortex_bot_dodge_until = time + 0.25 + random() * 0.20;
    cortex_bot_dodge_sign = (random() > 0.5) ? 1 : -1;
    cortex_bot_last_action = CX_ACT_DODGE;
};

float() Cortex_Bot_ApplyDodgeMaybe =
{
    local vector to_enemy;
    local vector perp;
    local vector vel;
    local float forward;
    local float side;

    if (time >= cortex_bot_dodge_until)
        return 0;

    if (!self.enemy)
        return 0;

    to_enemy = self.enemy.origin - self.origin;
    to_enemy_z = 0;
    if (vlen(to_enemy) < 0.01)
        return 0;

    perp = Cortex_Bot_Perp2D(normalize(to_enemy)) * cortex_bot_dodge_sign;
    if (self.flags & FL_CLIENT)
    {
        makevectors(self.v_angle);
        forward = perp * v_forward;
        side = perp * v_right;
        self.movement_x = self.movement_x + forward * 220;
        self.movement_y = self.movement_y + side * 220;
    }
    else
    {
        vel = self.velocity;
        vel = vel + perp * 220;
        self.velocity = vel;
    }

    return 1;
};

void(entity enemy) Cortex_Bot_AimAt =
{
    local vector to;
    local vector lead;
    local float dist;
    local float lead_t;
    local float bot_skill;
    local float jitter_deg;

    if (!enemy) return;

    to = enemy.origin + '0 0 16' - (self.origin + '0 0 16');
    dist = vlen(to);

    // Small linear lead; good enough for rockets at typical DM ranges.
    lead_t = Cortex_Clamp(dist * 0.001, 0.0, 0.35);
    lead = enemy.origin + enemy.velocity * lead_t;

    self.v_angle = vectoangles(lead - self.origin);
    self.angles_y = self.v_angle_y;

    // Humanization: slight aim jitter (scaled by range).
    bot_skill = cvar("cortex_skill");
    if (bot_skill < 0) bot_skill = 0;
    if (bot_skill > 1) bot_skill = 1;
    jitter_deg = cvar("cortex_bot_aim_jitter_deg") * (1 - bot_skill * 0.85);

    if (jitter_deg > 0)
    {
        self.v_angle_x = self.v_angle_x + crandom() * (jitter_deg * Cortex_Clamp(dist / 800, 0.3, 1));
        self.v_angle_y = self.v_angle_y + crandom() * (jitter_deg * Cortex_Clamp(dist / 800, 0.3, 1));
    }

    if (self.v_angle_x > 80) self.v_angle_x = 80;
    if (self.v_angle_x < -70) self.v_angle_x = -70;
};

void() Cortex_Bot_ForceJumpIfStuck =
{
    local float speed;

    if (self.flags & FL_CLIENT)
        return;

    speed = vlen(self.origin - cortex_bot_last_origin);
    if (speed > 8)
    {
        cortex_bot_last_origin = self.origin;
        cortex_bot_stuck_since = time;
        return;
    }

    if (time < cortex_bot_stuck_since + 0.75)
        return;

    // Try to jump out of small ledges.
    self.button2 = 1;
    if (!(self.flags & FL_CLIENT) && (self.flags & FL_ONGROUND))
        self.velocity_z = 270;

    cortex_bot_stuck_since = time;
};

void(entity enemy) Cortex_Bot_Attack =
{
    local float dist;
    local float bot_skill;
    local float fire_delay;

    if (!enemy) return;
    if (time < cortex_bot_respawn_grace_until) return;
    dist = vlen(enemy.origin - self.origin);
    if (dist > 900) return;

    if (time < cortex_bot_next_attack)
        return;

    bot_skill = cvar("cortex_skill");
    if (bot_skill < 0) bot_skill = 0;
    if (bot_skill > 1) bot_skill = 1;
    fire_delay = 0.28 - bot_skill * 0.13; // ~0.28s (newbie) .. ~0.15s (pro)
    if (fire_delay < 0.12) fire_delay = 0.12;

    // If we're a real client, let the normal weapon code handle firing.
    if (self.flags & FL_CLIENT)
    {
        self.button0 = 1;
        cortex_bot_next_attack = time + fire_delay;
        return;
    }

    // Fallback: fire rockets directly (best-effort).
    if (self.ammo_rockets > 0)
    {
        W_FireRocket();
        cortex_bot_next_attack = time + 0.8;
    }
};

void() Cortex_Bot_RunAI =
{
    local entity bot_enemy;
    local entity pickup;
    local float state;
    local float interval;
    local float speed;
    local vector move_goal;
    local vector move_dir;
    local float use_craft;
    local float react_min;
    local float react_max;
    local float allow_rj;
    local float act;
    local vector ambush_goal;
    local float mem_state;
    local float deny_r;
    local float bot_skill;
    local float style;
    local float move_mag;

    interval = cvar("cortex_bot_think_interval");
    if (interval <= 0)
        interval = 0.05;

    Cortex_Bot_DecayAdaptation();
    Cortex_PathInitMaybe();
    Cortex_Opp_Frame(self);

    if (self.flags & FL_CLIENT)
        self.v_angle = self.angles;

    // Clear buttons each tick; actions set them explicitly.
    self.button0 = 0;
    self.button2 = 0;
    if (self.flags & FL_CLIENT)
        self.movement = '0 0 0';

    bot_skill = cvar("cortex_skill");
    if (bot_skill < 0) bot_skill = 0;
    if (bot_skill > 1) bot_skill = 1;
    style = cvar("cortex_style");
    if (style < 0) style = 0;
    if (style > 3) style = 3;

    Cortex_Perception_Update(self);
    bot_enemy = cortex_percept_enemy;
    cortex_bot_visible_enemies = cortex_percept_visible_enemies;
    cortex_bot_tactic_mode = cortex_percept_tactic_mode;

    if (bot_enemy && bot_enemy != world)
        Cortex_Bot_MaybeSwitchWeapon(bot_enemy);

    CortexMem_LoadKey(CortexMem_KeyFor(mapname, bot_enemy));
    mem_state = CortexMem_State(self, bot_enemy, cortex_bot_visible_enemies);

    deny_r = cvar("cortex_bot_deny_radius");
    if (deny_r <= 0) deny_r = 300;

    pickup = Cortex_Bot_FindBestPickup(BOT_PICKUP_SCAN_RADIUS);

    state = Cortex_Bot_SelectState(bot_enemy, pickup);
    cortex_bot_state = state;

    if (cvar("cortex_debug"))
    {
        local string state_name;
        if (state == BOT_STATE_EXPLORE) state_name = "EXPLORE";
        else if (state == BOT_STATE_COLLECT) state_name = "COLLECT";
        else if (state == BOT_STATE_CHASE) state_name = "CHASE";
        else if (state == BOT_STATE_ATTACK) state_name = "ATTACK";
        else if (state == BOT_STATE_FLEE) state_name = "FLEE";
        else state_name = "UNKNOWN";
        CortexLog(LOG_info, "STATE", strcat("Bot state: ", state_name, " | Enemy: ", ftos(bot_enemy != world), " | Pickup: ", ftos(pickup != world)));
    }

    speed = 320;
    if (state == BOT_STATE_FLEE) speed = 420;
    if (state == BOT_STATE_CHASE) speed = 380;
    if (state == BOT_STATE_ATTACK) speed = 360;

    use_craft = 1;

    // Update fatigue (slow accumulation during sustained high speed).
    if (cvar("cortex_bot_fatigue_enable"))
    {
        if (vlen(self.velocity) > 360)
            cortex_bot_fatigue = Cortex_Clamp(cortex_bot_fatigue + 0.008, 0, 0.30);
        else
            cortex_bot_fatigue = Cortex_Clamp(cortex_bot_fatigue * 0.96, 0, 0.30);
    }

    if (state == BOT_STATE_FLEE)
    {
        self.enemy = bot_enemy;
        if (pickup)
        {
            move_goal = Cortex_PathNextWaypoint(self, pickup.origin);
            Cortex_Bot_MoveTo(move_goal, speed);
        }
        else if (bot_enemy)
            Cortex_Bot_MoveDir(self.origin - bot_enemy.origin, speed);
        else
            state = BOT_STATE_EXPLORE;
    }
    else if (state == BOT_STATE_COLLECT)
    {
        if (pickup)
        {
            move_goal = Cortex_PathNextWaypoint(self, pickup.origin);
            Cortex_Bot_MoveTo(move_goal, speed);

            // Denial pressure: if enemy contests a key item (RL/mega), shoot while moving in.
            if (cvar("cortex_bot_item_deny_enable") && bot_enemy)
            {
                if ((pickup.classname == "weapon_rocketlauncher" || pickup.mdl == "maps/b_bh100.bsp") &&
                    vlen(bot_enemy.origin - pickup.origin) < deny_r)
                {
                    Cortex_Bot_AimAt(bot_enemy);
                    Cortex_Bot_Attack(bot_enemy);
                }
            }
        }
        else
            state = BOT_STATE_EXPLORE;
    }

    if (state == BOT_STATE_CHASE)
    {
        self.enemy = bot_enemy;
        if (bot_enemy)
        {
            Cortex_Combat_MaybeSwitchWeapon(self, bot_enemy);
            Cortex_Bot_AimAt(bot_enemy);
            move_goal = Cortex_PathNextWaypoint(self, bot_enemy.origin);
            move_dir = move_goal - self.origin;

            // Reaction delay: don't switch tactics too fast.
            react_min = cvar("cortex_bot_react_min");
            react_max = cvar("cortex_bot_react_max");
            if (react_min < 0) react_min = 0;
            if (react_max < react_min) react_max = react_min;

            // Skill scaling: faster reactions at higher skill.
            react_min = react_min * (1 - bot_skill * 0.65);
            react_max = react_max * (1 - bot_skill * 0.65);

            // Skill scaling: faster reactions at higher skill.
            react_min = react_min * (1 - bot_skill * 0.65);
            react_max = react_max * (1 - bot_skill * 0.65);

            if (time >= cortex_bot_next_decision)
            {
                allow_rj = cvar("cortex_bot_allow_rocketjump") && (Cortex_Bot_RocketJumpSimScore() >= 0) && (cortex_bot_tactic_mode != 3) && (style >= 2);
                act = Cortex_MCTS_SelectActionMem(self, bot_enemy, move_goal, allow_rj, mem_state);
                cortex_bot_selected_action = act;
                cortex_bot_next_decision = time + react_min + random() * (react_max - react_min);

                cortex_mem_last_state = mem_state;
                cortex_mem_last_mcts_action = act;
            }

            act = cortex_bot_selected_action;
            if (act == 0) act = 1;

            if (use_craft && act == CX_MCTS_ACT_STRAFEJUMP)
                Cortex_Bot_DoStrafeJump(move_dir);
            else
            {
                Cortex_Bot_MoveTo(move_goal, speed);
                cortex_bot_last_action = CX_ACT_WALK;
            }
        }
        else
        {
            state = BOT_STATE_EXPLORE;
        }
    }

    if (state == BOT_STATE_ATTACK)
    {
        self.enemy = bot_enemy;
        if (bot_enemy)
        {
            Cortex_Combat_MaybeSwitchWeapon(self, bot_enemy);
            Cortex_Bot_AimAt(bot_enemy);

            move_goal = Cortex_PathNextWaypoint(self, bot_enemy.origin);
            move_dir = move_goal - self.origin;

            // Multi-enemy tactics: kite a bit instead of hard-committing to close range.
            if (cortex_bot_tactic_mode == 3 && vlen(bot_enemy.origin - self.origin) < 420)
            {
                move_goal = self.origin + normalize(self.origin - bot_enemy.origin) * 320;
                move_dir = move_goal - self.origin;
            }

            react_min = cvar("cortex_bot_react_min");
            react_max = cvar("cortex_bot_react_max");
            if (react_min < 0) react_min = 0;
            if (react_max < react_min) react_max = react_min;

            if (time >= cortex_bot_next_decision)
            {
                allow_rj = cvar("cortex_bot_allow_rocketjump") && (Cortex_Bot_RocketJumpSimScore() >= 0) && ((move_goal_z - self.origin_z) > 64) && (cortex_bot_tactic_mode != 3) && (style >= 2);
                act = Cortex_MCTS_SelectActionMem(self, bot_enemy, move_goal, allow_rj, mem_state);
                cortex_bot_selected_action = act;
                cortex_bot_next_decision = time + react_min + random() * (react_max - react_min);

                if (act == CX_MCTS_ACT_FEINT)
                    cortex_bot_feint_until = time + 0.30 + random() * 0.15;

                cortex_mem_last_state = mem_state;
                cortex_mem_last_mcts_action = act;
            }

            act = cortex_bot_selected_action;
            if (act == 0) act = 1;

            if (use_craft && act == CX_MCTS_ACT_DODGE)
            {
                Cortex_Bot_MaybeStartDodge(bot_enemy.origin - self.origin);
                Cortex_Bot_MoveTo(move_goal, speed);
                Cortex_Bot_ApplyDodgeMaybe();
                cortex_bot_last_action = CX_ACT_DODGE;
            }
            else if (use_craft && act == CX_MCTS_ACT_STRAFEJUMP)
            {
                Cortex_Bot_DoStrafeJump(move_dir);
            }
            else if (use_craft && act == CX_MCTS_ACT_ROCKETJUMP)
            {
                Cortex_Bot_DoRocketJump();
            }
            else if (use_craft && act == CX_MCTS_ACT_AMBUSH)
            {
                ambush_goal = Cortex_PathAmbushSpot(self, bot_enemy);
                Cortex_Bot_MoveTo(ambush_goal, speed);
                cortex_bot_last_action = CX_ACT_WALK;
            }
            else if (use_craft && act == CX_MCTS_ACT_FEINT && time < cortex_bot_feint_until)
            {
                Cortex_Bot_MoveDir(self.origin - bot_enemy.origin, speed);
                cortex_bot_last_action = CX_ACT_WALK;
            }
            else
            {
                Cortex_Bot_MoveTo(move_goal, speed);
                cortex_bot_last_action = CX_ACT_WALK;
            }

            Cortex_Bot_Attack(bot_enemy);

            // Optional taunt when committing to a fight (rate-limited).
            if (cvar("cortex_bot_taunt") && time > cortex_bot_next_taunt && random() < 0.03)
            {
                cortex_bot_next_taunt = time + 8 + random() * 8;
                bprint("CortexBot: come on then.\n");
            }
        }
        else
        {
            state = BOT_STATE_EXPLORE;
        }
    }

    if (state == BOT_STATE_EXPLORE)
    {
        if (time > cortex_bot_wander_until || vlen(cortex_bot_wander_goal - self.origin) < 64)
        {
            cortex_bot_wander_goal_x = self.origin_x + crandom() * 600;
            cortex_bot_wander_goal_y = self.origin_y + crandom() * 600;
            cortex_bot_wander_goal_z = self.origin_z;
            cortex_bot_wander_until = time + 2 + random() * 2;
        }
        move_goal = Cortex_PathNextWaypoint(self, cortex_bot_wander_goal);
        Cortex_Bot_MoveTo(move_goal, speed);
        cortex_bot_last_action = CX_ACT_WALK;
    }

    if (!bot_enemy && !pickup)
    {
        if (self.flags & FL_CLIENT)
            move_mag = vlen(self.movement);
        else
            move_mag = vlen(self.velocity);

        if (move_mag > 5)
            cortex_bot_idle_since = time;
        else if (time > cortex_bot_idle_since + 0.5)
        {
            Cortex_Bot_FallbackRoam(speed * 0.8);
            cortex_bot_idle_since = time;
        }
    }

    Cortex_Bot_ForceJumpIfStuck();

    // Team coordination: small separation steering (only meaningful in teamplay modes).
    if (!(self.flags & FL_CLIENT))
        self.velocity = self.velocity + Cortex_Team_SeparationSteer(self);

    if (cvar("cortex_bot_debug") && random() < 0.02)
    {
        bprint("CORTEX BOT: state ");
        bprint(ftos(cortex_bot_state));
        if (bot_enemy) { bprint(" enemy "); bprint(bot_enemy.netname); }
        bprint("\n");
    }

    self.nextthink = time + interval;
};

void() Cortex_BotSpawn =
{
    local vector origin;

    bprint("DEBUG: Cortex_BotSpawn called\n");
    cortex_bot_is_botclient = 0;
    cortex_q_walk = 0.5;
    cortex_q_strafejump = 0.5;
    cortex_q_dodge = 0.5;
    cortex_q_rocketjump = 0.5;
    cortex_bot_last_action = CX_ACT_NONE;
    cortex_bot_next_decision = time;
    cortex_bot_selected_action = CX_MCTS_ACT_WALK;
    cortex_bot_feint_until = 0;
    cortex_bot_next_taunt = time + 5;
    cortex_bot_next_weapon_switch = 0;
    cortex_bot_fatigue = 0;
    cortex_bot_visible_enemies = 0;
    cortex_bot_tactic_mode = 2;
    cortex_bot_respawn_at = 0;
    cortex_bot_respawn_grace_until = 0;
    cortex_bot_idle_since = time;
    cortex_bot_idle_until = 0;
    cortex_bot_idle_dir = '1 0 0';
    cortex_bot_wall_sign = 1;
    cortex_bot_wall_until = 0;

    cortex_mem_last_state = 0;
    cortex_mem_last_mcts_action = CX_MCTS_ACT_WALK;

    // Reset perception module globals.
    cortex_percept_enemy = world;
    cortex_percept_visible_enemies = 0;
    cortex_percept_tactic_mode = 2;
    cortex_percept_enemy_mega_heard_until = 0;
    cortex_percept_last_visible_enemy = world;
    cortex_percept_last_visible_time = 0;
    cortex_percept_forced_enemy = world;
    cortex_percept_forced_until = 0;
    cortex_percept_last_enemy = world;
    cortex_percept_last_enemy_health = 0;
    cortex_percept_last_enemy_health_time = -9999;

    CortexMem_Init();
    CortexMem_LoadKey(CortexMem_KeyFor(mapname, world));

    Cortex_Bot_LoadPersistentQ();

    if (Cortex_Bot_HasBotClientSupport())
    {
        Cortex_Bot_SpawnClient();
        if (cortex_bot && cortex_bot != world)
        {
            // Set up think for botclient mode
            cortex_bot.think = Cortex_BotThink;
            cortex_bot.nextthink = time + 0.05;
            bprint(strcat("DEBUG: Bot think scheduled for time ", ftos(cortex_bot.nextthink), " (botclient mode)\n"));
            return;
        }
    }

    origin = Cortex_Bot_FindSpawnOrigin();

    // Fallback: non-client physics entity.
    cortex_bot = spawn();
    cortex_bot.classname = "cortex_bot";

    cortex_bot.movetype = MOVETYPE_STEP;
    cortex_bot.solid = SOLID_SLIDEBOX;
    setsize(cortex_bot, '-16 -16 -24', '16 16 32');
    setorigin(cortex_bot, origin + '0 0 1');

    setmodel(cortex_bot, "progs/player.mdl");
    cortex_bot.frame = 0;

    cortex_bot.health = 100;
    cortex_bot.armorvalue = 0;
    cortex_bot.items = cortex_bot.items | IT_ROCKET_LAUNCHER;
    cortex_bot.weapon = IT_ROCKET_LAUNCHER;
    cortex_bot.ammo_rockets = 20;
    cortex_bot.currentammo = cortex_bot.ammo_rockets;

    cortex_bot.think = Cortex_BotThink;
    cortex_bot.nextthink = time + 0.05;
    bprint(strcat("DEBUG: Bot think scheduled for time ", ftos(cortex_bot.nextthink), " (fallback mode)\n"));
};

void() Cortex_BotEnsureSpawned =
{
    local float want_bot;

    want_bot = cvar("cortex_spawn_bot") || cvar("cortex_bot_enable");

    // If disabled, remove existing bot (if any).
    if (!want_bot)
    {
        if (cortex_bot)
        {
            if (cortex_bot_is_botclient && Cortex_Bot_HasDropClientSupport())
            {
                dropclient(cortex_bot);
            }
            else if (cortex_bot.classname == "cortex_bot")
            {
                remove(cortex_bot);
            }
        }
        cortex_bot = world;
        cortex_bot_is_botclient = 0;
        return;
    }

    // Already spawned and still valid.
    if (cortex_bot && ((cortex_bot.classname == "cortex_bot") || (cortex_bot.classname == "player")))
    {
        if (cortex_bot.think != Cortex_BotThink)
        {
            cortex_bot.think = Cortex_BotThink;
            if (cortex_bot.nextthink < time + 0.01)
                cortex_bot.nextthink = time + 0.05;
        }
        return;
    }

    Cortex_BotSpawn();
};

void() Cortex_BotThink =
{
    local float interval;

    interval = cvar("cortex_bot_think_interval");
    if (interval <= 0)
        interval = 0.02;

    // Schedule next think FIRST so we don't forget
    self.nextthink = time + interval;

    if (time <= cortex_bot_last_think_time)
        return;
    cortex_bot_last_think_time = time;

    if (!cvar("cortex_bot_enable"))
        return;

    // Debug: Log think activity
    if (cvar("cortex_debug"))
        CortexLog(LOG_info, "THINK", strcat("Bot think at time ", ftos(time)));

    Cortex_Bot_RunAI();
};

void(entity targ, entity attacker) Cortex_BotOnObituary =
{
    local entity real_attacker;
    local float reward;
    local float delay;

    real_attacker = attacker;
    if (attacker && (attacker.classname == "teledeath" || attacker.classname == "teledeath2"))
        real_attacker = attacker.owner;

    Cortex_Opp_OnKill(cortex_bot, targ, real_attacker);

    if (targ == cortex_bot)
    {
        cortex_bot_recent_deaths = cortex_bot_recent_deaths + 1;
        reward = -1;
        if (cortex_bot_last_action)
            Cortex_Bot_QUpdate(cortex_bot_last_action, reward);

        if (cortex_mem_last_mcts_action)
            CortexMem_QUpdate(cortex_mem_last_state, cortex_mem_last_mcts_action, reward);
        CortexMem_FlushMaybe();

        Cortex_Bot_SavePersistentQ();

        if (cortex_bot_is_botclient && cvar("cortex_bot_enable"))
        {
            delay = cvar("cortex_bot_respawn_delay");
            if (delay < 0) delay = 0;
            cortex_bot_respawn_at = time + delay;
        }
    }

    if (real_attacker == cortex_bot && targ != cortex_bot)
    {
        cortex_bot_recent_kills = cortex_bot_recent_kills + 1;
        reward = 1;
        if (cortex_bot_last_action)
            Cortex_Bot_QUpdate(cortex_bot_last_action, reward);

        if (cortex_mem_last_mcts_action)
            CortexMem_QUpdate(cortex_mem_last_state, cortex_mem_last_mcts_action, reward);
        CortexMem_FlushMaybe();
    }
};

void() Cortex_BotOnRespawn =
{
    local float grace;

    if (!cortex_bot) return;
    if (self != cortex_bot) return;
    if (!cvar("cortex_bot_enable")) return;

    cortex_bot_respawn_at = 0;
    grace = cvar("cortex_bot_respawn_grace");
    if (grace < 0) grace = 0;
    cortex_bot_respawn_grace_until = time + grace;
    Cortex_Bot_HookClient();
};

void() Cortex_Bot_Die =
{
    local float delay;

    // Fast-respawn for botclients so the match keeps flowing.
    if (!cvar("cortex_bot_enable"))
        return;

    if (deathmatch || coop)
    {
        delay = cvar("cortex_bot_respawn_delay");
        if (delay <= 0)
        {
            respawn();
            Cortex_Bot_HookClient();
        }
        else
        {
            self.think = respawn;
            self.nextthink = time + delay;
        }
        return;
    }
};

void() Cortex_ApplyControls =
{
    if (!cortex_bot_is_botclient)
        return;
    if (self != cortex_bot)
        return;
    if (!(self.flags & FL_CLIENT))
        return;
    if (!cvar("cortex_bot_enable"))
        return;

    if (self.nextthink > time)
        return;

    Cortex_BotThink();
};

void() Cortex_Bot_MaybeAutoRespawn =
{
    if (!cortex_bot_is_botclient)
        return;
    if (self != cortex_bot)
        return;
    if (!cvar("cortex_bot_enable"))
        return;
    if (self.deadflag < DEAD_DEAD)
        return;
    if (cortex_bot_respawn_at <= 0)
        return;
    if (time < cortex_bot_respawn_at)
        return;

    cortex_bot_respawn_at = 0;
    respawn();
};

void() SV_PlayerPhysics =
{
    if (cortex_bot_is_botclient && self == cortex_bot && cvar("cortex_bot_enable"))
    {
        input_movevalues = self.movement;
        input_angles = self.v_angle;
        input_buttons = (self.button0 ? 1 : 0) + (self.button2 ? 2 : 0) + (self.button1 ? 4 : 0);
        input_impulse = 0;
        input_timelength = frametime;
    }

    runstandardplayerphysics(self);
};
