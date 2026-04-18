# Scoring Rubric

## Levels
- `H1`: strict
- `H2`: very strict
- `H3`: extreme
- `H4`: ultra (default)

## Weights (100)
- Architecture and boundaries: 20
- Code quality and complexity: 20
- Test and regression confidence: 20
- Engineering and release gates: 15
- Security and configuration governance: 15
- Documentation and collaboration: 10

## Deduction Format
Use this exact structure per item:

`observation -> evidence -> risk -> deduction`

## H4 Baseline Deductions

### Architecture and boundaries (20)
- God object / oversized mixed module: 6-12
- Boundary bypass / cross-layer coupling: 4-10
- Refactor without staged plan/rollback: 3-8

### Code quality and complexity (20)
- Uncontrolled complexity in core paths: 5-12
- Missing failure-path handling: 3-8
- Technical debt markers not shrinking: 2-6

### Test and regression confidence (20)
- No relevant verification executed: >=8
- Critical path test gap: 5-12
- Passing tests but low trust due to unmanaged warning noise: 3-8

### Engineering and release gates (15)
- Missing executable gate: 4-10
- Hidden manual build steps: 3-8
- CI gate misalignment with release: 3-7

### Security and configuration governance (15)
- Secret/template boundary weak: 4-10
- Sensitive log/privacy leakage risk: 3-8
- Missing auth/session/permission chain protection evidence: 3-9

### Documentation and collaboration (10)
- README diverges from implemented behavior: 3-6
- Missing runbook/troubleshooting/rollback docs: 2-5
- Vague scope/validation statements: 2-4

## Hard Caps
- Any P0 blocker: cap 49
- No executable test evidence: cap 59
- No executable quality gate evidence: cap 64
- High architecture risk without remediation plan: cap 69
- No minimum CI safety baseline on mainline: cap 74

## Interval Caps (stability-first)
- Any one core dimension (`Architecture`, `Code Quality`, `Test Confidence`) <= 8/20: cap 79
- Any two core dimensions <= 8/20: cap 69
- Any one core dimension <= 5/20: cap 59
- Use the strictest cap if multiple apply.
