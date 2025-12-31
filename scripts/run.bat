@echo off
setlocal enabledelayedexpansion

:: Symbols for better readability
set "CHECK=[OK]"
set "CROSS=[!!]"
set "ARROW=[>>]"

cls
echo ========================================
echo   PROJECT CORTEX - Pure QuakeC Bot
echo ========================================
echo.
echo Starting Cortex bot launcher...
echo.

:: Navigate to repository root
pushd "%~dp0\.." >nul 2>&1
if errorlevel 1 (
    echo %CROSS% ERROR: Unable to navigate to repository root.
    echo %ARROW% Make sure this script is in the scripts/ directory.
    pause
    exit /b 1
)

echo.
echo ====== PRE-FLIGHT CHECKS ======
echo.

:: Check 1: Verify QuakeC compiler exists
echo [1/5] Checking for QuakeC compiler...
if exist "quakec\fteqcc64.exe" (
    echo %CHECK% Found: quakec\fteqcc64.exe
) else (
    echo %CROSS% ERROR: QuakeC compiler not found!
    echo %ARROW% Expected location: quakec\fteqcc64.exe
    echo %ARROW% Download from: https://fte.triptohell.info/
    pause
    popd >nul 2>&1
    exit /b 1
)

:: Check 2: Verify source files exist
echo [2/5] Checking for source files...
if exist "quakec\progs.src" (
    echo %CHECK% Found: quakec\progs.src
) else (
    echo %CROSS% ERROR: Build manifest not found!
    echo %ARROW% Missing: quakec\progs.src
    pause
    popd >nul 2>&1
    exit /b 1
)

:: Check 3: Verify Quake engine exists
echo [3/5] Checking for Quake engine...
if exist "Game\fteqw64.exe" (
    echo %CHECK% Found: Game\fteqw64.exe
) else (
    echo %CROSS% WARNING: Quake engine not found!
    echo %ARROW% Expected location: Game\fteqw64.exe
    echo %ARROW% Download from: https://fte.triptohell.info/
    echo.
    echo Do you want to continue anyway? (Y/N)
    choice /C YN /N /M "Press Y to continue, N to abort: "
    if errorlevel 2 (
        popd >nul 2>&1
        exit /b 1
    )
)

:: Check 4: Verify Quake data files
echo [4/5] Checking for Quake data files...
if exist "Game\id1\pak0.pak" (
    echo %CHECK% Found: Game\id1\pak0.pak
) else (
    echo %CROSS% WARNING: Quake data files not found!
    echo %ARROW% Expected location: Game\id1\pak0.pak
    echo %ARROW% You need the original Quake game data
    echo %ARROW% Get it from Steam, GOG, or use shareware version
    echo.
    echo Do you want to continue anyway? (Y/N)
    choice /C YN /N /M "Press Y to continue, N to abort: "
    if errorlevel 2 (
        popd >nul 2>&1
        exit /b 1
    )
)

:: Check 5: Create output directory if needed
echo [5/5] Checking output directory...
if not exist "Game\cortex" (
    echo %ARROW% Creating: Game\cortex\
    mkdir "Game\cortex" 2>nul
)
echo %CHECK% Output directory ready

echo.
echo ====== BUILDING ======
echo.

:: Build the mod
echo Building Cortex mod...
call scripts\build.bat
if errorlevel 1 (
    echo.
    echo %CROSS% BUILD FAILED!
    echo %ARROW% Check the error messages above for details
    echo %ARROW% Common issues:
    echo    - Syntax errors in .qc files
    echo    - Missing include files
    echo    - Compiler version mismatch
    echo.
    pause
    popd >nul 2>&1
    exit /b 1
)

echo %CHECK% Build successful!

:: Verify output file was created
if exist "Game\cortex\progs.dat" (
    echo %CHECK% Generated: Game\cortex\progs.dat
) else (
    echo %CROSS% ERROR: Build succeeded but progs.dat not found!
    pause
    popd >nul 2>&1
    exit /b 1
)

echo.
echo ====== LAUNCHING ======
echo.

:: Parse command line arguments
set EXTRA_ARGS=%*
if "%~1"=="" (
    echo %ARROW% Using default settings: Deathmatch on map dm3
    set EXTRA_ARGS=+set deathmatch 1 +map dm3
) else (
    echo %ARROW% Using custom arguments: %*
)

:: Set Cortex-specific flags
set PURE_FLAGS=+set cortex_pure_mode 1 +set cortex_bot_enable 1 +set cortex_spawn_bot 1 +set cortex_debug 0 +set cortex_log_level 1

echo %ARROW% Launching FTEQW with Cortex bot...
echo.
echo ====== QUICK START GUIDE ======
echo   Press ~ to open console
echo   Type: impulse 200  (spawn a bot)
echo   Type: impulse 205  (show help)
echo ===============================
echo.

pushd "%~dp0\..\Game" >nul 2>&1
if errorlevel 1 (
    echo %CROSS% ERROR: Unable to navigate to Game directory
    popd >nul 2>&1
    pause
    exit /b 1
)

:: Launch the game
fteqw64.exe -condebug -game cortex ^
  +set developer 1 ^
  +set sv_progsaccess 2 ^
  +set sv_public 0 ^
  +set cl_master "" ^
  %PURE_FLAGS% ^
  %EXTRA_ARGS%

set EXITCODE=%ERRORLEVEL%

:: Check exit status
echo.
echo ====== SHUTDOWN ======
if %EXITCODE% EQU 0 (
    echo %CHECK% Quake exited normally
) else (
    echo %CROSS% Quake exited with code: %EXITCODE%
    echo %ARROW% Console log saved to: Game\cortex\qconsole.log
    echo %ARROW% Check the log file for error details
    pause
)

popd >nul 2>&1
popd >nul 2>&1
exit /b %EXITCODE%
