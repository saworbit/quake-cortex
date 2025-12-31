@echo off
setlocal

pushd "%~dp0\.." >nul 2>&1
if errorlevel 1 (
    echo ERROR: Unable to cd to repository root.
    exit /b 1
)

echo ========================================
echo PROJECT CORTEX - Check Logs (Pure)
echo ========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='SilentlyContinue';" ^
  "$q1='Game\cortex_pure\qconsole.log'; $q2='Game\qconsole.log';" ^
  "$q=if(Test-Path $q1){$q1}elseif(Test-Path $q2){$q2}else{$null};" ^
  "$quakeLog=if($q){$q}else{'<missing>'};" ^
  "Write-Host ('Repo: ' + (Get-Location));" ^
  "Write-Host ('Quake log: ' + $quakeLog);" ^
  "Write-Host '';" ^
  "if($q){Write-Host '--- qconsole (tail 120) ---'; Get-Content $q -Tail 120; Write-Host ''};"

popd >nul 2>&1
exit /b 0
