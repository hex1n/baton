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
- Required artifact: `scoped-map.md`

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

### `verification_check`

- Active owner: `verification-explorer` or `architect`
- Goal: prove the intended verification path is executable
- Required artifact: `verification-path.md`

### `generating`

- Active owner: `generator`
- Goal: implement approved changes in the target workspace or worktree

### `reviewing`

- Active owner: `reviewer` or `evaluator`
- Goal: independently assess correctness, regressions, and coverage

### `blocked`

- Active owner: whoever surfaced the blocker
- Goal: stop unsafe forward progress and make the blocker explicit
- Blockers should be categorized:
  - `verification_blocker`
  - `scope_blocker`
  - `environment_blocker`
  - `design_blocker`

### `ready_for_human_close`

- Active owner: `human`
- Goal: accept residual risk and confirm the task can be closed

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
```

## Rules

1. Only one state may be active per task.
2. `blocked` must include a concrete reason and next decision needed.
3. `complete` requires human confirmation.
4. If verification assumptions change materially, return to `verification_check`.
5. Portable harness v1 assumes one non-complete active task per workspace. Use another worktree or clone for parallel tasks.
6. `start-task` initializes the task row only. Ordinary state transitions are performed by the current owner agent updating `module-status.md`.
