/*
    cortex_combat.qc - Cortex Bot v2 Combat Helpers
*/

void() W_SetCurrentAmmo;

float(entity bot) Cortex_Combat_Skill =
{
    local float s;
    s = cvar("cortex_skill");
    if (s < 0) s = 0;
    if (s > 1) s = 1;
    return s;
};

void(entity bot, entity enemy) Cortex_Combat_MaybeSwitchWeapon =
{
    local float dist;

    if (!bot || bot == world) return;
    if (!enemy || enemy == world) return;

    dist = vlen(enemy.origin - bot.origin);

    // Simple, id1-friendly weapon preference:
    // - RL if available and not point-blank
    // - SSG if point-blank and we have shells (won't always exist on bot)
    if ((bot.items & IT_ROCKET_LAUNCHER) && bot.ammo_rockets > 0 && dist > 120)
    {
        bot.weapon = IT_ROCKET_LAUNCHER;
        W_SetCurrentAmmo();
        return;
    }

    if ((bot.items & IT_SUPER_SHOTGUN) && bot.ammo_shells > 0 && dist < 220)
    {
        bot.weapon = IT_SUPER_SHOTGUN;
        W_SetCurrentAmmo();
        return;
    }

    // Default: keep current.
};

