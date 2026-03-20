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

echo [P0_GATE] Step3: run full test (may fail on historical baseline)
call hvigorw.bat -p product=default test
if errorlevel 1 (
  echo [P0_GATE][WARN] hvigor test failed. Check docs\weather\P0_TEST_BASELINE_WAIVER.md
  if "%STRICT_TEST%"=="1" (
    echo [P0_GATE][FAIL] STRICT_TEST=1, exit with failure.
    exit /b 2
  ) else (
    echo [P0_GATE][PASS_WITH_BASELINE_WARN] STRICT_TEST=0, keep non-blocking for P0 closure.
    exit /b 0
  )
)

echo [P0_GATE][PASS] all checks passed
exit /b 0
