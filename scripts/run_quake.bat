@echo off
setlocal
echo ========================================
echo PROJECT CORTEX - Launch Quake
echo ========================================
echo.
echo Make sure Python brain is running first!
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
fteqw64.exe -game cortex +set sv_progsaccess 2 +map start
set EXITCODE=%ERRORLEVEL%
popd >nul 2>&1
exit /b %EXITCODE%
