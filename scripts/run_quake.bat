@echo off
echo ========================================
echo PROJECT CORTEX - Launch Quake
echo ========================================
echo.
echo Make sure Python brain is running first!
echo.
echo Launching FTEQW with Cortex mod...
echo.

cd ..\Game
fteqw64.exe -game cortex +set sv_progsaccess 2 +map start
