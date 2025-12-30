@echo off
setlocal
echo ========================================
echo PROJECT CORTEX - Visualizer Mode
echo ========================================
echo.
echo Starting sensor visualizer...
echo Press Ctrl+C to stop
echo.
echo After this starts, launch Quake with:
echo   scripts\run_quake.bat
echo.
echo Note: visualizer tails the telemetry file (File IPC mode).
echo If pygame install fails (common on very new Python versions), run text mode:
echo   python cortex_visualizer.py --text
echo.
echo ========================================
echo.

pushd "%~dp0\.." >nul 2>&1
if errorlevel 1 (
    echo ERROR: Unable to cd to repository root.
    exit /b 1
)
python cortex_visualizer.py
set EXITCODE=%ERRORLEVEL%
popd >nul 2>&1
exit /b %EXITCODE%
