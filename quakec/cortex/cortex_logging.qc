/*
    cortex_logging.qc - Cortex Black Box Logging (Body layer)

    Provides structured, pipe-delimited logs for capture via engine console logging.

    Format:
      [TIME] | [LEVEL] | [SYSTEM] | [MESSAGE] | [OPTIONAL_DATA]
*/

// Log levels
float LOG_info = 0;
float LOG_warning = 1;
float LOG_error = 2;
float LOG_debug = 3;

// Configure current verbosity (0..3)
float CORTEX_LOG_LEVEL = 3;

string(float level) Cortex_LogLevelStr =
{
    if (level == LOG_info) return "INFO";
    if (level == LOG_warning) return "WARN";
    if (level == LOG_error) return "ERR ";
    return "DBUG";
};

void(float level, string line) Cortex_EmitLogLine =
{
    // DEBUG logs require `developer 1` to avoid spamming normal play.
    if (level == LOG_debug)
    {
        if (!cvar("developer"))
            return;
        dprint(line);
        return;
    }

    // INFO/WARN/ERR: always visible (and captured by -condebug).
    bprint(line);
};

void(float level, string system, string msg) CortexLog =
{
    local string level_str;
    local string line;

    if (level > CORTEX_LOG_LEVEL)
        return;

    level_str = Cortex_LogLevelStr(level);

    line = strcat("[", ftos(time));
    line = strcat(line, "] | [", level_str, "] | [", system, "] | ", msg, "\n");
    Cortex_EmitLogLine(level, line);
};

void(float level, string system, string msg, string data) CortexLogData =
{
    local string level_str;
    local string line;

    if (level > CORTEX_LOG_LEVEL)
        return;

    level_str = Cortex_LogLevelStr(level);

    line = strcat("[", ftos(time));
    line = strcat(line, "] | [", level_str, "] | [", system, "] | ", msg);
    if (data != "")
        line = strcat(line, " | ", data);
    line = strcat(line, "\n");

    Cortex_EmitLogLine(level, line);
};

void() Cortex_DumpState =
{
    local string data;
    local string enemy_class;

    enemy_class = "";
    if (self.enemy)
        enemy_class = self.enemy.classname;

    data = "{";
    data = strcat(data, "\"classname\":\"", self.classname, "\"");
    data = strcat(data, ",\"health\":", ftos(self.health));
    data = strcat(data, ",\"armor\":", ftos(self.armorvalue));
    data = strcat(data, ",\"weapon\":", ftos(self.weapon));
    data = strcat(data, ",\"currentammo\":", ftos(self.currentammo));
    data = strcat(data, ",\"origin\":\"", vtos(self.origin), "\"");
    data = strcat(data, ",\"velocity\":\"", vtos(self.velocity), "\"");
    data = strcat(data, ",\"angles\":\"", vtos(self.angles), "\"");
    data = strcat(data, ",\"enemy\":\"", enemy_class, "\"");
    data = strcat(data, "}");

    CortexLogData(LOG_info, "STATE", "dump", data);
};
