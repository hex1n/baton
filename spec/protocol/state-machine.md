# State Machine

## Canonical States

- `exploring`
- `specifying`
- `architecting`
- `awaiting_human_arch`
- `verification_check`
- `generating`
- `reviewing`
- `blocked`
- `ready_for_human_close`
- `complete`

## State Semantics

### `exploring`

- Active owner: `repo-explorer` or `scoped-explorer`
- Goal: establish repo map or task-local map
- Required artifact: `exploration.md`

### `specifying`

- Active owner: `specifier`
- Goal: convert findings and user intent into explicit requirements
- Required artifact: `requirements.md`

### `architecting`

- Active owner: `architect`
- Goal: convert requirements into an implementation approach and verification strategy
- Required artifact: `architecture.md`

### `awaiting_human_arch`

- Active owner: `human`
- Goal: approve or reject architecture direction
- Required artifacts: `requirements.md`, `architecture.md`
- Exit condition: approved architecture decisions that change
  requirements-level truth have been synced back into `requirements.md`

### `verification_check`

- Active owner: `verification-explorer` or `architect`
- Goal: prove the intended verification path is executable
- Required artifacts: `requirements.md`, `architecture.md`, `verification.md`

### `generating`

- Active owner: `generator`
- Goal: implement approved changes in the target workspace or worktree

### `reviewing`

- Active owner: `reviewer` or `evaluator`
- Goal: independently assess correctness, regressions, and coverage
- Exit artifact before human close: `evaluation.md`

### `blocked`

- Active owner: whoever surfaced the blocker
- Goal: stop unsafe forward progress and make the blocker explicit
- Blockers should be categorized by level:
  - `verification_blocker` — validation path broken (L1: execution)
  - `environment_blocker` — toolchain/infra issue (L1: execution)
  - `scope_blocker` — scope assumptions invalid (L2: design)
  - `design_blocker` — architecture approach flawed (L2: design)
  - `premise_blocker` — task premise or requirements themselves are suspect;
    cannot be resolved by retrying at architecture or generation level
    (L3: intent — requires re-examination of problem framing)

### `ready_for_human_close`

- Active owner: `human`
- Goal: accept residual risk and confirm the task can be closed
- Required artifacts: `requirements.md`, `architecture.md`, `verification.md`, `evaluation.md`

### `complete`

- Active owner: none
- Goal: mark the closed loop complete

## Allowed Transitions

```text
exploring -> specifying
specifying -> architecting
architecting -> awaiting_human_arch
awaiting_human_arch -> verification_check
verification_check -> generating
generating -> reviewing
reviewing -> ready_for_human_close
ready_for_human_close -> complete
any -> blocked
blocked -> verification_check
blocked -> architecting
blocked -> generating
blocked -> specifying
blocked -> exploring
```

## Interpretation

The harness has a linear happy path and explicit repair loops.

Happy path:

```text
exploring -> specifying -> architecting -> awaiting_human_arch
-> verification_check -> generating -> reviewing
-> ready_for_human_close -> complete
```

Repair loops:

```text
verification_check -> blocked -> architecting
verification_check -> blocked -> verification_check
generating -> blocked -> architecting
generating -> blocked -> generating
reviewing -> blocked -> generating -> reviewing
```

Premise escalation loops (L3 — premise_blocker only):

```text
blocked (premise) -> specifying -> architecting -> ...
blocked (premise) -> exploring -> specifying -> ...
```

The protocol keeps the main path readable and uses `blocked` plus explicit
re-entry points to represent repair, escalation, and retry.

## Escalation Advisory

When the same blocker category occurs twice in the same stage without
resolution, the blocked state owner should consider:
- Whether the blocker is actually a `premise_blocker`
- Advising the human that requirements or problem framing may need
  re-examination rather than another same-level retry

## Rules

1. Only one state may be active per task.
2. `blocked` must include a concrete reason and next decision needed.
3. `complete` requires human confirmation.
4. Before entering `verification_check`, `requirements.md` must reflect
   approved architecture decisions that affect requirements truth.
5. If verification assumptions change materially, return to `verification_check`.
6. Portable harness v1 assumes one non-complete active task per workspace. Use another worktree or clone for parallel tasks.
7. `start-task` initializes the task row only. Ordinary state transitions are performed by the current owner agent updating `task-status.md`.
