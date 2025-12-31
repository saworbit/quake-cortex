@echo off
setlocal
echo ========================================
echo PROJECT CORTEX - Pure QuakeC Bot
echo ========================================
echo.
echo This runs the internal QuakeC bot (no Python).
echo.
echo You can override map/deathmatch by passing args, e.g.:
echo   scripts\run_pure_qc.bat +set deathmatch 1 +map dm3
echo.
echo ========================================
echo.

pushd "%~dp0\.." >nul 2>&1
if errorlevel 1 (
    echo ERROR: Unable to cd to repository root.
    exit /b 1
)

echo [1/2] Building pure Cortex mod...
call scripts\build_pure.bat
if errorlevel 1 (
    echo ERROR: Pure build failed.
    pause
    popd >nul 2>&1
    exit /b 1
)

set EXTRA_ARGS=%*
if "%~1"=="" set EXTRA_ARGS=+set deathmatch 1 +map dm3

set PURE_FLAGS=+set cortex_pure_mode 1 +set cortex_bot_enable 1 +set cortex_spawn_bot 1 +set pr_no_playerphysics 0 +exec autoexec.cfg
set BIND_FLAGS=+bind w +forward +bind a +moveleft +bind s +back +bind d +moveright +bind SPACE +jump +bind SHIFT +speed +bind CTRL +attack +bind MOUSE1 +attack +bind MOUSE2 +mlook +set cl_forwardspeed 400 +set cl_backspeed 400 +set cl_sidespeed 400 +set cl_upspeed 200

echo [2/2] Launching pure Cortex client...
pushd "%~dp0\\..\\Game" >nul 2>&1
if errorlevel 1 (
    echo ERROR: Unable to cd to Game directory.
    popd >nul 2>&1
    exit /b 1
)

set GAMEEXE=fteqw64.exe
if not exist %GAMEEXE% (
    echo ERROR: fteqw64.exe not found in Game directory. This launcher is pure QuakeC only.
    popd >nul 2>&1
    pause
    exit /b 1
)

%GAMEEXE% -condebug -game cortex_pure ^
  +set developer 1 ^
  +set sv_progsaccess 2 ^
  +set sv_public 0 ^
  +set cl_master "" ^
  %PURE_FLAGS% ^
  %BIND_FLAGS% ^
  %EXTRA_ARGS%
set EXITCODE=%ERRORLEVEL%
if errorlevel 1 (
    echo ERROR: Quake exited with code %EXITCODE%
    pause
)
popd >nul 2>&1
exit /b %EXITCODE%
