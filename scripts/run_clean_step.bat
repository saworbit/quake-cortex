@echo off
setlocal
echo ========================================
echo PROJECT CORTEX - Clean Step Runner
echo ========================================
echo.
echo Steps:
echo   0 = Clean vanilla (PAKs only)
echo   1 = Add progs.dat, bots OFF, QC physics OFF
echo   2 = Add progs.dat, bots OFF, QC physics ON
echo   3 = Add progs.dat, bots ON (no spawn)
echo   4 = Add progs.dat, bots ON + spawn bot
echo   5 = Step 4 + autoexec binds
echo.

set "STEP=%~1"
if "%STEP%"=="" set STEP=0
if "%STEP%"=="help" goto :usage

shift
set "EXTRA_ARGS=%*"

for %%I in ("%~dp0..") do set "ROOT=%%~fI"
pushd "%ROOT%" >nul 2>&1
if errorlevel 1 (
    echo ERROR: Unable to cd to repository root.
    exit /b 1
)

if not exist "%ROOT%\Game\id1\PAK0.PAK" (
    echo ERROR: Missing Game\id1\PAK0.PAK
    popd >nul 2>&1
    exit /b 1
)

if not exist "%ROOT%\Game\fteqw64.exe" (
    echo ERROR: Missing Game\fteqw64.exe
    popd >nul 2>&1
    exit /b 1
)

mkdir "%ROOT%\Game\cortex_clean" >nul 2>&1
copy /Y "%ROOT%\Game\id1\PAK0.PAK" "%ROOT%\Game\cortex_clean\PAK0.PAK" >nul
if exist "%ROOT%\Game\id1\PAK1.PAK" (
    copy /Y "%ROOT%\Game\id1\PAK1.PAK" "%ROOT%\Game\cortex_clean\PAK1.PAK" >nul
)

set "COPY_PROGS=0"
set "COPY_AUTOEXEC=0"
set "RUN_FLAGS="
set "DEFAULT_ARGS=+map start"

if "%STEP%"=="0" (
    set COPY_PROGS=0
)
if "%STEP%"=="1" (
    set COPY_PROGS=1
    set RUN_FLAGS=+set cortex_bot_cvars_initialized 1 +set cortex_bot_enable 0 +set cortex_spawn_bot 0 +set pr_no_playerphysics 1
)
if "%STEP%"=="2" (
    set COPY_PROGS=1
    set RUN_FLAGS=+set cortex_bot_cvars_initialized 1 +set cortex_bot_enable 0 +set cortex_spawn_bot 0 +set pr_no_playerphysics 0
)
if "%STEP%"=="3" (
    set COPY_PROGS=1
    set RUN_FLAGS=+set cortex_pure_mode 1 +set cortex_bot_enable 1 +set cortex_spawn_bot 0 +set pr_no_playerphysics 0
    set DEFAULT_ARGS=+set deathmatch 1 +map dm3
)
if "%STEP%"=="4" (
    set COPY_PROGS=1
    set RUN_FLAGS=+set cortex_pure_mode 1 +set cortex_bot_enable 1 +set cortex_spawn_bot 1 +set pr_no_playerphysics 0
    set DEFAULT_ARGS=+set deathmatch 1 +map dm3
)
if "%STEP%"=="5" (
    set COPY_PROGS=1
    set COPY_AUTOEXEC=1
    set RUN_FLAGS=+set cortex_pure_mode 1 +set cortex_bot_enable 1 +set cortex_spawn_bot 1 +set pr_no_playerphysics 0 +exec autoexec.cfg
    set DEFAULT_ARGS=+set deathmatch 1 +map dm3
)

if "%COPY_PROGS%"=="1" (
    if not exist "%ROOT%\Game\cortex_pure\progs.dat" (
        echo ERROR: Missing Game\cortex_pure\progs.dat ^(build the mod first^).
        popd >nul 2>&1
        exit /b 1
    )
    copy /Y "%ROOT%\Game\cortex_pure\progs.dat" "%ROOT%\Game\cortex_clean\progs.dat" >nul
    if exist "%ROOT%\Game\cortex_pure\progs.lno" (
        copy /Y "%ROOT%\Game\cortex_pure\progs.lno" "%ROOT%\Game\cortex_clean\progs.lno" >nul
    )
)

if "%COPY_AUTOEXEC%"=="1" (
    if not exist "%ROOT%\docs\autoexec.example.cfg" (
        echo ERROR: Missing docs\autoexec.example.cfg
        popd >nul 2>&1
        exit /b 1
    )
    copy /Y "%ROOT%\docs\autoexec.example.cfg" "%ROOT%\Game\cortex_clean\autoexec.cfg" >nul
)

if "%EXTRA_ARGS%"=="" set EXTRA_ARGS=%DEFAULT_ARGS%

echo.
echo Step: %STEP%
echo Launching: Game\cortex_clean
echo Flags: %RUN_FLAGS%
echo Args: %EXTRA_ARGS%
echo.

pushd "%ROOT%\Game" >nul 2>&1
fteqw64.exe -condebug -game cortex_clean ^
  +set developer 1 ^
  +set sv_public 0 ^
  +set cl_master "" ^
  %RUN_FLAGS% ^
  %EXTRA_ARGS%
set EXITCODE=%ERRORLEVEL%
popd >nul 2>&1
popd >nul 2>&1
exit /b %EXITCODE%

:usage
echo Usage: scripts\\run_clean_step.bat [step] [extra args...]
echo Example: scripts\\run_clean_step.bat 2 +map start
popd >nul 2>&1
exit /b 1
