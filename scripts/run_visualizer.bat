@echo off
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
echo ========================================
echo.

cd ..
python python/cortex_visualizer.py
