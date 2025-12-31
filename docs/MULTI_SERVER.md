# Cortex Bot Multiplayer Server Setup

Host a listen or dedicated server so friends can join your Cortex-powered deathmatches. Works with **FTEQW** (default) or **DarkPlaces** (recommended for better bots/netcode). Bots auto-spawn on launch; no QuakeC hacking required unless you drop in the optional snippet at the end.

## Assumptions
- `Game/cortex_pure/progs.dat` exists (run `scripts/build_pure.bat` first).
- Quake data present in `Game/id1/`.
- Ports open: UDP 26000 in your router/firewall.

## Step 1: One-click server BAT files (place in `Game/`)
Run as admin (right click → Run as Administrator). For DarkPlaces you can use the server binaries that ship with the engine.

### FTEQW Listen Server (you + guests)
`run_fte_multi.bat`:
```
fteqw64.exe -game cortex +map dm3 +deathmatch 1 +listen 8 +sv_cheats 1 +cortex_add_bots 4
```

### FTEQW Dedicated Server (headless)
`run_fte_dedicated.bat`:
```
fteqw-sv64.exe -game cortex +map dm3 +deathmatch 1 +dedicated 16 +sv_cheats 1 +cortex_add_bots 8
```

### DarkPlaces Listen Server (recommended)
`run_dp_multi.bat`:
```
darkplaces.exe -game cortex +map dm3 +deathmatch 1 +listen 8 +sv_cheats 1 +cortex_add_bots 4
```

### DarkPlaces Dedicated Server (headless, stable)
`run_dp_dedicated.bat`:
```
darkplaces-server.exe -game cortex +map dm3 +deathmatch 1 +dedicated 16 +sv_cheats 1 +cortex_add_bots 8 +rcon_password cortex_secret
```

Change `+map dm3` to `dm4`/`start`/`e1m1`. `+listen 8` caps human players; `+dedicated 16` reserves 16 slots with no local player. `cortex_add_bots N` auto-spawns bots.

Once the BAT runs, the console logs `Listening on port 26000`. Players connect using:

```
connect YOUR_IP:26000
```

Replace `YOUR_IP` with your local/public IP depending on LAN/internet play.

## Step 2: Port forwarding (internet play)
1. Find your internal IP: `ipconfig` → IPv4 (e.g., `192.168.1.42`).
2. Login to your router (usually `http://192.168.1.1`). Credentials often `admin/admin`.
3. Forward UDP port **26000** to your IPv4 address (internal/external both 26000).
4. Windows Firewall: Allow `fteqw64.exe`/`darkplaces.exe` for UDP port 26000.
5. Test: `canyouseeme.org` (port 26000) or `quakeservers.net` to verify visibility.

> Local test? run server and `connect 127.0.0.1:26000`.

## Step 3: Server console handy commands
The usual Cortex console verbs work. Extra server-focused ones:

| Command | What it does |
| --- | --- |
| `status` | Shows players + bots + IPs |
| `changelevel dm4` | Force map change mid-match |
| `kick <name>` | Kick a bot or player |
| `sv_cheats 0` | Lock cheats after warmup |
| `rcon_password <pass>` | Sets remote admin password |
| `rcon <pass> "command"` | Run command from client (ex: `rcon cortex_secret "cortex_add_bots 1"`) |

## Step 4: Update `cortex_bots.cfg` with server extras
Append the following to the config you already exec (see `docs/BOTS_GUIDE.md`):

```
// Server helpers
alias cortex_server_status "status; echo ^3Players/Bots listed!"
alias cortex_change_map "changelevel $1; echo ^2Map changed to $1!"
alias cortex_kick_player "kick $1; echo ^1Kicked $1!"

bind m "cortex_change_map dm3"
bind k "cortex_server_status"
```

Then run `exec cortex_bots.cfg` in the console again. The binds let you `m` to rotate maps and `k` to check players/bots at a glance.

## Step 5: Optional QuakeC snippet (insert before `Cortex_SpawnBot`)
Add these helper-hooks if you edit `quakec/cortex/bot/cortex_bot.qc`. They keep bots from teamkilling (if `+teamplay 1`), respawn everybody automatically, and let `cortex_add_bots` respect server counts:

```qc
void() cortex_add_bots =
{
    local float num = bound(1, stof(argv(1)), 16);
    for (float i = 0; i < num; i++)
    {
        cortex_spawn_bot();
        cortex_bots[i].team = random(1, 4);
    }
};

void() BotRespawn =
{
    if (self.health <= 0)
    {
        self.health = 100;
        self.origin = find(lastspawn, classname, "info_player_deathmatch").origin;
        self.nextthink = time + 0.1;
    }
};
```

Inside `Cortex_BotThink`, wrap target selection:

```qc
if (cvar("teamplay") && target.team == self.team) return;
```

Recompile with `scripts/build_pure.bat` after editing.

## Troubleshooting
- **No connection**: double-check firewall/port forward, use `connect 127.0.0.1:26000` for local.
- **Lag**: use dedicated servers, limit bots to ≤8 human-like.
- **Bots too strong**: `cortex_set_skill 0.6` inside console.
- **Public server**: add `+servername "Cortex DM!"` to the BAT command line.
- **24/7 hosting**: run the dedicated BAT on a spare PC or VPS; `quake.by/tutorials` is a good external reference.

Enjoy hosting multiplayer lobby matches where Cortex bots fill every slot—they start automatically, respond to server binds, and keep your friends honest!
