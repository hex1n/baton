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

### Contract Status
- Status: {agreed / revise / blocked}
- Blocking ambiguities: {none / list}
- Verification readiness: {ready / partial / blocked}

### Recommendation
{ready / revise / blocked}

### Verification Add-ons (for verify pass)
- Recommended: `{none / adversarial / cross-model / adversarial,cross-model}`
- Why: `{brief reason, or "None."}`

### Plan Quality
- Depth: `{normal / deepen}`
- Search Adequacy: `{adequate / under-searched}`
- Why: `{brief reason}`

### Round Load
- Load: `{normal / heavy / overloaded}`
- Why: `{brief reason}`
- Action: `{proceed / warn / split-or-override / proceed-under-override}`

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

### Activated Add-ons
- Used: `{none / adversarial / cross-model / adversarial,cross-model}`
- Notes: `{what ran, or "Not run yet."}`

## Findings

### Code bugs
{None or actionable list}

### Design issues
{None or actionable list}

### Requirement gaps
{None or actionable list}

### Findings Sidecar
- Path: `{.context/baton/active/findings/review-round-{N}.json or N/A}`
- Status: `{written / not needed}`
- Summary: `{machine-readable normalized findings for tooling, or "N/A"}`

## Human Judgment

### Already verified
- {high-confidence evidence}

### Needs your judgment
1. {judgment call or residual risk}

### Risk note
Verifier ran in Mode {A / B / C / C+}. Confidence: {high / medium / low}.

### Independence note
{Normal independence maintained. / ⚠️ Verification independence: degraded — human review weight is higher.}

## Routing Signals

| Key | Value |
|-----|-------|
| Next Route | {builder / planner / human / closeout} |
| Human Review Needed | {yes / no} |
| Blocking | {none / code-bug / design-issue / requirement-gap / environment / assumption / overload} |
| Verification Add-ons | {none / adversarial / cross-model / adversarial,cross-model} |
| Plan Quality | {adequate / under-searched} |
| Round Load | {normal / heavy / overloaded} |

## Verdict
{PASS / FAIL / BLOCKED}
