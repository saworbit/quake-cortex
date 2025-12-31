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

set EXTRA_ARGS=%*
if "%~1"=="" set EXTRA_ARGS=+set deathmatch 1 +map dm3

set PURE_FLAGS=+set cortex_pure_mode 1 +set cortex_bot_enable 1 +set cortex_spawn_bot 1

pushd "%~dp0\\..\\Game" >nul 2>&1
if errorlevel 1 (
    echo ERROR: Unable to cd to Game directory.
    exit /b 1
)

set GAMEEXE=fteqw64.exe
if not exist %GAMEEXE% (
    echo ERROR: %GAMEEXE% not found in Game directory.
    popd >nul 2>&1
    exit /b 1
)

set OUTDIR=%~dp0\\..\\Game\\cortex_pure
if not exist %OUTDIR% (
    echo ERROR: Pure mod not built yet. Run scripts\build_pure.bat first.
    popd >nul 2>&1
    exit /b 1
)

%GAMEEXE% -condebug -game cortex_pure ^
  +set developer 1 ^
  +set sv_progsaccess 2 ^
  +set sv_public 0 ^
  +set cl_master "" ^
  %PURE_FLAGS% ^
  %EXTRA_ARGS%
set EXITCODE=%ERRORLEVEL%
popd >nul 2>&1
exit /b %EXITCODE%
set EXITCODE=%ERRORLEVEL%
popd >nul 2>&1
exit /b %EXITCODE%

