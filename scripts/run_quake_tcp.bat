@echo off
setlocal
echo ========================================
echo PROJECT CORTEX - Launch Quake (Stream Mode)
echo ========================================
echo.
echo This mode streams telemetry over a local stream (ws:// recommended, tcp:// fallback) and enables control input.
echo Make sure you understand `pr_enable_uriget` before using this.
echo If your build *incorrectly* negotiates TLS on tcp://, prefer ws:// or upgrade FTEQW.
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

set CORTEX_URI=ws://127.0.0.1:26000/
if /I "%1"=="tcp" set CORTEX_URI=tcp://127.0.0.1:26000
if not "%CORTEX_STREAM_URI%"=="" set CORTEX_URI=%CORTEX_STREAM_URI%

echo Using cortex stream URI: %CORTEX_URI%
echo.

fteqw64.exe -condebug -game cortex ^
  +set developer 1 ^
  +set pr_checkextension 1 ^
  +set pr_enable_uriget 1 ^
  +set net_enable_tls 0 ^
  +set net_enable_dtls 0 ^
  +set cortex_tcp_uri %CORTEX_URI% ^
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
