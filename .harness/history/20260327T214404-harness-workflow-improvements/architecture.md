# Architecture: harness-workflow-improvements

**Topic**: Retrospective-driven Baton Harness workflow improvements
**Status**: `approved`
**Sizing**: `Medium`

## 1. Problem

The harness currently leaks three kinds of workflow ambiguity:

- Gate 2 does not explicitly force `requirements.md` to absorb approved architecture decisions before verification begins.
- Isolation guidance is aimed at the wrong phases, adding friction early while leaving Gate 3 policy under-specified.
- Remaining runtime token/schema duplication and link-mode assumptions allow scripts to drift from the actual workspace state.
- Codex guidance says Verifier / Evaluator should be isolated, but it still lacks an operator-facing example that shows how to actually launch and reap those sub-agents.

## 2. First-Principles

### 2.1 Problem Statement

The fix should make the workflow safer by tightening handoffs, not by adding a second orchestration layer. The protocol already has gates, artifacts, and status transitions; the missing piece is better alignment between protocol docs, role skills, and enforcement scripts.

### 2.2 Constraints

- Do not add a scheduler or automation layer.
- Preserve the existing canonical states unless a new state is strictly necessary.
- Keep Bash and PowerShell bootstrap flows aligned.
- Keep the protocol portable; adapter details belong in adapter docs.
- Avoid destructive workspace mutations when fixing mirrored skill propagation.

### 2.3 Solution Categories

- Category A: introduce a new canonical `requirements_sync` state and expand the state machine.
- Category B: keep the existing states, but make Gate 2 explicitly require a requirements sync pass and enforce the supporting rules in docs, skills, and scripts.
- Category C: patch only the user docs and leave scripts / skill enforcement unchanged.

### 2.4 Evaluation

- Why Category B wins:
  - It fixes the retrospective's actual failure mode at the gate boundary without adding new lifecycle complexity.
  - It keeps the protocol portable and lightweight while still adding machine-checkable enforcement where drift was observed.
  - It lets isolation policy and token sources be corrected in the same pass.
- Why Category A is rejected:
  - A new state would add more transition logic, more mirrored literals, and more update burden than the problem justifies.
  - The retrospective showed a gate checklist failure, not an inability to represent workflow state.
- Why Category C is rejected:
  - The repo already proved that docs-only alignment is insufficient; script/runtime drift still caused incorrect behavior.

## 3. Recommended Architecture

- Approach:
  - Treat the Requirements Sync Pass as a mandatory Gate 2 checklist item, not a new state.
  - Make Verifier and Evaluator the explicitly isolated judgment roles.
  - Centralize remaining runtime tokens in `spec/protocol/` and consume them from bootstrap scripts.
  - Make consistency/sync scripts inspect real workspace state instead of relying on intended state markers.
- Confirmed decisions:
  - D1: no new canonical state for requirements sync
  - D2: Verifier and Evaluator are the mandatory isolated roles; Explorer returns to normal same-session default
  - D3: `states.txt` joins `owners.txt` as a machine-readable source of truth
  - D4: `.link-mode` becomes advisory metadata, not the deciding signal for `sync-skills.sh`
  - D5: document concrete Codex `spawn_agent` / `wait_agent` examples in adapter + skill + README guidance rather than introducing a helper wrapper script
- Key change points:
  - protocol docs: `gates.md`, `role-contracts.md`, `state-machine.md`, `artifact-schema.md`
  - adapter docs: `spec/adapters/codex.md`, `spec/adapters/cli-adapter-interface.md`
  - skills: `harness-explorer`, `harness-specifier`, `harness-architect`, `harness-verifier`, `harness-evaluator`
  - bootstrap/enforcement: `start-task.{sh,ps1}`, `check-consistency.sh`, `sync-skills.sh`
  - user docs: `README.md`, optionally `spec/README.md`
- Data/control boundaries:
  - `spec/protocol/*.txt` holds canonical token sets
  - role skills consume protocol decisions and describe operator behavior
  - bootstrap scripts enforce token validity
  - `check-consistency.sh` verifies repository invariants before/during verification
- Backward-compatibility notes:
  - existing state names remain unchanged
  - `start-task` interface remains the same; only validation moves to token files
  - mirrored skill directories continue to work regardless of whether the workspace uses symlinks, hardlinks, or copies

## 4. Surface Scan

| File | Level | Disposition | Reason |
|---|---|---|---|
| `spec/protocol/gates.md` | L1 | modify | add the Gate 2 requirements sync rule |
| `spec/protocol/role-contracts.md` | L1 | modify | clarify Specifier/Architect/Verifier responsibilities and isolation roles |
| `spec/protocol/state-machine.md` | L1 | modify | clarify that requirements sync happens before `verification_check` without adding a state |
| `spec/protocol/artifact-schema.md` | L2 | modify | document decision records / generator-feedback usage if needed for upstream correction |
| `spec/protocol/states.txt` | L1 | add | canonical state tokens for bootstrap scripts |
| `spec/adapters/cli-adapter-interface.md` | L1 | modify | narrow mandatory isolation to Verifier/Evaluator |
| `spec/adapters/codex.md` | L1 | modify | add runnable Verifier/Evaluator `spawn_agent` examples and waiting guidance |
| `skills/harness-explorer.md` | L1 | modify | remove forced fork and align role guidance |
| `skills/harness-specifier.md` | L1 | modify | require unresolved decision tracking and post-approval requirements sync |
| `skills/harness-architect.md` | L1 | modify | require explicit decision handoff and sync confirmation before verification |
| `skills/harness-verifier.md` | L1 | modify | require isolated cold-read, check requirements/architecture alignment first, and point Codex users to the adapter example |
| `skills/harness-evaluator.md` | L1 | modify | keep isolation and point Codex users to the adapter example |
| `spec/bootstrap/start-task.sh` | L1 | modify | load states from `states.txt` |
| `spec/bootstrap/start-task.ps1` | L1 | modify | load states from `states.txt` |
| `spec/bootstrap/check-consistency.sh` | L1 | modify | validate owners/states token sources and mirrored skill parity |
| `spec/bootstrap/sync-skills.sh` | L1 | modify | detect actual link/copy state before deciding to sync |
| `README.md` | L2 | modify | update operator-facing workflow wording |
| `spec/README.md` | L2 | optional modify | mirror README workflow wording if needed |

## 5. Validation Strategy

- Primary checks:
  - `bash spec/bootstrap/check-consistency.sh`
  - `bash spec/bootstrap/start-task.sh --repo-root . --task-id verify-workflow --owner scoped-explorer --state exploring --notes "verification probe" --dry-run`
  - `pwsh ./spec/bootstrap/start-task.ps1 -RepoRoot . -TaskId verify-workflow -Owner scoped-explorer -State exploring -Notes "verification probe" -DryRun`
  - `bash spec/bootstrap/sync-skills.sh`
  - `rg -n "spawn_agent|wait_agent|fork_context" README.md spec/adapters/codex.md skills/harness-verifier.md skills/harness-evaluator.md`
- Review focus:
  - protocol docs and role skills say the same thing about Gate 2 and isolation
  - bootstrap scripts read canonical token sources rather than hardcoded lists
  - sync behavior depends on actual file state
- Risks that validation cannot fully eliminate:
- docs may still drift later if future changes skip `check-consistency.sh`
- adapter semantics outside Codex/Claude may still need manual interpretation
- example snippets can drift if the underlying Codex tool signature changes and the docs are not updated with it

## 6. Risks

- `sync-skills.sh` mode detection could misclassify unusual filesystem behavior if symlink/hardlink checks are too naive.
- Adding `states.txt` reduces drift only if all bootstrap consumers are updated in the same task.
- README-only wording changes will not help if mirrored skill copies remain stale; sync must be part of verification.
- Example snippets may encourage copy-paste use of `wait_agent` even when the caller is not actually blocked, so the docs should explain the constraint explicitly.

## 7. Self-Challenge

1. Is this the best category, or only the first workable one?
   - Best category for v1. The retrospective does not justify state-machine expansion yet.
2. Which assumptions remain unverified?
   - That `pwsh` is present locally and that `sync-skills.sh` can reliably infer mode from the current workspace layout.
3. What would a skeptic challenge first?
   - Whether a Gate 2 checklist item is strong enough without a new state. The answer depends on script/skill enforcement being updated in the same patch.
