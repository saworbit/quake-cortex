/*
    cortex_debug.qc - Bot Debug Utilities

    Enhanced logging and debugging tools for bot behavior troubleshooting.
*/

// Debug visualization helpers
void(vector start, vector end, float colormap) Cortex_DebugLine =
{
    // Draw a debug line (requires developer mode)
    if (!cvar("developer") || !cvar("cortex_debug"))
        return;

    // Note: QuakeC doesn't have built-in debug lines like modern engines
    // This is a placeholder for future temp entity drawing
    // For now, we log it
    local string msg;
    msg = strcat("Line: ", vtos(start), " -> ", vtos(end));
    CortexLog(LOG_debug, "VISUAL", msg);
};

// Log bot decision with context
void(entity bot, string decision, string reason) Cortex_LogDecision =
{
    local string msg;

    if (!cvar("cortex_debug"))
        return;

    msg = strcat("Decision: ", decision, " | Reason: ", reason);
    CortexLogData(LOG_debug, "BOT_AI", msg, "");
};

// Log bot perception
void(entity bot, string what_seen) Cortex_LogPerception =
{
    local string msg;

    if (!cvar("cortex_debug"))
        return;

    msg = strcat("Perceived: ", what_seen);
    CortexLog(LOG_debug, "PERCEPTION", msg);
};

// Log bot movement
void(entity bot, vector target, string movement_type) Cortex_LogMovement =
{
    local string msg;

    if (!cvar("cortex_debug"))
        return;

    msg = strcat("Movement[", movement_type, "]: ");
    msg = strcat(msg, "to ", vtos(target));
    msg = strcat(msg, " from ", vtos(bot.origin));
    CortexLog(LOG_debug, "MOVEMENT", msg);
};

// Log bot combat action
void(entity bot, entity target, string action) Cortex_LogCombat =
{
    local string msg, target_info;

    if (!cvar("cortex_debug"))
        return;

    if (target)
        target_info = strcat(target.classname, " @ ", vtos(target.origin));
    else
        target_info = "none";

    msg = strcat("Combat[", action, "]: ");
    msg = strcat(msg, "target=", target_info);
    msg = strcat(msg, " | bot_health=", ftos(bot.health));
    msg = strcat(msg, " | bot_armor=", ftos(bot.armorvalue));

    CortexLog(LOG_debug, "COMBAT", msg);
};

// Dump comprehensive bot state for debugging
void(entity bot) Cortex_DumpBotState =
{
    local string data;
    local string enemy_info;
    local string msg;

    if (!cvar("developer") && !cvar("cortex_debug"))
        return;

    bprint("\n=== BOT STATE DUMP ===\n");

    msg = strcat("Time: ", ftos(time), "s\n");
    bprint(msg);

    msg = strcat("Position: ", vtos(bot.origin), "\n");
    bprint(msg);

    msg = strcat("Velocity: ", vtos(bot.velocity), "\n");
    bprint(msg);

    msg = strcat("Angles: ", vtos(bot.angles), "\n");
    bprint(msg);

    msg = strcat("Health: ", ftos(bot.health), "\n");
    bprint(msg);

    msg = strcat("Armor: ", ftos(bot.armorvalue), "\n");
    bprint(msg);

    msg = strcat("Weapon: ", ftos(bot.weapon), "\n");
    bprint(msg);

    msg = strcat("Ammo: ", ftos(bot.currentammo), "\n");
    bprint(msg);

    msg = strcat("Frags: ", ftos(bot.frags), "\n");
    bprint(msg);

    if (bot.enemy)
    {
        enemy_info = strcat(bot.enemy.classname, " @ ", vtos(bot.enemy.origin));
        msg = strcat("Enemy: ", enemy_info, "\n");
        bprint(msg);

        msg = strcat("Enemy health: ", ftos(bot.enemy.health), "\n");
        bprint(msg);
    }
    else
    {
        bprint("Enemy: none\n");
    }

    if (bot.goalentity)
    {
        msg = strcat("Goal: ", bot.goalentity.classname);
        msg = strcat(msg, " @ ", vtos(bot.goalentity.origin), "\n");
        bprint(msg);
    }
    else
    {
        bprint("Goal: none\n");
    }

    bprint("=====================\n\n");

    // Also log to structured log
    Cortex_DumpState();
};

// Performance monitoring
float bot_think_times[10];  // Last 10 think times
float bot_think_index;

void(float think_time) Cortex_RecordThinkTime =
{
    if (!cvar("cortex_debug"))
        return;

    bot_think_times[bot_think_index] = think_time;
    bot_think_index = bot_think_index + 1;
    if (bot_think_index >= 10)
        bot_think_index = 0;
};

void() Cortex_PrintPerformanceStats =
{
    local float i, total, avg;
    local string msg;

    if (!cvar("cortex_debug"))
        return;

    total = 0;
    for (i = 0; i < 10; i = i + 1)
        total = total + bot_think_times[i];

    avg = total / 10;

    msg = strcat("Avg think time (last 10): ", ftos(avg), "ms");
    CortexLog(LOG_info, "PERF", msg);
};

// Error reporting with context
void(string error_msg, string context) Cortex_ReportError =
{
    local string full_msg;
    full_msg = strcat(error_msg, " | Context: ", context);
    CortexLog(LOG_error, "BOT_ERROR", full_msg);

    full_msg = strcat("!!! CORTEX ERROR: ", error_msg, "\n");
    bprint(full_msg);
};

// Warning with suggestion
void(string warning_msg, string suggestion) Cortex_WarnWithSuggestion =
{
    local string full_msg;
    full_msg = strcat(warning_msg, " | Suggestion: ", suggestion);
    CortexLog(LOG_warning, "BOT_WARN", full_msg);
};
