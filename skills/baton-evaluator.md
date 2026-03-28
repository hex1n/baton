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
3. Read `.harness/verification-path.md`
4. Read the implementation diff (`git diff HEAD~1` or as provided)

Do not read Generator execution notes or inherit conversation history.

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
               .harness/verification-path.md, and the implementation diff.
               Follow baton-evaluator skill instructions.")
```

See `spec/adapters/claude-code.md` § Context Isolation for the full pattern.

## Codex Execution Note

In Codex, launch this role as `spawn_agent({ fork_context: false })` and allow
it to cold-read only the approved artifacts plus the implementation diff. See
`spec/adapters/codex.md` for the concrete spawn/wait example and the warning
against `fork_context: true`.

## Role Contract

- **Inputs**: changed files / diff, `requirements.md`, `architecture.md`,
  `verification-path.md`
- **Outputs**: findings, residual risks, go/no-go conclusion

## Artifact Language Policy

Before writing any human-facing artifact:

1. If `.harness/profile.local.yaml` sets `documentation.artifact_language` to
   `zh` or `en`, use that language.
2. If it is `auto`, follow the current user request language.
3. If the setting is missing, default to Chinese.

Do not localize `module-status.md`. Keep the control-plane file, owner tokens,
state tokens, and blocker categories in stable English.

## Gate: Independent Review

All criteria must pass before human close:

- [ ] Findings are explicit
- [ ] Blockers are either fixed or accepted
- [ ] No unresolved contradiction between implementation and requirements

## Context Independence

**Start from a fresh perspective.** Do not carry forward the Generator's
reasoning or assumptions. Re-derive your understanding from the artifacts
and the diff. This is the entire point of independent review — if you
replay the Generator's logic, you will miss what the Generator missed.

## Execution Guide

### Layer 1: Deterministic Checks

Run the verification commands from `verification-path.md`:

- Compile / build → must pass
- Test suite → must pass
- Lint / static analysis → must pass (or deviations explained)

**Any failure in Layer 1 stops the evaluation.** Do not proceed to Layer 2
with a broken build or failing tests. Return findings immediately.

### Layer 2: Diff Review

Review the actual diff against the architecture:

- **Architecture conformance** — do changes match the approved approach?
- **Unexpected changes** — files or behaviors modified outside the approved
  write surface?
- **Bug patterns** — null handling, off-by-one, resource leaks, race conditions
- **Security** — injection, auth bypass, secret exposure, unsafe deserialization
- **Pattern consistency** — does new code follow existing codebase conventions?

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

## Repair Loop

When evaluation finds issues:

1. Write findings with specific file paths and evidence.
2. Generator fixes the findings.
3. Re-evaluate from Layer 1 (full re-run, not incremental).
4. After **3 consecutive BLOCKED rounds**, escalate to human — the repair
   loop is not converging and needs human judgment.

Warnings do not trigger the repair loop unless they threaten correctness.

## Extension: java-backend-strict

When working with the java-backend-strict extension, add runtime signal
collection between Layer 1 and Layer 3:
- Collect startup logs, health check responses, and runtime metrics
- Include runtime signals as evidence in Layer 3 criteria evaluation

## State Transition

On PASS: update `module-status.md` → state `ready_for_human_close`,
owner `human`.
On BLOCKED: update `module-status.md` → state `blocked`, owner `generator`,
with findings written to evaluation output. Increment the eval round counter
in the State Notes section of `module-status.md` (format: `Current eval round: N`).
