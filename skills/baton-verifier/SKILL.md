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

## Isolation Self-Check

Before proceeding, verify you are running in a fresh context:

- If you can recall Architect reasoning, Specifier decisions, or design
  discussions from earlier in this conversation — context you did not
  load from the artifacts above — **STOP**.
- You are NOT in a fresh context. Inherited reasoning defeats the
  purpose of independent verification path discovery.
- Instruct the orchestrator to re-dispatch via `Agent` tool
  (not `Skill` tool) and restart from a blank session.

If you loaded the artifacts above and have no prior conversation
history, proceed.

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

In Codex, this role MUST be launched as `spawn_agent({ fork_context: false })`.
Do not run verifier logic inline in the parent thread and do not use
`fork_context: true`.

The orchestrator must pass the spawned agent id into the prompt, and the
verifier must record it in `verification-path.md` as:

- `Agent ID: <spawned-agent-id>`

If the orchestrator cannot provide a real isolated agent id, strict mode must
block instead of silently degrading. See `spec/adapters/codex.md` for the
concrete spawn/wait example.

## Role Contract

- **Inputs**: `requirements.md`, `architecture.md`, repo profile
- **Outputs**: exact commands or checks, executability proof, blocking conditions
- **Required artifact**: `verification-path.md`

## Artifact Language Policy

Read `artifact_language` from `task-status.md` § State Notes (`zh` or `en`).
Write all human-facing artifacts in that language.
Do not localize `task-status.md`.

## Gate: Verification Path Check

All criteria must pass before Generator can begin:

- [ ] `requirements.md` and `architecture.md` contain no unresolved contradiction
- [ ] Exact validation commands or checks are listed
- [ ] Commands are executable in the current repo context
- [ ] Isolation mode is declared (`strict` or `compat`)
- [ ] Execution context is declared
- [ ] Toolchain blockers are known
- [ ] Fallback validation is defined if primary path is unavailable

**Fail criteria** (any of these blocks Generator):

- Test/build chain is unknown
- Validation path is blocked by unresolved environment or repo issues
- Task is `strict` but verification can only run as `sequential_fallback`
- Generator would be forced to implement without a realistic verification path

## Required Artifact: `verification-path.md`

Sections (all required):

1. **Intended Checks** — what each check validates, mapped to requirements
2. **Commands** — exact commands to run, with expected output patterns
3. **Dependencies and Prerequisites** — tools, versions, env vars, test data,
   fixture setup commands
4. **Execution Provenance** — `Role`, `Isolation mode`, `Execution context`,
   `Evidence`, `Fallback policy`, and `Fallback reason`
5. **Dry-Run Result** — actual output from running the commands now
6. **CI Compatibility** — gaps between local and CI execution (if any)
7. **Performance Baseline** — current metrics for performance-sensitive
   tasks (High risk only; omit for Low/Medium)
8. **Blockers** — anything preventing validation, with category
9. **Fallback Strategies** — alternative validation if primary path fails

## Execution Guide

### Core Question

> "If Generator writes the code correctly, can we prove it works?"

If the answer is **no** or **uncertain**, the task is **blocked**.

### 0. Environment Prerequisite Check

Before dry-running any commands, verify the project can build and test
at all. This catches infrastructure issues early (missing deps, no test
runner config, broken toolchain) so they don't block Phase 6.

1. **Dependencies installed?** Check whether `node_modules/`, `vendor/`,
   `.venv/`, or equivalent exist. If not, run the install command
   (`npm install`, `pip install -r requirements.txt`, etc.) and record it
   as a prerequisite in the artifact.
2. **Build tool present?** Verify the build command (`tsc`, `go build`,
   `mvn`, etc.) is available and the project compiles.
3. **Test runner configured?** Check that a test config file exists
   (`jest.config.*`, `pytest.ini`, `phpunit.xml`, etc.). If missing,
   record it as an `environment_blocker` — Generator must create the
   config before tests can run.
4. **CI config readable?** If a CI config exists (`.github/workflows/`,
   `.gitlab-ci.yml`, `Jenkinsfile`), confirm it parses.

Record all findings in the **Dependencies and Prerequisites** section.
Any unresolvable issue is a blocker with category `environment_blocker`.

### 1. Read Architecture Verification Strategy

- First compare `requirements.md` with approved decisions in `architecture.md`.
- If requirements still reflect pre-approval assumptions, block and hand back
  for requirements sync before writing validation commands.
- Extract the verification approach from `architecture.md`.
- List what needs to be validated per requirement or module.

### 2. List Concrete Commands

For each requirement or module:
- Write the exact command to run
- Include expected output or success criteria
- Note any ordering dependencies between commands

### 3. Check Prerequisites

For each command, verify:
- Build tool is installed and configured
- Dependencies are resolved (can the project build right now?)
- Test infrastructure exists (test runner, fixtures, test dependencies)
- Required environment variables or config files are present
- Test data prerequisites: what fixtures, seeds, or mock data are needed?
  Document setup commands in the artifact.

### 4. Dry-Run the Commands

**Run the commands now** and record the actual output:
- If tests pass → record the passing output as baseline
- If tests fail → distinguish between "test infra works but tests fail"
  (acceptable — Generator will make them pass) and "test infra is broken"
  (blocker)
- If commands cannot run at all → blocker with category

### 5. CI Pipeline Check

Verify that the validation commands will also work in CI:
- Are there CI-only environment variables or secrets needed?
- Does CI use a different execution environment than local?
- Are there CI-specific timeouts or resource limits?
- If CI configuration exists in the repo, cross-reference the validation
  commands against CI steps.

If validation commands work locally but would fail in CI, document the
gap and add CI-specific commands to the artifact.

### 6. Performance Baseline (High risk only)

For performance-sensitive tasks (identified by risk assessment):
- Capture current performance metrics during dry-run (response time,
  throughput, memory usage)
- Record baseline values in the artifact
- Define acceptable regression thresholds
- Generator and Evaluator use these baselines for comparison

### 7. Identify Blockers

Categorize any blockers found:
- `verification_blocker` — cannot validate at all
- `environment_blocker` — missing tools, deps, or config
- `scope_blocker` — validation requires changes outside approved scope

### 8. Define Fallback Strategies

For each primary validation path, define what to do if it fails:
- Alternative commands or manual verification steps
- Reduced-scope validation that still provides confidence
- Explicit "no fallback available" if none exists

### 9. Record Execution Provenance

- Read `verification_isolation_mode` from `.harness/profile.local.yaml` if present.
- If absent, treat the task as `strict`.
- Write the shared provenance fields:
  - `Role: verification_explorer`
  - `Isolation mode: strict|compat`
  - `Execution context: isolated_subagent`
  - `Execution context: fresh_session`
  - `Execution context: session_reset`
  - `Execution context: sequential_fallback`
  - `Agent ID: <spawned-agent-id>`
- `Evidence` should say what artifacts/config you cold-read and whether you
  actually dry-ran commands.
- `Fallback policy` should say how degraded execution is handled.
- In `strict`, inability to use a real isolated context is a blocker.
- In `compat`, sequential fallback is allowed only if you record a concrete
  fallback reason.

### Risk-Adaptive Depth

Read the risk level from `task-status.md` § State Notes and adapt:

| Risk Level | Depth Adjustments |
|------------|-------------------|
| **Low** | Basic verification; skip CI check and performance baseline |
| **Medium** | Standard — all checks, CI compatibility if CI config exists |
| **High** | Full depth — all checks required, CI compatibility mandatory, performance baseline required, test data setup scripted |

### Quality Check

- Every requirement has at least one validation command.
- Every command has been dry-run with output recorded.
- Blockers are categorized and actionable.
- Fallback exists or is explicitly marked absent.
- Test data prerequisites are documented with setup commands.

## State Transition

On pass: update `task-status.md` → state `generating`, owner `generator`.
On fail: update `task-status.md` → state `blocked` with `verification_blocker`,
include specific blockers and what is needed to unblock.
