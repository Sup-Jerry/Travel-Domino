# Project Scoring Log

This file is append-only.
Do not edit or rewrite previous records unless explicitly requested by the user.
Each scoring run must append one new section with a timestamp.

---

## 2026-04-02T22:46:04+08:00

- Project: Travel Domino (`E:/Travel`)
- Score: 72/100
- Grade: 70-79 (Usable with high risk)
- Level used at runtime: H3
- Confidence: Medium
- Hard-cap triggered: No

Top deductions:
1. Oversized core files (God Object tendency) in timeline/page modules.
2. Backend lint gate failed (`ESLint v9` config missing).
3. CI workflow scope is narrow (security gate only).
4. Backend README endpoint claims exceed implemented controller surface.
5. Open TODO technical debt in QR/image service paths.

Evidence commands executed:
- `npm test -- --runInBand` (workdir: `backend`) -> passed (2 suites, 6 tests)
- `powershell -ExecutionPolicy Bypass -File scripts/ci/secret-scan.ps1` -> passed
- `npm run lint` (workdir: `backend`) -> failed (missing `eslint.config.*`)
- repository/file inspections via `rg --files`, `Get-Content`, `Get-ChildItem`, `git ls-files`

Notes:
- This entry records the scoring run completed before the H4 policy upgrade.
- Future runs must follow updated `high-bar-project-scoring` defaults (H4) and append here only.
