# Technical Decisions

**Owner**: `architect`
**Status**: `final` (approved 2026-04-05 at Gate 2)

## D1: Bundle vs split cleanup (Category A vs B)

- Choice: Category A — bundle all 5 units (delete directory,
  clean README, delete dead guards in check-consistency.sh, clean
  SKILL.md prose, add new invariant-19 regression guard) into a
  single commit.
- Rejected Alternatives: Category B (split into 4 separate
  commits, checkpoint per unit); Category C (scripted find+sed
  sweep).
- Why: The 5 units are semantically atomic — "overlay is
  retired; here is the assertion that it stays retired". The whole
  change is ~15 lines removed + ~5 added across 4 files; one brain-
  load for review. Intermediate states of Category B are worse
  than the start state (dead-empty guards pointing at deleted
  paths, prose hinting at removed extensions). Commit bisectability
  buys nothing because there is no behavior change to bisect.
- Why Not: Category B has no reviewer upside on a zero-
  behavior-change cleanup. Category C directly violates constraint
  C2 (no sed sweeps on check-consistency.sh) — the lesson from
  skill-retrospective-alignment about substring matching on bash
  variable prefixes rules it out.
- Impact: Generator implements as one bundled batch. Verifier
  gates on `bash check-consistency.sh` end-to-end + 6 grep ACs +
  artifact schema validation.

## D2: Bundle regression guard R7 (Q1)

- Choice: Include R7 / U5 (new `invariant-19: [[ ! -d
  "$repo_root/spec/extensions" ]]`) in this task, not a follow-up.
- Rejected Alternatives: Drop R7 from this task and spin off
  as a separate follow-up task `spec-extensions-regression-guard`.
- Why: The lesson from `knowledge-compound-mvp` — "cross-file
  regex contracts need a static checker, not per-file unit tests"
  — applies in reverse: the moment U3 merges (deleting invariants
  14/17/18's negative halves), the last cross-file assertion that
  `spec/extensions/` stays absent is gone. Closing that gap in the
  same commit is ~5 lines and removes all ambiguity about whether
  the task is "done". Splitting creates a time window where the
  gap exists and relies on task-queue discipline to close it,
  which is exactly the failure mode the lesson warns about.
- Why Not: The user did not explicitly ask for R7 in the
  original request. A strictly-minimal interpretation of scope
  would drop it. The architect judges the added line to be a
  load-bearing completion of the user's request ("delete the
  directory and make sure it stays deleted"), not scope creep.
- Impact: One additional invariant block in check-
  consistency.sh (~5 lines). One additional acceptance criterion
  (AC-7). Both plans (baton-architect and first-principles-planner)
  agree on this.

## D3: Leave docs/*.md snapshots untouched (Q2)

- Choice: Do not modify any of the 5 `docs/*.md` files that
  mention the overlay (baton-positioning, review-analysis,
  runtime-thickness-analysis, baton-project-deep-analysis{,-zh},
  spec-deep-analysis).
- Rejected Alternatives: Add a one-line footer "(historical
  snapshot — spec/extensions overlay removed on 2026-04-05)" to
  each file.
- Why: User explicitly set this scope at Gate 0 triage. The 5
  files are historical analysis snapshots — their value lies in
  accurately reflecting the project state at their write-time.
  Retroactive footers break snapshot semantics. A retrospective
  standardization candidate can later propose a `docs/README.md`
  index note if reader confusion becomes a problem.
- Why Not: Some readers of `docs/*.md` may briefly be confused
  about whether `spec/extensions/` still exists. Accepted residual
  — these docs are not primary governance surface and the risk is
  bounded.
- Impact: Zero files touched in `docs/`. Flag in retrospective
  as standardization candidate for a docs-freshness check.
