---
name: baton-verifier
context: fork
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

## Startup (context: fork — must load artifacts explicitly)

This skill should start from the artifacts, not from prior role reasoning.

Load these inputs before proceeding:

1. Read `.harness/requirements.md`
2. Read `.harness/architecture.md`
3. Read repo profile / validation config if present

Do not inherit Explorer / Specifier / Architect reasoning as your verification
baseline.

## Claude Code Execution Note

In Claude Code, dispatch this role as an isolated subagent via the `Agent` tool.
Do NOT invoke inline via the `Skill` tool — that executes within the current
conversation and does not provide context isolation.

Preferred (if `.claude/agents/baton-verifier` is registered):
```
Agent(subagent_type: "baton-verifier",
      prompt: "Verify the validation path for task [task-id].")
```

Fallback (always works):
```
Agent(subagent_type: "general-purpose",
      prompt: "You are the Verification Explorer. Cold-read only:
               .harness/requirements.md, .harness/architecture.md,
               and repo validation config.
               Follow baton-verifier skill instructions.")
```

See `spec/adapters/claude-code.md` § Context Isolation for the full pattern.

## Codex Execution Note

In Codex, launch this role as `spawn_agent({ fork_context: false })` and tell
the sub-agent to cold-read only `requirements.md`, `architecture.md`, and repo
validation config. See `spec/adapters/codex.md` for the concrete spawn/wait
example.

## Role Contract

- **Inputs**: `requirements.md`, `architecture.md`, repo profile
- **Outputs**: exact commands or checks, executability proof, blocking conditions
- **Required artifact**: `verification-path.md`

## Artifact Language Policy

Before writing any human-facing artifact:

1. If `.harness/profile.local.yaml` sets `documentation.artifact_language` to
   `zh` or `en`, use that language.
2. If it is `auto`, follow the current user request language.
3. If the setting is missing, default to Chinese.

Do not localize `module-status.md`. Keep the control-plane file, owner tokens,
state tokens, and blocker categories in stable English.

## Gate: Verification Path Check

All criteria must pass before Generator can begin:

- [ ] `requirements.md` and `architecture.md` contain no unresolved contradiction
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

- First compare `requirements.md` with approved decisions in `architecture.md`.
- If requirements still reflect pre-approval assumptions, block and hand back
  for requirements sync before writing validation commands.
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
