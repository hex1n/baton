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
- main approach and rejected categories are visible
- human has approved the direction

## Gate 3: Verification Path Check

Required before `Generator`.

Pass criteria:

- exact validation commands or checks are listed
- commands are executable in the current repo context
- toolchain blockers are known
- fallback validation is defined if the primary path is unavailable

Fail criteria:

- test/build chain is unknown
- validation path is blocked by unresolved environment or repo issues
- generator would be forced to implement without a realistic verification path

## Gate 4: Independent Review

Required before `ready_for_human_close`.

Pass criteria:

- findings are explicit
- blockers are either fixed or accepted
- no unresolved contradiction remains between implementation and requirements

## Gate 5: Human Close

Required before `complete`.

Pass criteria:

- human accepts current residual risk
- human agrees the task objective has been met
