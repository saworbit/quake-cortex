@echo off
setlocal
echo ========================================
echo PROJECT CORTEX - Launch Quake (TCP Stream)
echo ========================================
echo.
echo This mode streams telemetry over a local stream (tcp:// or ws:// depending on engine) and enables control input.
echo Make sure you understand `pr_enable_uriget` before using this.
echo If your build insists on TLS for tcp://, this script also disables cert verification for localhost.
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
if not exist id1\\PAK0.PAK (
    echo ERROR: Missing Quake data: Game\\id1\\PAK0.PAK
    echo See SETUP_GUIDE.md
    popd >nul 2>&1
    exit /b 1
)

fteqw64.exe -condebug -game cortex ^
  +set developer 1 ^
  +set pr_checkextension 1 ^
  +set pr_enable_uriget 1 ^
  +set tls_ignorecertificateerrors 1 ^
  +set cortex_tcp_uri tcp://127.0.0.1:26000 ^
  +set cortex_use_tcp 1 ^
  +set cortex_enable_controls 1 ^
  +set cortex_send_interval 0.05 ^
  +map start

set EXITCODE=%ERRORLEVEL%
popd >nul 2>&1
if not "%EXITCODE%"=="0" (
    echo.
    echo Quake exited with code %EXITCODE%.
    echo Check Game\\cortex\\qconsole.log (some builds write Game\\qconsole.log) for details.
    pause
)
exit /b %EXITCODE%
