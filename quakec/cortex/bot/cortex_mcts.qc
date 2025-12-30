/*
    cortex_mcts.qc - Lightweight Rollout-Based Action Selection (Pure QuakeC)

    Not a full tree search; instead we approximate "MCTS feel" by:
    - evaluating a small set of candidate actions
    - running a few short stochastic rollouts per action
    - picking the action with the best average score

    This is designed to be cheap at ~10Hz.
*/

float() crandom;
float(float state, float mcts_action) CortexMem_QGet;

#define CX_MCTS_ACT_WALK        1
#define CX_MCTS_ACT_STRAFEJUMP  2
#define CX_MCTS_ACT_DODGE       3
#define CX_MCTS_ACT_ROCKETJUMP  4
#define CX_MCTS_ACT_FEINT       5
#define CX_MCTS_ACT_AMBUSH      6

vector(vector dir) CortexMCTS_Perp2D =
{
    local vector perp;
    perp_x = -dir_y;
    perp_y = dir_x;
    perp_z = 0;
    if (vlen(perp) < 0.01)
        return '0 0 0';
    return normalize(perp);
};

float(vector pos, vector vel, entity bot, entity enemy, vector goal, float action) CortexMCTS_Rollout =
{
    local float i;
    local float dt;
    local float score;
    local vector dir;
    local vector perp;
    local vector start;
    local vector endpos;
    local float collided;
    local float want_away;

    dt = 0.05; // 4 steps = 0.2s
    score = 0;
    collided = 0;

    for (i = 0; i < 4; i = i + 1)
    {
        dir = goal - pos;
        dir_z = 0;
        if (vlen(dir) > 0.01)
            dir = normalize(dir);

        if (action == CX_MCTS_ACT_FEINT && enemy)
        {
            // First half: retreat, second half: re-approach.
            want_away = (i < 2) ? 1 : 0;
            if (want_away)
                dir = normalize(pos - enemy.origin);
        }

        if (action == CX_MCTS_ACT_STRAFEJUMP)
        {
            perp = CortexMCTS_Perp2D(dir);
            if (random() > 0.5) perp = perp * -1;
            vel = normalize(dir + perp * 0.35) * 480;
        }
        else if (action == CX_MCTS_ACT_DODGE && enemy)
        {
            perp = CortexMCTS_Perp2D(normalize(enemy.origin - pos));
            if (random() > 0.5) perp = perp * -1;
            vel = vel + perp * 240;
        }
        else if (action == CX_MCTS_ACT_WALK || action == CX_MCTS_ACT_AMBUSH)
        {
            vel = dir * 320;
        }

        if (action == CX_MCTS_ACT_ROCKETJUMP)
        {
            // Simulate a single upward impulse; penalize for low health.
            vel_z = vel_z + 350;
            score = score - 5;
        }
        else
        {
            // Gravity-ish (very rough; we only care about collision risk).
            vel_z = vel_z - 120;
        }

        start = pos + '0 0 16';
        endpos = start + vel * dt;
        traceline(start, endpos, TRUE, bot);
        if (trace_fraction < 0.85)
        {
            collided = 1;
            // Bounce off a bit.
            vel = vel * 0.2;
        }

        pos = pos + vel * dt;
    }

    // Reward: closer to goal, slight height gain (for vertical navigation).
    score = score - vlen(goal - pos) * 0.01;
    score = score + (pos_z - bot.origin_z) * 0.01;

    // Ambush preference: end out of LOS if possible.
    if (action == CX_MCTS_ACT_AMBUSH && enemy)
    {
        traceline(pos + '0 0 16', enemy.origin + '0 0 16', TRUE, bot);
        if (trace_fraction < 1)
            score = score + 4;
        else
            score = score - 2;
    }

    // Penalize collisions heavily.
    if (collided)
        score = score - 6;

    // Add a touch of noise ("gut feel").
    score = score + crandom() * 0.75;

    return score;
};

float(entity bot, entity enemy, vector goal, float allow_rocketjump) Cortex_MCTS_SelectAction =
{
    local float best_act;
    local float best_score;
    local float act;
    local float total;
    local float sims;
    local float s;
    local vector pos;
    local vector vel;
    local float threat;

    if (!bot || bot == world)
        return CX_MCTS_ACT_WALK;

    best_act = CX_MCTS_ACT_WALK;
    best_score = -999999;

    pos = bot.origin;
    vel = bot.velocity;

    threat = 0;
    if (enemy)
        threat = Cortex_Opp_Threat(enemy);

    // Keep sim count low; cvar allows tuning.
    sims = cvar("cortex_bot_mcts_rollouts");
    if (sims <= 0) sims = 8;
    if (sims > 16) sims = 16;

    for (act = CX_MCTS_ACT_WALK; act <= CX_MCTS_ACT_AMBUSH; act = act + 1)
    {
        if (act == CX_MCTS_ACT_ROCKETJUMP && !allow_rocketjump)
            continue;

        // High-threat enemies should bias to dodge/ambush/feint a bit.
        total = 0;
        for (s = 0; s < sims; s = s + 1)
            total = total + CortexMCTS_Rollout(pos, vel, bot, enemy, goal, act);

        total = total / sims;

        if (act == CX_MCTS_ACT_DODGE)
            total = total + threat * 2.0;
        if (act == CX_MCTS_ACT_FEINT)
            total = total + threat * 0.8;
        if (act == CX_MCTS_ACT_AMBUSH)
            total = total + threat * 0.6;

        if (total > best_score)
        {
            best_score = total;
            best_act = act;
        }
    }

    return best_act;
};

float(entity bot, entity enemy, vector goal, float allow_rocketjump, float state) Cortex_MCTS_SelectActionMem =
{
    local float best_act;
    local float best_score;
    local float act;
    local float total;
    local float sims;
    local float s;
    local vector pos;
    local vector vel;
    local float threat;
    local float qbias;

    if (!bot || bot == world)
        return CX_MCTS_ACT_WALK;

    best_act = CX_MCTS_ACT_WALK;
    best_score = -999999;

    pos = bot.origin;
    vel = bot.velocity;

    threat = 0;
    if (enemy)
        threat = Cortex_Opp_Threat(enemy);

    sims = cvar("cortex_bot_mcts_rollouts");
    if (sims <= 0) sims = 8;
    if (sims > 16) sims = 16;

    for (act = CX_MCTS_ACT_WALK; act <= CX_MCTS_ACT_AMBUSH; act = act + 1)
    {
        if (act == CX_MCTS_ACT_ROCKETJUMP && !allow_rocketjump)
            continue;

        total = 0;
        for (s = 0; s < sims; s = s + 1)
            total = total + CortexMCTS_Rollout(pos, vel, bot, enemy, goal, act);

        total = total / sims;

        if (act == CX_MCTS_ACT_DODGE)
            total = total + threat * 2.0;
        if (act == CX_MCTS_ACT_FEINT)
            total = total + threat * 0.8;
        if (act == CX_MCTS_ACT_AMBUSH)
            total = total + threat * 0.6;

        // Persistent memory bias (opponent/map specific).
        qbias = CortexMem_QGet(state, act);
        total = total + qbias * 1.5;

        if (total > best_score)
        {
            best_score = total;
            best_act = act;
        }
    }

    return best_act;
};
