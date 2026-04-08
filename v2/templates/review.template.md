# Review: Round {N}

## Pre-flight

### AC Testability
- AC-{N}.1: {status}

### Test Baseline
{summary}

### Environment
- Mode: {A / B / C / C+}
- Tier 2: {full / partial / unavailable}

### Plan Challenges
1. {challenge or "No significant issues found."}

### Recommendation
{ready / revise / blocked}

## Verification

### Tier 1: Deterministic
- Compile / check: {status}
- Tests: {summary}

### Tier 2: Runtime
{summary or "Skipped — Mode C/C+."}

### Tier 3a: AC Coverage
| AC | Test | Exists | Passes | Verifies AC |
|----|------|--------|--------|-------------|
| AC-{N}.1 | {test identifier} | {status} | {status} | {status} |

## Findings

### Code bugs
{None or actionable list}

### Design issues
{None or actionable list}

### Requirement gaps
{None or actionable list}

## Human Judgment

### Already verified
- {high-confidence evidence}

### Needs your judgment
1. {judgment call or residual risk}

### Risk note
Verifier ran in Mode {A / B / C / C+}. Confidence: {high / medium / low}.

## Routing Signals

| Key | Value |
|-----|-------|
| Next Route | {builder / planner / human / closeout} |
| Human Review Needed | {yes / no} |
| Blocking | {none / code-bug / design-issue / requirement-gap / environment / assumption} |

## Verdict
{PASS / FAIL / BLOCKED}
