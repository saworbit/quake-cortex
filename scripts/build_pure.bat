@echo off
setlocal
echo ========================================
echo PROJECT CORTEX - Build Pure QuakeC Bot
echo ========================================
echo.
pushd "%~dp0\.." >nul 2>&1
if errorlevel 1 (
    echo ERROR: Unable to cd to repo root.
    exit /b 1
)

set FTEQC=quakec\fteqcc64.exe
if exist "%FTEQC%" goto :FTEQCC_FOUND
echo ERROR: fteqcc64.exe not found.
echo Place it under quakec\fteqcc64.exe
popd >nul 2>&1
exit /b 1
:FTEQCC_FOUND

set OUTDIR=Game\cortex
if exist "%OUTDIR%" goto :OUTDIR_READY
mkdir "%OUTDIR%"
:OUTDIR_READY

call "%FTEQC%" quakec\progs.src
if errorlevel 1 (
    echo Build failed.
    popd >nul 2>&1
    exit /b 1
)

echo Build succeeded: %OUTDIR%\progs.dat
popd >nul 2>&1
exit /b 0
