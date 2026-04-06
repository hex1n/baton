# Scoped Map: remove-spec-extensions

**Requirement**: Delete `spec/extensions/` and every live reference to it
**Domain**: harness governance / protocol cleanup
**Owner**: `scoped-explorer`
**Status**: `final`

> Note: Phase 2 exploration executed inline in the orchestrator's main
> context this turn — user explicitly rejected the baton-explorer Agent
> dispatch. `exploration.md` has no isolation provenance block, so
> validate-isolation.sh does not apply. Phase 5 Verify and Phase 7
> Review will still run via strict subagent dispatch.

## 1. Scope

- **In scope**:
  1. `rm -rf spec/extensions/` — deletes 7 files under
     `java-backend-strict/` (README.md, artifact-overlay.md,
     runtime-evaluator.md, state-overlay.md, and 3 templates).
  2. Remove 3 references in `spec/README.md` (lines 17, 136–137, 201).
  3. Remove dead code in `spec/bootstrap/commands/check-consistency.sh`:
     3 `legacy_*_template` variables (lines 20, 23, 24) + 3 invariant
     guard blocks (invariants 14, 17, 18 at lines 473–474, 647–648,
     700–701).
  4. Clean 1 parenthetical in `skills/baton-evaluator/SKILL.md:210`
     ("(extensions may replace this layer)") — discovered during this
     scan, not in user's original scope but trivially part of "remove
     every live reference".

- **Out of scope** (per user decision at triage):
  - `docs/*.md` analytical snapshots mentioning the overlay
    (baton-positioning, review-analysis, runtime-thickness-analysis,
    baton-project-deep-analysis{,-zh}, spec-deep-analysis) — historical
    artifacts, leave as-is.
  - `.harness/history/**` — archived task artifacts, immutable.
  - `.tmp/deep-research-workspace/**` — scratch workspace.

- **Expected write boundary**: 4 files edited (delete + modify), 7
  files deleted, ~15 lines removed, 0 lines added at baseline. If the
  §8 risk-1 mitigation is adopted, +1 line added.

## 2. Entry Point

No runtime entry — this is a governance/validation cleanup. The
"entry points" are the static surfaces that currently read or assert
about `spec/extensions/`:

- `spec/README.md` — describes `extensions/` in the governance tree.
- `spec/bootstrap/commands/check-consistency.sh` — asserts the legacy
  overlay templates are **absent** via invariants 14/17/18 (migration
  guardrails from `promote-java-artifacts`, 2026-04-04).
- `skills/baton-evaluator/SKILL.md:210` — stale parenthetical
  documentation.

**Why these are the entries**: they are the only non-archival, non-
test locations that mention `extensions/` or `java-backend-strict`
(verified by full-repo grep, filtering out `.harness/history/`,
`docs/`, and `.tmp/`).

## 3. Call Chain

```text
(no runtime call chain — static references only)

spec/README.md ──► human reader
                   (docs the overlay exists → after: no mention)

check-consistency.sh ──► invariant 14/17/18 "[[ -e legacy_*_template ]]" guard
                         (dead since promote-java-artifacts removed the files)
                         (positive half "[[ -e spec/templates/*.template.md ]]" stays)

baton-evaluator SKILL.md ──► LLM reader
                             (hints extensions may replace Layer 2 → after: no hint)
```

## 4. Data Flow

Not applicable in the runtime sense. Static information flow only:
the repo currently tells readers (both human and LLM) that
`spec/extensions/` exists as a governance concept. After the change,
that signal is removed everywhere except historical snapshots.

## 5. Existing Behavior

- **Current observable behavior**: `spec/extensions/java-backend-
  strict/` holds 7 files (4 .md + 3 templates). `spec/README.md`
  advertises the directory. `check-consistency.sh` invariants
  14/17/18 each have two halves: (a) positive — the core template
  under `spec/templates/` must exist and match schema; (b) negative
  — the legacy path under `spec/extensions/java-backend-strict/
  templates/` must NOT exist. `baton-evaluator` SKILL.md:210 has a
  parenthetical "(extensions may replace this layer)".
- **Current validation rules**: invariants 14/17/18's negative
  halves fire if anyone re-creates the legacy files. They have been
  dead (permanently false `[[ -e ... ]]`) for one task cycle.
- **Existing implicit constraints**: the three core templates in
  `spec/templates/` — `codebase-map.template.md`,
  `decisions.template.md`, `escalation.template.md` — are load-
  bearing for invariants 14/17/18's positive halves. Verified all
  three exist; removing the legacy-half does not weaken the positive-
  half coverage.

## 6. Existing Tests

- **Directly relevant tests**: none. `tests/test-check-consistency*.sh`
  does not exist — the consistency checker has no dedicated unit
  test. Greps on `tests/` for `extensions`, `java-backend-strict`,
  and `spec/extensions` return zero matches.
- **Nearby reusable tests**: `bash spec/bootstrap/commands/check-
  consistency.sh` end-to-end is the functional test. After the
  edits, it must still exit 0, proving all remaining invariants
  (including the surviving positive halves of 14/17/18) still hold.
- **No useful tests found**: nothing needs to be written for this
  task beyond the existing end-to-end invoke.

## 7. Change History

- **`promote-java-artifacts`** (2026-04-04, `.harness/history/19`):
  promoted the three templates from `spec/extensions/java-backend-
  strict/templates/` into `spec/templates/` core. Deleted the legacy
  files at file level but deliberately kept the invariant guards as
  migration regression catchers for one task cycle. Those guards
  have been dead (permanently-false `[[ -e ... ]]`) since that
  commit.
- **`baton-positioning`** (2026-03-28): recast Baton as "protocol-
  first with a local reference runtime". This is the conceptual
  reason the overlay's content was pulled into core — the "stack-
  specific stricter overlay" concept was folded into the main
  protocol.
- **High-churn files in scope**: `spec/bootstrap/commands/check-
  consistency.sh` churns frequently (most tasks add invariants to
  it), so edits here need careful Edit-tool context to avoid false
  matches on `legacy_` or invariant numbers.

## 8. Dependency / Risk Scan

**Full-repo grep for `extensions|java-backend-strict`** (excluding
`.harness/history/`):

| File | Lines | Kind | Action |
|------|-------|------|--------|
| `spec/README.md` | 17, 136–137, 201 | live governance reference | DELETE |
| `spec/bootstrap/commands/check-consistency.sh` | 20, 23, 24 (vars); 473–474, 647–648, 700–701 (guards) | dead invariant guards | DELETE (both halves of the guard blocks) |
| `skills/baton-evaluator/SKILL.md` | 210 | stale parenthetical | EDIT — remove `(extensions may replace this layer)` |
| `skills/deep-research/SKILL.md` | 343 | false positive — "columnar extensions" in SQLite example | NO ACTION |
| `docs/*.md` (5 files) | various | historical analysis snapshots | NO ACTION (out of scope per user) |
| `.tmp/deep-research-workspace/**` | various | scratch workspace | NO ACTION |
| `tests/**` | (no matches) | — | NO ACTION |

- **Integration / infra touch?** No. Pure static cleanup.
- **Migrations / schema touch?** No. The migration already happened;
  this removes residues.
- **Cross-domain touch?** Minor — `baton-evaluator` SKILL.md is
  contract-shaped documentation, so removing the extensions
  parenthetical is a semantic declaration that Layer 2 is no longer
  pluggable by extensions. This matches `baton-positioning` but
  should be called out in retrospective.
- **Fragility / coupling / missing coverage**:
  - **Risk 1 (Low prob, Medium impact)**: After removing invariants
    14/17/18's negative halves, there is no automated assertion that
    `spec/extensions/` stays deleted. A future edit could recreate
    the directory silently. Mitigation candidate: add a single
    `[[ ! -d spec/extensions ]]` assertion to check-consistency.sh
    (one line). Architect decides whether to bundle in this task or
    split.
  - **Risk 2 (accepted)**: `docs/*.md` drift — 5 historical docs
    still reference the overlay. User scope accepts this; flag in
    retrospective as a standardization candidate.
  - **Risk 3 (Low prob, Low impact)**: `baton-evaluator` SKILL.md
    semantic shift. Removing "(extensions may replace this layer)"
    is a small hook-point declaration. Matches baton-positioning.
    Flag in retrospective.

## 9. Change Shape

- **This looks like**: a pure-deletion cleanup with cross-file
  consistency — remove a directory, its governance references, and
  the migration guards that protected its removal.
- **Estimated file count**: 4 files edited + 7 files deleted = 11
  file-paths touched.
- **Preferred implementation depth**: bundle as a single generator
  batch. Units are tightly coupled (invariants 14/17/18 cannot be
  removed without also removing the directory they guard; the
  `spec/README.md` references must not outlive the directory).
  Splitting would create intermediate states where check-consistency
  diverges from repo reality.

## 10. Open Questions

- **Q1** — Bundle or split the regression guard? Should we add
  `[[ ! -d spec/extensions ]]` to check-consistency.sh as part of
  this task, or as a follow-up? Trade-off: bundling keeps
  "remove X and guard X stays removed" atomic; splitting keeps this
  task minimal. Architect decides in `architecture.md`.
- **Q2** — Retroactive footer on `docs/*.md`? Leave fully untouched
  (user scope says leave), or add a one-line "(historical snapshot —
  extensions overlay removed 2026-04-05)" footer? Architect decides.
  Default: leave untouched, match user scope.

## 11. Recommendation

- **Proceed?** Yes. User's triage scope is correct and complete on
  the live-reference axis, with one small addition (`baton-evaluator`
  SKILL.md:210) discovered during the scan. That addition is trivial
  enough to fold in without renegotiating scope.
- **Suggested next step**: Phase 3 Specify. Specifier should mirror
  the §9 unit shape as 4 acceptance criteria + a 5th AC for
  "check-consistency.sh still passes end-to-end", and resolve Q1/Q2
  with the architect before Gate 2.
- **Uncertainty flags**:
  - Q1/Q2 decisions await architect judgment — low uncertainty,
    both options are defensible.
  - No runtime behavior to validate — all validation is via
    check-consistency.sh and validate-artifact.sh runs.
  - Phase 2 was inline (non-isolated) per user decision; if a
    latent reference exists that grep missed (e.g., a symlink, a
    generated file), it will surface only at Phase 7 Review.
    Mitigation: Phase 5 Verify will include an exact
    `grep -R "spec/extensions"` re-scan as an AC.

## 12. Historical Lessons

> Read `knowledge/lessons.md` (10 lessons from 3 prior tasks).
> Applicability noted per lesson.

- **Relevant prior lessons**:
  - **Cross-file regex contracts need a static checker, not
    per-file unit tests** (knowledge-compound-mvp, 2026-04-05).
    *Directly applicable.* This task removes the last explicit
    cross-file guard for `spec/extensions/` presence. Symmetric
    risk: future edits re-add the directory with no check. §8
    risk 1 and §10 Q1 carry this into architecture.
  - **Python `str.replace` substring-matches across markdown
    heading levels** (skill-retrospective-alignment, 2026-04-05).
    *Applicable as caution for implementation.* When cleaning
    `check-consistency.sh`, use Edit tool with sufficient unique
    context per hunk — do NOT use sed or replace_all on `legacy_`
    or bare invariant numbers (grep shows many occurrences of
    `legacy_` / 3 hits each for invariant numbers; partial
    matches are plausible).
  - **"Low-risk" is not a license to skip strict isolation in a
    repo that dogfoods strict** (skill-retrospective-alignment).
    *Live tension, not directly applicable as a rule.* This
    exploration ran inline because the user explicitly rejected
    the Agent dispatch this turn. `exploration.md` has no
    isolation provenance block so the validator doesn't block,
    but Phase 5 Verify and Phase 7 Review MUST use strict
    subagent dispatch — no inline compat.
  - **`validate-artifact.sh` and `check-lesson-index-consistency.sh`
    are complementary** (skill-retrospective-alignment). *Applicable
    as background.* Before removing invariants 14/17/18, confirmed
    (§6) no `validate-artifact.sh` case depends on the legacy
    paths. The positive "core template exists" halves stay, so
    validate-artifact.sh's template-shape expectations are
    unchanged.
  - **`validate-artifact.sh` should distinguish "section header
    exists" from "section has content"** (knowledge-compound-mvp).
    *Applicable to this document's validity.* This exploration
    fills §6, §12 with substance, not placeholder bullets — the
    awk non-empty check should pass.

- **Lessons explicitly not applicable**:
  - BSD sed BRE optional-group syntax (knowledge-compound-mvp) —
    task uses `rm -rf` and Edit tool, not sed.
  - Context isolation rules need negative assertions
    (knowledge-compound-mvp) — task does not touch role-contracts
    or isolation.
  - Silent protocol-layer bugs compound invisibly
    (knowledge-compound-mvp) — task does not add new write paths.
  - Skill template rewrite must update prose too
    (skill-retrospective-review / knowledge-compound-mvp) — task
    does not rewrite skill templates.
  - `validate-artifact.sh` has no case for retrospective
    (skill-retrospective-review) — irrelevant to this task type.
  - `user-invocable: true` dual-contract
    (skill-retrospective-review) — no skill rewrites.
  - Design validator error output to localize problems
    (skill-retrospective-alignment) — skill-authoring lesson, not
    applicable to implementation.
