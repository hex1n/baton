# Role Contracts

## Repo Explorer

- Use when: first harness adoption in a repository
- Inputs:
  - repo root
  - repo profile
- Outputs:
  - repo map
  - high-risk directories
  - default verification entry points
- Typical artifact:
  - optional `repo-map.md`
  - conditionally required `codebase-map.md` (when running in repo-wide mode)
- Status responsibility:
  - when acting as the current owner, update `task-status.md` before handoff

## Scoped Explorer

- Use when: every concrete feature or bug task
- Inputs:
  - user request
  - repo map or local repo context
- Outputs:
  - task-local call chain
  - direct change surfaces
  - test landing points
  - risk notes
- Required artifact:
  - `scoped-map.md`
- Status responsibility:
  - when `scoped-map.md` is ready, hand off by updating `task-status.md`

## Specifier

- Inputs:
  - user request
  - `scoped-map.md`
- Outputs:
  - in-scope and out-of-scope boundaries
  - functional requirements
  - acceptance criteria
- Required artifact:
  - `requirements.md`
- Status responsibility:
  - update `task-status.md` when handing off to `architect` or when blocked
  - when approved architecture decisions change requirements-level truth,
    update `requirements.md` before verification begins

## Architect

- Inputs:
  - `scoped-map.md`
  - `requirements.md`
- Outputs:
  - recommended implementation category
  - confirmed decisions that affect requirements truth
  - file-level impact
  - validation strategy
  - known tradeoffs and residual risks
- Required artifact:
  - `architecture.md`
  - conditionally required `decisions.md` (when architecture contains rejected alternatives)
- Status responsibility:
  - update `task-status.md` when handing off to `human` or `verification-explorer`
  - do not hand off to `verification-explorer` until `requirements.md`
    reflects approved architecture decisions

## Verification Explorer

- Inputs:
  - `requirements.md`
  - `architecture.md`
  - repo profile
- Outputs:
  - proof that `requirements.md` and `architecture.md` agree on what will
    be validated
  - exact commands or checks to validate the change
  - proof that the validation path is executable
  - blocking conditions if validation is not reachable
- Required artifact:
  - `verification-path.md`
- Status responsibility:
  - update `task-status.md` with `verification_check` progress or blockers

## Generator

- Inputs:
  - approved `requirements.md`
  - approved `architecture.md`
  - verified `verification-path.md`
- Outputs:
  - code changes
  - local execution notes
  - updated `task-status.md`
- Status responsibility:
  - keep `task-status.md` current during implementation and before handoff to review

## Reviewer

- Inputs:
  - changed files
  - `requirements.md`
  - `architecture.md`
- Outputs:
  - findings first
  - residual risks
  - explicit "no findings" if applicable
- Status responsibility:
  - update `task-status.md` with review outcome or blocker status

## Evaluator

- Inputs:
  - implementation diff
  - review findings
  - verification results
- Outputs:
  - go/no-go style conclusion
  - unmet acceptance criteria
  - final residual risk statement
- Required artifact:
  - `evaluation.md`
- Status responsibility:
  - update `task-status.md` before handoff to `human`

## Context Isolation Note

- `Verification Explorer` and `Evaluator` are the mandatory artifact-isolated
  judgment roles in `strict` mode.
- Repos may opt into `compat` mode, but only if the produced artifacts make the
  degraded execution context explicit.
- Early-phase roles may run in the main session when their outputs remain
  explicit in `.harness/`.

## Implementation Note: Reviewer + Evaluator Merge

In single-agent CLI environments, Reviewer and Evaluator MAY be merged into a
single role only when the chosen mode still satisfies the isolation policy
(`strict` isolated context, or explicit `compat` fallback).

Conditions for valid merge:
- The merged role must maintain context independence (see `cli-adapter-interface.md`)
- Findings must still be explicit before go/no-go conclusion
- The merge must be documented in the adapter's role execution section

When sub-agents are available, keeping them separate is preferred —
Reviewer can run in parallel with final Generator cleanup.

## Human

- Responsibilities:
  - approve architecture direction
  - accept or reject residual risks
  - decide when blocked tasks should resume
  - confirm completion

## Shared Rule

- `start-task` initializes a task row.
- After that point, the current owner agent updates `task-status.md` as part of normal task execution.
- A helper script may exist in a local repo, but the protocol does not require one for ordinary state transitions.
