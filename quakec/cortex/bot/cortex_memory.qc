/*
    cortex_memory.qc - Persistent Memory + Event Inference (Pure QuakeC)

    Goals:
    - Persist a small, opponent-aware Q-table across sessions using cvar strings.
    - Keep encoding compact and safe for cvars: base64 alphabet via chr2str/str2chr.
    - Provide simple state quantization for 1v1 vs multi, distance, health.

    Notes:
    - Requires DP_QC_CVAR_STRING to reliably read string cvars at runtime.
    - We store 32 states x 6 actions = 192 values, each quantized to 64 levels (1 char).
*/
// Builtins used here are declared in `lib/dpextensions.qc` (compiled before cortex files).

#define CX_MEM_STATES 32
#define CX_MEM_ACTS   6
#define CX_MEM_SIZE   (CX_MEM_STATES * CX_MEM_ACTS)

#define CX_MEM_ACT_WALK        1
#define CX_MEM_ACT_STRAFEJUMP  2
#define CX_MEM_ACT_DODGE       3
#define CX_MEM_ACT_ROCKETJUMP  4
#define CX_MEM_ACT_FEINT       5
#define CX_MEM_ACT_AMBUSH      6

string cortex_mem_b64;
string cortex_mem_key_current;
string cortex_mem_q; // length CX_MEM_SIZE
float cortex_mem_dirty;
float cortex_mem_enabled;

float() CortexMem_HasCvarString =
{
    if (!cvar("pr_checkextension"))
        return 0;
    if (!checkextension("DP_QC_CVAR_STRING"))
        return 0;
    // str2chr/chr2str come from the string extension set on most engines.
    if (!checkextension("FTE_STRINGS"))
        return 0;
    return 1;
};

float(string name) CortexMem_NameHash =
{
    local float i;
    local float n;
    local float sum;

    sum = 0;
    n = strlen(name);
    for (i = 0; i < n; i = i + 1)
        sum = sum + str2chr(name, i) * (i + 1);

    // Keep it short for cvar names.
    return mod(sum, 10000);
};

string(string map_name, entity enemy) CortexMem_KeyFor =
{
    local float h;
    local string key;

    key = strcat("cortex_mem_", map_name);

    if (enemy && enemy != world && enemy.netname != "")
    {
        h = CortexMem_NameHash(enemy.netname);
        h = floor(h);
        key = strcat(key, "_", ftos(h));
    }

    return key;
};

string() CortexMem_DefaultQ =
{
    local float i;
    local string s;
    local string mid;

    // q=0 maps to ~middle of [0..63] -> pick 32
    mid = substring(cortex_mem_b64, 32, 1);
    s = "";
    for (i = 0; i < CX_MEM_SIZE; i = i + 1)
        s = strcat(s, mid);
    return s;
};

float(string c) CortexMem_B64Index =
{
    // c should be length 1
    return strstrofs(cortex_mem_b64, c, 0);
};

string(float code) CortexMem_B64Char =
{
    if (code < 0) code = 0;
    if (code > 63) code = 63;
    return substring(cortex_mem_b64, code, 1);
};

float(float q) CortexMem_QToCode =
{
    local float code;

    // Clamp to [-2,2], map to [0,63]
    if (q < -2) q = -2;
    if (q > 2) q = 2;
    code = floor(((q + 2) / 4) * 63 + 0.5);
    if (code < 0) code = 0;
    if (code > 63) code = 63;
    return code;
};

float(float code) CortexMem_CodeToQ =
{
    // Map [0..63] -> [-2..2]
    return (code / 63) * 4 - 2;
};

string(string s, float idx, string c) CortexMem_SetChar =
{
    local float n;
    local string a;
    local string b;

    n = strlen(s);
    if (idx < 0 || idx >= n)
        return s;

    a = substring(s, 0, idx);
    b = substring(s, idx + 1, n - (idx + 1));
    return strcat(a, c, b);
};

float(float mcts_action) CortexMem_ActionToIndex =
{
    // Map MCTS action ids to a dense [0..CX_MEM_ACTS-1] index.
    if (mcts_action == CX_MEM_ACT_WALK) return 0;
    if (mcts_action == CX_MEM_ACT_STRAFEJUMP) return 1;
    if (mcts_action == CX_MEM_ACT_DODGE) return 2;
    if (mcts_action == CX_MEM_ACT_ROCKETJUMP) return 3;
    if (mcts_action == CX_MEM_ACT_FEINT) return 4;
    if (mcts_action == CX_MEM_ACT_AMBUSH) return 5;
    return 0;
};

float(float state, float mcts_action) CortexMem_Index =
{
    local float a;
    a = CortexMem_ActionToIndex(mcts_action);
    if (state < 0) state = 0;
    if (state > (CX_MEM_STATES - 1)) state = (CX_MEM_STATES - 1);
    return state * CX_MEM_ACTS + a;
};

void() CortexMem_Init =
{
    cortex_mem_b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    cortex_mem_key_current = "";
    cortex_mem_q = "";
    cortex_mem_dirty = 0;
    cortex_mem_enabled = CortexMem_HasCvarString() && cvar("cortex_bot_persist");
};

void(string key) CortexMem_LoadKey =
{
    local string s;

    if (!cortex_mem_enabled)
        return;

    if (cortex_mem_key_current == key && cortex_mem_q != "")
        return;

    // Save old key if dirty.
    if (cortex_mem_dirty && cortex_mem_key_current != "")
    {
        cvar_set(cortex_mem_key_current, cortex_mem_q);
        cortex_mem_dirty = 0;
    }

    cortex_mem_key_current = key;
    s = cvar_string(key);

    if (strlen(s) != CX_MEM_SIZE)
        cortex_mem_q = CortexMem_DefaultQ();
    else
        cortex_mem_q = s;
};

void() CortexMem_FlushMaybe =
{
    if (!cortex_mem_enabled) return;
    if (!cortex_mem_dirty) return;
    if (cortex_mem_key_current == "") return;

    // Write immediately; still cheap due to compact encoding.
    cvar_set(cortex_mem_key_current, cortex_mem_q);
    cortex_mem_dirty = 0;
};

float(float state, float mcts_action) CortexMem_QGet =
{
    local float idx;
    local string c;
    local float code;

    if (!cortex_mem_enabled) return 0;
    if (cortex_mem_q == "") return 0;

    idx = CortexMem_Index(state, mcts_action);
    c = substring(cortex_mem_q, idx, 1);
    code = CortexMem_B64Index(c);
    if (code < 0) code = 32;
    return CortexMem_CodeToQ(code);
};

void(float state, float mcts_action, float reward) CortexMem_QUpdate =
{
    local float idx;
    local float q;
    local float alpha;
    local float code;
    local string c;

    if (!cortex_mem_enabled) return;
    if (cortex_mem_q == "") return;

    idx = CortexMem_Index(state, mcts_action);
    q = CortexMem_QGet(state, mcts_action);

    // Small learning rate; reward should be in roughly [-2..2].
    alpha = 0.08;
    q = q + alpha * (reward - q);

    code = CortexMem_QToCode(q);
    c = CortexMem_B64Char(code);
    cortex_mem_q = CortexMem_SetChar(cortex_mem_q, idx, c);
    cortex_mem_dirty = 1;
};

float(entity bot, entity enemy, float visible_count) CortexMem_State =
{
    local float hb;
    local float db;
    local float multi;
    local float dist;

    if (!bot || bot == world)
        return 0;

    // Health bucket (0..3)
    hb = floor((bot.health / 100) * 4);
    if (hb < 0) hb = 0;
    if (hb > 3) hb = 3;

    // Distance bucket (0..3)
    dist = 999999;
    if (enemy)
        dist = vlen(enemy.origin - bot.origin);

    if (dist < 220) db = 0;
    else if (dist < 520) db = 1;
    else if (dist < 900) db = 2;
    else db = 3;

    multi = (visible_count > 1) ? 1 : 0;

    return hb + db * 4 + multi * 16;
};
