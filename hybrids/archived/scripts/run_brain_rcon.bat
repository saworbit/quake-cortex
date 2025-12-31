@echo off
setlocal
echo ========================================
echo PROJECT CORTEX - Brain (RCON / DarkPlaces)
echo ========================================
echo.
echo Prereqs:
echo - DarkPlaces running via: scripts\run_darkplaces.bat
echo - Matching rcon_password (default: cortex_secret)
echo.
echo Starting RCON brain loop...
echo Press Ctrl+C to stop
echo.
echo ========================================
echo.

pushd "%~dp0\.." >nul 2>&1
if errorlevel 1 (
    echo ERROR: Unable to cd to repository root.
    exit /b 1
)

python cortex_rcon.py
set EXITCODE=%ERRORLEVEL%
popd >nul 2>&1
exit /b %EXITCODE%

