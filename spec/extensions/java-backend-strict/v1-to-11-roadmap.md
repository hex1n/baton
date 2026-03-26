# v1 To 11-Style Roadmap

## Goal

Move portable harness v1 toward the heavier `11.md` design without breaking
portability.

## P0: Extension Layer First

Do first:

- keep portable core unchanged
- add strict behavior as `extensions/java-backend-strict`
- document the extra artifacts and stricter evaluator model

Avoid:

- rewriting core v1 into a Java-only protocol

## P1: Artifact Upgrade

Promote these into everyday strict-mode use:

- `codebase-map.md`
- `decisions.md`
- `api-contract.yaml`
- `evaluation-report.md`
- `generator-feedback.md`
- `runtime-signals/`

Success condition:

- a strict-mode task can run without inventing ad hoc side documents

## P2: Evaluator Upgrade

Add the three-layer evaluator behavior:

1. deterministic checks
2. runtime signal collection
3. requirement-driven judgment

Success condition:

- `Evaluator` is no longer just a review label
- `evaluation-report.md` becomes the primary repair signal to generator

## P3: Module Loop Upgrade

Teach strict mode to operate by module:

- module batches
- module evaluation rounds
- cross-cutter final pass

Success condition:

- `module-status.md` exposes module and round progress clearly

## P4: Human Gate Upgrade

Make the higher-friction approvals explicit:

- architecture approval
- migration approval
- evaluator escalation after three failed rounds
- final close

Success condition:

- risky transitions are no longer implicit in chat flow

## P5: Optional Runtime Implementation

Only after the extension stabilizes, consider building a local runtime that adds:

- role dispatch helpers
- evaluator execution helpers
- runtime signal collectors
- report normalization

This should remain an implementation layer, not a protocol prerequisite.

## Recommended Adoption Order

1. adopt the extension docs
2. use the templates
3. run one pilot Java task manually
4. refine the extension from pilot results
5. automate only the parts that proved stable
