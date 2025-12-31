@echo off
setlocal
echo ========================================
echo PROJECT CORTEX - Pure QuakeC Bot (DEBUG MODE)
echo ========================================
echo.
echo This runs the bot with FULL DEBUG LOGGING enabled:
echo   - cortex_debug = 1
echo   - developer = 1
echo   - cortex_log_level = 3 (maximum verbosity)
echo   - Console output logged to qconsole.log
echo.
echo After the game closes, check Game/cortex_pure/qconsole.log
echo.
echo You can override map/deathmatch by passing args, e.g.:
echo   scripts\run_pure_debug.bat +set deathmatch 1 +map dm1
echo.
echo ========================================
echo.

pushd "%~dp0\.." >nul 2>&1
if errorlevel 1 (
    echo ERROR: Unable to cd to repository root.
    exit /b 1
)

set LOG_DIR=Game\cortex_pure\logs
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
if exist "Game\cortex_pure\qconsole.log" (
    for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "(Get-Date).ToString('yyyyMMdd_HHmmss')"`) do set LOG_TS=%%I
    move /Y "Game\cortex_pure\qconsole.log" "%LOG_DIR%\\qconsole_%LOG_TS%.log" >nul
    powershell -NoProfile -Command "Get-ChildItem -Path '%LOG_DIR%' -Filter 'qconsole_*.log' | Sort-Object LastWriteTime -Descending | Select-Object -Skip 5 | Remove-Item -Force" >nul 2>&1
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
if "%~1"=="" set EXTRA_ARGS=+set deathmatch 1 +map dm1

set PURE_FLAGS=+set cortex_pure_mode 1 +set cortex_bot_enable 1 +set cortex_spawn_bot 1 +set pr_no_playerphysics 0
set DEBUG_FLAGS=+set cortex_debug 1 +set cortex_log_level 3 +set developer 1

echo [2/2] Launching pure Cortex client in DEBUG mode...
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

echo.
echo =======================================
echo DEBUG MODE ACTIVE - Logs at: Game/cortex_pure/qconsole.log
echo =======================================
echo.

%GAMEEXE% -condebug -game cortex_pure ^
  +set sv_public 0 ^
  +set cl_master "" ^
  %PURE_FLAGS% ^
  %DEBUG_FLAGS% ^
  %EXTRA_ARGS% ^
  +exec autoexec.cfg
set EXITCODE=%ERRORLEVEL%

echo.
echo =======================================
echo Game closed. Check logs at:
echo   Game/cortex_pure/qconsole.log
echo =======================================
echo.

if errorlevel 1 (
    echo ERROR: Quake exited with code %EXITCODE%
    pause
)
popd >nul 2>&1
exit /b %EXITCODE%
