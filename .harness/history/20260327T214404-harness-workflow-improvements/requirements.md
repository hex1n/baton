# Requirements: harness-workflow-improvements

**Topic**: Retrospective-driven Baton Harness workflow improvements
**Status**: `complete`
**Sizing**: `Medium`

## 1. Problem

The previous task retrospective exposed four repeatable workflow failures:

1. `requirements.md` could be finalized before architecture decisions were frozen, so Gate 3 was catching contradictions that should have been prevented at Gate 2.
2. Context isolation rules were misapplied. The workflow incurred early-stage friction while the highest-value independent judgment points were Gate 3 (Verifier) and Gate 4 (Evaluator).
3. Runtime tokens and lightweight protocol schema were still partially duplicated across scripts and docs, so drift remained possible even after `owners.txt` was introduced.
4. `sync-skills.sh` treated `.link-mode` as ground truth, which breaks in fresh clones where git materializes expected symlinks as ordinary file copies.

## 2. Scope

### 2.1 In Scope

- Updating the portable harness protocol docs so Gate 2 explicitly requires requirements sync after approved architecture decisions.
- Updating role skills so responsibilities match that gate behavior and the refined isolation policy.
- Centralizing remaining bootstrap state tokens into machine-readable sources consumed by scripts.
- Updating invariant checks and skill sync behavior so these workflow rules are mechanically enforced.
- Updating user-facing docs where the day-to-day workflow changes.
- Adding concrete Codex sub-agent execution examples for Verifier and Evaluator so operators can run isolated `spawn_agent({ fork_context: false })` flows, not just read abstract guidance.

### 2.2 Out of Scope

- Adding a fully automated orchestrator or scheduler.
- Changing the one-active-task-per-workspace invariant.
- Redesigning the role model beyond the workflow clarifications surfaced in the retrospective.
- Introducing backward-compatibility shims for deprecated workflow variants unless required by the current repo state.

## 3. Functional Requirements

### FR-1 Gate 2 Requirements Sync

- The protocol must require that `requirements.md` reflects every approved architecture decision that affects requirements-level truth before the task may enter verification.
- This requirement must be visible in the portable protocol, not only in one adapter or one skill.

### FR-2 Isolation At The Right Gates

- The workflow must make Verifier and Evaluator the mandatory context-isolated roles for task execution.
- The workflow must stop treating early-phase roles as universally isolation-required when same-session execution is acceptable and lower friction.
- Adapter guidance must explain how Verifier/Evaluator isolation is achieved in Codex and generic CLI environments.

### FR-3 Canonical Runtime Tokens

- Runtime token sets consumed by bootstrap scripts must live in machine-readable source files under `spec/protocol/`.
- `start-task.sh` and `start-task.ps1` must load valid state tokens from the canonical source rather than hardcoding them.
- Consistency checks must validate these canonical sources against the places that consume them.

### FR-4 Actual Skill-Link Detection

- `sync-skills.sh` must determine whether syncing is needed by inspecting the actual filesystem relationship between `skills/` and the mirrored copies, rather than trusting `.link-mode` alone.
- When targets are real symlinks or hardlinks, the script may no-op.
- When targets are plain file copies, the script must sync even if `.link-mode` claims the intended mode is `symlink`.

### FR-5 Preflight Coverage For Workflow Drift

- The existing consistency preflight must cover the new canonical token source and continue catching mirrored-skill drift before Generator begins work.
- The workflow documentation must make that preflight part of the recommended path before or during verification.

### FR-6 Concrete Codex Sub-Agent Examples

- Codex-facing docs must show an end-to-end isolated execution pattern for Verifier and Evaluator using `spawn_agent({ fork_context: false })`.
- The examples must show what inputs are passed, what must not be inherited, and how `wait_agent` is used without turning the workflow into a blocking-by-default loop.
- At least one user-facing entry point outside the adapter doc must tell the operator where to find or how to use these examples.

## 4. Non-Goals

- Adding a new canonical workflow state solely for the requirements sync pass.
- Turning retrospective writing into a separate scheduler feature.
- Enforcing every role transition through a helper script instead of direct `module-status.md` edits.

## 5. Acceptance Criteria

### AC-1 Gate 2 Sync Is Explicit

- [ ] `spec/protocol/gates.md` states that Gate 2 passes only when `requirements.md` reflects all approved architecture decisions that affect requirements truth.
- [ ] At least one role-skill path covering Specifier, Architect, or Verifier tells the operator to perform this sync before verification begins.

### AC-2 Isolation Policy Matches The Retrospective

- [ ] `skills/harness-verifier.md` and `skills/harness-evaluator.md` require isolated cold-read execution.
- [ ] `skills/harness-explorer.md` no longer forces `context: fork`.
- [ ] `spec/adapters/codex.md` and `spec/adapters/cli-adapter-interface.md` document Verifier/Evaluator isolation without requiring the same for early-phase roles.

### AC-3 State Tokens Have A Single Source

- [ ] A machine-readable `spec/protocol/states.txt` exists and lists the canonical states.
- [ ] `spec/bootstrap/start-task.sh` and `spec/bootstrap/start-task.ps1` validate input state tokens against `states.txt`.
- [ ] Consistency tooling checks the canonical token files without relying on duplicated literals as the source of truth.

### AC-4 Skill Sync Uses Actual File State

- [ ] `spec/bootstrap/sync-skills.sh` inspects the actual target files and distinguishes `symlink`, `hardlink`, and `copy`.
- [ ] In a workspace where mirrored skills are copies, running the script produces sync writes instead of incorrectly reporting "no sync needed."

### AC-5 Workflow Docs Reflect The New Operating Model

- [ ] `README.md` or `spec/README.md` explains the updated Gate 2 behavior and points operators to the consistency preflight.
- [ ] The documented workflow still preserves one active task per workspace and human approval before verification.

### AC-6 Codex Sub-Agent Examples Are Actionable

- [ ] `spec/adapters/codex.md` contains a concrete Verifier example using `spawn_agent({ fork_context: false })` and a corresponding `wait_agent` handoff pattern.
- [ ] `spec/adapters/codex.md` contains a concrete Evaluator example using explicit artifact inputs and forbids `fork_context: true`.
- [ ] `skills/harness-verifier.md` or `skills/harness-evaluator.md` includes a concise Codex execution note pointing operators to the isolated sub-agent pattern.
- [ ] `README.md` points Codex users to the adapter example instead of leaving sub-agent execution implicit.

## 6. Constraints

- Preserve cross-platform behavior between Bash and PowerShell bootstrap scripts.
- Keep the protocol tool-agnostic unless a requirement is explicitly adapter-specific.
- Avoid destructive relinking or replacing user workspace layout as part of ordinary sync.
- Prefer low-complexity enforcement over introducing a new scheduler/state machine unless the existing model cannot express the fix.

## 7. Validation Intent

- Use `check-consistency.sh` as the protocol preflight after code/doc changes land.
- Dry-run both `start-task.sh` and `start-task.ps1` to prove canonical owner/state token loading still works.
- Run `sync-skills.sh` in the current workspace to prove actual file-state detection chooses sync behavior correctly.
- Review the updated docs and role skills to confirm Gate 2 sync and isolation responsibilities are aligned across spec and implementation.
- Grep the adapter / README / skill docs for `spawn_agent`, `wait_agent`, and `fork_context` to confirm the concrete Codex examples are present and consistent.
