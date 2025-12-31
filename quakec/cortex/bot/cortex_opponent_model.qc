/*
    cortex_opponent_model.qc - Lightweight Opponent Modeling (Pure QuakeC)

    QuakeC doesn't have convenient arrays/dicts, so we store per-opponent
    statistics in spawned entities keyed by netname.

    Tracked (minimal + practical):
    - damage_to_bot: how much this opponent has hurt the bot
    - damage_from_bot: how much the bot has hurt this opponent
    - kills/deaths vs bot
    - "air ratio" (samples of being airborne) as a proxy for jumpiness
*/

.string cx_opp_name;
.float cx_opp_damage_to_bot;
.float cx_opp_damage_from_bot;
.float cx_opp_kills;
.float cx_opp_deaths;
.float cx_opp_air_samples;
.float cx_opp_air_count;
.float cx_opp_last_sample;
.entity cx_opp_next;

entity cortex_opp_head;

entity(entity pl) Cortex_Opp_Get =
{
    local entity o;
    local string name;

    if (!pl || pl == world) return world;
    if (pl.netname == "") return world;

    name = pl.netname;

    o = cortex_opp_head;
    while (o)
    {
        if (o.cx_opp_name == name)
            return o;
        o = o.cx_opp_next;
    }

    o = spawn();
    o.classname = "cortex_opp";
    o.solid = SOLID_NOT;
    o.movetype = MOVETYPE_NONE;

    o.cx_opp_name = name;
    o.cx_opp_damage_to_bot = 0;
    o.cx_opp_damage_from_bot = 0;
    o.cx_opp_kills = 0;
    o.cx_opp_deaths = 0;
    o.cx_opp_air_samples = 0;
    o.cx_opp_air_count = 0;
    o.cx_opp_last_sample = -9999;

    o.cx_opp_next = cortex_opp_head;
    cortex_opp_head = o;

    return o;
};

void(entity bot, entity pl) Cortex_Opp_SampleMovement =
{
    local entity o;
    local float airborne;

    if (!pl || pl == world) return;
    if (pl.classname != "player") return;
    if (pl.health <= 0) return;

    o = Cortex_Opp_Get(pl);
    if (!o) return;

    if (time < o.cx_opp_last_sample + 0.25)
        return;

    o.cx_opp_last_sample = time;

    airborne = (pl.flags & FL_ONGROUND) ? 0 : 1;
    o.cx_opp_air_samples = o.cx_opp_air_samples + airborne;
    o.cx_opp_air_count = o.cx_opp_air_count + 1;
};

float(entity pl) Cortex_Opp_AirRatio =
{
    local entity o;
    o = Cortex_Opp_Get(pl);
    if (!o) return 0;
    if (o.cx_opp_air_count <= 0) return 0;
    return o.cx_opp_air_samples / o.cx_opp_air_count;
};

float(entity pl) Cortex_Opp_Threat =
{
    local entity o;
    local float threat;
    local float air;

    o = Cortex_Opp_Get(pl);
    if (!o) return 0;

    // Basic threat: damage they've done, plus a bit for being "airborne often" (harder to hit).
    threat = o.cx_opp_damage_to_bot * 0.02;
    air = Cortex_Opp_AirRatio(pl);
    threat = threat + air * 0.5;

    // Clamp to a sane range for weighting.
    if (threat < 0) threat = 0;
    if (threat > 3) threat = 3;
    return threat;
};

void(entity bot, entity targ, entity attacker, float damage) Cortex_Opp_OnDamage =
{
    local entity o;

    if (!bot || bot == world) return;
    if (!targ || targ == world) return;
    if (!attacker || attacker == world) return;

    // Only track interactions involving the bot to keep overhead low.
    if (targ == bot && attacker.classname == "player")
    {
        o = Cortex_Opp_Get(attacker);
        if (o) o.cx_opp_damage_to_bot = o.cx_opp_damage_to_bot + damage;

        // Immediate retarget when taking damage.
        if (cvar("cortex_bot_retaliate_time") > 0)
        {
            cortex_percept_forced_enemy = attacker;
            cortex_percept_forced_until = time + cvar("cortex_bot_retaliate_time");
        }
    }

    if (attacker == bot && targ.classname == "player")
    {
        o = Cortex_Opp_Get(targ);
        if (o) o.cx_opp_damage_from_bot = o.cx_opp_damage_from_bot + damage;
    }
};

void(entity bot, entity victim, entity killer) Cortex_Opp_OnKill =
{
    local entity o;

    if (!bot || bot == world) return;
    if (!victim || victim == world) return;
    if (!killer || killer == world) return;

    if (victim == bot && killer.classname == "player")
    {
        o = Cortex_Opp_Get(killer);
        if (o) o.cx_opp_kills = o.cx_opp_kills + 1;
    }

    if (killer == bot && victim.classname == "player")
    {
        o = Cortex_Opp_Get(victim);
        if (o) o.cx_opp_deaths = o.cx_opp_deaths + 1;
    }
};

void(entity bot) Cortex_Opp_Frame =
{
    local entity head;

    if (!bot || bot == world) return;

    head = findradius(bot.origin, 1400);
    while (head)
    {
        if (head.classname == "player" && head != bot)
            Cortex_Opp_SampleMovement(bot, head);
        head = head.chain;
    }
};
