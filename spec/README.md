# Portable Harness Spec v1

## Purpose

This directory defines a portable `harness` protocol that can be reused across:

- any repository
- any agent CLI
- single-agent or multi-agent execution modes

It is intentionally split into:

- `protocol/`: tool-agnostic rules
- `templates/`: repo-local artifacts
- `adapters/`: CLI capability contract
- `profiles/`: repo-type examples
- `extensions/`: stack-specific stricter overlays
- `bootstrap/`: adoption checklist for a new repo

## Design Principles

1. The protocol is primary. A specific agent CLI is only an execution adapter.
2. Repo-specific knowledge belongs in a profile, not in the core protocol.
3. Multi-agent execution is preferred, not required. Sequential fallback must remain valid.
4. Verification is a first-class gate, not a post-implementation afterthought.
5. `module-status.md` is the minimum control plane.
6. Heavier stack-specific behavior should be added as an extension, not pushed into the portable core by default.

## Minimum Closed Loop

The smallest portable harness loop is:

1. `Scoped Explorer`
2. `Specifier`
3. `Architect`
4. `Verification Path Check`
5. `Generator`
6. `Reviewer`
7. `Human Close`

## Recommended Repo Layout

```text
.harness/
  scoped-map.md
  requirements.md
  architecture.md
  verification-path.md
  module-status.md
  retrospective.md
```

This spec does not require `.harness/` specifically, but all examples assume it.

## Directory Contents

```text
spec/
  README.md
  bootstrap/
    init-harness.md
    init-harness.ps1
    init-harness.sh
    start-task.md
    start-task.ps1
    start-task.sh
  protocol/
    state-machine.md
    role-contracts.md
    artifact-schema.md
    gates.md
  adapters/
    cli-adapter-interface.md
    codex.md
    claude-code.md
    cursor.md
  templates/
    scoped-map.template.md
    requirements.template.md
    architecture.template.md
    verification-path.template.md
    module-status.template.md
    retrospective.template.md
    profile.local.template.yaml
  profiles/
    java-maven.yaml
    node-monorepo.yaml
    python-service.yaml
  extensions/
    java-backend-strict/
      README.md
      artifact-overlay.md
      runtime-evaluator.md
      state-overlay.md
      v1-to-11-roadmap.md
      templates/
        codebase-map.template.md
        decisions.template.md
        api-contract.template.yaml
        evaluation-report.template.md
        generator-feedback.template.md
        runtime-signals.README.md
```

## How To Use

1. Pick a repo profile closest to the target repository.
2. Pick the adapter mapping closest to the target agent environment.
3. If your stack needs a stricter execution model, add the matching extension overlay.
4. Follow `bootstrap/init-harness.md`.
5. Copy the templates into the target repo's `.harness/`.
6. Run the gates in `protocol/gates.md` in order.
7. Record all status transitions in `module-status.md`.

Draft bootstrap scripts are included for convenience:

- `bootstrap/init-harness.ps1`
- `bootstrap/init-harness.sh`
- `bootstrap/start-task.ps1`
- `bootstrap/start-task.sh`

Recommended bootstrap flow:

1. run `init-harness`
2. run `Repo Explorer`
3. run `start-task`
4. let the current owner agent update `module-status.md` and fill the active task artifacts in `.harness/`

For Java/Spring business systems that need the heavier `11.md` style loop, start from:

- [java-backend-strict/README.md](./extensions/java-backend-strict/README.md)

## Non-Goals

- This spec does not define a scheduler implementation.
- This spec does not require sub-agent support.
- This spec does not define prompt wording for a specific model.
- This spec does not replace repo-specific engineering judgment.
