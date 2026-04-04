# Runtime Evaluator

## Goal

Define the stricter evaluator model used by Java backend strict mode.

This role is closer to the `11.md` evaluator than to a normal code review pass.

## Evaluator Intent

The evaluator should answer:

- does the implementation satisfy the accepted requirements
- do runtime signals suggest hidden correctness or operational risk
- is there any blocker that should stop handoff to human close

## Source Independence Rule

Primary evaluation should be derived from:

- `requirements.md`
- `api-contract.yaml`
- executable validation commands
- runtime behavior
- database state
- application health and logs

Default rule:

- do not read generator source code while producing the primary evaluation report

If a blocker is found and a later localization pass is needed, do that as a
separate review activity, not as part of the primary independent judgment.

## Three Layers

Core `evaluation.md` defines a three-layer evaluation structure:
Layer 1 (Deterministic Checks), Layer 2 (Diff Review), Layer 3
(Requirements Verification). This extension **replaces** core Layer 2
with runtime signal collection while keeping Layers 1 and 3 aligned.

### Layer 1: Deterministic Checks

Zero-AI-judgment checks where possible (extends core Layer 1):

- compile
- existing tests
- API contract validation
- database state assertions
- health endpoint checks

Any hard failure here should block before higher-layer interpretation.

### Layer 2: Runtime Signals (replaces core Diff Review)

Collect facts first:

- SQL logs
- transaction behavior
- endpoint latency
- async execution behavior
- cache behavior
- connection pool signals

The output of this layer is evidence, not final judgment.
Core's Layer 2 (Diff Review) is subsumed — runtime evidence provides
stronger signal than static diff analysis for Java backend systems.

### Layer 3: Requirement-Driven Judgment

Use the acceptance checklist to determine:

- which requirements are satisfied
- which edge cases are missing
- which runtime signals should be treated as blockers
- which issues are warnings only

## Output Contract

The evaluator should write:

- `evaluation-report.md`
- `runtime-signals/` raw evidence files

The report should include:

- total verdict
- deterministic check summary
- runtime signal summary
- requirement-by-requirement judgment
- blockers
- warnings
- residual risk statement

## Interaction With Generator

Strict mode uses a bounded repair loop:

1. evaluator writes `evaluation-report.md`
2. generator fixes blocking issues
3. evaluator reruns
4. after three blocked rounds, escalate to human

Warnings do not need to block unless they materially threaten correctness or deployment safety.

## Cross-Cutter

After module-level evaluation is complete, run a final evaluator pass as
`Cross-Cutter` to check:

- module interactions
- shared runtime regressions
- final migration and safety concerns

`Cross-Cutter` is not a separate core role. It is the evaluator's final global mode.
