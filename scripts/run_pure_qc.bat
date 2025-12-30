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

call scripts\run_quake.bat +set cortex_bot_enable 1 %EXTRA_ARGS%
set EXITCODE=%ERRORLEVEL%
popd >nul 2>&1
exit /b %EXITCODE%

