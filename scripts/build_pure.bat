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
if not exist %FTEQC% (
    echo ERROR: fteqcc64.exe not found (needed for pure build).
    echo Place it under quakec\fteqcc64.exe
    popd >nul 2>&1
    exit /b 1
)

set OUTDIR=Game\cortex_pure
if not exist %OUTDIR% (
    mkdir %OUTDIR%
)

call "%FTEQC%" quakec\progs_pure.src
if errorlevel 1 (
    echo Build failed.
    popd >nul 2>&1
    exit /b 1
)

echo Build succeeded: %OUTDIR%\progs.dat
popd >nul 2>&1
exit /b 0
