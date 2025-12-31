@echo off
setlocal enabledelayedexpansion

echo ========================================
echo PROJECT CORTEX - Mode B (TCP) - Debug
echo ========================================
echo.
echo This will:
echo   1) Build QuakeC (progs.dat)
echo   2) Start the TCP Brain logger (server)
echo   3) Start Quake in TCP mode (client)
echo.
echo Notes:
echo - No pip install required for this debug logger.
echo - Quake connects to ws://127.0.0.1:26000/ by default (set CORTEX_STREAM_URI or pass "tcp" to run_quake_tcp.bat to override)
echo - Logs: Game\cortex\qconsole.log (some builds write Game\qconsole.log)
echo.

pushd "%~dp0\.." >nul 2>&1
if errorlevel 1 (
    echo ERROR: Unable to cd to repository root.
    exit /b 1
)

echo [1/3] Building QuakeC...
call scripts\build.bat
if errorlevel 1 (
    echo.
    echo ERROR: Build failed. Fix build errors, then re-run this script.
    popd >nul 2>&1
    exit /b 1
)

echo.
echo [2/3] Starting TCP Brain logger in a new window...
start "Cortex Brain TCP (Debug Logger)" cmd /k scripts\run_brain_tcp.bat

echo.
echo [3/3] Starting Quake (TCP mode) in a new window...
start "FTEQW (Cortex TCP Mode)" cmd /k scripts\run_quake_tcp.bat

echo.
echo Done. If Quake doesn't connect, wait a few seconds (it retries).
echo Close both windows to stop.
popd >nul 2>&1
exit /b 0
