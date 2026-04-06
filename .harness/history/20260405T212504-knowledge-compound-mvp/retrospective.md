# Retrospective: knowledge-compound-mvp

## 1. Outcome

- Closed as: completed — lesson-index silent bug fixed and end-to-end validated
- Main blocker: none after Gate 2 approval
- Human decision: 2026-04-05 — accepted all 6 Gate 2 defaults in a single pass; continued past Gate 2 after first-principles-planner vs baton-pipeline comparison trial

## 2. What Worked

- Running first-principles-planner and baton's own pipeline in parallel on the same problem exposed the silent bug that motivated this task — the comparison surfaced the failure mode before a formal incident
- One static consistency checker (`check-lesson-index-consistency.sh`) caught more drift cases (path, isolation rule, protocol docs) than a shared constants module would have, at lower complexity
- End-to-end tmp-repo fixture test was a cheap and decisive proof — avoided needing to run a full baton task to validate the extractor chain

## 3. What Failed

- The original 2025-11 wiring (commit `884e4ce`) was merged without any cross-file validation; three files drifted independently and the feature silently returned empty for ~4 months
- My first draft of `baton-explorer/SKILL.md` referenced §11 for Historical Lessons but `exploration.template.md` used §12 — same class of numbering drift as the original bug; caught only because I re-read the template

## 4. Repo-Specific Lessons

- **Cross-file regex contracts need a static checker, not per-file unit tests.** Trigger: a sed/awk/grep in file A targets a header format owned by file B (or C), and no single edit touches both. Takeaway: add a standalone check script that grep-validates both sides agree on the exact heading shape, wire it into pre-commit. Unit tests on either side alone will pass while the chain is dead. Why: this is exactly how commit `884e4ce` stayed broken for months.
- **When a skill's output template is the contract for a downstream extractor, updating the template is not enough — the skill prose must explicitly instruct the LLM to write the new section.** Trigger: adding or renaming a section that a script downstream will parse. Takeaway: grep the skill body for the section header too; if it only appears in the "example output" block and not in the instructions, the LLM will skip it half the time.
- **`validate-artifact.sh` should distinguish "section header exists" from "section has content".** Grep proves the header is present, awk is needed to detect empty sections (e.g. only a template placeholder or a `<!-- comment -->`). Takeaway: for any required artifact section whose silent omission is a load-bearing failure mode, add an awk-based non-empty check, not just a grep header check.
- **BSD sed BRE: optional groups use `\(…\)\{0,1\}`, not `\(…\)?`.** Takeaway: when writing sed patterns that must run on macOS (default user platform), test the regex on BSD sed before trusting it — GNU sed's extended syntax will silently match nothing on BSD.

## 5. Harness Lessons

- **Context isolation rules must be guarded by a negative assertion in a checker, not only documented in role-contracts.md.** `role-contracts.md:133` has said "verification-explorer and evaluator MUST NOT read lessons" for months, but nothing stopped a future edit from adding the read step. Takeaway: every "MUST NOT" rule in role-contracts needs a corresponding grep-based negative check in a consistency script; otherwise the rule is aspirational.
- **Silent protocol-layer bugs compound invisibly — add observability at the extraction/write boundary.** The original extractor wrote nothing for months and produced no error, no warning, no log. Takeaway: whenever a protocol script conditionally writes an artifact, it should either write something observable (even "no lessons extracted for task X") or fail loudly if it was supposed to write but found nothing to extract. Silent no-op is the worst failure mode.
- **Gate 2's "accept all defaults" path is fast but risky if the architect hasn't considered all 6 dimensions.** This task happened to be narrow enough that all 6 defaults were genuinely correct, but a more complex task with even one bad default would have shipped silently. Takeaway: when recommending "accept all defaults," the architect should state explicitly which defaults were load-bearing judgment calls vs. obvious mechanical choices, so the human's one-click approval is informed.

## 6. Standardization Candidates

- Generalize the consistency-checker pattern: any cross-file regex contract in the harness protocol should get a dedicated `check-<feature>-consistency.sh`. Candidates: provenance header parsing, task-status schema validation, template↔validator alignment.
- Consider adding an awk-based "section non-empty" helper to `validate-artifact.sh` as a reusable function, so future required sections can opt into content-level checks with one line.
