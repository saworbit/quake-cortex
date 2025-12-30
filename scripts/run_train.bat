@echo off
setlocal
echo ========================================
echo PROJECT CORTEX - Train (Stable Baselines 3)
echo ========================================
echo.
echo 1) In one terminal:
echo    scripts\run_quake_tcp.bat
echo.
echo 2) In another terminal (this one):
echo    Starting training loop...
echo.

pushd "%~dp0\.." >nul 2>&1
if errorlevel 1 (
    echo ERROR: Unable to cd to repository root.
    exit /b 1
)

python train_cortex.py
set EXITCODE=%ERRORLEVEL%
popd >nul 2>&1
exit /b %EXITCODE%

