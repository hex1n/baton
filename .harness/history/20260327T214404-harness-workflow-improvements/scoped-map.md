# Scoped Map: harness-workflow-improvements

**Requirement**: Apply retrospective-driven improvements to the Baton Harness workflow and enforce them through protocol docs, skills, and bootstrap scripts.
**Domain**: harness protocol / bootstrap / role-skill governance
**Owner**: `scoped-explorer`
**Status**: `complete`

## 1. Scope

- In scope:
  - `spec/protocol/*` documents that define gates, role contracts, state semantics, and artifact expectations
  - `spec/adapters/*` guidance for Codex and generic CLI adapters
  - role skills in `skills/harness-*.md`
  - bootstrap / guard scripts in `spec/bootstrap/*.sh` and `spec/bootstrap/*.ps1`
  - user-facing docs in `README.md` and `spec/README.md` if workflow wording changes
- Out of scope:
  - full workflow automation or a scheduler
  - changing the one-active-task-per-workspace invariant
  - broad adapter rewrites outside the workflow improvements surfaced by the retrospective
- Expected write boundary:
  - protocol docs, skill docs, bootstrap scripts, and mirrored skill copies if sync is required

## 2. Entry Point

- Primary entry classes or files:
  - `spec/protocol/gates.md`
  - `spec/protocol/role-contracts.md`
  - `spec/protocol/state-machine.md`
  - `spec/protocol/artifact-schema.md`
  - `skills/harness-specifier.md`
  - `skills/harness-architect.md`
  - `skills/harness-verifier.md`
  - `skills/harness-explorer.md`
  - `skills/harness-evaluator.md`
  - `spec/bootstrap/start-task.sh`
  - `spec/bootstrap/start-task.ps1`
  - `spec/bootstrap/check-consistency.sh`
  - `spec/bootstrap/sync-skills.sh`
- Methods, APIs, commands, or scripts:
  - `start-task.{sh,ps1}` initialize task state and validate owner/state tokens
  - `check-consistency.sh` is the existing invariant preflight
  - `sync-skills.sh` is the existing skill-copy propagation path
- Why these are the entries:
  - the retrospective surfaced failures at gate handoff, context-isolation policy, and distributed token / link-mode handling, all of which are defined or enforced in these files

## 3. Call Chain

```text
retrospective findings
-> protocol docs define gate semantics and role responsibilities
-> role skills operationalize those semantics in day-to-day task execution
-> bootstrap / consistency scripts enforce token and file invariants at runtime
-> README / adapter docs shape how users and agent runtimes actually run the harness
```

## 4. Existing Behavior

- Current observable behavior:
  - Gate 2 only checks broad architecture/requirements consistency; it does not explicitly require a requirements sync after human-approved architecture decisions.
  - `skills/harness-explorer.md` currently forces `context: fork`, while `skills/harness-verifier.md` does not, even though the retrospective found the highest value isolation at Verifier/Evaluator.
  - `start-task.sh` and `start-task.ps1` already use `owners.txt`, but state tokens are still duplicated in code.
  - `sync-skills.sh` trusts `.link-mode`, which can lie in fresh clones where git materializes symlinks as plain files.
- Current validation rules:
  - `check-consistency.sh` verifies owner tokens, module-status header alignment, and skill-copy parity.
  - `start-task --dry-run` proves initialization behavior without editing `.harness/`.
- Existing implicit constraints:
  - mirrored skills under `.claude/skills/` and `.agents/` must stay aligned with `skills/`
  - PowerShell and Bash bootstrap paths must stay behaviorally consistent
  - protocol changes should stay tool-agnostic unless explicitly adapter-specific

## 5. Existing Tests

- Directly relevant tests:
  - `bash spec/bootstrap/check-consistency.sh`
  - `bash spec/bootstrap/start-task.sh --repo-root . --task-id <id> --dry-run`
  - `pwsh ./spec/bootstrap/start-task.ps1 -RepoRoot . -TaskId <id> -DryRun`
- Nearby reusable tests:
  - script-level dry runs in `spec/bootstrap/link-skills.sh --dry-run`
- No useful tests found:
  - there is no standalone automated test suite for protocol docs or skill semantics beyond script preflights

## 6. Dependency / Risk Scan

- Will this likely touch integration or infra?
  - Yes. Skill mirroring and adapter docs affect Claude/Codex runtime behavior, even though no production service is involved.
- Will this likely touch migrations or schema?
  - Yes, in the lightweight sense of protocol schema: owner/state token sources and `module-status.md` workflow expectations.
- Will this likely cross business domains?
  - No. This is contained to the Baton Harness governance layer.

## 7. Change Shape

- This looks like:
  - a medium protocol/automation refinement with both documentation and script enforcement changes
- Estimated file count:
  - roughly 12-18 files, depending on mirrored skill updates
- Preferred implementation depth:
  - protocol-first: document the intended workflow, then align skill instructions, then align bootstrap/preflight scripts

## 8. Open Questions

- Should the requirements sync pass become a new canonical state, or remain a hard Gate 2 checklist item without state-machine expansion?
- Is it sufficient to centralize `states.txt` in bootstrap + consistency checks, or do role skills also need machine-checked state-token validation?

## 9. Recommendation

- Proceed?
  - Yes. The retrospective identified repeatable failure modes and clear low-risk fixes.
- Suggested next step:
  - Write requirements that formalize Gate 2 requirements sync, narrow mandatory isolation to Verifier/Evaluator, centralize state tokens, and fix actual link-mode detection.
