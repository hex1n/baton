---
normative-status: Implementation-time investigation protocol, not a standalone phase.
name: baton-debug
description: >
  Use when hitting test failures, unexpected behavior, or repeated implementation
  failures during IMPLEMENT. Provides systematic root cause analysis. Also use
  when stop-guard or failure-tracker signals repeated failures.
user-invocable: true
---

## Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION
DEBUG IS EVIDENCE COLLECTION — NOT A NEW PHASE
VERIFY = VISIBLE OUTPUT. "I checked" is not evidence.
```

## Role

baton-debug is an implementation-time investigation protocol triggered inside
IMPLEMENT. It does not replace RESEARCH as a phase; it produces evidence needed
either to resume implementation safely, to escalate back to RESEARCH/PLAN,
or to abandon a wrong line of implementation.

## Red Flags

These thoughts mean STOP — you're rationalizing:

| Thought | Reality |
|---------|---------|
| "I know where the problem is, just fix it" | Hypothesis ≠ root cause. Reproduce first, then analyze |
| "Let me try once more with different parameters" | Parameter tweaks are not new approaches. Check information gain |
| "This is probably a simple typo" | Reproduce it. If it's truly simple, Phase 1 takes 30 seconds |
| "I'll just add a quick workaround" | Workarounds mask root causes. Investigate first |
| "The test environment must be broken" | Cannot reproduce → investigate environment, don't assume |

## When to Use

- Test failure not immediately obvious
- Repeated implementation attempts without evidence-backed explanation
- Unexpected behavior contradicting plan assumptions
- User says "debug", "investigate", "调试", "排查"

If the supposed cause is not backed by direct observable evidence, treat it as
not obvious — enter baton-debug.

**When NOT to use**: First-time failure with direct evidence-backed cause
and low blast radius (e.g. normal red-green-refactor cycle).

## The Process

### Phase 1: Reproduce

1. Record exact error — full output, not summary
2. Reproduce the failure
3. Isolate — minimal reproduction case?

Cannot reproduce → do not modify business code. First confirm environment
differences, input conditions, execution paths, and dependency versions.
If internal analysis is exhausted, search external sources (issue trackers,
changelogs, known-issues pages) for matching symptoms before escalating.

### Phase 2: Pattern Analysis

1. Grep for similar working patterns — compare
2. Diff working vs broken — what's different?
3. Check `git diff`/`git log` for recent changes
4. If failure may involve third-party dependencies, check external sources
   (changelogs, issue trackers, release notes) for breaking changes

### Phase 3: Hypothesis

1. State: "Failure occurs because X"
2. Predict: "If I change Y, result should be Z"
3. Test: one change, observe
4. Record: confirmed or refuted, with evidence. Note what was eliminated.

**Timeboxing:** If reproduction or environment investigation exceeds 10
distinct diagnostic steps without progress, treat as equivalent to a failed
hypothesis test for stop-rule purposes.

**Stop rules (evidence-quality driven):**
- 3 hypothesis tests that produced no significant new evidence → stop and
  escalate. "Significant" means it eliminated a candidate cause, narrowed the
  search space, or revealed a new failure dimension
- Even before 3: repeated parameter tweaks, circular reasoning, or
  explanations that don't close → stop and escalate
- If each failed hypothesis narrows the search space, may continue, but must
  explicitly record which hypotheses were eliminated and why

### Phase 4: Fix

Only after root cause confirmed — a root cause is "confirmed" when the
observed failure is explained by the hypothesis AND the predicted intervention
produces the expected result:

1. Create the smallest reliable verification artifact for the confirmed root
   cause — failing test, repro script, assertion, trace capture, fixture, or
   log capture as appropriate
2. Minimal fix addressing root cause
3. Verify — verification artifact passes, existing tests pass
4. Grep for same pattern elsewhere. Fix siblings only if within approved
   scope; otherwise annotate and escalate

## Escalation Criteria

| Situation | Action |
|-----------|--------|
| Root cause confirmed, plan assumptions unchanged | Fix within IMPLEMENT |
| Root cause confirmed, but plan assumptions wrong / write set exceeded | Escalate to RESEARCH/PLAN update |
| Root cause unconfirmed after stop rule triggers | Stop fixing, submit findings, report to human |

## Output Routing

| Condition | Write to |
|-----------|----------|
| Resolved within IMPLEMENT, no plan impact | Plan `## Annotation Log` only (brief note) |
| Findings inform future work but don't change current plan | Research supplement (following project naming convention) |
| Plan assumptions proved wrong → escalating | Original research file (new section) + plan annotation |
