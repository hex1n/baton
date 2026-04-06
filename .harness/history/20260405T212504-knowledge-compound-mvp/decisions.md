# Technical Decisions

**Topic**: 修复并上线 baton lesson-index 跨任务复利机制
**Owner**: `architect`
**Status**: `ratified`
**Gate 2 approved**: 2026-04-05 (user accepted all 6 recommended defaults in a single pass)

## D1: Physical location of the cross-task lesson store

- Choice: **Category B** — `<repo-root>/knowledge/lessons.md`, gitignored, local-only.
- Rejected Alternatives:
  - Category A: keep status quo `.harness/lesson-index.md` tracked in repo. Preserves protocol self-consistency but can't hold company-sensitive context.
  - Category C: dual-file split (tracked `.harness/lesson-index.md` for protocol-level lessons + gitignored `knowledge/lessons.md` for private). Extra complexity with two extraction targets and two merge points; not worth it for a single-user flow.
- Why: User explicitly chose "`knowledge/` at repo root + gitignored + local" in clarification-brief Q3, so future company tasks can record sensitive context without leaking. Adds zero new runtime, only one path string change.
- Why Not (Category A): rejected in clarification-brief — violates user's privacy requirement.
- Impact: `.gitignore` adds `knowledge/`; `start-task.sh` writes to new path; `role-contracts.md` / `artifact-schema.md` reference new path; users are responsible for local backup (accepted trade-off).

## D2: Write trigger point (who performs the extraction)

- Choice: **Option α** — keep the delayed shell extraction inside `spec/bootstrap/commands/start-task.sh` at task-start time. Reads the outgoing task's `retrospective.md` and appends to `knowledge/lessons.md`.
- Rejected Alternatives:
  - Option β: move extraction into `skills/baton-retrospective/SKILL.md`, have the LLM write the lesson block directly when closing the task. Closer temporal coupling, but subject to the same "LLM might skip it silently" failure mode that broke this feature for months.
- Why: Bash is more reliable than LLM compliance for mechanical extraction. The existing extractor logic (commit 884e4ce) already handles LRU pruning, header preservation, and atomic writes — reusing it is lower-risk than rewriting in skill prose.
- Why Not (β): LLMs forget. This whole task exists because the LLM-facing half of the chain was silently broken for months.
- Impact: zero code-path change for the extractor other than regex/path fixes; the trigger remains start-task.sh's existing lesson-extraction block.

## D3: Consistency guarantee mechanism

- Choice: **Validator-only** — `spec/bootstrap/commands/check-lesson-index-consistency.sh` runs as a static check. No shared constants module, no code-generation.
- Rejected Alternatives:
  - Extract heading patterns into a shared constants file (`spec/bootstrap/lib/lesson-headings.sh`) sourced by both start-task.sh and SKILL templates. Stronger guarantee, but over-engineered for a single-user flow.
  - Manual discipline only. Rejected: this failure mode IS the bug.
- Why: Single check script catches the exact regression that caused the original bug (3-file heading drift) plus adjacent drift (path, isolation rule, protocol docs). Cheaper than a constants module, and catches more cases.
- Why Not: if the project gains more contributors, a constants module becomes justified.
- Impact: `check-lesson-index-consistency.sh` added; not wired into CI automatically (single-user flow, invoked manually or via pre-commit if the user wants).

## D4: Minimum lesson schema

- Choice: **Single-line markdown bullet** with free-form structure. Recommended shape:
  `- **[context]** trigger: takeaway ([source: task-id/retrospective.md])`
- Rejected Alternatives:
  - YAML frontmatter per entry. Over-engineered; breaks "hand-editable" design goal.
  - Structured table. Rigid; lessons don't fit uniform columns.
- Why: Matches Karpathy LLM-wiki philosophy (raw sources + minimal wiki layer); easy for a human to write by hand; easy for the extractor to preserve as a verbatim block.
- Why Not: loses queryability — accepted trade-off since total entry count is bounded by LRU-30.
- Impact: `spec/templates/lesson-index.template.md` comment reflects the recommended shape; no schema enforcement in the validator (human review only).

## D5: LRU retention threshold

- Choice: **30 tasks** (up from the original 10).
- Rejected Alternatives: 10 (original), 50, 100, unbounded.
- Why: For a single-user flow, 10 is too aggressive — long-running use will lose relevant lessons before they matter. 30 is a reasonable middle ground: roughly one year of weekly tasks, still short enough to keep the index loadable into LLM context in one read.
- Why Not 50/100: LLM context size at 50 entries starts to compete with other artifacts in the same read step.
- Impact: `start-task.sh` `max_lesson_tasks=30`; `artifact-schema.md` reflects the new threshold; older overruns are pruned on each archival cycle.

## D6: Backfill intervention mode

- Choice: **Semi-automatic** — `spec/bootstrap/commands/backfill-lessons.sh` walks `.harness/history/*/retrospective.md`, extracts candidate lessons (Chinese and English headings), outputs to a draft `knowledge/lessons.md.draft`, and waits for human review before the user `mv`'s it to the live file.
- Rejected Alternatives:
  - Fully manual: read 15 retrospectives by hand. Too slow.
  - Fully automatic: script commits directly to `knowledge/lessons.md`. Risks polluting the index with low-signal "just follow process" boilerplate — the Risk-1 failure mode from clarification-brief.
- Why: script solves the tedious extraction; human judgment solves the non-obvious-lesson filter (the actual hard part).
- Why Not fully auto: see Risk-1 in clarification-brief — signal-to-noise is the #1 failure mode for this feature.
- Impact: `backfill-lessons.sh` is a one-shot bootstrap tool; it does not run during normal task archival. User runs it once to seed `knowledge/lessons.md`, then discards the script (or keeps it for future historic retros).
