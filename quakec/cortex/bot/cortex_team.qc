/*
    cortex_team.qc - Cortex Bot v2 Team Coordination (lightweight)

    In teamplay modes, apply a small separation steering force to avoid clumping.
*/

vector(entity bot) Cortex_Team_SeparationSteer =
{
    local entity head;
    local vector steer;
    local vector away;
    local float dist;
    local float teamplay_mode;
    local float t;

    float(float v, float lo, float hi) Clamp =
    {
        if (v < lo) return lo;
        if (v > hi) return hi;
        return v;
    };

    steer = '0 0 0';
    if (!bot || bot == world) return steer;

    teamplay_mode = cvar("teamplay");
    if (teamplay_mode != 2) return steer;

    head = findradius(bot.origin, 280);
    while (head)
    {
        if (head.classname == "player" && head != bot && head.health > 0 && head.team == bot.team && bot.team > 0)
        {
            away = bot.origin - head.origin;
            dist = vlen(away);
            if (dist > 1)
            {
                away = normalize(away);
                t = 1 - Clamp(dist / 280, 0, 1);
                steer = steer + away * (120 * t);
            }
        }
        head = head.chain;
    }

    return steer;
};
