# Quick Checklist

## Minimal Evidence Collection
- Repository status:
  - `git status -sb`
- File inventory:
  - `rg --files`
- Test inventory:
  - `rg --files entry/src/test`
  - `rg --files backend/test`
- Technical debt markers:
  - `rg -n "TODO|FIXME|HACK" entry backend docs`
- Build/test quick gates:
  - backend: `npm test -- --runInBand` (from `backend/`)
  - client: project fastest gate script (for example `scripts/ci/unit-all.ps1`)
- Secret tracking sanity:
  - `git ls-files .env build-profile.json5 entry/src/main/ets/common/utils/AppConfig.ets`

## High-Value Signals
- Oversized core files (God object risk)
- Dirty mainline with unmanaged refactor spread
- Passing tests with low-trust warning noise
- Documentation vs implemented capability drift
- Missing rollback/runbook evidence

## Confidence Rule
- High: both code evidence + executable verification present
- Medium: code evidence strong, verification partial
- Low: mostly static inspection with limited executable evidence
