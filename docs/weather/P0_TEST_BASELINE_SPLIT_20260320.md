# Weather P0 Full Test Split Report

- Time: 2026-03-20 12:36:08
- Command: `./hvigorw.bat -p product=default test`
- ProcessExitCode: 0
- RawLog: `.tmp/weather-full-test.log`

## 1. New Failures (Candidate)
- None

## 2. Historical Baseline
| File | Code | Reason | Detail |
| --- | --- | --- | --- |
| entry/src/test/TimeConstraintSolver.test.ets | TEST_ASSERTION_FAIL | HISTORICAL_ASSERTION | solver_should_cross_day_on_23xx_to_00xx_boundary |

## 3. Conclusion
- No new failures introduced in this round.
