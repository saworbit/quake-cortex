@echo off
setlocal
echo ========================================
echo PROJECT CORTEX - Reset Clean Folder
echo ========================================
echo.

for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "CLEAN=%ROOT%\Game\cortex_clean"

if not exist "%CLEAN%" (
    mkdir "%CLEAN%" >nul 2>&1
)

del /f /q "%CLEAN%\progs.dat" 2>nul
del /f /q "%CLEAN%\progs.lno" 2>nul
del /f /q "%CLEAN%\autoexec.cfg" 2>nul
del /f /q "%CLEAN%\default.cfg" 2>nul
del /f /q "%CLEAN%\fte.cfg" 2>nul
del /f /q "%CLEAN%\config.cfg" 2>nul
del /f /q "%CLEAN%\qconsole.log" 2>nul

echo Clean folder reset: %CLEAN%
echo Kept: PAK0.PAK / PAK1.PAK
