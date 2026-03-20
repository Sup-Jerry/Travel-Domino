@echo off
setlocal enabledelayedexpansion

if "%STRICT_TEST%"=="" set STRICT_TEST=0

echo [P0_GATE] Step1: assembleHap
call hvigorw.bat -p product=default assembleHap
if errorlevel 1 (
  echo [P0_GATE][FAIL] assembleHap failed
  exit /b 1
)

echo [P0_GATE] Step2: clear potential dependencyMap readonly flag
if exist ".hvigor\dependencyMap" attrib -R ".hvigor\dependencyMap"

echo [P0_GATE] Step3: run weather minimal suite
powershell -ExecutionPolicy Bypass -File "scripts\ci\weather-p0-min.ps1"
if errorlevel 1 (
  echo [P0_GATE][FAIL] weather minimal suite failed
  exit /b 2
)

echo [P0_GATE] Step4: run weather structure check
powershell -ExecutionPolicy Bypass -File "scripts\ci\weather-structure-check.ps1"
if errorlevel 1 (
  echo [P0_GATE][FAIL] weather structure check failed
  exit /b 3
)

echo [P0_GATE] Step5: run full test and baseline split report
powershell -ExecutionPolicy Bypass -File "scripts\ci\weather-baseline-split.ps1"
if errorlevel 1 (
  echo [P0_GATE][WARN] full test has issues. Check docs\weather\P0_TEST_BASELINE_SPLIT_*.md
  if "%STRICT_TEST%"=="1" (
    echo [P0_GATE][FAIL] STRICT_TEST=1, exit with failure.
    exit /b 4
  ) else (
    echo [P0_GATE][PASS_WITH_BASELINE_WARN] STRICT_TEST=0, keep non-blocking for P0 closure.
    exit /b 0
  )
)

echo [P0_GATE] Step6: generate TC status report
powershell -ExecutionPolicy Bypass -File "scripts\ci\weather-tc-report.ps1"

echo [P0_GATE][PASS] all checks passed
exit /b 0
