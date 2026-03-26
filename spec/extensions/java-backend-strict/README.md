# Java Backend Strict Extension

## Goal

Move portable harness v1 toward the heavier Java backend design in `11.md`
without collapsing the portable core into a Spring-specific runtime.

This extension is meant for:

- Java backend repositories
- Spring-heavy business systems
- tasks where runtime verification quality matters more than portability simplicity

Use this extension on top of the core protocol, not instead of it.

## What This Extension Adds

Compared with the portable core, this extension adds:

1. stricter artifact requirements
2. a dedicated runtime evaluator model
3. module-by-module generation and evaluation loops
4. explicit migration and escalation checkpoints
5. stronger runtime signal collection expectations

## Recommended Use Order

1. bootstrap the repo with portable harness v1
2. enable the Java repo profile
3. adopt the artifacts in [artifact-overlay.md](./artifact-overlay.md)
4. follow the stricter loop in [state-overlay.md](./state-overlay.md)
5. run the evaluator using [runtime-evaluator.md](./runtime-evaluator.md)

## Extension Boundary

This extension does not redefine the portable core's canonical ideas:

- file-based control plane
- explicit blockers
- human approval before close
- adapter independence

It does tighten the workflow substantially for Java backend work.

## Key Differences From Core v1

- `Repo Explorer` should usually emit `codebase-map.md`, not only an optional repo map.
- `Architect` should emit `decisions.md` and `api-contract.yaml` in addition to `architecture.md`.
- `Generator` should work module by module, not only task by task.
- `Evaluator` is not just a diff reviewer. It is a runtime-oriented validator with three layers.
- `Cross-Cutter` is treated as the evaluator's final global pass.

## Core Mapping

- Portable core: minimum closed loop
- This extension: Java backend strict mode

The intention is:

- keep core portable
- let strict stacks opt into heavier artifacts and gates

## Files In This Extension

- [artifact-overlay.md](/C:/Users/hexin/Desktop/project/fundsalesmrksupport/docs/harness-spec-v1/extensions/java-backend-strict/artifact-overlay.md)
- [runtime-evaluator.md](/C:/Users/hexin/Desktop/project/fundsalesmrksupport/docs/harness-spec-v1/extensions/java-backend-strict/runtime-evaluator.md)
- [state-overlay.md](/C:/Users/hexin/Desktop/project/fundsalesmrksupport/docs/harness-spec-v1/extensions/java-backend-strict/state-overlay.md)
- [v1-to-11-roadmap.md](/C:/Users/hexin/Desktop/project/fundsalesmrksupport/docs/harness-spec-v1/extensions/java-backend-strict/v1-to-11-roadmap.md)
- `templates/`
