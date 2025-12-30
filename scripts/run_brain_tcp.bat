@echo off
setlocal
echo ========================================
echo PROJECT CORTEX - Brain Server (TCP Stream)
echo ========================================
echo.
echo This starts a TCP server on 127.0.0.1:26000 for QuakeC to connect to via:
echo   tcp://127.0.0.1:26000
echo.
echo In another terminal, launch Quake with:
echo   scripts\run_quake_tcp.bat
echo.
echo Or use the idiot-proof launcher (starts both windows):
echo   scripts\run_mode_b_debug.bat
echo.
echo Note: this is a debug logger. For RL training, run:
echo   python train_cortex.py
echo.
echo ========================================
echo.

pushd "%~dp0\.." >nul 2>&1
if errorlevel 1 (
    echo ERROR: Unable to cd to repository root.
    exit /b 1
)
python python\cortex_brain.py
set EXITCODE=%ERRORLEVEL%
popd >nul 2>&1
exit /b %EXITCODE%
