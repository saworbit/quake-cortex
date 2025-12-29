@echo off
setlocal
echo ========================================
echo PROJECT CORTEX - Build Script
echo ========================================
echo.

pushd "%~dp0\..\\quakec" >nul 2>&1
if errorlevel 1 (
    echo ERROR: Unable to cd to repository quakec directory.
    exit /b 1
)

echo [1/2] Checking for FTEQW compiler...
if not exist fteqcc64.exe (
    echo ERROR: fteqcc64.exe not found in quakec directory
    echo.
    popd >nul 2>&1
    exit /b 1
)

echo [2/2] Compiling QuakeC code...
fteqcc64.exe
set BUILD_ERRORLEVEL=%ERRORLEVEL%
popd >nul 2>&1

if %BUILD_ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo BUILD SUCCESSFUL!
    echo ========================================
    echo.
    echo Output: Game\cortex\progs.dat
    echo.
    echo To run:
    echo 1. Start Python: scripts\run_brain.bat
    echo 2. Launch Quake: scripts\run_quake.bat
    echo.
    exit /b 0
) else (
    echo.
    echo ========================================
    echo BUILD FAILED!
    echo ========================================
    echo.
    echo Check the error messages above.
    exit /b %BUILD_ERRORLEVEL%
)
