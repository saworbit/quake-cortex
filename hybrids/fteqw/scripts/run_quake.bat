@echo off
setlocal
echo ========================================
echo PROJECT CORTEX - Launch Quake
echo ========================================
echo.
echo Modes:
echo - Pure QuakeC bot (no Python): pass +cortex_bot_enable 1
echo - Hybrid (Python brain): run scripts\run_brain.bat first (file IPC)
echo - Hybrid (TCP stream): use scripts\run_quake_tcp.bat instead
echo.
echo Launching FTEQW with Cortex mod...
echo.

pushd "%~dp0\\..\\Game" >nul 2>&1
if errorlevel 1 (
    echo ERROR: Unable to cd to repository Game directory.
    exit /b 1
)
if not exist fteqw64.exe (
    echo ERROR: fteqw64.exe not found in Game directory.
    echo See SETUP_GUIDE.md for where to place the engine binary.
    popd >nul 2>&1
    exit /b 1
)
set EXTRA_ARGS=%*
if "%~1"=="" set EXTRA_ARGS=+map start

fteqw64.exe -condebug -game cortex ^
  +set developer 1 ^
  +set sv_progsaccess 2 ^
  +set sv_public 0 ^
  +set cl_master "" ^
  %EXTRA_ARGS%
set EXITCODE=%ERRORLEVEL%
popd >nul 2>&1
exit /b %EXITCODE%
