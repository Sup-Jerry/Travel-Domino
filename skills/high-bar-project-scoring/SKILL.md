---
name: high-bar-project-scoring
description: Use when the user asks to score, grade, evaluate quality, or rank a codebase/project and expects strict, evidence-first assessment.
---

# High Bar Project Scoring

Strict project scoring workflow with evidence-first deductions and reproducible output.

## Trigger Conditions
- The user asks to score/grade/evaluate project quality.
- The user asks for stricter standards or high-threshold review.
- The user expects score + reasons + actionable improvements.

## Output Language
- Default: Chinese.
- Scoring log file content: English only (ASCII preferred).

## Global Rules
- Never score by impression. Collect evidence first.
- Every key deduction must map to file paths, command output, or test results.
- If evidence is incomplete, explicitly lower confidence and score conservatively.
- Keep conclusions consistent with evidence severity.

## Strictness Levels
### H1 (Strict)
- Team daily delivery baseline.

### H2 (Very Strict)
- Mainline maintainability baseline.

### H3 (Extreme)
- Production-grade baseline with sustainability checks.

### H4 (Ultra, default)
- Release-gate level for long-term operation.
- Stronger penalties on architecture, automation, and regression confidence.

If level is not explicitly provided, use `H4`.

## Scoring Model (100 points)

### Dimensions and Weights
- Architecture and boundaries: 20
- Code quality and complexity: 20
- Test and regression confidence: 20
- Engineering and release gates: 15
- Security and configuration governance: 15
- Documentation and collaboration: 10

### Deduction Method
- Start from 100 and deduct by evidence.
- Decimal per dimension is allowed; final total is integer.
- Each deduction line must follow:
  `observation -> evidence -> risk -> deduction`

## H4 Penalty Baseline (Stricter)

### Architecture and Boundaries (20)
- Core God Object or oversized mixed-responsibility module: deduct 6-12
- Cross-layer coupling / boundary bypass: deduct 4-10
- High-risk refactor without staged plan or rollback path: deduct 3-8

### Code Quality and Complexity (20)
- Uncontrolled complexity in core modules: deduct 5-12
- Incomplete error handling on failure path: deduct 3-8
- Long-standing technical debt markers (TODO/FIXME/HACK): deduct 2-6

### Test and Regression Confidence (20)
- No relevant test command executed before conclusion: deduct at least 8
- Critical path missing tests / broken regression chain: deduct 5-12
- Tests pass but warning noise unmanaged / low trust output: deduct 3-8

### Engineering and Release Gates (15)
- Missing executable gates or non-reproducible gates: deduct 4-10
- Build pipeline depends on manual hidden steps: deduct 3-8
- CI gate misaligned with real release needs: deduct 3-7

### Security and Configuration Governance (15)
- Poor secret/template boundary governance: deduct 4-10
- Sensitive logs/privacy leakage risk: deduct 3-8
- Missing protection evidence on auth/session/permission chain: deduct 3-9

### Documentation and Collaboration (10)
- README deviates from implemented capability: deduct 3-6
- Missing runbook/troubleshooting/rollback doc: deduct 2-5
- Validation scope and impact description unclear: deduct 2-4

## Hard Caps and Veto Rules (H4)
- Any P0 blocker risk (data corruption, severe security flaw, cannot build): total capped at 49
- No executable test evidence: total capped at 59
- No executable quality gate evidence: total capped at 64
- Architecture high-risk identified with no remediation plan: total capped at 69
- CI does not enforce minimum test + lint/security on mainline: total capped at 74

## Stability-First Interval Caps (Global)
- Principle: overall stability has priority over isolated excellence.
- A standout single feature cannot offset obvious defects in other core dimensions.
- If any one core dimension (`Architecture`, `Code Quality`, `Test Confidence`) is <= 8/20: total capped at 79.
- If any two core dimensions are <= 8/20: total capped at 69.
- If any one core dimension is <= 5/20: total capped at 59.
- Apply the strictest cap when multiple cap rules are triggered.

## Grade Bands
- 90-100: High-standard reference level
- 80-89: Reliable overall, but has explicit shortfalls to fix soon
- 70-79: Usable but high risk for scaling complexity
- 60-69: Quality is borderline; fix foundation first
- 0-59: Not acceptable for continued feature expansion

## Mandatory Output Template
The final response must include:
1. Total score and grade
2. Level (H1/H2/H3/H4)
3. Dimension breakdown (6 items)
4. Top 5 deductions with evidence
5. Hard-cap trigger status
6. Confidence (high/medium/low) with reason
7. Top 3 prioritized actions (executable and verifiable)

## Execution Steps
1. Inventory repository structure and stack.
2. Run the fastest relevant verification set (tests/build/gates).
3. Collect evidence and map to all 6 dimensions.
4. Check hard-cap rules first, then finalize score.
5. Output in order: evidence -> judgment -> action.

## Scoring Log Policy (Mandatory)
After each scoring run, update this file:
- `docs/quality/PROJECT_SCORING_LOG.md`

Rules:
- Append-only. Never modify historical entries unless the user explicitly asks.
- Add one new section per scoring run.
- Use timestamp in ISO-8601 with timezone offset.
- Log content must be English only (ASCII preferred).
- Include: score, level, confidence, cap trigger, top deductions, commands executed.

If the log file is missing, create it from scratch using the same append-only policy.

## Prohibited
- No intuition-only scoring.
- No high score while ignoring obvious high-risk issues.
- No final score without deduction evidence.
- Do not score planned work as completed capability.
