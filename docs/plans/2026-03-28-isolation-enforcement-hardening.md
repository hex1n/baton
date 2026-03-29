# Isolation Enforcement Hardening Plan

**Goal:** Close the protocol gap where Baton requires isolated verifier/evaluator roles in principle, but still allows same-thread execution to pass as if the requirement were satisfied.

**Scope:** Portable core only. This task hardens spec, templates, skill contracts, and bootstrap/runtime validation around isolation evidence. It does not introduce a heavy orchestrator, background daemon, or Java-strict-specific runtime.

**Key decision:** Baton should distinguish between two explicit execution modes:

- `strict`: verifier and evaluator must run in isolated contexts; inability to do so is a blocker
- `compat`: sequential fallback is allowed, but it must be explicitly declared and surfaced as degraded independence

---

## Workstream 1: Protocol Alignment

- Update the adapter interface so `strict` and `compat` are explicit protocol modes.
- Remove the current ambiguity where one document says isolation is mandatory while another still treats sequential fallback as generally valid.
- Align Codex and Claude adapters to the same rule.

## Workstream 2: Artifact Provenance

- Extend `verification-path.md` so Gate 3 records:
  - isolation mode
  - execution context
  - explicit fallback reason when degraded
- Promote `evaluation.md` from optional to conditionally required before human close.
- Require evaluator output to capture the same isolation provenance and a final verdict.

## Workstream 3: Runtime Enforcement

- Add a dedicated validator that checks isolation declarations against the current task state.
- Make stop hooks run both state-artifact validation and isolation validation.
- Require `evaluation.md` before `ready_for_human_close` and `complete`.

## Workstream 4: User-Facing Governance

- Update root governance so the human-facing rule is no longer vague "context isolation", but a concrete rule about which roles must be isolated and what happens if isolation is unavailable.
- Add profile knobs for verification/review isolation mode so repos can intentionally opt into `compat` instead of silently drifting into it.

## Workstream 5: Tests

- Add focused tests for:
  - strict mode rejecting sequential fallback
  - compat mode requiring an explicit reason
  - `ready_for_human_close` blocking without `evaluation.md`
  - hook installation including isolation validation

---

## Verification

- `bash tests/test-validate-artifact.sh`
- `bash tests/test-validate-state-artifacts.sh`
- `bash tests/test-validate-isolation.sh`
- `bash tests/test-install-hooks.sh`
- `bash spec/bootstrap/check-consistency.sh`

## Exit Condition

The task is ready for human close when:

- spec and adapters agree on strict vs compat semantics
- `verification-path.md` and `evaluation.md` carry explicit isolation provenance
- runtime validation can block a task that claims progress without the required isolation evidence
- the current repo passes the updated focused tests and consistency checks
