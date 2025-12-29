/*
    cortex_sensor.qc - Sensor Suite for Project Cortex

    This file implements the "eyes" of the AI bot:
    - Raycasts (Lidar-style 360° vision)
    - Proprioception (velocity, health, ammo, weapon state)
    - Environmental awareness (ground detection, nearby items)
*/

// Number of rays in the lidar sphere
#define RAYCAST_COUNT 32

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
Cortex_BuildSensorPacket

Assembles all sensor data into a single JSON packet
This is what gets sent to the Python brain every frame.
=================
*/
string() Cortex_BuildSensorPacket =
{
    local string packet;

    // PHASE 1: Send simple position data (compatible with Python parser)
    // Format: POS: 'x y z'
    packet = "POS: '";
    packet = strcat(packet, ftos(self.origin_x), " ");
    packet = strcat(packet, ftos(self.origin_y), " ");
    packet = strcat(packet, ftos(self.origin_z));
    packet = strcat(packet, "'\n");

    return packet;

    /* PHASE 2: Full JSON sensor data (commented out for now)
    packet = "{";
    packet = strcat(packet, "\"type\":\"sensor_update\"");
    packet = strcat(packet, ",\"time\":", ftos(time));
    packet = strcat(packet, ",\"position\":", Cortex_GetPosition());
    packet = strcat(packet, ",\"velocity\":", Cortex_GetVelocity());
    packet = strcat(packet, ",\"state\":", Cortex_GetState());

    // Note: Raycasts are expensive, only send every 3rd frame
    if (framecount % 3 == 0)
        packet = strcat(packet, ",\"raycasts\":", Cortex_CastRays());

    packet = strcat(packet, "}\n");

    return packet;
    */
};
