/*
    cortex_tactics.qc - Cortex Bot v2 Tactics (HUBT-lite)

    Provides a small hierarchy:
    - mode selection (1v1 / balanced / multi)
    - high-level intent shaping (kite when outnumbered, deny when contested)

    The detailed utilities and action rollouts live in cortex_bot.qc + cortex_mcts.qc.
*/

float(entity bot) Cortex_Tactics_Style =
{
    local float s;
    s = cvar("cortex_style");
    if (s < 0) s = 0;
    if (s > 3) s = 3;
    return s;
};

float(entity bot) Cortex_Tactics_Skill =
{
    local float s;
    s = cvar("cortex_skill");
    if (s < 0) s = 0;
    if (s > 1) s = 1;
    return s;
};

float(float visible_enemies) Cortex_Tactics_Mode =
{
    if (visible_enemies <= 1) return 1;
    if (visible_enemies > 2) return 3;
    return 2;
};

float(entity bot, entity enemy, entity target_item, float visible_enemies) Cortex_Tactics_ShouldKite =
{
    local float mode;
    local float dist;

    if (!bot || bot == world) return 0;
    if (!enemy || enemy == world) return 0;

    mode = Cortex_Tactics_Mode(visible_enemies);
    if (mode != 3) return 0;

    dist = vlen(enemy.origin - bot.origin);
    if (dist < 420) return 1;
    return 0;
};

