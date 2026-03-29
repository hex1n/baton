# Module-Status Control Plane Hardening Plan

**Goal:** Close the concrete P0 gap identified in `docs/review-analysis.md` by making `module-status.md` a stable control plane with one shared row-selection contract across bootstrap, hooks, session context, validators, and status/reporting surfaces.

**Scope:** Baton core control-plane hardening only. No new workflow concepts, no Java strict expansion, no scheduler/orchestrator work.

**Key decision:** Define the **current task row** as the **last data row** in the `module-status.md` task table. All readers and writers must use that same rule. Legacy 5-column rows must still be readable during migration, with `Eval Round = 0` as the compatibility default.

---

## Workstream 1: Contract

- Add one shared parsing implementation for `module-status.md`.
- Support both schemas during read:
  - legacy: `Scope | Owner | State | Updated At | Notes`
  - current: `Scope | Owner | State | Eval Round | Updated At | Notes`
- Normalize parsed rows to one shape:
  - `scope`
  - `owner`
  - `state`
  - `eval_round`
  - `updated_at`
  - `notes`

## Workstream 2: Runtime Readers

- Move `harness-context.sh` to the shared parser.
- Move `validate-state-artifacts.sh` to the shared parser.
- Move hook-generated transition/state reads in `install-hooks.sh` to the shared parser.
- Keep current behavior, but make it operate on the last data row instead of the first.

## Workstream 3: Bootstrap + Migration

- Fix `start-task.sh` so it can read legacy live `module-status.md` files without dropping history rows.
- Fix `start-task.ps1` with the same compatibility behavior.
- Ensure new writes always materialize the current schema with `Eval Round`.

## Workstream 4: Checks

- Extend `check-consistency.sh` to validate the live `.harness/module-status.md` shape when present.
- Add tests that lock in:
  - latest-row semantics
  - legacy-schema compatibility
  - preserved behavior for validators and hooks

## Workstream 5: Spec / Skill Documentation

- Document the current-row rule in the spec/bootstrap layer.
- Update `skills/baton-status.md` so it explicitly reads the last task row.

---

## Verification

- `bash tests/test-harness-context.sh`
- `bash tests/test-validate-state-artifacts.sh`
- `bash tests/test-validate-transition.sh`
- `bash tests/test-install-hooks.sh`
- `bash spec/bootstrap/check-consistency.sh`

If hook configs drift after script changes, re-run:

```bash
bash spec/bootstrap/install-hooks.sh --repo-root . --bootstrap-dir spec/bootstrap
```

---

## Exit Condition

The task is ready for human close when:

- one shared parser/contract exists
- runtime readers and hooks use it
- live `module-status.md` is migrated to the new schema
- tests prove latest-row semantics and legacy compatibility
- `check-consistency.sh` can fail on a broken live control plane
