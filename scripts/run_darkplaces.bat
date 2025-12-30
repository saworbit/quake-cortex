@echo off
setlocal
echo ========================================
echo PROJECT CORTEX - Launch DarkPlaces
echo ========================================
echo.
echo Optional (Phase 2 control via RCON):
echo   scripts\run_brain_rcon.bat
echo.
echo Launching DarkPlaces with Cortex mod...
echo.

pushd "%~dp0\\..\\Game" >nul 2>&1
if errorlevel 1 (
    echo ERROR: Unable to cd to repository Game directory.
    exit /b 1
)

if not exist darkplaces.exe (
    echo ERROR: darkplaces.exe not found in Game directory.
    echo Download DarkPlaces and place it at: Game\darkplaces.exe
    popd >nul 2>&1
    exit /b 1
)

darkplaces.exe -game cortex -listen 8 -port 26000 -console ^
  +exec cortex_darkplaces.cfg ^
  +set sv_public 0 ^
  +set cl_master "" ^
  +set developer 1 ^
  +set sv_cheats 1 ^
  +set deathmatch 1 ^
  +set rcon_password "cortex_secret" ^
  +map start

set EXITCODE=%ERRORLEVEL%
popd >nul 2>&1
exit /b %EXITCODE%
