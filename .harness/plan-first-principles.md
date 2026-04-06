# First-Principles Plan: remove-spec-extensions

> **Parallel output** for comparison with `.harness/architecture.md`
> (baton-architect output). Same task, different skill. Not a baton
> protocol artifact — no validator runs on this file.
>
> **Depth**: Standard. Rationale: the problem is well-understood
> (cleanup after completed migration), solution space is narrow (3
> candidates at most), but the user explicitly requested a Standard
> comparison baseline.
>
> **Input sources**: same as baton-architect — `exploration.md`,
> `requirements.md`, `knowledge/lessons.md`, repo greps.

---

## TL;DR (read first)

**Root problem**: `promote-java-artifacts` (2026-04-04) did half of a
two-step migration. It promoted the overlay's templates into core
but deliberately kept the migration guards in `check-consistency.sh`
as "migration regression catchers" for one task cycle. That cycle
has elapsed. The guards are now permanently-dead code, and the
directory they guarded is a zombie advertising a concept that
`baton-positioning` retired.

**Recommended action**: bundle 5 changes into one commit — delete
directory, clean 3 README refs, delete 3 vars + 3 if-blocks in
check-consistency.sh, delete 1 parenthetical in baton-evaluator
SKILL.md, ADD 1 new invariant `[[ ! -d spec/extensions ]]` as
regression guard. Total: ~15 lines removed, ~5 lines added, 7
files deleted. Verification: `check-consistency.sh` exit 0 + 6
targeted grep sweeps.

**Primary risk**: cross-file substring matching in
`check-consistency.sh`. Mitigation: per-hunk Edit calls with 3+
lines unique context, no sed sweeps.

**Disagreement with user's stated scope**: none. The original
request ("删除 spec/extensions 目录及其下面所有文件") is
literally one of five units in this plan. The other four are
downstream consequences the user implicitly accepted by
answering "基线+清理 check-consistency" at the Gate 0 triage
question. The +1 unit (new regression invariant) is an addition
the user did not explicitly request — justified in §2.4.

---

## Action Plan

| Priority | Change | Effort | Risk | Value |
|----------|--------|--------|------|-------|
| P0 | `rm -rf spec/extensions/` (7 files deleted) | ~1 min | None | Resolves user's literal ask |
| P0 | `spec/README.md` — 3 Edit calls, lines 17 / 136–137 / 201 | ~3 min | R-R1 (tree diagram symmetry) | Removes reader-facing mislead |
| P0 | `check-consistency.sh` — 6 Edit calls (3 vars + 3 if-blocks) | ~10 min | R-R2 (substring mismatch) | Removes permanent dead guards |
| P0 | `baton-evaluator` SKILL.md:210 — 1 Edit call | ~1 min | None | Removes stale hook-point prose |
| P1 | `check-consistency.sh` — ADD `invariant-19: [[ ! -d spec/extensions ]]` | ~5 min | None | **Closes the guard gap opened by the P0 changes** |
| **Total** | 4 edits + 1 delete + 1 add | **~20 min** | Low | Atomic cleanup, leaves no residue |

**Execution order** (single commit):
1. U1 (`rm -rf`) — first, atomic, no Edit dependency
2. U2 (README) — independent
3. U3 (check-consistency.sh deletes) — **run `bash
   check-consistency.sh` after this step** to verify surviving
   halves of invariants 14/17/18 still hold
4. U5 (check-consistency.sh add invariant-19) — depends on U1
   (for the runtime assertion to pass)
5. U4 (SKILL.md) — last, smallest
6. Final gate: `bash spec/bootstrap/commands/check-consistency.sh`
   end-to-end + `validate-artifact.sh` on all `.harness/` docs

## What NOT to Do

- **Do not use sed for the check-consistency.sh sweep.** `legacy_`
  is a prefix shared by 3 related variables, and the file has
  ~800 lines of bash with many `if [[ -e ... ]]` patterns. A
  sed sweep will find substring matches in wrong places.
  (Lesson source: `knowledge/lessons.md` — "Python str.replace
  substring-matches"; the same class of bug applies to bash
  variable prefixes.)
- **Do not split into 4 commits.** Intermediate states are
  confused — e.g., after U1 but before U3 the three invariants
  have dead-empty `[[ -e /deleted/path ]]` guards that still
  pass but are nonsense. Commit bisectability buys nothing
  because there is no behavior to bisect. The whole change is
  ~15 lines; it is one brain-load.
- **Do not touch `docs/*.md` files.** User scope is explicit.
  They are historical snapshots by design; editing them breaks
  their "snapshot" semantics. Flag in retrospective as
  standardization candidate instead.
- **Do not defer U5 (new invariant) to a follow-up task.** The
  same lesson that motivated building `check-consistency.sh` in
  the first place — "cross-file regex contracts need a static
  checker" — applies here in reverse: deleting the last cross-
  file assertion about `spec/extensions/` opens a check gap the
  instant U3 commits. Closing it in the same commit is ~5 lines
  and removes all ambiguity about whether the task is "done".

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Substring match error in check-consistency.sh Edit calls | Low (2/10) | Medium (could break master) | Per-hunk unique context (3+ lines), validate with grep post-edit |
| spec/README.md tree diagram visual asymmetry after line removal | Low | Low | Manual eye-read post-edit; if broken, fix manually |
| Future dev creates `spec/extensions/` again with no alert | Medium (if not guarded) | Medium | Closed by U5 (new invariant-19) |
| Latent reference grep missed (symlink, generated file, multi-line) | Very Low | Low (caught at Phase 5 Verify) | AC-6 full-repo sweep as final gate |
| `docs/*.md` drift — 5 files still mention the overlay | Accepted | Low (reader confusion only) | Out of scope per user; flag in retrospective |

---

## Analysis (why this plan, not another)

### Phase 1 — Problem Archaeology

**Five Whys**:
```
Stated: "Delete spec/extensions and all files in it"
Why?    → The overlay directory is a dead concept.
Why?    → `promote-java-artifacts` (2026-04-04) moved its
          templates to core.
Why?    → `baton-positioning` (2026-03-28) folded "stack-specific
          stricter overlays" into protocol core, retiring the
          overlay-as-extension model.
Root:     Baton's positioning changed from "protocol + optional
          overlays" to "protocol + local reference runtime".
          spec/extensions/ is residue from the old model.
```

The stated ask ("delete the directory") **is** the actionable
root — there is no deeper problem to reframe. But there is a
secondary root: the `check-consistency.sh` guards are not just
dead, they are guards that **prevent the very thing we are about
to do** (they would fail if the legacy templates existed, which
they don't, so they pass in a permanently-false-condition trance).
Deleting them is part of the literal request because the request
says "all files in spec/extensions" — and that directory's live
references outside itself are semantically part of "all files in
it".

**Load-bearing assumptions**:

1. **Positive halves of invariants 14/17/18 adequately cover the
   core templates.** Testable: read the invariant bodies. Verified
   in exploration §6 — each invariant has a positive
   `[[ -e spec/templates/*.template.md ]]` check plus downstream
   schema/skill/validator assertions. Removing the negative legacy
   halves drops zero coverage. **Verified before proceeding.**

2. **`check-consistency.sh` end-to-end is a sufficient functional
   test.** Convention — the repo has never had a unit test for
   this script and has always validated it via end-to-end invoke.
   Acceptable because this task only touches permanently-dead
   code, so there is no behavior change that would need finer
   test granularity.

3. **User genuinely wants `docs/*.md` snapshots untouched.**
   User intent — confirmed at Gate 0 via structured question.
   Verified.

4. **No latent reference exists that repo-wide grep missed.**
   Testable but not exhaustive (grep is line-based). Caught by
   AC-6 as a post-generation sweep. Accepted residual.

**Constraints vs. conventions**:

- **True constraint**: `check-consistency.sh` must stay exit 0
  (external: any downstream task invocation depends on it). Keep.
- **True constraint**: strict isolation for Phase 5 Verify / Phase
  7 Review (contract with `validate-isolation.sh` + strong local
  lesson). Keep.
- **Convention (kept)**: one commit, not four. Convention that
  cleanup tasks are bundled; questioned and kept because the
  alternative has no benefit.
- **Convention (kept)**: manual Edit tool, no sed. Questioned and
  kept because the lesson from skill-retrospective-alignment
  specifically warned against the sed alternative.
- **Convention (questioned, kept)**: no unit test for
  check-consistency.sh. Acceptable because adding one is a
  standardization candidate out of scope here.

### Phase 2 — Solution Reconstruction

**Three solution categories** (differ in mechanism, not
parameters):

- **Category A — Atomic bundled cleanup + new regression guard.**
  *Mechanism*: treat the 4 deletions and the 1 addition as one
  semantic unit ("overlay is retired; here is the assertion that
  it stays retired"). One commit, one gate, one review.
- **Category B — Sequential split commits, no regression guard.**
  *Mechanism*: maximize commit bisectability by splitting the 4
  deletion units into separate commits, then run check-consistency
  after each. No new invariant; the lack of a check is accepted.
- **Category C — Scripted sweep via find + sed.**
  *Mechanism*: write a one-shot cleanup script that greps and
  sed-deletes mechanically. No per-hunk manual Edit calls.

**Inversion test** ("under what conditions would Category A be the
worst approach?"):

- If the task were actually **large** (say 50+ files), a bundled
  commit would be unreviewable. — Not this task (~15 lines).
- If the units had **independent rollback value** (e.g., U1 could
  ship but U3 might need to wait on another team), splitting
  would be right. — Not this task (all units are tightly coupled
  to the same conceptual change).
- If adding invariant-19 required **coordinated changes** in
  unrelated files, bundling it into this task would bloat scope.
  — Exploration found no such coordination needed.
- If the user had **explicitly rejected** the regression guard
  idea, bundling would violate scope. — User did not reject it;
  it is simply not in the original statement.

No plausible failure mode for Category A on this task.

**Rejection reasoning**:

- **Category B rejected** because intermediate states are
  semantically confused (dead-empty invariants pointing at
  deleted paths, skill prose hinting at removed extensions, etc.)
  and commit bisectability has no value on a zero-behavior-change
  cleanup. Split adds reviewer friction (4 diffs to scan instead
  of 1) with no safety upside.
- **Category C rejected** because it directly contradicts the
  skill-retrospective-alignment lesson about substring matching.
  `check-consistency.sh` has 3 variables with the `legacy_`
  prefix and many other variables elsewhere; a sed sweep targeted
  at `legacy_` is one near-miss away from breaking an unrelated
  invariant. The manual Edit path is safer and only marginally
  slower.

### Phase 3 — Dissenting Path

If the user disagrees with bundling R7/U5 (the new regression
invariant), here is the "split and follow-up" plan:

1. Drop U5 from this task; mark R7 as `deferred` in
   requirements.md.
2. Create a follow-up task `spec-extensions-regression-guard`
   immediately after this task closes — one-line change, ~5
   minutes.
3. Risk: the follow-up gets forgotten. Probability: non-trivial
   given task queue churn. Mitigation: have the retrospective
   for this task explicitly name the follow-up as an open
   standardization candidate.

**Conditions that would justify splitting**:
- If the user preferred strictly-minimal commits that match the
  literal request only.
- If U5 required investigation into where to place the new
  invariant (it doesn't — trivial location).
- If bundling would break commit-message hygiene (it doesn't —
  one sentence covers all 5 units).

---

## Self-Check

**Core question**: What is this plan's most likely failure mode,
and what would I do differently if I knew it would fail?

Most likely failure: one of the 6 Edit calls to
`check-consistency.sh` fails because the `old_string` context I
chose is not as unique as I thought — another invariant uses
similar phrasing. The Edit tool errors on ambiguous matches, so
the failure is **loud**, not silent. Recovery: read the surrounding
window, pick more unique context (e.g., include an adjacent
`printf` line with a distinctive number), retry.

**Second-most-likely failure**: after U3, `check-consistency.sh`
passes but I notice a cosmetic issue (e.g., a blank line left
behind where the if-block used to be). Low impact, quick fix.

**If the user stated a solution, not a problem — did I trace to
the actual root?** Yes. The user stated a literal deletion. Five
Whys traced back to `baton-positioning` repositioning. The root
confirms the literal ask rather than reframing it; I validated the
user's instinct with evidence (§2.4 exploration) rather than
forcing a reframe.

**If I am recommending against the user's approach — what
evidence would change my mind?** Not applicable here. The plan
extends the user's approach (adds U5) rather than opposing it.
Evidence that would pull U5 out: a user statement that they
prefer minimal commits, or exploration surfacing a reason U5
requires coordinated changes.

**Can the user predict the outcome from reading this plan alone?**
Yes, if they read the Action Plan table plus the "What NOT to
Do" section. The "Why this plan" analysis is optional reading
for the reasoning audit.

---

## Plan Comparison Note (vs baton-architect)

The `baton-architect` output (`.harness/architecture.md`) and
this first-principles plan arrive at **the same recommendation**
(Category A, bundle R7, ~15-line single commit) through different
document structures. Expected deltas for the user to evaluate:

| Dimension | baton-architect | first-principles-planner |
|-----------|----------------|--------------------------|
| Section structure | Fixed 8 sections + Delivery Order (validator-enforced) | Flexible: TL;DR → Action Plan → What Not → Risks → Analysis → Self-Check |
| Audience | Reviewer + downstream skills (verifier, generator, evaluator) — machine-parseable | Human decision-maker — conclusion-first |
| Lesson integration | Cites lessons explicitly in `## 6. Risks` with source lines | Cites lessons inline with "(Lesson source: ...)" parenthetical |
| Decision framework | Category comparison + Self-Challenge + Reversibility table | Five Whys + Assumption Audit + Inversion Test + Dissenting Path |
| Artifact commitments | `.harness/architecture.md` passes validator; downstream skills consume it | `.harness/plan-first-principles.md` (non-protocol); no downstream consumer |
| Depth calibration | Risk-adaptive matrix (Medium → full comparison, delivery order recommended) | Depth calibration table (Standard here, explicit rationale) |
| Human gate handling | Has `## 8. Human Judgment Notes` section for Gate 2 annotations | No gate section; expects direct user confirmation |
| Verification binding | §5 maps to requirements.md ACs and produces exact commands for verification.md | Names the checks but does not bind to requirements.md IDs |

**Where the two agree**: recommended approach, delivery order
within the bundle, bundling decision for R7, rejection of sed
sweeps, docs/*.md out of scope.

**Where the two differ in emphasis**:
- baton-architect spends more space on **reviewability** (Surface
  Scan table, Reversibility concern, downstream skill hand-off).
- first-principles-planner spends more space on **root-cause
  justification** (Five Whys trace to `baton-positioning`,
  explicit assumption-audit verification of A1).

Neither document surfaces a decision the other misses for this
task. On a larger or more ambiguous task, the divergence would be
larger.
