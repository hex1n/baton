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
5. `task-status.md` is the minimum control plane.
6. Heavier stack-specific behavior should be added as an extension, not pushed into the portable core by default.

## Minimum Closed Loop

The smallest portable harness loop is:

Happy path:

1. `Scoped Explorer`
2. `Specifier`
3. `Architect`
4. `Verification Path Check`
5. `Generator`
6. `Reviewer`
7. `Human Close`

Repair loops:

- `Verification Path Check` may block and route back to `Architect` or `Specifier`
- `Generator` may block and route back to `Architect`, `Specifier`, or `Human`
- `Reviewer` / `Evaluator` may block and route back to `Generator` for repair, then re-run review

## Recommended Repo Layout

```text
AGENTS.md
CLAUDE.md
.harness/
  exploration.md
  requirements.md
  architecture.md
  verification.md
  task-status.md
  retrospective.md
```

This spec does not require `.harness/` specifically, but all examples assume it.
In this reference implementation, `AGENTS.md` and `CLAUDE.md` are shared
root-level governance entrypoints materialized from one template.

## Directory Contents

```text
spec/
  README.md
  bootstrap/
    README.md
    commands/
      install-harness.sh
      init-harness.sh
      start-task.sh
      update-harness.sh
      link-skills.sh
      sync-skills.sh
      sync-entrypoints.sh
      check-consistency.sh
      install-hooks.sh
      validate-artifact.sh
      validate-isolation.sh
      validate-state-artifacts.sh
      validate-transition.sh
      show-context.sh
    hooks/
      run-hook.cmd
      session-start
      pre-transition
      post-artifact
      stop-check
      subagent-stop
    lib/
      task-status.sh
      paths.sh
      profile.sh
      provenance.sh
      state-requirements.sh
    install-harness.md
    install-harness.sh
    init-harness.md
    init-harness.sh
    prepare-review.md
    prepare-review.sh
    sync-entrypoints.md
    sync-entrypoints.sh
    start-task.md
    start-task.sh
    update-harness.md
    update-harness.sh
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
    exploration.template.md
    requirements.template.md
    architecture.template.md
    verification.template.md
    task-status.template.md
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
5. Copy the templates into the target repo's `.harness/`, then materialize root
   governance entrypoints.
6. Run the gates in `protocol/gates.md` in order.
7. Record all status transitions in `task-status.md`.

Reference bootstrap entrypoints are included for convenience:

- `bootstrap/install-harness.sh`
- `bootstrap/init-harness.sh`
- `bootstrap/start-task.sh`
- `bootstrap/update-harness.sh`

Windows uses the same shell entrypoints through Git Bash or `bash ...` from
PowerShell. The reference runtime does not maintain separate `.ps1` business
entrypoints under `spec/bootstrap/`.

Recommended bootstrap flow:

1. run `install-harness`
2. run vendored `init-harness`
3. review generated root `CLAUDE.md` and `AGENTS.md`
4. run `Repo Explorer`
5. run `start-task`
6. after architecture approval, sync `requirements.md` to any approved
   architecture decisions that change requirements-level truth
7. run `spec/bootstrap/check-consistency.sh` before or during `verification_check`
8. run `bootstrap/prepare-review.sh` before isolated verifier / evaluator handoff
9. let the current owner agent update `task-status.md` and fill the active task artifacts in `.harness/`

## Distribution Model

The recommended external-repo adoption model is:

- vendored upstream payload under `.vendor/baton-harness/`
- lockfile truth in `.harness/harness.lock.yaml`
- local overrides under `.harness/overrides/`
- runtime skills materialized into `.claude/skills/` and `.agents/`

This replaces manual copy as the primary recommendation while keeping a
copy-based fallback available.

For Java/Spring business systems that need the heavier `11.md` style loop, start from:

- [java-backend-strict/README.md](./extensions/java-backend-strict/README.md)

## Non-Goals

- This spec does not define a scheduler implementation.
- This spec does not require sub-agent support.
- This spec does not define prompt wording for a specific model.
- This spec does not replace repo-specific engineering judgment.
