---
name: harness-verifier
description: >
  Verify that the planned validation path is executable before implementation
  begins. Trigger when the user asks to "verify the path", "check verification",
  "can we test this", "prove we can validate", or "Gate 3". Takes
  architecture.md and repo profile, produces verification-path.md with exact
  commands, dry-run results, and fallback strategies. Produces verification
  proof, not implementations.
user-invocable: true
---

# Verifier

> Derived from spec/protocol/role-contracts.md — Verification Explorer

## Role Contract

- **Inputs**: `architecture.md`, repo profile
- **Outputs**: exact commands or checks, executability proof, blocking conditions
- **Required artifact**: `verification-path.md`

## Gate: Verification Path Check

All criteria must pass before Generator can begin:

- [ ] Exact validation commands or checks are listed
- [ ] Commands are executable in the current repo context
- [ ] Toolchain blockers are known
- [ ] Fallback validation is defined if primary path is unavailable

**Fail criteria** (any of these blocks Generator):

- Test/build chain is unknown
- Validation path is blocked by unresolved environment or repo issues
- Generator would be forced to implement without a realistic verification path

## Required Artifact: `verification-path.md`

Sections (all required):

1. **Intended Checks** — what each check validates, mapped to requirements
2. **Commands** — exact commands to run, with expected output patterns
3. **Dependencies and Prerequisites** — tools, versions, env vars, test data
4. **Dry-Run Result** — actual output from running the commands now
5. **Blockers** — anything preventing validation, with category
6. **Fallback Strategies** — alternative validation if primary path fails

## Execution Guide

### Core Question

> "If Generator writes the code correctly, can we prove it works?"

If the answer is **no** or **uncertain**, the task is **blocked**.

### 1. Read Architecture Verification Strategy

- Extract the verification approach from `architecture.md`.
- List what needs to be validated per requirement or module.

### 2. List Concrete Commands

For each requirement or module:
- Write the exact command (test runner, build, lint, curl, etc.)
- Include expected output or success criteria
- Note any ordering dependencies between commands

### 3. Check Prerequisites

For each command, verify:
- Build tool is installed and configured
- Dependencies are resolved (can the project build right now?)
- Test infrastructure exists (test runner, fixtures, test DB)
- Required environment variables or config files are present

### 4. Dry-Run the Commands

**Run the commands now** and record the actual output:
- If tests pass → record the passing output as baseline
- If tests fail → distinguish between "test infra works but tests fail"
  (acceptable — Generator will make them pass) and "test infra is broken"
  (blocker)
- If commands cannot run at all → blocker with category

### 5. Identify Blockers

Categorize any blockers found:
- `verification_blocker` — cannot validate at all
- `environment_blocker` — missing tools, deps, or config
- `scope_blocker` — validation requires changes outside approved scope

### 6. Define Fallback Strategies

For each primary validation path, define what to do if it fails:
- Alternative commands or manual verification steps
- Reduced-scope validation that still provides confidence
- Explicit "no fallback available" if none exists

### Quality Check

- Every requirement has at least one validation command.
- Every command has been dry-run with output recorded.
- Blockers are categorized and actionable.
- Fallback exists or is explicitly marked absent.

## State Transition

On pass: update `module-status.md` → state `generating`, owner `generator`.
On fail: update `module-status.md` → state `blocked` with `verification_blocker`,
include specific blockers and what is needed to unblock.
