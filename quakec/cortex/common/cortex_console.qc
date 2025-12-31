/*
    cortex_console.qc - Console Commands & Menu System

    Provides easy-to-use console commands and in-game menu for bot management.
*/

// Register all Cortex console commands
void() Cortex_RegisterCommands =
{
    CortexLog(LOG_info, "CONSOLE", "Registering console commands...");

    // Register commands (these will be available as impulses or via server commands)
    // Note: QuakeC doesn't have direct console command registration like modern engines
    // Instead, we'll use cvars and impulses for control

    CortexLog(LOG_info, "CONSOLE", "Console commands registered. Use 'cortex_help' for list.");
};

// Helper: Find all bot entities
float() Cortex_CountBots =
{
    local entity e;
    local float count;

    count = 0;
    if (cvar("pr_checkextension") && checkextension("DP_SV_BOTCLIENT"))
    {
        e = find(world, classname, "player");
        while (e)
        {
            if (clienttype(e) == CLIENTTYPE_BOT)
                count = count + 1;
            e = find(e, classname, "player");
        }
    }

    e = find(world, classname, "cortex_bot");
    while (e)
    {
        count = count + 1;
        e = find(e, classname, "cortex_bot");
    }
    return count;
};

// Helper: Kill all bots
void() Cortex_KillAllBots =
{
    local entity e, next;
    local float count;
    local string msg;

    count = 0;
    if (cvar("pr_checkextension") && checkextension("DP_SV_BOTCLIENT") && checkextension("DP_SV_DROPCLIENT"))
    {
        e = find(world, classname, "player");
        while (e)
        {
            next = find(e, classname, "player");
            if (clienttype(e) == CLIENTTYPE_BOT)
            {
                dropclient(e);
                count = count + 1;
            }
            e = next;
        }
    }

    e = find(world, classname, "cortex_bot");
    while (e)
    {
        next = find(e, classname, "cortex_bot");
        count = count + 1;
        remove(e);
        e = next;
    }

    if (count > 0)
    {
        msg = strcat("Removed ", ftos(count), " Cortex bot(s)\n");
        bprint(msg);
    }
    else
        bprint("No Cortex bots to remove\n");
};

// Helper: List all bots
void() Cortex_ListAllBots =
{
    local entity e;
    local float count;
    local string info;

    count = 0;
    bprint("=== CORTEX BOTS ===\n");

    if (cvar("pr_checkextension") && checkextension("DP_SV_BOTCLIENT"))
    {
        e = find(world, classname, "player");
        while (e)
        {
            if (clienttype(e) == CLIENTTYPE_BOT)
            {
                count = count + 1;
                info = strcat("Bot #", ftos(count));
                info = strcat(info, " | Name: ", e.netname);
                info = strcat(info, " | Health: ", ftos(e.health));
                info = strcat(info, " | Armor: ", ftos(e.armorvalue));
                info = strcat(info, " | Frags: ", ftos(e.frags));
                info = strcat(info, "\n");
                bprint(info);
            }
            e = find(e, classname, "player");
        }
    }

    e = find(world, classname, "cortex_bot");
    while (e)
    {
        count = count + 1;
        info = strcat("Bot #", ftos(count));
        info = strcat(info, " | Health: ", ftos(e.health));
        info = strcat(info, " | Armor: ", ftos(e.armorvalue));
        info = strcat(info, " | Frags: ", ftos(e.frags));
        info = strcat(info, "\n");
        bprint(info);
        e = find(e, classname, "cortex_bot");
    }

    if (count == 0)
        bprint("No Cortex bots active\n");
    else
    {
        info = strcat(ftos(count), " bot(s) total\n");
        bprint(info);
    }
};

// Helper: Print help
void() Cortex_PrintHelp =
{
    bprint("\n");
    bprint("=== CORTEX BOT COMMANDS ===\n");
    bprint("Console variables (use 'set' or 'toggle'):\n");
    bprint("  cortex_bot_enable <0|1>    - Enable/disable bot AI\n");
    bprint("  cortex_spawn_bot <0|1>     - Spawn bot on map start\n");
    bprint("  cortex_bot_skill <0-3>     - Bot difficulty (0=easy, 3=hard)\n");
    bprint("  cortex_debug <0|1>         - Enable debug output\n");
    bprint("  cortex_log_level <0-3>     - Log verbosity (0=info only, 3=all)\n");
    bprint("\n");
    bprint("Manual spawning:\n");
    bprint("  impulse 200                - Spawn a bot at your location\n");
    bprint("  impulse 201                - Remove all bots\n");
    bprint("  impulse 202                - List all bots\n");
    bprint("  impulse 203                - Show bot status\n");
    bprint("  impulse 204                - Toggle debug mode\n");
    bprint("\n");
    bprint("Advanced:\n");
    bprint("  developer <0|1>            - Show debug logs\n");
    bprint("  condump <filename>         - Dump console to file\n");
    bprint("\n");
};

// Helper: Print status
void() Cortex_PrintStatus =
{
    local float bot_count;
    local string status;

    bot_count = Cortex_CountBots();

    bprint("\n");
    bprint("=== CORTEX STATUS ===\n");
    status = strcat("Active bots: ", ftos(bot_count), "\n");
    bprint(status);
    status = strcat("Bot AI enabled: ", ftos(cvar("cortex_bot_enable")), "\n");
    bprint(status);
    status = strcat("Auto-spawn: ", ftos(cvar("cortex_spawn_bot")), "\n");
    bprint(status);
    status = strcat("Skill level: ", ftos(cvar("cortex_bot_skill")), "\n");
    bprint(status);
    status = strcat("Debug mode: ", ftos(cvar("cortex_debug")), "\n");
    bprint(status);
    status = strcat("Log level: ", ftos(cvar("cortex_log_level")), "\n");
    bprint(status);
    status = strcat("Server time: ", ftos(time), "s\n");
    bprint(status);
    bprint("\n");
};

// Impulse handler for bot commands
void() Cortex_HandleImpulse =
{
    // Impulse 200: Spawn bot
    if (self.impulse == 200)
    {
        bprint("Spawning Cortex bot...\n");
        Cortex_BotSpawn();
        self.impulse = 0;
        return;
    }

    // Impulse 201: Kill all bots
    if (self.impulse == 201)
    {
        Cortex_KillAllBots();
        self.impulse = 0;
        return;
    }

    // Impulse 202: List bots
    if (self.impulse == 202)
    {
        Cortex_ListAllBots();
        self.impulse = 0;
        return;
    }

    // Impulse 203: Status
    if (self.impulse == 203)
    {
        Cortex_PrintStatus();
        self.impulse = 0;
        return;
    }

    // Impulse 204: Toggle debug
    if (self.impulse == 204)
    {
        local float debug_mode;
        debug_mode = cvar("cortex_debug");
        if (debug_mode)
        {
            cvar_set("cortex_debug", "0");
            bprint("Cortex debug mode: OFF\n");
        }
        else
        {
            cvar_set("cortex_debug", "1");
            bprint("Cortex debug mode: ON\n");
        }
        self.impulse = 0;
        return;
    }

    // Impulse 205: Help
    if (self.impulse == 205)
    {
        Cortex_PrintHelp();
        self.impulse = 0;
        return;
    }
};

// Show welcome message with quick start instructions
void() Cortex_ShowWelcome =
{
    bprint("\n");
    bprint("======================================\n");
    bprint("    PROJECT CORTEX - Pure QuakeC Bot\n");
    bprint("======================================\n");
    bprint("\n");
    bprint("Quick Start:\n");
    bprint("  Press ~ to open console\n");
    bprint("  Type: impulse 200  (spawn a bot)\n");
    bprint("  Type: impulse 203  (show status)\n");
    bprint("\n");
    bprint("For full command list, use: impulse 205\n");
    bprint("or bind a key: bind h 'impulse 205'\n");
    bprint("\n");
};
