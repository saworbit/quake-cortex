@echo off
setlocal
echo ========================================
echo PROJECT CORTEX - Clean Install Test
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

mkdir "%ROOT%\Game\cortex_clean" >nul 2>&1
copy /Y "%ROOT%\Game\id1\PAK0.PAK" "%ROOT%\Game\cortex_clean\PAK0.PAK" >nul
if exist "%ROOT%\Game\id1\PAK1.PAK" (
    copy /Y "%ROOT%\Game\id1\PAK1.PAK" "%ROOT%\Game\cortex_clean\PAK1.PAK" >nul
)

set EXTRA_ARGS=%*
if "%~1"=="" set EXTRA_ARGS=+map start

echo.
echo Launching clean test: Game\cortex_clean
echo Extra args: %EXTRA_ARGS%
echo.

pushd "%ROOT%\Game" >nul 2>&1
fteqw64.exe -condebug -game cortex_clean %EXTRA_ARGS%
set EXITCODE=%ERRORLEVEL%
popd >nul 2>&1
popd >nul 2>&1
exit /b %EXITCODE%
