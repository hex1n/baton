# Gates

## Gate 1: Scoped Exploration Complete

Required before `Specifier`.

Pass criteria:

- primary entry points identified
- likely write surface identified
- test landing points identified
- high-risk directories called out

## Gate 2: Architecture Approved

Required before `Verification Path Check`.

Pass criteria:

- requirements and architecture are internally consistent
- `requirements.md` reflects every approved architecture decision that changes
  requirements-level truth before verification begins
- main approach and rejected categories are visible
- human has approved the direction

## Gate 3: Verification Path Check

Required before `Generator`.

Pass criteria:

- `requirements.md` and `architecture.md` contain no unresolved contradiction
- exact validation commands or checks are listed
- commands are executable in the current repo context
- verification isolation mode is declared
- verification execution context is declared
- toolchain blockers are known
- fallback validation is defined if the primary path is unavailable
- consistency preflight has passed or an explicit blocker has been recorded

Fail criteria:

- test/build chain is unknown
- validation path is blocked by unresolved environment or repo issues
- task is `strict` but verification can only run as `sequential_fallback`
- generator would be forced to implement without a realistic verification path

## Gate 4: Independent Review

Required before `ready_for_human_close`.

Pass criteria:

- findings are explicit
- blockers are either fixed or accepted
- no unresolved contradiction remains between implementation and requirements
- `evaluation.md` exists with verdict and execution context
- task is not claiming `strict` review while recording `sequential_fallback`

## Gate 5: Human Close

Required before `complete`.

Pass criteria:

- human accepts current residual risk
- human agrees the task objective has been met
