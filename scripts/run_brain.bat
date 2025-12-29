@echo off
setlocal
echo ========================================
echo PROJECT CORTEX - Brain Server
echo ========================================
echo.
echo Starting Python brain server...
echo Press Ctrl+C to stop
echo.
echo After this starts, launch Quake with:
echo   scripts\run_quake.bat
echo.
echo ========================================
echo.

pushd "%~dp0\.." >nul 2>&1
if errorlevel 1 (
    echo ERROR: Unable to cd to repository root.
    exit /b 1
)
python cortex_brain.py
set EXITCODE=%ERRORLEVEL%
popd >nul 2>&1
exit /b %EXITCODE%
