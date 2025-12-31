/*
    cortex_forward.qc - Forward Declarations

    This file MUST be compiled early (right after defs.qc) to provide
    forward declarations for Cortex functions that are called by base
    Quake code before they're defined in Cortex modules.
*/

// Global variables used by base Quake code
entity lastspawn;
entity cortex_bot;  // Primary Cortex bot entity reference

// Cortex bot hooks called by base Quake (defined later in cortex/bot/)
void(entity bot, entity targ, entity attacker, float damage) Cortex_Opp_OnDamage;
void() Cortex_BotOnRespawn;
void(entity targ, entity attacker) Cortex_BotOnObituary;
void() Cortex_BotSpawn;

// Console commands (defined later in cortex/common/)
void() Cortex_HandleImpulse;
void() Cortex_ShowWelcome;
void() Cortex_DumpState;

// World management called by base Quake (defined later in cortex/common/cortex_world.qc)
void(entity ent) CopyToBodyQueue;

// External control hook (not used in pure mode, stub provided)
void() Cortex_ApplyControls;
