# Retrospective: skill-retrospective-review

## 1. Outcome

- Closed as: completed — analysis delivered, follow-up task scoped
- Main blocker: none
- Human decision: 2026-04-05 — accepted recommendation to keep `baton-retrospective` skill name, accepted finding that skill/template have drifted, chose to spin off a separate `skill-retrospective-alignment` task rather than expanding scope of this discussion task

## 2. What Worked

- Scoping this task as Low-risk discussion-only (no code changes, §1 out-of-scope locked) allowed a direct skill-read → analysis → recommendation flow without Clarifier/Architect ceremony
- Reading the live `knowledge/lessons.md` during exploration §12 surfaced the recursive hit — the lesson from the previous task ("skill output template is the contract") directly applied to the skill being reviewed. This is the first evidence that the compounding mechanism actually changes analysis behavior, not just stores text.

## 3. What Failed

- Not a failure in this task, but a finding: the previous task's `check-lesson-index-consistency.sh` only guards §4/§5 heading presence in `baton-retrospective/SKILL.md` — it does NOT guard that skill prose ordering matches template ordering. The consistency checker has a gap large enough for this new drift to sit in.

## 4. Repo-Specific Lessons

- **`validate-artifact.sh` has no case for `retrospective` — retrospectives are written with ZERO structural validation.** Trigger: any edit to `skills/baton-retrospective/SKILL.md` or `spec/templates/retrospective.template.md`. Takeaway: when adding a new artifact type to the harness, grep `validate-artifact.sh` for the type name; if missing, the artifact has no section guarantees and can silently drift. This is how the skill/template shape diverged without anyone noticing. Why: retrospective.md is now load-bearing for `knowledge/lessons.md` (via start-task.sh extractor), so its structure is a contract, not just documentation.

## 5. Harness Lessons

- **Skills with `user-invocable: true` but whose outputs feed a downstream script are dual-contract: LLM-facing prose AND machine-parseable schema.** Trigger: any user-invocable skill whose output is later parsed by a non-LLM consumer (shell, validator, other tooling). Takeaway: treat the skill as having two audiences — the LLM reader (prose + examples) and the downstream parser (exact headings, exact field names). A change that's clear to the LLM can silently break the parser, and vice versa. Why: `baton-retrospective` is the canonical example — its §4/§5 headings are load-bearing for `start-task.sh`, but the rest of its output template drifted freely because the LLM-facing half was never audited against the machine-facing half.
- **Lesson-compounding works best when the reader's analysis question is specific enough to trigger recall.** The question "discuss necessity of baton-retrospective" is general, but "is the skill's output template a contract for a downstream parser?" is specific — and that's exactly the shape of the previously-compounded lesson. Takeaway: explorer §12 should be read BEFORE framing the exploration, not after, so the lesson can shape the question rather than just decorate the answer. (This run I read lessons mid-exploration, not before.)

## 6. Standardization Candidates

- Add `retrospective` to `validate-artifact.sh` case list — unblock a whole class of future drift
- Explorer's §12 Historical Lessons should be read in Step 0 (before scope definition), not Step 1b — so lessons can influence what's in scope
