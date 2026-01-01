# Clean Install Changelog

Purpose: isolate movement and bot issues by starting from a clean mod folder and
adding files one at a time.

## Environment
- Date:
- Engine build:
- Repo version:
- Notes:

## Log format (fill as you go)
Step | Action | Expected | Result | Notes | Artifacts
--- | --- | --- | --- | --- | ---
0 | Reset clean folder + run step 0 | Movement works | Movement works | Reset removed old progs/configs | Game\cortex_clean\qconsole.log
1 | Run step 1 (progs.dat only, bots/QC physics off) | Movement works | Movement works after manual new game | Menu appeared; manual map start | Game\cortex_clean\qconsole.log
2 | Run step 2 (QC physics ON, bots OFF) | Movement works | Failed: no movement | Dropped to menu; manual new game | Game\cortex_clean\qconsole.log
2a | Patch SV_PlayerPhysics (do not override player input globals) | Movement works | Pending retest | Update in quakec/cortex/bot/cortex_bot.qc | -

## Steps
1) Create a clean mod folder
   - Command: `scripts\run_clean_setup.bat` (recommended; creates folder + copies PAKs + launches)
   - Manual: `New-Item -ItemType Directory -Path Game\cortex_clean -Force`
   - Result:
   - Artifacts:

2) Copy base PAKs
   - Command: `Copy-Item Game\id1\PAK0.PAK Game\cortex_clean\`
   - Command: `Copy-Item Game\id1\PAK1.PAK Game\cortex_clean\`
   - Result:
   - Artifacts:

3) Launch vanilla Quake from the clean folder
   - Before step 0: `scripts\reset_clean_folder.bat` (removes progs/configs/logs from prior tests)
   - Command: `scripts\run_clean_step.bat 0` (recommended)
   - Manual (run from `Game\`): `.\fteqw64.exe -condebug -game cortex_clean +map start`
   - Check movement (arrow keys by default). If needed, run: `exec default.cfg`
   - Result:
   - Artifacts: `Game\cortex_clean\qconsole.log`

4) Add Cortex gamecode only (no bots, QC physics off)
   - Command: `scripts\run_clean_step.bat 1`
   - Expected: player movement still works
   - Result:
   - Artifacts: `Game\cortex_clean\qconsole.log`

5) Enable QC player physics (no bots)
   - Command: `scripts\run_clean_step.bat 2`
   - Expected: player movement still works
   - Result:
   - Artifacts: `Game\cortex_clean\qconsole.log`

6) Enable bots (no spawn)
   - Command: `scripts\run_clean_step.bat 3`
   - Expected: player movement still works
   - Result:
   - Artifacts: `Game\cortex_clean\qconsole.log`

7) Spawn a bot
   - Command: `scripts\run_clean_step.bat 4`
   - Expected: player + bot move
   - Result:
   - Artifacts: `Game\cortex_clean\qconsole.log`

8) Add binds (autoexec)
   - Command: `scripts\run_clean_step.bat 5`
   - Expected: WASD works
   - Result:
   - Artifacts: `Game\cortex_clean\qconsole.log`

9) Add config files one at a time (if needed)
   - Manual: Add `default.cfg` from `Game\cortex_pure` and retest
   - Add `fte.cfg` from `Game\cortex_pure` and retest
   - If movement breaks, remove the last file and record it here

10) (Optional) Reset to a clean config between runs
   - Delete `Game\cortex_clean\config.cfg` before relaunching
   - Result:
   - Artifacts:
