@echo off
setlocal
echo ========================================
echo PROJECT CORTEX - Clean Cortex Test
echo ========================================
echo.

for %%I in ("%~dp0..") do set "ROOT=%%~fI"
pushd "%ROOT%" >nul 2>&1
if errorlevel 1 (
    echo ERROR: Unable to cd to repository root.
    exit /b 1
)

if not exist "%ROOT%\Game\id1\PAK0.PAK" (
    echo ERROR: Missing Game\id1\PAK0.PAK
    popd >nul 2>&1
    exit /b 1
)

if not exist "%ROOT%\Game\fteqw64.exe" (
    echo ERROR: Missing Game\fteqw64.exe
    popd >nul 2>&1
    exit /b 1
)

if not exist "%ROOT%\Game\cortex_pure\progs.dat" (
    echo ERROR: Missing Game\cortex_pure\progs.dat ^(build the mod first^).
    popd >nul 2>&1
    exit /b 1
)

mkdir "%ROOT%\Game\cortex_clean" >nul 2>&1
copy /Y "%ROOT%\Game\id1\PAK0.PAK" "%ROOT%\Game\cortex_clean\PAK0.PAK" >nul
if exist "%ROOT%\Game\id1\PAK1.PAK" (
    copy /Y "%ROOT%\Game\id1\PAK1.PAK" "%ROOT%\Game\cortex_clean\PAK1.PAK" >nul
)

copy /Y "%ROOT%\Game\cortex_pure\progs.dat" "%ROOT%\Game\cortex_clean\progs.dat" >nul
if exist "%ROOT%\Game\cortex_pure\progs.lno" (
    copy /Y "%ROOT%\Game\cortex_pure\progs.lno" "%ROOT%\Game\cortex_clean\progs.lno" >nul
)

set EXTRA_ARGS=%*
if "%~1"=="" set EXTRA_ARGS=+set deathmatch 1 +map dm3

set PURE_FLAGS=+set cortex_pure_mode 1 +set cortex_bot_enable 1 +set cortex_spawn_bot 1 +set pr_no_playerphysics 0

echo.
echo Launching clean Cortex test: Game\cortex_clean
echo Extra args: %EXTRA_ARGS%
echo.

pushd "%ROOT%\Game" >nul 2>&1
fteqw64.exe -condebug -game cortex_clean ^
  +set developer 1 ^
  +set sv_public 0 ^
  +set cl_master "" ^
  %PURE_FLAGS% ^
  %EXTRA_ARGS%
set EXITCODE=%ERRORLEVEL%
popd >nul 2>&1
popd >nul 2>&1
exit /b %EXITCODE%
