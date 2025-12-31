/*
    cortex_perception.qc - Cortex Bot v2 Perception

    Pure QuakeC perception utilities:
    - nearest visible enemy selection
    - visible enemy count (for 1v1 vs multi decisions)
    - inferred "events" like megahealth pickup via health spikes

    This intentionally avoids large voxel arrays; QuakeC memory/array support
    varies by compiler/engine. We instead use cheap traces and entity scans.
*/

entity cortex_percept_enemy;
float cortex_percept_visible_enemies;
float cortex_percept_tactic_mode; // 1=1v1, 2=balanced, 3=multi

// Last seen enemy memory.
entity cortex_percept_last_visible_enemy;
float cortex_percept_last_visible_time;

// Forced retaliation target (set on damage).
entity cortex_percept_forced_enemy;
float cortex_percept_forced_until;

// Inferred "heard mega" timer (seconds).
float cortex_percept_enemy_mega_heard_until;

// Enemy health delta tracker.
entity cortex_percept_last_enemy;
float cortex_percept_last_enemy_health;
float cortex_percept_last_enemy_health_time;

entity(entity bot, float radius) Cortex_Perception_FindNearestVisibleEnemy =
{
    local entity head;
    local entity best;
    local float best_dist;
    local float dist;
    local vector start;
    local vector forward;
    local vector to;
    local float fov_deg;
    local float min_dot;

    if (!bot || bot == world) return world;

    best_dist = 999999;
    start = bot.origin + '0 0 16';

    fov_deg = cvar("cortex_bot_fov_deg");
    if (fov_deg <= 0 || fov_deg >= 360)
        min_dot = -2;
    else
    {
        if (bot.flags & FL_CLIENT)
            makevectors(bot.v_angle);
        else
            makevectors(bot.angles);
        forward = v_forward;
        min_dot = cos((fov_deg * 0.5) * 0.0174532925);
    }

    head = findradius(bot.origin, radius);
    while (head)
    {
        if (head.classname == "player" && head != bot && head.health > 0)
        {
            if (min_dot > -1)
            {
                to = head.origin - bot.origin;
                to_z = 0;
                if (vlen(to) > 0.01)
                {
                    to = normalize(to);
                    if ((forward * to) < min_dot)
                    {
                        head = head.chain;
                        continue;
                    }
                }
            }

            traceline(start, head.origin + '0 0 16', TRUE, bot);
            if (trace_fraction == 1)
            {
                dist = vlen(head.origin - bot.origin);
                if (dist < best_dist)
                {
                    best = head;
                    best_dist = dist;
                }
            }
        }
        head = head.chain;
    }

    if (!best) return world;
    return best;
};

float(entity bot, float radius) Cortex_Perception_CountVisibleEnemies =
{
    local entity head;
    local float count;
    local vector start;
    local vector forward;
    local vector to;
    local float fov_deg;
    local float min_dot;

    if (!bot || bot == world) return 0;

    count = 0;
    start = bot.origin + '0 0 16';

    fov_deg = cvar("cortex_bot_fov_deg");
    if (fov_deg <= 0 || fov_deg >= 360)
        min_dot = -2;
    else
    {
        if (bot.flags & FL_CLIENT)
            makevectors(bot.v_angle);
        else
            makevectors(bot.angles);
        forward = v_forward;
        min_dot = cos((fov_deg * 0.5) * 0.0174532925);
    }

    head = findradius(bot.origin, radius);
    while (head)
    {
        if (head.classname == "player" && head != bot && head.health > 0)
        {
            if (min_dot > -1)
            {
                to = head.origin - bot.origin;
                to_z = 0;
                if (vlen(to) > 0.01)
                {
                    to = normalize(to);
                    if ((forward * to) < min_dot)
                    {
                        head = head.chain;
                        continue;
                    }
                }
            }

            traceline(start, head.origin + '0 0 16', TRUE, bot);
            if (trace_fraction == 1)
                count = count + 1;
        }
        head = head.chain;
    }

    return count;
};

void(entity bot, entity enemy) Cortex_Perception_MonitorEvents =
{
    local float dt;
    local float delta;

    if (!bot || bot == world) return;
    if (!enemy || enemy == world) return;

    // Infer "mega pickup sound" from a large positive health delta over a short window.
    if (cortex_percept_last_enemy != enemy)
    {
        cortex_percept_last_enemy = enemy;
        cortex_percept_last_enemy_health = enemy.health;
        cortex_percept_last_enemy_health_time = time;
        return;
    }

    dt = time - cortex_percept_last_enemy_health_time;
    if (dt <= 0) dt = 0.0001;

    // Sample at most ~5Hz for stability.
    if (dt < 0.20)
        return;

    delta = enemy.health - cortex_percept_last_enemy_health;

    // Mega adds 100; allow for some noise.
    if (delta >= 80 && enemy.health > 150 && enemy.health < 260)
        cortex_percept_enemy_mega_heard_until = time + 10;

    cortex_percept_last_enemy_health = enemy.health;
    cortex_percept_last_enemy_health_time = time;
};

void(entity bot) Cortex_Perception_Update =
{
    local entity visible;
    local entity forced;
    local float memory;

    if (!bot || bot == world)
        return;

    visible = Cortex_Perception_FindNearestVisibleEnemy(bot, 1200);
    if (visible && visible != world)
    {
        cortex_percept_last_visible_enemy = visible;
        cortex_percept_last_visible_time = time;
    }

    forced = cortex_percept_forced_enemy;
    if (forced && forced != world && forced.health > 0 && time <= cortex_percept_forced_until)
    {
        cortex_percept_enemy = forced;
    }
    else
    {
        cortex_percept_forced_enemy = world;
        cortex_percept_forced_until = 0;

        if (visible && visible != world)
        {
            cortex_percept_enemy = visible;
        }
        else
        {
            memory = cvar("cortex_bot_enemy_memory");
            if (memory < 0) memory = 0;
            if (cortex_percept_last_visible_enemy && cortex_percept_last_visible_enemy != world &&
                cortex_percept_last_visible_enemy.health > 0 &&
                (time - cortex_percept_last_visible_time) <= memory)
            {
                cortex_percept_enemy = cortex_percept_last_visible_enemy;
            }
            else
            {
                cortex_percept_enemy = world;
            }
        }
    }
    cortex_percept_visible_enemies = Cortex_Perception_CountVisibleEnemies(bot, 900);

    if (cortex_percept_visible_enemies <= 1) cortex_percept_tactic_mode = 1;
    else if (cortex_percept_visible_enemies > 2) cortex_percept_tactic_mode = 3;
    else cortex_percept_tactic_mode = 2;

    if (cortex_percept_enemy && cortex_percept_enemy != world)
        Cortex_Perception_MonitorEvents(bot, cortex_percept_enemy);
};

