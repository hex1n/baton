# Provenance Standardization Hardening Plan

**Goal:** Turn verifier / evaluator provenance from “present in some form” into a stable, shared interface that validators, status surfaces, and human close can all consume reliably.

**Scope:** Portable core only. This task standardizes provenance schema, adds a shared reader, exposes provenance/verdict at human-close, and codifies coupling checks. It does not add runtime telemetry or change the state machine.

**Key decision:** Use one shared provenance block for independent-judgment artifacts, with fixed field names and one shared bootstrap reader.

---

## Workstream 1: Shared Provenance Contract

- Add a standard provenance block to artifact schema.
- Make `verification-path.md` and `evaluation.md` use the same section name.
- Fix the field names across both artifacts.

## Workstream 2: Shared Reader

- Add a bootstrap helper for provenance field reads and normalization.
- Move `validate-isolation.sh` to the shared helper.
- Reuse the same helper in status surfaces.

## Workstream 3: Human-Close Visibility

- Enhance `harness-context.sh` to show:
  - verifier isolation mode / execution context
  - evaluator isolation mode / execution context
  - evaluator verdict
- Align `skills/baton-status.md` with that behavior.

## Workstream 4: Coupling Invariants

- Extend `check-consistency.sh` so provenance hardening cannot drift silently:
  - templates
  - validator
  - start-task reset
  - tests

## Workstream 5: Verification

- `bash tests/test-validate-artifact.sh`
- `bash tests/test-validate-isolation.sh`
- `bash tests/test-harness-context.sh`
- `bash tests/test-start-task.sh`
- `bash spec/bootstrap/check-consistency.sh`
- live `.harness/` artifact / state / isolation validation
