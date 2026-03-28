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
  scoped-map.md
  requirements.md
  architecture.md
  verification-path.md
  module-status.md
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
    install-harness.md
    install-harness.ps1
    install-harness.sh
    init-harness.md
    init-harness.ps1
    init-harness.sh
    sync-governance-entrypoints.md
    sync-governance-entrypoints.ps1
    sync-governance-entrypoints.sh
    start-task.md
    start-task.ps1
    start-task.sh
    update-harness.md
    update-harness.ps1
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
    scoped-map.template.md
    requirements.template.md
    architecture.template.md
    verification-path.template.md
    module-status.template.md
    retrospective.template.md
    profile.local.template.yaml
    zh/
      scoped-map.template.md
      requirements.template.md
      architecture.template.md
      verification-path.template.md
      retrospective.template.md
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
7. Record all status transitions in `module-status.md`.

Draft bootstrap scripts are included for convenience:

- `bootstrap/init-harness.ps1`
- `bootstrap/init-harness.sh`
- `bootstrap/start-task.ps1`
- `bootstrap/start-task.sh`

Recommended bootstrap flow:

1. run `install-harness`
2. run vendored `init-harness`
3. review generated root `CLAUDE.md` and `AGENTS.md`
4. run `Repo Explorer`
5. run `start-task`
6. after architecture approval, sync `requirements.md` to any approved
   architecture decisions that change requirements-level truth
7. run `spec/bootstrap/check-consistency.sh` before or during `verification_check`
8. let the current owner agent update `module-status.md` and fill the active task artifacts in `.harness/`

## Artifact Language

Portable harness v1 supports English and Chinese for human-facing artifacts.

- bootstrap scripts accept `--language auto|en|zh`
- `.harness/profile.local.yaml` persists the choice in
  `documentation.artifact_language`
- this reference implementation defaults to Chinese when no policy is set
- in scripts, `auto` resolves from the environment locale
- in writing skills, `auto` means "follow the current user request language"
- `module-status.md` remains English because it is the portable control plane

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
