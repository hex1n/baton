---
name: verification-gate
description: >
  Use after implementation is complete. Run all verification steps,
  record evidence in verification.md. Supports scope-based regression
  testing when project-config.json defines test suites.
  Never declare success without running the actual checks.
  Can run standalone (Layer 0) on any code changes.
---
# Verification Gate

Verification is evidence collection, not opinion. You must run the
actual commands, observe the actual output, and record the actual
results. "It should work" is not evidence.

## Quick Reference

| Attribute        | Value                                                              |
|------------------|--------------------------------------------------------------------|
| Trigger          | After implementation is complete                                   |
| Input            | `.baton/project-config.json` commands + workspace state            |
| Output           | `verification.md` with command output evidence                     |
| Side effects     | None (read-only verification)                                      |
| Sole responsibility | Running checks and recording evidence                          |
| Exit condition   | verification.md has `TASK-STATUS: DONE` and all checks pass        |

## Mode Behavior

| Mode               | Cross-skill deps | Output path                                    | Gate check |
|--------------------|-------------------|------------------------------------------------|------------|
| PURE STANDALONE    | Skip              | `./verification.md`                            | Skip       |
| PROJECT STANDALONE | Skip              | `.baton/scratch/verification-<timestamp>.md`   | Skip       |
| WORKFLOW MODE      | Enforced          | `.baton/tasks/<id>/verification.md`            | Enforced   |

---

## Standalone mode (Layer 0)

This skill can run independently. Use `baton verify` to invoke it.

When running standalone:
- If no project-config.json is provided, tries common commands for
  the detected stack.
- Regression testing requires project-config.json with suite definitions.

## Process

Announce: "I'm running verification for task <task-id>."

### Step 1: Read project config
Use `.baton/project-config.json` commands. If commands are empty,
try common commands for the detected stack.
⚠️ Checkpoint: Are you about to skip verification because "no tests configured"? → Build check is minimum. Do a manual smoke test.

### Step 2: Run compile/build
### Step 3: Run tests
### Step 4: Run lint/type-check (if configured)
### Step 5: Run regression suites (if configured)
### Step 6: Check todo completeness
### Step 7: Write verification.md
### Step 8: If all checks pass, add `<!-- TASK-STATUS: DONE -->`

## Scope-based regression testing (Layer 2)

When `project-config.json` includes a `regression` section,
verification automatically runs scope-matched tests.

A suite runs if ANY of its scope globs match ANY modified file.
Modified files are determined by the plan's File change manifest
or `git diff --name-only`.

## verification.md structure

```markdown
# Verification: <task-id or scope>

## Build
Command: `<command>`
Result: ✅ SUCCESS / ❌ FAILED

## Tests
Command: `<command>`
Result: ✅ N/N passed / ❌ N failed

## Lint / type-check
Result: ✅ / ⚠️ NOT CONFIGURED

## Regression suites
| Suite | Scope match | Result |
| :--- | :--- | :--- |
| core-api | ✅ src/api/users.ts | ✅ 12/12 passed |
| auth-flow | ⏭️ no overlap | Skipped |

## Todo completion
- [x] All N items checked in plan.md

## Manual verification
- [describe any manual checks]

## Issues found
None / [list issues and resolution]

<!-- TASK-STATUS: DONE -->
```

## What counts as evidence

- ✅ Command output showing pass/fail counts
- ✅ Log excerpt or error message
- ❌ "It should work because I wrote it correctly"
- ❌ "The tests pass" (without showing which tests)
- ❌ "I checked and it's fine" (checked how?)

## Rationalizations to watch for

| You think | Why it's wrong | Do this instead |
| :--- | :--- | :--- |
| "The code compiles so it works" | Compiling ≠ correct | Run tests |
| "I wrote the tests so they pass" | Run them. Read the output. Record it. | Run them. |
| "No tests configured, verification done" | Manual check still required | At minimum verify build + manual smoke test |
| "I'll just say it passed" | That's fabricating evidence | Run the command. Copy the output. |
| "Regression suites aren't configured, skip" | That's a config gap, not a pass | Flag missing config as WARNING |
