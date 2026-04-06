# Retrospective: remove-spec-extensions

## 1. Outcome

- Closed as: complete
- Main blocker: none
- Human decision: accepted cosmetic fixes (double blank lines, singular "extension" wording); confirmed close

## 2. What Worked

- Category A (bundled single commit) was the right call — the 5 units are tightly coupled and the whole change is small enough to review in one pass
- Bundling R7 (invariant-19 regression guard) atomically closed the "unguarded deletion" gap that knowledge-compound-mvp warned about
- Per-hunk Edit with unique context avoided the substring-matching trap that burned skill-retrospective-alignment
- Strict isolation for verifier and evaluator caught the provenance bullet gap (missing `- Verdict:` field) before human close

## 3. What Failed

- Evaluator wrote the verdict only in a section heading, not as a provenance bullet field — `validate-isolation.sh` reads `- Verdict:` via `provenance_read_field`, so the stop hook blocked. Required a post-evaluation fix.
- Architecture stated if-blocks were 2 lines; they were 4 lines (if/printf/increment/fi). Non-blocking but inaccurate.

## 4. Repo-Specific Lessons

- `validate-isolation.sh` reads `Verdict` from evaluation.md as a provenance bullet (`- Verdict: <value>`), not from the `## Verdict` section body. Evaluators must include a `- Verdict:` bullet in the Execution Provenance block, not just a section heading. This is the same provenance-field contract that verification.md uses for Role/Isolation mode/etc.

## 5. Harness Lessons

- The evaluation template should pre-populate a `- Verdict:` bullet in the Execution Provenance section to prevent this class of omission. Currently the template has no such hint, and the evaluator skill doesn't mention it.

## 6. Standardization Candidates

- `docs/*.md` historical snapshots still reference `spec/extensions/java-backend-strict/` — a `docs/README.md` index note or freshness check could reduce future reader confusion (deferred per NG-1)
- Evaluation template should include `- Verdict:` in the provenance block scaffold
