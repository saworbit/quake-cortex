/*
    cortex_sensor.qc - Sensor Suite for Project Cortex

    This file implements the "eyes" of the AI bot:
    - Raycasts (Lidar-style 360° vision)
    - Proprioception (velocity, health, ammo, weapon state)
    - Environmental awareness (ground detection, nearby items)
*/

// Number of rays in the lidar sphere
#define RAYCAST_COUNT 32
#define CORTEX_LIDAR_RANGE 1000
#define CORTEX_ENEMY_RADIUS 1000

// Sensor data structure
string sensor_data;

/*
=================
Cortex_CastRays

Casts rays in a sphere around the bot to detect walls and surfaces.
Returns a JSON array of distances and surface types.
=================
*/
string() Cortex_CastRays =
{
    local float i;
    local float pitch, yaw;
    local vector dir, endpos;
    local vector hitpos;
    local float dist;
    local string result;

    result = "[";

    // Cast rays in a spherical pattern (simple latitude/longitude distribution)
    for (i = 0; i < RAYCAST_COUNT; i = i + 1)
    {
        // Distribute rays in rings around sphere
        // Golden angle for even distribution
        yaw = (i * 137.508) + self.angles_y; // Golden angle + bot's current yaw

        // Simple pitch distribution from -60 to +60 degrees (horizon focus)
        // Map i to a range: bottom ring, middle ring, top ring
        pitch = -60 + (i * 120 / RAYCAST_COUNT);

        // Create angle vector and convert to direction
        dir_x = pitch;
        dir_y = yaw;
        dir_z = 0;

        makevectors(dir);

        // Cast ray 1000 units out
        endpos = self.origin + v_forward * 1000;
        traceline(self.origin, endpos, TRUE, self);

        // Calculate distance
        dist = vlen(trace_endpos - self.origin);

        // Build JSON object for this ray
        if (i > 0)
            result = strcat(result, ",");

        result = strcat(result, "{");
        result = strcat(result, "\"dist\":", ftos(dist));
        result = strcat(result, ",\"hit\":", (trace_fraction < 1) ? "true" : "false");

        // Detect surface type by content
        if (pointcontents(trace_endpos) == CONTENT_LAVA)
            result = strcat(result, ",\"surface\":\"lava\"");
        else if (pointcontents(trace_endpos) == CONTENT_SLIME)
            result = strcat(result, ",\"surface\":\"slime\"");
        else if (pointcontents(trace_endpos) == CONTENT_WATER)
            result = strcat(result, ",\"surface\":\"water\"");
        else
            result = strcat(result, ",\"surface\":\"solid\"");

        result = strcat(result, "}");
    }

    result = strcat(result, "]");
    return result;
};

/*
=================
Cortex_GetVelocity

Returns current velocity as JSON object
=================
*/
string() Cortex_GetVelocity =
{
    local string result;
    local float speed;

    speed = vlen(self.velocity);

    result = "{";
    result = strcat(result, "\"x\":", ftos(self.velocity_x));
    result = strcat(result, ",\"y\":", ftos(self.velocity_y));
    result = strcat(result, ",\"z\":", ftos(self.velocity_z));
    result = strcat(result, ",\"speed\":", ftos(speed));
    result = strcat(result, "}");

    return result;
};

/*
=================
Cortex_GetState

Returns bot's internal state (health, ammo, weapon, etc.)
=================
*/
string() Cortex_GetState =
{
    local string result;
    local float grounded;

    // Check if on ground
    grounded = (self.flags & FL_ONGROUND) ? 1 : 0;

    result = "{";
    result = strcat(result, "\"health\":", ftos(self.health));
    result = strcat(result, ",\"armor\":", ftos(self.armorvalue));
    result = strcat(result, ",\"weapon\":", ftos(self.weapon));
    result = strcat(result, ",\"ammo\":", ftos(self.currentammo));
    result = strcat(result, ",\"grounded\":", ftos(grounded));
    result = strcat(result, ",\"waterlevel\":", ftos(self.waterlevel));
    result = strcat(result, "}");

    return result;
};

/*
=================
Cortex_GetPosition

Returns position and angles as JSON
=================
*/
string() Cortex_GetPosition =
{
    local string result;

    result = "{";
    result = strcat(result, "\"x\":", ftos(self.origin_x));
    result = strcat(result, ",\"y\":", ftos(self.origin_y));
    result = strcat(result, ",\"z\":", ftos(self.origin_z));
    result = strcat(result, ",\"pitch\":", ftos(self.angles_x));
    result = strcat(result, ",\"yaw\":", ftos(self.angles_y));
    result = strcat(result, ",\"roll\":", ftos(self.angles_z));
    result = strcat(result, "}");

    return result;
};

/*
=================
Cortex_Vec3Array

Returns a vector as a JSON array: [x,y,z]
=================
*/
string(vector v) Cortex_Vec3Array =
{
    local string out;

    out = "[";
    out = strcat(out, ftos(v_x), ",", ftos(v_y), ",", ftos(v_z), "]");
    return out;
};

/*
=================
Cortex_Lidar5

Returns a JSON array of 5 trace fractions (0..1).
Rays: center, left15, right15, left30, right30 (approx).
=================
*/
string() Cortex_Lidar5 =
{
    local vector start;
    local vector endpos;
    local vector dir;
    local float i;
    local string result;

    makevectors(self.v_angle);
    start = self.origin + '0 0 16';

    result = "[";

    // i = -2..2 -> -30deg, -15deg, 0deg, +15deg, +30deg (approx)
    for (i = -2; i <= 2; i = i + 1)
    {
        dir = v_forward + (v_right * (i * 0.15));
        dir = normalize(dir);

        endpos = start + (dir * CORTEX_LIDAR_RANGE);
        traceline(start, endpos, TRUE, self);

        if (i > -2)
            result = strcat(result, ",");
        result = strcat(result, ftos(trace_fraction));
    }

    result = strcat(result, "]");
    return result;
};

/*
=================
Cortex_VisibleEnemies

Returns a JSON array of visible player summaries (distance only, for now).
=================
*/
string() Cortex_VisibleEnemies =
{
    local string result;
    local entity head;
    local float first_enemy;
    local vector start;
    local float dist;

    start = self.origin + '0 0 16';
    first_enemy = 1;

    result = "[";

    head = findradius(self.origin, CORTEX_ENEMY_RADIUS);
    while (head)
    {
        if (head.classname == "player" && head != self && head.health > 0)
        {
            traceline(start, head.origin + '0 0 16', TRUE, self);
            if (trace_fraction == 1)
            {
                dist = vlen(head.origin - self.origin);
                if (!first_enemy)
                    result = strcat(result, ",");
                first_enemy = 0;
                result = strcat(result, "{\"dist\":", ftos(dist), "}");
            }
        }
        head = head.chain;
    }

    result = strcat(result, "]");
    return result;
};

/*
=================
Cortex_BuildSensorPacket

Assembles all sensor data into a single JSON packet
This is what gets sent to the Python brain every frame.
=================
*/
string() Cortex_BuildSensorPacket =
{
    local string packet;

    packet = "{";
    packet = strcat(packet, "\"time\":", ftos(time));

    // Proprioception
    packet = strcat(packet, ",\"health\":", ftos(self.health));
    packet = strcat(packet, ",\"armor\":", ftos(self.armorvalue));
    packet = strcat(packet, ",\"ammo_shells\":", ftos(self.ammo_shells));
    packet = strcat(packet, ",\"ammo_nails\":", ftos(self.ammo_nails));
    packet = strcat(packet, ",\"ammo_rockets\":", ftos(self.ammo_rockets));
    packet = strcat(packet, ",\"ammo_cells\":", ftos(self.ammo_cells));
    packet = strcat(packet, ",\"pos\":", Cortex_Vec3Array(self.origin));
    packet = strcat(packet, ",\"vel\":", Cortex_Vec3Array(self.velocity));

    // Vision + awareness
    packet = strcat(packet, ",\"lidar\":", Cortex_Lidar5());
    packet = strcat(packet, ",\"enemies\":", Cortex_VisibleEnemies());

    packet = strcat(packet, "}\n");
    return packet;
};
