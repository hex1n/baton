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

Judgment prompts (present to human before approval decision; answering is optional):

1. Does this approach remind you of a previous change? How did that go?
2. If something feels off but you cannot articulate it, which part triggers that sense?
3. Which assumption in this architecture worries you most?

If the human provides annotations, persist them in `architecture.md` § Human
Judgment Notes. Annotations are archived with the task and available for
retrospective analysis but are not consumed by automated roles.

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

## Escalation Advisory

When a blocker at the same stage recurs twice without resolution, the
current owner must evaluate whether the root cause is at a higher level
(L3: premise). If so, categorize as `premise_blocker` and route to
`specifying` or `exploring` rather than retrying at the current level.

See `state-machine.md` § Escalation Advisory for transition rules.

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

Judgment prompts (present to human before close decision; answering is optional):

1. Based on your knowledge of this codebase, what is the biggest implicit risk this change introduces?
2. Does any residual risk feel more serious than `evaluation.md` describes?
3. If this change fails in production, what is the most likely failure mode?

If the human provides annotations, persist them in `evaluation.md` § Human
Judgment Notes.
