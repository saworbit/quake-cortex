@echo off
echo ========================================
echo PROJECT CORTEX - Build Script
echo ========================================
echo.

cd ..\quakec

echo [1/2] Checking for FTEQW compiler...
if not exist fteqcc64.exe (
    echo ERROR: fteqcc64.exe not found in quakec directory
    echo.
    pause
    exit /b 1
)

echo [2/2] Compiling QuakeC code...
fteqcc64.exe

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo BUILD SUCCESSFUL!
    echo ========================================
    echo.
    echo Output: Game\cortex\progs.dat
    echo.
    echo To run:
    echo 1. Start Python: python python\cortex_brain.py
    echo 2. Launch Quake: cd Game ^&^& fteqw64.exe -game cortex +map dm4
    echo.
) else (
    echo.
    echo ========================================
    echo BUILD FAILED!
    echo ========================================
    echo.
    echo Check the error messages above.
)

cd ..\scripts
pause
