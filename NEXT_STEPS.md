# Next Steps for Project Cortex

This document outlines concrete actions to take when resuming development, organized by priority and estimated difficulty.

**Last Updated**: December 29, 2025
**Current Objective**: Get Phase 1 telemetry pipeline working

---

## 🎯 Immediate Priority: Fix Telemetry Pipeline

### Step 1: Verify the Pipeline Works

**Goal**: Confirm that the system works when properly configured

**Actions**:
1. Start Python brain:
   ```bash
   scripts\run_brain.bat
   ```

2. Launch Quake:
   ```bash
   scripts\run_quake.bat
   ```

3. In Quake console (Shift+Esc), verify file access:
   - Type `sv_progsaccess` (should show `2`)
   - If not, set it: `sv_progsaccess 2`

4. Move around to generate telemetry (WASD bindings are provided by `Game/cortex/default.cfg`)

**Success Criteria**:
- Console shows: `CORTEX: Initializing AI Bridge...`
- Console shows: `CORTEX: Telemetry file opened!`
- Python shows: `[POS] X=... Y=... Z=...`
- Telemetry file exists at `Game/cortex/data/cortex_telemetry.txt`

**If This Works**: The code is correct, we just need to automate the setup
**If This Fails**: There's a deeper issue with the QuakeC code or file I/O

---

### Step 2: Debug File Access (If Manual Setup Fails)

**Goal**: Understand why fopen() isn't working

**Actions**:
1. Add more debug output to `cortex_bridge.qc`:
   ```c
   void() Cortex_Init =
   {
       dprint("DEBUG: Cortex_Init called\n");
       bprint("DEBUG: About to open file\n");

       cortex_socket = TCP_Connect("cortex_telemetry.txt");

       local string result;
       result = ftos(cortex_socket);
       bprint("DEBUG: File handle = ");
       bprint(result);
       bprint("\n");

       // ... rest of function
   }
   ```

2. Recompile: `cd quakec && ../Game/fteqcc64.exe`

3. Test again and check console output

**Look For**:
- Does `Cortex_Init` get called at all?
- What's the file handle value? (-1 = failed, >= 0 = success)
- Are there any FTEQW error messages?

---

### Step 3: Try Alternative Initialization Timing

**Goal**: Call Cortex_Init after config files have executed

**Note**: This approach is now implemented (Cortex initializes from StartFrame and retries file-open until sv_progsaccess is enabled).

**Approach A: Delay Init to StartFrame**

Edit `cortex_world.qc`:
```c
float cortex_initialized;  // Global flag

void() worldspawn =
{
    // ... all existing worldspawn code ...

    // DON'T call Cortex_Init here anymore
    // Cortex_Init();  <-- Remove this

    cortex_initialized = 0;  // Add this flag
};

void() StartFrame =
{
    // Call base StartFrame logic
    teamplay = cvar("teamplay");
    skill = cvar("skill");
    framecount = framecount + 1;

    // Initialize Cortex on first frame (after configs loaded)
    if (!cortex_initialized)
    {
        cortex_initialized = 1;
        Cortex_Init();
    }

    // Then run telemetry
    local entity old_self;
    old_self = self;
    self = find(world, classname, "player");
    if (self)
        Cortex_Think();
    self = old_self;
};
```

**Rationale**: StartFrame runs every frame during gameplay, AFTER config files have been executed. The flag ensures we only init once.

---

### Step 4: autoexec.cfg (Implemented)

`Game/cortex/autoexec.cfg` now exists and re-asserts `sv_progsaccess 2`. WASD/mouse bindings are provided by `Game/cortex/default.cfg`, so `exec default.cfg` is optional (only useful if user configs override binds).

---

### Step 5: Research FTEQW File Access Permissions

**Goal**: Find the official way to enable QuakeC file I/O

**Actions**:
1. Read FTEQW documentation on sv_progsaccess
2. Check FTEQW forums/wiki for QuakeC file access examples
3. Look at other FTEQW mods that use file I/O
4. Join FTEQW Discord/IRC and ask the developers

**Questions to Ask**:
- What's the proper way to set sv_progsaccess for a mod?
- Can it be set in a config file or does it require console?
- Are there alternatives to sv_progsaccess for file access?
- Is there a "mod manifest" file that can request permissions?

**Resources**:
- FTEQW Wiki: https://fte.triptohell.info/
- FTEQW Forums: https://forums.triptohell.info/
- QuakeOne Forums: https://www.quakeone.com/

---

## 🔬 Diagnostic Tools to Build

### Create Console Command for Testing

Add a manual trigger to test file I/O:

`cortex_bridge.qc`:
```c
void() CortexTest =
{
    bprint("=== CORTEX TEST START ===\n");

    local float test_file;
    test_file = fopen("cortex_test.txt", FILE_WRITE);

    if (test_file >= 0)
    {
        bprint("✓ File opened successfully!\n");
        fputs(test_file, "Test write from QuakeC\n");
        fclose(test_file);
        bprint("✓ File written and closed!\n");
    }
    else
    {
        bprint("✗ File open FAILED!\n");
        bprint("  Make sure sv_progsaccess is set to 2\n");
    }

    bprint("=== CORTEX TEST END ===\n");
};
```

Then in `defs.qc` or wherever console commands are registered, add:
```c
void() CortexTest;  // Forward declaration
```

And register it so you can type `cortex_test` in console to trigger it.

**Usage**: Type `cortex_test` in console to check if file I/O works

---

## 📦 Automation Improvements

### Create Startup Script

Once manual setup works, you can optionally create `Game/cortex/startup.cfg`:
```
// Cortex Startup Configuration
sv_progsaccess 2
map start
```

Then launch with:
```bash
fteqw64.exe -game cortex +exec startup.cfg
```

---

### Update Test Harness

Once you know what works, update `test_cortex_connection.py` to use the correct method:

```python
# If autoexec.cfg works:
self.quake_process = subprocess.Popen(
    [quake_exe, "-game", "cortex"],
    # autoexec.cfg runs automatically
)

# If +exec works:
self.quake_process = subprocess.Popen(
    [quake_exe, "-game", "cortex", "+exec", "startup.cfg"],
)

# If nothing works:
# Keep current manual instructions approach
```

---

## 🚀 Once Telemetry Works

### Phase 1 Completion Checklist

- [ ] Telemetry file is created automatically
- [ ] Python brain receives position data
- [ ] Coordinates update when player moves
- [ ] No manual console commands required
- [ ] Test harness works automatically
- [ ] Documentation updated with working procedure

### Then Move to Phase 2

See original roadmap:
1. **Phase 2A**: Python → Quake control inputs
2. **Phase 2B**: Implement movement policy neural network
3. **Phase 2C**: Training environment setup

---

## 🐛 Alternative Approaches (If All Else Fails)

### Approach 1: Use TCP Instead of Files

**Pros**:
- More standard communication method
- Better performance
- Easier to debug

**Cons**:
- Might hit same sv_progsaccess restrictions
- More complex QuakeC code

**Implementation**:
- Use FTEQW's builtin TCP functions
- See `fteextensions.qc` for available functions

---

### Approach 2: Use Quake Console Commands

**Idea**: Instead of file I/O, have QuakeC use `localcmd()` to write data

```c
void() SendTelemetry =
{
    local string cmd;
    cmd = "echo POS: ";
    cmd = strcat(cmd, ftos(self.origin_x), " ");
    cmd = strcat(cmd, ftos(self.origin_y), " ");
    cmd = strcat(cmd, ftos(self.origin_z), "\n");
    localcmd(cmd);
}
```

Then redirect Quake's console output to a file:
```bash
fteqw64.exe -game cortex > telemetry.log 2>&1
```

**Pros**:
- No file permissions needed
- Uses built-in Quake functionality

**Cons**:
- Console spam
- Harder to parse
- Performance concerns

---

### Approach 3: Use FTEQW Extensions/Plugins

**Idea**: FTEQW supports plugins written in C

**Implementation**:
- Write a C plugin that provides unrestricted file access
- QuakeC calls plugin functions instead of fopen()
- Plugin handles all file I/O

**Pros**:
- Full control
- No permission issues
- Best performance

**Cons**:
- Requires C programming
- More complex setup
- Platform-specific compilation

---

### Approach 4: Use Network Datagram (UDP)

**Idea**: UDP might be less restricted than TCP or files

```c
float(string dest) UDP_Connect;  // Check if FTEQW has this
```

**Rationale**: Some engines allow UDP without sv_progsaccess

---

## 📝 Documentation to Update (When Working)

1. **README.md**: Update status to "Phase 1 Complete ✓"
2. **SETUP_GUIDE.md**: Simplify if automation works
3. **KNOWN_ISSUES.md**: Move solved issues to "Resolved" section
4. **test_cortex_connection.py**: Remove manual instruction prints

---

## 💡 Long-term Improvements

### Code Quality
- Add error handling to all file operations
- Create logging system for debugging
- Add QuakeC unit tests (if possible)

### Features
- Visual telemetry debugger (overlay in-game)
- Configuration file for telemetry settings
- Support for multiple bots simultaneously

### Documentation
- Video tutorial of setup process
- Architecture diagrams
- API documentation for sensor data format

---

## 🎓 Learning Resources

If you need to learn more about the technologies:

**FTEQW QuakeC**:
- Official FTEQW docs: https://fte.triptohell.info/
- QuakeC tutorials: https://www.inside3d.com/qctut/
- FTE extensions reference: `quakec/lib/Quake-master/fteextensions.qc`

**Quake Engine Internals**:
- Quake source code: https://github.com/id-Software/Quake
- Quake engine book: https://fabiensanglard.net/quakeSource/

**Python AI/ML**:
- Reinforcement Learning: https://spinningup.openai.com/
- PPO algorithm: https://arxiv.org/abs/1707.06347
- PyTorch tutorials: https://pytorch.org/tutorials/

---

## 🤔 Decision Points

When you resume, you'll need to decide:

1. **How much time to spend on automation?**
   - Manual console setup works → Good enough for development
   - Full automation needed → Worth investing more time

2. **Stick with file I/O or switch to TCP?**
   - Files: Simpler, but permission issues
   - TCP: More complex, but standard

3. **Debug current approach or try alternatives?**
   - Debugging: Might find simple fix
   - Alternatives: Might avoid unsolvable issues

4. **Continue solo or seek help?**
   - Forums/Discord: FTEQW community might have instant answers
   - Documentation: Might contain the solution

---

**Good luck resuming development! 🚀**

**Remember**: The code compiles and the architecture is sound. It's just a configuration/permissions issue. Once solved, the rest should flow smoothly.
