@echo off
setlocal
echo ========================================
echo PROJECT CORTEX - Launch Quake (TCP Stream)
echo ========================================
echo.
echo This mode streams telemetry over tcp:// and enables control input.
echo Make sure you understand `pr_enable_uriget` before using this.
echo.
echo If you just want file telemetry, use:
echo   scripts\run_quake.bat
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

fteqw64.exe -game cortex ^
  +set pr_enable_uriget 1 ^
  +set cortex_use_tcp 1 ^
  +set cortex_enable_controls 1 ^
  +set cortex_send_interval 0.05 ^
  +map start

set EXITCODE=%ERRORLEVEL%
popd >nul 2>&1
exit /b %EXITCODE%

