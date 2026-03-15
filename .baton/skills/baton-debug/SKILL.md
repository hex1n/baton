---
normative-status: Implementation-time research subflow, not a standalone phase.
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
DEBUG IS RESEARCH — WRITE FINDINGS TO THE RESEARCH FILE
VERIFY = VISIBLE OUTPUT. "I checked" is not evidence.
```

## Red Flags

These thoughts mean STOP — you're rationalizing:

| Thought | Reality |
|---------|---------|
| "I know where the problem is, just fix it" | Hypothesis ≠ root cause. Reproduce first, then analyze |
| "Let me try once more with different parameters" | Parameter tweaks are not new approaches. 3-failure rule |
| "This is probably a simple typo" | Reproduce it. If it's truly simple, Phase 1 takes 30 seconds |
| "I'll just add a quick workaround" | Workarounds mask root causes. Investigate first |
| "The test environment must be broken" | Cannot reproduce → investigate environment, don't assume |

## When to Use

- Test failure not immediately obvious
- Same approach failed 2+ times
- Unexpected behavior contradicting plan assumptions
- User says "debug", "investigate", "调试", "排查"

**When NOT to use**: Normal TDD flow. First-time failure with obvious fix.

## The Process

### Phase 1: Reproduce

1. Record exact error — full output, not summary
2. Reproduce the failure
3. Isolate — minimal reproduction case?

Cannot reproduce → investigate environment, not code.

### Phase 2: Pattern Analysis

1. Grep for similar working patterns — compare
2. Diff working vs broken — what's different?
3. Check `git diff`/`git log` for recent changes

### Phase 3: Hypothesis

1. State: "Failure occurs because X"
2. Predict: "If I change Y, result should be Z"
3. Test: one change, observe
4. Record: confirmed or refuted, with evidence

3 failed hypotheses → stop fixing, perform architectural review,
write findings to research file, report to human.

### Phase 4: Fix

Only after root cause confirmed:
1. Write failing test for root cause
2. Minimal fix addressing root cause
3. Verify — new test passes, existing tests pass
4. Grep for same pattern elsewhere — fix siblings

### Output

All findings → research file or research supplement.
Plan file gets brief Annotation Log note only.
