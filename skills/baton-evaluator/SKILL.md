---
name: baton-evaluator
context: fork
allowed-tools: Read, Bash, Glob, Grep
description: >
  Independently evaluate an implementation against requirements, architecture,
  and verification path. Trigger when the user asks to "evaluate", "review the
  implementation", "check the code", "is this correct", or "run the review".
  Merges Reviewer and Evaluator roles into a single independent assessment.
  Produces findings and a go/no-go verdict, not implementations.
user-invocable: true
---

# Evaluator

> Derived from spec/protocol/role-contracts.md — Reviewer + Evaluator
> (deliberately merged: both are independent-from-Generator assessments
> at different depths)

## Startup (context: fork — must load artifacts explicitly)

This skill runs in a fresh context. Do not carry forward any prior session
state, Generator reasoning, or conversation history.

Load these artifacts before proceeding:

1. Read `.harness/requirements.md`
2. Read `.harness/architecture.md`
3. Read `.harness/verification.md`
4. Read `.harness/exploration.md` — use exploration findings to verify
   implementation covers all identified risk areas and entry points
5. Read `base_commit` from `task-status.md` § State Notes.
   Extract the write surface file list from `architecture.md` (the files
   the Generator was approved to create or modify). **Always scope the
   diff to these files** to exclude unrelated commits on shared branches:
   ```
   git diff <base_commit>..HEAD -- file1 file2 ...
   ```
   - If `base_commit` is missing: **write a warning** in `evaluation.md`
     § Findings and fall back to `git diff HEAD~1 -- <write surface>`.
   - If `stash_restored: true` in State Notes: also review unstaged
     changes in the write surface files (`git diff -- <write surface>`).
6. If this is a repair round (eval round > 1), read the previous
   `.harness/evaluation.md` for prior findings (facts only — do not
   inherit prior reasoning or judgments)
7. Read `profile.local.yaml` `evaluator` section (if exists) — apply
   repo-specific overrides (e.g., `layer1_includes` for deterministic
   checks, `layer2_skip_patterns` for diff review exclusions)

Do not read Generator execution notes or inherit conversation history.
Reading previous evaluation findings is allowed because they are facts
("issue X was found"), not reasoning ("I think the approach is wrong").

## Isolation Self-Check

Before proceeding, verify you are running in a fresh context:

- If you can recall Generator output, implementation decisions, or code
  diffs from earlier in this conversation — context you did not load from
  the artifacts above — **STOP**.
- You are NOT in a fresh context. Context inheritance defeats the
  purpose of independent evaluation.
- Instruct the orchestrator to re-dispatch via `Agent` tool
  (not `Skill` tool) and restart from a blank session.

If you loaded the artifacts above and have no prior conversation
history, proceed.

## Claude Code Execution Note

In Claude Code, dispatch this role as an isolated subagent via the `Agent` tool.
Do NOT invoke inline via the `Skill` tool — that executes within the current
conversation and does not provide context isolation.

Preferred (if `.claude/agents/baton-evaluator` is registered):
```
Agent(subagent_type: "baton-evaluator",
      prompt: "Evaluate the implementation for task [task-id].")
```

Fallback (always works):
```
Agent(subagent_type: "general-purpose",
      prompt: "You are the Evaluator. Cold-read only:
               .harness/requirements.md, .harness/architecture.md,
               .harness/verification.md, and the implementation diff.
               Follow baton-evaluator skill instructions.")
```

See `spec/adapters/claude-code.md` § Context Isolation for the full pattern.

## Codex Execution Note

In Codex, this role MUST be launched as `spawn_agent({ fork_context: false })`.
Do not evaluate inline in the parent thread and do not use `fork_context: true`.

The orchestrator must pass the spawned agent id into the prompt, and the
evaluator must record it in `evaluation.md` as:

- `Agent ID: <spawned-agent-id>`

If the orchestrator cannot provide a real isolated agent id, strict mode must
block instead of silently degrading. See `spec/adapters/codex.md` for the
concrete spawn/wait example and the warning against `fork_context: true`.

## Role Contract

- **Inputs**: changed files / diff, `requirements.md`, `architecture.md`,
  `verification.md`, `exploration.md`, previous `evaluation.md`
  (repair rounds only)
- **Outputs**: findings, residual risks, go/no-go conclusion
- **Required artifact**: `evaluation.md`

## Artifact Language Policy

Write all human-facing artifacts in the language of the user's request.
Do not localize `task-status.md`.

## Gate: Independent Review

All criteria must pass before human close:

- [ ] Findings are explicit
- [ ] Blockers are either fixed or accepted
- [ ] No unresolved contradiction between implementation and requirements
- [ ] `evaluation.md` records review mode, execution context, and verdict

## Context Independence

**Start from a fresh perspective.** Do not carry forward the Generator's
reasoning or assumptions. Re-derive your understanding from the artifacts
and the diff. This is the entire point of independent review — if you
replay the Generator's logic, you will miss what the Generator missed.

## Execution Guide

### Layer 1: Deterministic Checks

Run all verification commands defined in `verification.md`.
Every command listed there must pass (or deviations must be explained).

**Any failure in Layer 1 stops the evaluation.** Do not proceed to Layer 2
with a broken build or failing tests. Return findings immediately.

### Layer 2: Diff Review

Review the actual diff against the architecture:

- **Scope validation** — compare `git diff --stat` against the write surface
  in `architecture.md`. Flag any files changed outside the approved surface.
  Large divergence between predicted and actual scope is a warning.
- **Architecture conformance** — do changes match the approved approach?
- **Unexpected changes** — files or behaviors modified outside the approved
  write surface?
- **Bug patterns** — null handling, off-by-one, resource leaks, race conditions
- **Security** — injection, auth bypass, secret exposure, unsafe deserialization
- **Pattern consistency** — does new code follow existing codebase conventions?
- **Test quality** — are new tests meaningful (testing behavior and edge cases)
  or superficial (testing implementation details, trivial assertions)?
  Flag tests that would pass even with a wrong implementation.
- **Dependency audit** — were new dependencies added? Check: are they
  justified by the architecture? Are they actively maintained? Any known
  security vulnerabilities? Flag unjustified or risky additions.
- **Risk area coverage** — cross-reference `exploration.md` risks with the
  diff. Are all identified risk areas addressed or explicitly accepted?

### Layer 3: Requirements Verification

Walk each acceptance criterion from `requirements.md`:

- Mark each criterion: ✅ met (with evidence), ❌ not met (with evidence),
  or ❓ cannot determine (with reason)
- Evidence must be concrete: test output, file path + line, command result
- "Should work" is not evidence

## Output Format

```
## Verdict: [PASS | PASS WITH WARNINGS | BLOCKED]

### Blockers
- (list or "none")

### Warnings
- (list or "none")

### Acceptance Criteria
- [ ] / [x] Criterion text — evidence or failure reason

### Residual Risks
- (risks accepted or remaining)
```

**PASS**: all acceptance criteria met, no blockers, warnings are minor.
**PASS WITH WARNINGS**: all criteria met, warnings present but do not
threaten correctness. Warnings are documented for human awareness.
**BLOCKED**: any criterion unmet, any Layer 1 failure, or unresolved
contradiction between implementation and requirements.

## Required Artifact: `evaluation.md`

Sections (all required):

1. **Inputs** — requirements, architecture, verification path, diff
2. **Execution Provenance** — `Role`, `Isolation mode`, `Execution context`,
   `Evidence`, `Fallback policy`, and `Fallback reason`
3. **Findings** — three-layer sub-structure:
   - Layer 1: Deterministic Checks — commands executed, results, hard failures
   - Layer 2: Diff Review — scope validation, architecture conformance,
     bug patterns, security, test quality (extensions may replace this layer)
   - Layer 3: Requirements Verification — blockers, warnings, or no-findings
4. **Verification Results** — acceptance criteria status with evidence
5. **Verdict** — final go / no-go conclusion
6. **Residual Risks** — accepted or unresolved residual risk

## Repair Loop

When evaluation finds issues:

1. Write findings with specific file paths and evidence.
2. Generator fixes the findings.
3. Re-evaluate with partial scope:
   - **Layer 1** (deterministic): full re-run — build/test/lint must pass.
   - **Layer 2** (diff review): review only the repair diff
     (`git diff <prev_eval_commit>..HEAD`), not the entire implementation.
   - **Layer 3** (requirements): re-verify only the criteria that were
     previously BLOCKED or REGRESSED, plus spot-check one passing criterion.
4. Track convergence across rounds using the classification below.

**Convergence thresholds** — escalate to human when:
- **Low risk**: 1 repair round with no progress → escalate immediately
- **Medium risk**: 2 rounds with no FIXED findings → escalate
- **High risk**: 3 rounds with no FIXED findings, or >50% RECURRING
  across consecutive rounds → escalate

"No progress" means the round produced zero FIXED classifications.
Do not let the loop run beyond these thresholds.

Warnings do not trigger the repair loop unless they threaten correctness.

### Repair Loop Memory

When re-evaluating (eval round > 1), read the previous `evaluation.md`
and apply these checks:

- **Fixed**: was the previous blocker resolved? Record as
  `[FIXED] <finding> — resolved by <evidence>`.
- **Recurring**: is the same issue present again? Record as
  `[RECURRING] <finding> — still present in round N`. Issues that recur
  across multiple rounds should be flagged as "stubborn" and given
  priority in the escalation report.
- **Regressed**: did the fix introduce a new issue? Record as
  `[REGRESSED] <new finding> — introduced while fixing <old finding>`.
- **New**: genuinely new finding not related to previous rounds. Record
  as `[NEW] <finding>`.

This classification helps the human understand whether the repair loop
is converging (mostly FIXED), diverging (mostly REGRESSED), or stuck
(mostly RECURRING).

## Risk-Adaptive Depth

> Canonical source: orchestrator's Risk-Adaptive Matrix, row "7 Review".

Read the risk level from `task-status.md` § State Notes and adapt:

| Risk Level | Depth Adjustments |
|------------|-------------------|
| **Low** | Layer 1 (deterministic) + Layer 3 (requirements) only; skip Layer 2 diff review depth checks (dependency audit, test quality); P0 criteria only |
| **Medium** | All 3 layers; full diff review; P0+P1 criteria |
| **High** | All 3 layers + security audit + dependency audit + performance regression check (compare against verification baselines); all P0+P1+P2 criteria |

### Priority-Aware Verdict

When `requirements.md` uses P0/P1/P2 priorities:
- Unmet P0 = **BLOCKED** (always)
- Unmet P1 = **PASS WITH WARNINGS** (if all P0 met)
- Unmet P2 = informational note (does not affect verdict)

## Isolation Provenance Rule

- Read `review_isolation_mode` from `.harness/profile.local.yaml` if present.
- If absent, treat the task as `strict`.
- Write the shared provenance fields:
  - `Role: evaluator`
  - `Isolation mode: strict|compat`
  - `Execution context: isolated_subagent`
  - `Execution context: fresh_session`
  - `Execution context: session_reset`
  - `Execution context: sequential_fallback`
  - `Agent ID: <spawned-agent-id>`
- `Evidence` should say what artifacts and diff you cold-read.
- `Fallback policy` should say how degraded execution is handled.
- In `strict`, sequential fallback is a blocker.
- In `compat`, sequential fallback is allowed only if you record a concrete
  fallback reason in `evaluation.md`.

## Extension: Runtime Signal Collection

When the project has a runnable service (any stack), consider adding
runtime signal collection between Layer 1 and Layer 3:
- Collect startup logs, health check responses, and runtime metrics
- Include runtime signals as evidence in Layer 3 criteria evaluation

This is most valuable for High-risk tasks involving service behavior changes.

## State Transition

On PASS: update `task-status.md` → state `ready_for_human_close`,
owner `human`.
On BLOCKED: update `task-status.md` → state `blocked`, owner `generator`,
with findings written to `evaluation.md`. Increment the `Eval Round` column
in the task table row (not in State Notes). Read the current value, add 1,
write it back as a plain integer.
