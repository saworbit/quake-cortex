@echo off
setlocal
echo ========================================
echo PROJECT CORTEX - DM Follow Bot (RCON)
echo ========================================
echo.
echo Prereqs:
echo - DarkPlaces running via: scripts\run_darkplaces.bat
echo - Matching rcon_password (default: cortex_secret)
echo.
echo Starting follow bot...
echo Press Ctrl+C to stop
echo.
echo ========================================
echo.

pushd "%~dp0\.." >nul 2>&1
if errorlevel 1 (
    echo ERROR: Unable to cd to DarkPlaces hybrid directory.
    exit /b 1
)

python python\bots\dm_follow_bot.py %*
set EXITCODE=%ERRORLEVEL%
popd >nul 2>&1
exit /b %EXITCODE%
