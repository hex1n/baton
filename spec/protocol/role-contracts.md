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
- Status responsibility:
  - when acting as the current owner, update `module-status.md` before handoff

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
  - when `scoped-map.md` is ready, hand off by updating `module-status.md`

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
  - update `module-status.md` when handing off to `architect` or when blocked

## Architect

- Inputs:
  - `scoped-map.md`
  - `requirements.md`
- Outputs:
  - recommended implementation category
  - file-level impact
  - validation strategy
  - known tradeoffs and residual risks
- Required artifact:
  - `architecture.md`
- Status responsibility:
  - update `module-status.md` when handing off to `human` or `verification-explorer`

## Verification Explorer

- Inputs:
  - `architecture.md`
  - repo profile
- Outputs:
  - exact commands or checks to validate the change
  - proof that the validation path is executable
  - blocking conditions if validation is not reachable
- Required artifact:
  - `verification-path.md`
- Status responsibility:
  - update `module-status.md` with `verification_check` progress or blockers

## Generator

- Inputs:
  - approved `requirements.md`
  - approved `architecture.md`
  - verified `verification-path.md`
- Outputs:
  - code changes
  - local execution notes
  - updated `module-status.md`
- Status responsibility:
  - keep `module-status.md` current during implementation and before handoff to review

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
  - update `module-status.md` with review outcome or blocker status

## Evaluator

- Inputs:
  - implementation diff
  - review findings
  - verification results
- Outputs:
  - go/no-go style conclusion
  - unmet acceptance criteria
  - final residual risk statement
- Status responsibility:
  - update `module-status.md` before handoff to `human`

## Human

- Responsibilities:
  - approve architecture direction
  - accept or reject residual risks
  - decide when blocked tasks should resume
  - confirm completion

## Shared Rule

- `start-task` initializes a task row.
- After that point, the current owner agent updates `module-status.md` as part of normal task execution.
- A helper script may exist in a local repo, but the protocol does not require one for ordinary state transitions.
