# Architecture: remove-spec-extensions

**Topic**: delete `spec/extensions/` and clean every live reference
**Status**: `proposed`
**Sizing**: `Small`

## 1. Problem Framing

Four live surfaces still advertise or guard an overlay directory
(`spec/extensions/java-backend-strict/`) whose contents were promoted
into `spec/templates/` core by `promote-java-artifacts` (2026-04-04).
The directory, three `spec/README.md` references, six lines of
`check-consistency.sh` dead-guard code (3 variables + 3 if-blocks for
invariants 14/17/18), and one parenthetical in
`skills/baton-evaluator/SKILL.md:210` all need to go. Implementation
must keep `check-consistency.sh` passing end-to-end and must not
weaken the surviving positive halves of invariants 14/17/18 that
guard the core templates.

## 2. First-Principles

### 2.1 Problem Statement

A directory and its associated governance/validation scaffolding have
become dead weight after a prior migration. We need a deletion that
is: (a) complete — no stray live references; (b) safe — no
unrelated validator coverage dropped; (c) verifiable — every change
can be checked via a deterministic command; (d) non-regressing —
optionally guarded by a new check so future accidental re-creation
fires loudly.

### 2.2 Constraints

- **C1** `bash spec/bootstrap/commands/check-consistency.sh` must
  exit 0 after every logical unit.
- **C2** No sed/awk global sweeps on `check-consistency.sh`; use
  Edit tool with unique per-hunk context. (Source: `knowledge/lessons.md`
  — "Python str.replace substring-matches across markdown heading
  levels" — the same substring-matching class of bug applies to
  bash `legacy_` prefixes which appear many times in this file.)
- **C3** Phase 5 Verify and Phase 7 Review MUST run strict isolation
  via Agent dispatch (baton-verifier / baton-evaluator). (Source:
  `knowledge/lessons.md` — "'Low-risk' is not a license to skip
  strict isolation in a repo that dogfoods strict".)
- **C4** Positive halves of invariants 14/17/18 (the
  `[[ -e spec/templates/*.template.md ]]` checks and the downstream
  schema/skill/validator checks) must remain intact — only the
  legacy-absent negative halves are removed.
- **C5** `docs/*.md` historical snapshots (5 files) are out of scope
  per user decision; do not touch.

### 2.3 Solution Categories

- **Category A — Sequential cleanup, bundled single commit.**
  Execute the 4 units (`rm -rf`, README edits, check-consistency.sh
  edits, SKILL.md edit) in one generator batch; run
  `check-consistency.sh` end-to-end once at the end as the
  functional gate. One commit. Optionally bundle R7 (new
  `[[ ! -d spec/extensions ]]` invariant) into the same batch.
  **Mechanism**: treat the cleanup as one atomic unit because the
  units are tightly coupled (removing the directory without removing
  its invariants leaves permanently-false dead guards; removing the
  invariants without removing the directory leaves the README
  consistent but the invariants silently OK).

- **Category B — Split into 4 commits, checkpoint per unit.**
  Run `check-consistency.sh` after each unit; commit after each
  pass. Creates 4 intermediate states where the repo is partially
  cleaned up. **Mechanism**: favors reversibility — each unit is a
  separate undo point.

- **Category C — Automated sweep via scripted find+sed.**
  Write a one-shot cleanup script that grep-finds and sed-deletes
  all matching lines. **Mechanism**: mechanical — no per-hunk Edit
  calls.

### 2.4 Evaluation

- **Why Category A wins**: the 4 units are semantically atomic
  (all-or-nothing — any intermediate state leaves the repo in a
  confused partial-cleanup state where `check-consistency.sh` may
  still pass but the documentation and the guardrails disagree
  with each other). Small total surface (~15 lines removed, 7
  files deleted) means the commit is reviewable in one pass. The
  tightly-coupled "remove X and the guards that watch for X" idiom
  argues for atomicity. Verification is one command:
  `check-consistency.sh` end-to-end.

- **Why Category B is rejected**: the intermediate states are
  worse than the start state. After unit 1 (delete directory), the
  3 invariants have dead-empty `if [[ -e ... ]]` guards — still
  passing but pointing at a deleted path. After unit 2 (README),
  the skill still hints at extensions. After unit 3 (check-
  consistency), the skill still hints. Splitting has no reviewer
  benefit because the whole change is tiny and one-brain-load.
  Commit bisectability has no value because there is no behavior
  change to bisect against.

- **Why Category C is rejected**: violates C2 directly. The lesson
  from `skill-retrospective-alignment` is explicit: substring
  matching on `legacy_` is unsafe because `legacy_escalation_template`
  is a prefix of other bash variable names that may exist in the
  file. `check-consistency.sh` has grown many invariants and has
  high historical churn. One false positive in a sed sweep =
  broken invariant = broken master. The manual Edit-tool path
  with unique per-hunk context is safer and only marginally
  slower.

**Decision**: Category A, with R7 bundled (see §3 rationale).

## 3. Recommended Approach

- **Approach**: Category A — sequential cleanup of 4 units in one
  generator batch, one functional verification at the end,
  committed as a single logical change. Bundle R7 (regression
  guard) into the same batch.

- **Key change points**:
  1. **Unit U1** — `rm -rf spec/extensions/` (deletes 7 files).
  2. **Unit U2** — `spec/README.md`: 3 precise Edit calls to remove
     lines 17 (`- extensions/: stack-specific stricter overlays`),
     136–137 (`extensions/` and `java-backend-strict/` inside the
     tree diagram), and 201 (`[java-backend-strict/README.md](...)`
     bullet). Re-verify tree diagram remains syntactically coherent.
  3. **Unit U3** — `spec/bootstrap/commands/check-consistency.sh`:
     6 precise Edit calls (3 for variable definitions at lines
     20/23/24, 3 for the `if [[ -e legacy_*_template ]]; then ...`
     blocks at 473–474 / 647–648 / 700–701). Each Edit uses the
     full 2-line `if ... fi` span as `old_string` with unique
     surrounding context to avoid partial matches.
  4. **Unit U4** — `skills/baton-evaluator/SKILL.md`: 1 Edit call
     removing ` (extensions may replace this layer)` from line 210
     while keeping the surrounding sentence grammatical.
  5. **Unit U5 (R7)** — `spec/bootstrap/commands/check-consistency.sh`:
     append a new invariant-19 block (or a minimal inline assertion
     in a logical location) asserting `[[ ! -d
     "$repo_root/spec/extensions" ]]`. **Bundling rationale**: the
     same lesson that says "cross-file regex contracts need a
     static checker" (from `knowledge/lessons.md` —
     knowledge-compound-mvp) applies in the inverse here: we are
     removing the last cross-file assertion that `spec/extensions/`
     stays absent, so the checker gap opens the moment unit U3
     merges. Adding U5 in the same commit closes that gap atomically.
     Splitting to a follow-up task means the gap exists for the
     duration between tasks, and the follow-up is easy to forget —
     exactly the failure mode the lesson warns about.
  6. **Verification step (not a generator unit)** — run
     `bash spec/bootstrap/commands/check-consistency.sh` once after
     all 5 units. Expected: exit 0; stdout contains `OK: invariant-14`,
     `OK: invariant-17`, `OK: invariant-18`, and (new) `OK:
     invariant-19`. Run `validate-artifact.sh` on all `.harness/`
     artifacts.

- **Data/control boundaries**:
  - No runtime data flow touched.
  - Static governance surface: the "governance → validator → core
    template" chain. Before: chain branches to legacy paths that
    are absent-guarded. After: chain is monolithic through core
    templates only, with one new negative assertion guarding the
    absence of the overlay directory.

- **Backward-compatibility notes**: None. `spec/extensions/` has no
  downstream consumers (verified by repo-wide grep minus history/docs
  /tmp). The only "consumer" was the migration guard, which is
  itself being removed. `docs/*.md` snapshots are intentionally
  frozen and will remain consistent with their own timestamps.

- **Q2 resolution (docs footer)**: Leave `docs/*.md` fully
  untouched per user scope. Rationale: adding retrospective footers
  to historical analysis documents is a documentation-style
  judgment the user has already made, and touching them would
  break the "historical snapshot" invariant (i.e., that these
  files capture what the project looked like at their write-time).
  If future confusion arises, a retrospective-flagged standardization
  candidate can add a `docs/README.md` index note.

## 4. Surface Scan

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| `spec/extensions/java-backend-strict/README.md` | L1 | delete | direct target of R1 |
| `spec/extensions/java-backend-strict/artifact-overlay.md` | L1 | delete | direct target of R1 |
| `spec/extensions/java-backend-strict/runtime-evaluator.md` | L1 | delete | direct target of R1 |
| `spec/extensions/java-backend-strict/state-overlay.md` | L1 | delete | direct target of R1 |
| `spec/extensions/java-backend-strict/templates/api-contract.template.yaml` | L1 | delete | direct target of R1 |
| `spec/extensions/java-backend-strict/templates/evaluation-report.template.md` | L1 | delete | direct target of R1 |
| `spec/extensions/java-backend-strict/templates/runtime-signals.README.md` | L1 | delete | direct target of R1 |
| `spec/README.md` | L1 | modify (3 hunks) | R2 — governance doc consistency |
| `spec/bootstrap/commands/check-consistency.sh` | L1 | modify (6 hunks delete + 1 hunk add) | R3/R4/R7 — dead code removal + new regression guard |
| `skills/baton-evaluator/SKILL.md` | L1 | modify (1 hunk) | R5 — stale parenthetical cleanup |
| `docs/baton-positioning.md`, `docs/review-analysis.md`, `docs/runtime-thickness-analysis.md`, `docs/baton-project-deep-analysis.md`, `docs/baton-project-deep-analysis-zh.md`, `docs/spec-deep-analysis.md` | L3 | skip | out of scope (NG-1, user decision) |
| `skills/deep-research/SKILL.md` | L3 | skip | false-positive match ("columnar extensions" in SQLite example) |
| `.harness/history/**`, `.tmp/**` | L3 | skip | archived/scratch |
| `tests/**` | L3 | skip | zero matches verified |
| `spec/templates/{escalation,decisions,codebase-map}.template.md` | L2 | read-only verify | positive halves of invariants 14/17/18 still point here; confirm files exist and unchanged |

## 5. Verification Strategy

- **Primary check**: `bash spec/bootstrap/commands/check-consistency.sh`
  exits 0 and reports OK for invariants 14, 17, 18, and (new) 19.
  This single command is load-bearing because it is both the
  functional test (surviving positive halves still hold) and the
  negative-regression guard (via new R7 invariant).

- **Review focus**:
  1. Confirm no `legacy_` substring survives in
     `check-consistency.sh` (grep-based AC-3).
  2. Confirm `spec/README.md` tree diagram remains syntactically
     coherent after 3 deletions (manual eye + grep).
  3. Confirm `skills/baton-evaluator/SKILL.md:210` sentence remains
     grammatical after parenthetical removal (manual read).
  4. Confirm `grep -rE "spec/extensions|java-backend-strict" .
     --exclude-dir={.harness,docs,.tmp,.git,node_modules}` returns
     zero matches (AC-6 — full sweep catch for latent references).

- **Risks that validation cannot fully eliminate**:
  - A future edit re-creates `spec/extensions/` with a different
    subdirectory name (e.g. `spec/extensions/ruby-backend-strict/`)
    — the R7 `[[ ! -d spec/extensions ]]` guard catches the
    directory but not the concept. Accepted — broader concept
    policing is out of scope.
  - A developer writing a new skill could reference the removed
    parenthetical from `baton-evaluator` SKILL.md before the cache
    updates — negligible probability, no mitigation.

## 6. Risks

- **R-R1 (Low prob / Low impact)** — `spec/README.md` tree diagram
  becomes visually asymmetric after removing 2 lines from the
  middle. **Mitigation**: read the diagram post-edit; if the visual
  indentation/alignment breaks, fix manually.

- **R-R2 (Low prob / Medium impact)** — one of the 6 Edit calls in
  `check-consistency.sh` fails to match because another line in
  the file happens to contain the same unique-seeming context
  string. **Mitigation**: use 3+ lines of surrounding context in
  each `old_string`, including the line numbers implicitly via
  neighboring unique identifiers (e.g., `invariant-14`, nearby
  `printf` statements). If match fails, read the relevant window
  first and adjust context. (Cited lesson: `knowledge/lessons.md`
  — cross-file regex contracts need a static checker; this task's
  defense is per-hunk context + post-edit grep validation, not a
  checker.)

- **R-R3 (accepted)** — `docs/*.md` (5 files) will reference an
  overlay that no longer exists in the live repo. Accepted per
  user scope (NG-1). Flagged in retrospective as standardization
  candidate (docs freshness check).

- **R-R4 (mitigated by R7)** — Future re-creation of
  `spec/extensions/` with no automated alert. Mitigated by adding
  invariant-19 (`[[ ! -d spec/extensions ]]`) in unit U5. This is
  why R7 is bundled, not split.

- **Historical lessons considered**:
  - `knowledge/lessons.md` — "Cross-file regex contracts need a
    static checker": addressed by bundling R7/U5.
  - `knowledge/lessons.md` — "Python str.replace substring-matches":
    addressed by C2 constraint + per-hunk context discipline.
  - `knowledge/lessons.md` — "'Low-risk' is not a license to skip
    strict isolation": addressed by C3 — Phase 5/7 will use strict
    subagent dispatch even though this task is Small-Medium.
  - `knowledge/lessons.md` — `validate-artifact.sh` and
    `check-consistency.sh` are complementary: addressed by §5
    validation strategy running both.
  - No other entries apply.

## Delivery Order

Medium risk — delivery order recommended, not required. Since the
whole change is one bundled commit, the "order" is really the
within-commit sequence of Edit operations (relevant only to avoid
mid-batch breakage):

1. **U1** — `rm -rf spec/extensions/` first. This is atomic and
   has no edit-tool dependency.
2. **U2** — `spec/README.md` edits. Independent of U1.
3. **U3** — `check-consistency.sh` dead-code removal (6 hunks).
   Run `bash check-consistency.sh` after U3 to confirm the
   surviving halves of invariants 14/17/18 still pass (this is
   the risky unit).
4. **U5** — `check-consistency.sh` add new invariant-19 for R7.
   Depends on U1 (directory must already be absent for the
   assertion to pass at run time) and U3 (to avoid conflicts
   with neighbor invariants being edited).
5. **U4** — `skills/baton-evaluator/SKILL.md:210`. Independent;
   scheduled last because it is the smallest and easiest undo.
6. **Final validation** — run `check-consistency.sh` end-to-end
   one more time + `validate-artifact.sh` on all `.harness/` docs.

## 7. Self-Challenge

1. **Is this the best category, or only the first workable one?**
   Category A is almost trivially best because the change is tiny
   and tightly coupled. The question of "best" is really "should
   R7 be bundled?" — argued in §3. The alternative (split R7) is
   defensible but loses the atomicity of "remove X and add the
   guard that X stays removed" in one commit, which is the exact
   cross-file-contract failure mode knowledge-compound-mvp warned
   about.

2. **Which assumptions remain unverified?**
   - A2 (no latent reference outside the ones found) — verified
     by repo-wide grep, but grep is line-based, so a multi-line
     reference, a symlink, or a generated file could evade it.
     Mitigation: AC-6 runs the same grep post-generation.
   - A4 (end-to-end check-consistency is sufficient test) —
     untestable without writing a unit test; accepted.

3. **What would a skeptic challenge first?**
   - "Why bundle R7 when the user didn't ask for it?" Answer:
     the lesson-compounded architectural judgment says unguarded
     deletions become regression surfaces; the cost of U5 is ~5
     lines; the cost of forgetting U5 is the whole reason
     check-consistency.sh exists.
   - "Why not also touch the `docs/*.md` files?" Answer: user
     scope is explicit; footer-adding is style, not correctness.
   - "Why remove the parenthetical in `baton-evaluator` SKILL.md
     at all if it's just prose?" Answer: prose that contradicts
     the reality of the repo is worse than no prose — it misleads
     future readers into thinking extensions is a plug-point.

4. **Pattern-match intuitions (marked as such)**:
   - Intuition: "`check-consistency.sh` is fragile under sed
     sweeps." Basis: direct lesson from skill-retrospective-
     alignment. Would change if: a robust bash-aware refactoring
     tool existed (it doesn't).
   - Intuition: "One commit is better than four for a ~15-line
     change." Basis: reviewer cognitive load argument + tight
     semantic coupling. Would change if: the user explicitly
     preferred bisectability (they haven't stated a preference).
   - Intuition: "R7 belongs in this task, not a follow-up."
     Basis: cross-file regex contract lesson. Would change if:
     the architect discovers R7 requires coordinated changes
     with unrelated files, which exploration did not find.

## 8. Human Judgment Notes

> Populated during Gate 2 review. Not machine-editable.
> Space for the reviewer's tacit signals — intuitions, pattern recalls,
> or concerns that resist full articulation.

- <human annotation, if any>
