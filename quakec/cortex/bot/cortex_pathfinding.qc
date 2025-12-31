/*
    cortex_pathfinding.qc - Lightweight Navigation for Cortex Bot

    A practical alternative to voxel grids in QuakeC: build a small graph of
    navigation nodes from existing map points (DM spawns, items, weapons) and
    run A* over those nodes when direct line-of-sight movement is blocked.

    This is intentionally conservative:
    - Nodes are sparse to keep A* cheap.
    - Neighbor links are generated on-the-fly (no big adjacency tables).
    - Returns the next waypoint (vector) rather than a full path list.
*/

// Per-node pathfinding fields (only used on cortex_navnode entities).
.entity cx_nav_next;
.float cx_pf_stamp;
.float cx_pf_state;   // 0=unseen, 1=open, 2=closed
.float cx_pf_g;
.float cx_pf_h;
.float cx_pf_f;
.entity cx_pf_parent;

float() crandom;

entity cortex_nav_head;
float cortex_nav_count;
float cortex_nav_initialized;
float cortex_pf_search_id;

#define CORTEX_NAV_MAX_NODES 256

float(float v, float lo, float hi) CortexNav_Clamp =
{
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
};

entity(vector org) CortexNav_AddNode =
{
    local entity node;

    if (cortex_nav_count >= CORTEX_NAV_MAX_NODES)
        return world;

    node = spawn();
    node.classname = "cortex_navnode";
    node.solid = SOLID_NOT;
    node.movetype = MOVETYPE_NONE;
    setorigin(node, org);

    node.cx_nav_next = cortex_nav_head;
    cortex_nav_head = node;
    cortex_nav_count = cortex_nav_count + 1;

    return node;
};

entity(vector org, float min_dist) CortexNav_AddNodeUnique =
{
    local entity n;

    n = cortex_nav_head;
    while (n)
    {
        if (vlen(n.origin - org) < min_dist)
            return n;
        n = n.cx_nav_next;
    }

    return CortexNav_AddNode(org);
};

float(vector start, vector endpos, entity ignore) CortexNav_HasLine =
{
    traceline(start, endpos, TRUE, ignore);
    return (trace_fraction == 1);
};

float(entity a, entity b, entity mover) CortexNav_AreNeighbors =
{
    local vector start;
    local vector endpos;
    local float dz;
    local float dist;

    if (!a || !b) return 0;
    if (a == b) return 0;

    dist = vlen(b.origin - a.origin);
    if (dist > cvar("cortex_bot_nav_link_radius"))
        return 0;

    dz = fabs(b.origin_z - a.origin_z);
    if (dz > 192)
        return 0;

    start = a.origin + '0 0 18';
    endpos = b.origin + '0 0 18';
    if (!CortexNav_HasLine(start, endpos, mover))
        return 0;

    return 1;
};

float(entity a, entity b) CortexNav_Heuristic =
{
    local vector d;
    d = b.origin - a.origin;
    d_z = d_z * 1.25;
    return vlen(d);
};

entity(vector pos) CortexNav_FindNearestNode =
{
    local entity node;
    local entity best;
    local float best_dist;
    local float dist;

    best_dist = 999999;
    node = cortex_nav_head;
    while (node)
    {
        dist = vlen(node.origin - pos);
        if (dist < best_dist)
        {
            best = node;
            best_dist = dist;
        }
        node = node.cx_nav_next;
    }

    return best;
};

entity(entity mover, float max_dist) CortexNav_FindReachableNode =
{
    local entity node;
    local entity best;
    local float best_dist;
    local float dist;
    local vector start;
    local vector endpos;

    if (!mover || mover == world)
        return world;

    best_dist = 999999;
    start = mover.origin + '0 0 16';

    node = cortex_nav_head;
    while (node)
    {
        dist = vlen(node.origin - mover.origin);
        if (dist <= max_dist && dist < best_dist)
        {
            endpos = node.origin + '0 0 16';
            if (CortexNav_HasLine(start, endpos, mover))
            {
                best = node;
                best_dist = dist;
            }
        }
        node = node.cx_nav_next;
    }

    return best;
};

entity(entity mover, vector goalpos, float max_dist) CortexNav_FindReachableToward =
{
    local entity node;
    local entity best;
    local float best_goal_dist;
    local float dist;
    local float goal_dist;
    local vector start;
    local vector endpos;

    if (!mover || mover == world)
        return world;

    best_goal_dist = 999999;
    start = mover.origin + '0 0 16';

    node = cortex_nav_head;
    while (node)
    {
        dist = vlen(node.origin - mover.origin);
        if (dist <= max_dist)
        {
            endpos = node.origin + '0 0 16';
            if (CortexNav_HasLine(start, endpos, mover))
            {
                goal_dist = vlen(goalpos - node.origin);
                if (goal_dist < best_goal_dist)
                {
                    best_goal_dist = goal_dist;
                    best = node;
                }
            }
        }
        node = node.cx_nav_next;
    }

    return best;
};

entity(entity goal) CortexNav_FindBestOpen =
{
    local entity node;
    local entity best;
    local float best_f;

    best_f = 999999999;
    node = cortex_nav_head;
    while (node)
    {
        if (node.cx_pf_stamp == cortex_pf_search_id && node.cx_pf_state == 1)
        {
            if (node.cx_pf_f < best_f)
            {
                best_f = node.cx_pf_f;
                best = node;
            }
        }
        node = node.cx_nav_next;
    }

    return best;
};

void(entity node, float stamp) CortexNav_TouchForSearch =
{
    if (node.cx_pf_stamp != stamp)
    {
        node.cx_pf_stamp = stamp;
        node.cx_pf_state = 0;
        node.cx_pf_g = 0;
        node.cx_pf_h = 0;
        node.cx_pf_f = 0;
        node.cx_pf_parent = world;
    }
};

entity(entity start, entity goal, entity mover) CortexNav_AStar =
{
    local float iter;
    local entity current;
    local entity neighbor;
    local float tentative_g;

    if (!start || !goal) return world;

    cortex_pf_search_id = cortex_pf_search_id + 1;
    if (cortex_pf_search_id < 1) cortex_pf_search_id = 1;

    CortexNav_TouchForSearch(start, cortex_pf_search_id);
    CortexNav_TouchForSearch(goal, cortex_pf_search_id);

    start.cx_pf_state = 1;
    start.cx_pf_g = 0;
    start.cx_pf_h = CortexNav_Heuristic(start, goal);
    start.cx_pf_f = start.cx_pf_h;
    start.cx_pf_parent = world;

    // Hard cap iterations to avoid frame spikes.
    for (iter = 0; iter < 96; iter = iter + 1)
    {
        current = CortexNav_FindBestOpen(goal);
        if (!current)
            return world;

        if (current == goal)
            return current;

        current.cx_pf_state = 2;

        // Expand: consider all nodes as candidates; sparse graph keeps this cheap.
        neighbor = cortex_nav_head;
        while (neighbor)
        {
            CortexNav_TouchForSearch(neighbor, cortex_pf_search_id);

            if (neighbor.cx_pf_state != 2 && CortexNav_AreNeighbors(current, neighbor, mover))
            {
                tentative_g = current.cx_pf_g + vlen(neighbor.origin - current.origin);

                if (neighbor.cx_pf_state != 1 || tentative_g < neighbor.cx_pf_g)
                {
                    neighbor.cx_pf_parent = current;
                    neighbor.cx_pf_g = tentative_g;
                    neighbor.cx_pf_h = CortexNav_Heuristic(neighbor, goal);
                    neighbor.cx_pf_f = neighbor.cx_pf_g + neighbor.cx_pf_h;
                    neighbor.cx_pf_state = 1;
                }
            }

            neighbor = neighbor.cx_nav_next;
        }
    }

    return world;
};

entity(entity start, entity endnode) CortexNav_PathNextHopNode =
{
    local entity node;
    local entity prev;

    node = endnode;
    prev = world;

    while (node && node != world && node != start)
    {
        prev = node;
        node = node.cx_pf_parent;
    }

    if (node == start)
        return prev;

    return world;
};

vector(entity mover, vector goalpos) CortexNav_NextWaypoint =
{
    local entity start;
    local entity goal;
    local entity endnode;
    local entity next;
    local entity fallback;
    local vector startpos;
    local vector endpos;
    local float max_direct;
    local float max_reach;

    if (!cortex_nav_initialized)
        return goalpos;

    if (!mover || mover == world)
        return goalpos;

    startpos = mover.origin + '0 0 16';
    endpos = goalpos + '0 0 16';

    max_direct = cvar("cortex_bot_nav_direct_check_radius");
    if (max_direct <= 0) max_direct = 1200;

    if (vlen(goalpos - mover.origin) < max_direct && CortexNav_HasLine(startpos, endpos, mover))
        return goalpos;

    max_reach = cvar("cortex_bot_nav_link_radius");
    if (max_reach <= 0) max_reach = 600;
    max_reach = max_reach * 2;

    start = CortexNav_FindReachableNode(mover, max_direct);
    if (!start)
        start = CortexNav_FindNearestNode(mover.origin);
    goal = CortexNav_FindNearestNode(goalpos);
    if (!start || !goal)
        return goalpos;

    endnode = CortexNav_AStar(start, goal, mover);
    if (endnode)
    {
        next = CortexNav_PathNextHopNode(start, endnode);
        if (next)
            return next.origin;
    }

    fallback = CortexNav_FindReachableToward(mover, goalpos, max_reach);
    if (fallback)
        return fallback.origin;

    return goalpos;
};

void(string class_name) CortexNav_AddAllByClass =
{
    local entity e;
    e = find(world, classname, class_name);
    while (e)
    {
        CortexNav_AddNodeUnique(e.origin, 48);
        e = find(e, classname, class_name);
    }
};

void() CortexNav_BuildFromWorld =
{
    local entity n;
    local vector org;
    local float i;

    cortex_nav_head = world;
    cortex_nav_count = 0;

    // Spawn points.
    CortexNav_AddAllByClass("info_player_deathmatch");
    CortexNav_AddAllByClass("info_player_start");

    // Items (id1).
    CortexNav_AddAllByClass("item_health");
    CortexNav_AddAllByClass("item_armor1");
    CortexNav_AddAllByClass("item_armor2");
    CortexNav_AddAllByClass("item_armorInv");
    CortexNav_AddAllByClass("item_shells");
    CortexNav_AddAllByClass("item_spikes");
    CortexNav_AddAllByClass("item_rockets");
    CortexNav_AddAllByClass("item_cells");

    // Weapons (id1).
    CortexNav_AddAllByClass("weapon_supershotgun");
    CortexNav_AddAllByClass("weapon_nailgun");
    CortexNav_AddAllByClass("weapon_supernailgun");
    CortexNav_AddAllByClass("weapon_grenadelauncher");
    CortexNav_AddAllByClass("weapon_rocketlauncher");
    CortexNav_AddAllByClass("weapon_lightning");

    // Create a few extra nodes around existing nodes to make the graph less brittle.
    // Note: iterate over a snapshot of the initial list (avoid expanding indefinitely while iterating).
    n = cortex_nav_head;
    for (i = 0; i < 64 && n; i = i + 1)
    {
        org_x = n.origin_x + crandom() * 256;
        org_y = n.origin_y + crandom() * 256;
        org_z = n.origin_z + 64;
        traceline(org, org - '0 0 256', TRUE, world);
        if (trace_fraction < 1)
            CortexNav_AddNodeUnique(trace_endpos + '0 0 2', 64);

        n = n.cx_nav_next;
    }

    cortex_nav_initialized = 1;
};

vector(entity mover, entity enemy) CortexNav_AmbushSpot =
{
    local entity n;
    local vector best;
    local float best_score;
    local float score;
    local float d_bot;
    local float d_enemy;
    local vector start;
    local vector endpos;

    if (!cortex_nav_initialized)
        return enemy ? enemy.origin : mover.origin;

    if (!mover || mover == world)
        return enemy ? enemy.origin : '0 0 0';

    if (!enemy || enemy == world)
        return mover.origin;

    best = enemy.origin;
    best_score = -999999;

    n = cortex_nav_head;
    while (n)
    {
        d_bot = vlen(n.origin - mover.origin);
        d_enemy = vlen(n.origin - enemy.origin);

        // Keep it local; we want "corner peeks", not map-wide wandering.
        if (d_bot < 900 && d_enemy < 700)
        {
            // Must be reachable in a straight line from bot.
            start = mover.origin + '0 0 16';
            endpos = n.origin + '0 0 16';
            if (CortexNav_HasLine(start, endpos, mover))
            {
                // Prefer positions that break LOS to the enemy.
                traceline(endpos, enemy.origin + '0 0 16', TRUE, mover);
                if (trace_fraction < 1)
                {
                    score = 100;
                    score = score - d_bot * 0.05;
                    score = score - d_enemy * 0.03;

                    // Prefer slightly higher ground.
                    score = score + (n.origin_z - enemy.origin_z) * 0.02;

                    if (score > best_score)
                    {
                        best_score = score;
                        best = n.origin;
                    }
                }
            }
        }

        n = n.cx_nav_next;
    }

    return best;
};

void() Cortex_PathInitMaybe =
{
    if (cortex_nav_initialized)
        return;

    // Defaults: keep pathing light and optional.
    if (cvar("cortex_bot_nav_enable"))
        CortexNav_BuildFromWorld();
};

vector(entity mover, vector goalpos) Cortex_PathNextWaypoint =
{
    if (!cvar("cortex_bot_nav_enable"))
        return goalpos;

    return CortexNav_NextWaypoint(mover, goalpos);
};

vector(entity mover, entity enemy) Cortex_PathAmbushSpot =
{
    if (!cvar("cortex_bot_nav_enable"))
        return enemy ? enemy.origin : mover.origin;

    return CortexNav_AmbushSpot(mover, enemy);
};
