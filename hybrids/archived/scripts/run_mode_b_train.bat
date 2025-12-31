@echo off
setlocal enabledelayedexpansion

echo ========================================
echo PROJECT CORTEX - Mode B (TCP) - Training
echo ========================================
echo.
echo This will:
echo   1) Build QuakeC (progs.dat)
echo   2) Create a venv (.venv_tcp) using Python 3.11 (recommended)
echo   3) Install Python deps (SB3/Gymnasium) into that venv
echo   4) Start Quake (TCP mode) in a new window
echo   5) Run training (TCP server) in THIS window
echo.
echo If you are on a very new Python and installs fail: use the venv this script creates.
echo.

pushd "%~dp0\.." >nul 2>&1
if errorlevel 1 (
    echo ERROR: Unable to cd to repository root.
    exit /b 1
)

echo [1/5] Building QuakeC...
call scripts\build.bat
if errorlevel 1 (
    echo.
    echo ERROR: Build failed. Fix build errors, then re-run this script.
    popd >nul 2>&1
    exit /b 1
)

set VENV_DIR=.venv_tcp
set PY_LAUNCHER=py -3.11

echo.
echo [2/5] Creating venv: %VENV_DIR%
%PY_LAUNCHER% -V >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python launcher for 3.11 not found.
    echo Install Python 3.11 (recommended) and ensure the Windows "py" launcher is available.
    echo Then re-run: scripts\run_mode_b_train.bat
    popd >nul 2>&1
    exit /b 1
)

if not exist "%VENV_DIR%\\Scripts\\python.exe" (
    %PY_LAUNCHER% -m venv "%VENV_DIR%"
    if errorlevel 1 (
        echo ERROR: Failed to create venv.
        popd >nul 2>&1
        exit /b 1
    )
)

echo.
echo [3/5] Installing Python deps into venv (this can take a while)...
"%VENV_DIR%\\Scripts\\python.exe" -m pip install --upgrade pip
if errorlevel 1 (
    echo ERROR: pip upgrade failed.
    popd >nul 2>&1
    exit /b 1
)
"%VENV_DIR%\\Scripts\\python.exe" -m pip install -r python\\requirements.txt
if errorlevel 1 (
    echo.
    echo ERROR: Dependency install failed.
    echo Common fixes:
    echo - Use Python 3.12 x64 (this script requires it)
    echo - Update pip: "%VENV_DIR%\\Scripts\\python.exe" -m pip install -U pip
    echo - Ensure you have enough disk space and network access
    popd >nul 2>&1
    exit /b 1
)

echo.
echo [4/5] Starting Quake (TCP mode) in a new window...
start "FTEQW (Cortex TCP Mode)" cmd /k scripts\run_quake_tcp.bat

echo.
echo [5/5] Starting training (Quake will connect to 127.0.0.1:26000)...
echo Close this window to stop training.
echo.

"%VENV_DIR%\\Scripts\\python.exe" train_cortex.py
set EXITCODE=%ERRORLEVEL%

popd >nul 2>&1
exit /b %EXITCODE%
