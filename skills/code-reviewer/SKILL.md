---
name: code-reviewer
description: >
  Use after implementation to review code changes against the plan.
  Checks spec compliance, interface stability, reliability, performance,
  project-specific rules, and hard constraints audit.
  Reads .baton/review-checklists.md and .baton/governance/hard-constraints.md
  for project-specific checks.
  Can run standalone (Layer 0) on any code diff.
---
# Code Review

Code review has one purpose: find what went wrong before the human sees
it. Your job is to be the human's safeguard, not the implementer's
cheerleader.

## Quick Reference

| Attribute        | Value                                                              |
|------------------|--------------------------------------------------------------------|
| Trigger          | After implementation (and ideally after verification)              |
| Input            | Approved plan.md (if available) + changed files from disk          |
| Output           | `review.md` with BLOCKING/WARNING/NOTE findings + file:line evidence |
| Side effects     | Updates `Last-validated` in hard-constraints.md (if APPROVED)      |
| Sole responsibility | Reviewing code + updating hard-constraints metadata            |
| Exit condition   | No BLOCKING issues remain (or human accepts risk)                  |

## Mode Behavior

| Mode               | Cross-skill deps | Output path                                | Gate check |
|--------------------|-------------------|--------------------------------------------|------------|
| PURE STANDALONE    | Skip              | `./review.md`                              | Skip       |
| PROJECT STANDALONE | Skip              | `.baton/scratch/review-<timestamp>.md`     | Skip       |
| WORKFLOW MODE      | Enforced          | `.baton/tasks/<id>/review.md`              | Enforced   |

---

## Standalone mode (Layer 0)

Use `baton review [--diff HEAD~N] [--plan plan.md]` to invoke directly.

When running standalone:
- If plan.md is provided, spec compliance is checked.
- If plan.md is NOT provided, spec compliance is skipped.
- If hard-constraints.md is not available, constraints audit is skipped.

## Review modes

**Subagent review (preferred):** Dispatch subagents using prompts in
`~/.baton/prompts/`. Fresh context = naturally objective.

**Self-review (fallback):** Review your own code. Use the protocol below
to counteract confirmation bias through structure.

## Self-review protocol

**Do not review from memory. Re-read every file from disk.**

1. Close your mental model.
2. Read plan.md fresh — as if someone else wrote it.
3. Read each changed file from disk — cite file:line for every finding.
4. **Assume-bug-first:** For each check, start from the assumption
   there IS a bug. Look for code evidence to disprove it.

## Process

Announce: "I'm reviewing the implementation against the plan."

### Step 1: Read plan.md (if available)
⚠️ Checkpoint: Are you reviewing from memory? → Re-read from disk. Cite file:line.

### Step 2: Read the actual changes from disk

### Step 3: Run four-stage review
- Stage 1: Spec compliance (if plan.md available)
- Stage 2: Code quality
- Stage 3: Project-specific checks
- Stage 4: Constraints audit (if hard-constraints.md available)

### Step 4: Write review.md

## Stage 1: Spec compliance (requires plan.md)

For each planned change:
- Is it implemented? Missing = BLOCKING.
- Is it correct? Wrong behavior = BLOCKING.
- Is anything extra? Unplanned additions = WARNING.

## Stage 2: Code quality

Apply assume-bug-first for each dimension:

### Error handling and reliability
- Assume: new error paths are NOT handled.
- Assume: exceptions are caught too broadly.

### Interface stability
- Check `.baton/project-config.json` → `constraints.stable_contracts`.
- Changes without plan approval = BLOCKING.

### Performance and observability
- Assume: there is an N+1 query.
- Assume: large data operations are unbounded.

### Concurrency and state
- Assume: shared state has race conditions.

### Testing
- Assume: new code paths are NOT tested.

## Stage 3: Project-specific checks

Read `.baton/review-checklists.md`. Apply every relevant item.

## Stage 4: Constraints audit

1. **Violation detection:** Check each constraint against current changes.
2. **Staleness detection:** Flag constraints with `Last-validated` >60 days.
3. **New constraint suggestions:** If changes introduce a pattern that
   should be enforced project-wide, suggest it.

### Updating constraint metadata

- **If APPROVED:** Update `Last-validated` in hard-constraints.md.
  This is the ONLY field the reviewer may modify.
- **If CHANGES REQUESTED:** Do NOT update. Record in review.md only.

## Severity classification

**BLOCKING** — Must fix: breaking changes, data loss, security, spec non-compliance, hard constraint violations.

**WARNING** — Should fix: unplanned changes, missing edge case tests, observability gaps, stale constraints.

**NOTE** — Optional: naming, refactoring, documentation, new constraint suggestions.

## Rationalizations to watch for

| You think | Why it's wrong | Do this instead |
| :--- | :--- | :--- |
| "The change is too small to review" | Small changes have highest assumption density | Run all stages |
| "I implemented it, so I know it's correct" | You know intention, not what you wrote | Re-read from disk. Cite file:line. |
| "I can see it's fine" | Seeing is not evidence | Write the specific line number |
| "All issues are minor, ship it" | If any BLOCKING exists, do not approve | Fix BLOCKING now |
| "Constraints audit is overkill" | Constraint violations are hardest to catch later | If hard-constraints.md exists, always audit |
| "No plan, no review needed" | Code quality review is valuable without a plan | Run stages 2-4 |
