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

set PURE_FLAGS=+set cortex_pure_mode 1 +set cortex_bot_enable 1 +set cortex_spawn_bot 1 +set pr_no_playerphysics 0

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

set USER_CFG_FLAGS=
if exist "cortex_pure\\autoexec.cfg" (
    set USER_CFG_FLAGS=+exec autoexec.cfg
) else (
    echo NOTE: No cortex_pure\\autoexec.cfg found; using engine/global config.
    echo NOTE: Copy your autoexec.cfg into Game\\cortex_pure if movement keys are missing.
)

%GAMEEXE% -condebug -game cortex_pure ^
  +set developer 1 ^
  +set sv_public 0 ^
  +set cl_master "" ^
  %PURE_FLAGS% ^
  %EXTRA_ARGS% ^
  %USER_CFG_FLAGS%
set EXITCODE=%ERRORLEVEL%
if errorlevel 1 (
    echo ERROR: Quake exited with code %EXITCODE%
    pause
)
popd >nul 2>&1
exit /b %EXITCODE%
