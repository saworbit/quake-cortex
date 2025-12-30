@echo off
setlocal

pushd "%~dp0\.." >nul 2>&1
if errorlevel 1 (
    echo ERROR: Unable to cd to repository root.
    exit /b 1
)

echo ========================================
echo PROJECT CORTEX - Check Logs
echo ========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='SilentlyContinue';" ^
  "$q1='Game\\cortex\\qconsole.log'; $q2='Game\\qconsole.log';" ^
  "$q=if(Test-Path $q1){$q1}elseif(Test-Path $q2){$q2}else{$null};" ^
  "$brain=(Get-ChildItem '.cortex\\logs\\cortex_brain_*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1);" ^
  "$tcp=(Get-ChildItem '.cortex\\logs\\cortex_brain_tcp_*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1);" ^
  "$quakeLog=if($q){$q}else{'<missing>'};" ^
  "$brainLog=if($brain){$brain.FullName}else{'<missing>'};" ^
  "$tcpLog=if($tcp){$tcp.FullName}else{'<missing>'};" ^
  "Write-Host ('Repo: ' + (Get-Location));" ^
  "Write-Host ('Quake log: ' + $quakeLog);" ^
  "Write-Host ('Brain log: ' + $brainLog);" ^
  "Write-Host ('Brain TCP log: ' + $tcpLog);" ^
  "Write-Host '';" ^
  "if($q){Write-Host '--- qconsole (tail 80) ---'; Get-Content $q -Tail 80; Write-Host ''};" ^
  "if($tcp){Write-Host '--- cortex_brain_tcp (tail 80) ---'; Get-Content $tcp.FullName -Tail 80; Write-Host ''};" ^
  "if($brain){Write-Host '--- cortex_brain (tail 40) ---'; Get-Content $brain.FullName -Tail 40; Write-Host ''};" ^
  "Write-Host 'Hints:';" ^
  "Write-Host '- If Brain shows TLSV1_ALERT_UNKNOWN_CA: your engine is doing TLS on tcp://. Prefer ws:// (default in scripts\\run_quake_tcp.bat).';" ^
  "Write-Host '- If Quake log shows qcfopen(\"ws://...\"): Access denied: the build blocks URI streams (ensure pr_enable_uriget 1, or upgrade FTEQW).';"

popd >nul 2>&1
exit /b 0
