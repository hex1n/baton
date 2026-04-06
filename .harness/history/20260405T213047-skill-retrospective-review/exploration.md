# Scoped Map: skill-retrospective-review

**Requirement**: 讨论 `skills/baton-retrospective` 的必要性,并给出命名建议
**Domain**: baton harness / skills layer
**Owner**: `scoped-explorer`
**Status**: `complete`

## 1. Scope

- In scope: analysis and recommendation on (a) whether `baton-retrospective` should exist as a dedicated skill, (b) whether its current name is optimal; identify drift between the skill and its template
- Out of scope: implementing any rename, editing the skill body, changing other skills, refactoring the retrospective template
- Expected write boundary: only `.harness/` artifacts for this task (no code changes)

## 2. Entry Point

- Primary: `skills/baton-retrospective/SKILL.md` (174 lines)
- Contracts it touches:
  - `spec/templates/retrospective.template.md` (the artifact schema)
  - `spec/bootstrap/commands/start-task.sh` lines 246–296 (the downstream lesson extractor)
  - `spec/protocol/role-contracts.md` (phase ownership)
  - `skills/baton-orchestrator/SKILL.md` (uses it as a distinct phase)
- Why these are entries: the skill defines an LLM-facing contract whose outputs are now parsed by a shell script — it sits at the intersection of the skill layer and the protocol layer.

## 3. Call Chain

```text
task complete trigger
  → user invokes baton-retrospective (or orchestrator calls it)
  → skill reads .harness/*.md
  → skill writes .harness/retrospective.md (level-2 sections)
  → skill updates task-status.md to `complete`
  → next task start → start-task.sh:246 archives retrospective.md
  → start-task.sh:251–254 sed-extracts §4/§5 → knowledge/lessons.md
  → next task's explorer reads knowledge/lessons.md (MUST, per role-contracts)
```

## 4. Data Flow

- Source: all `.harness/*.md` artifacts from the completed task
- Transforms: LLM synthesizes metrics, identifies non-obvious lessons, drafts 8 output dimensions per skill prose
- Sink: `retrospective.md` (level-2 sections); `task-status.md` (state=complete)
- Downstream consumer: `start-task.sh` regex extractor → `knowledge/lessons.md`

## 5. Existing Behavior

- Skill is `user-invocable: true` — triggered by "write retrospective", "task complete", "close task", "post-mortem"
- Skill prose (lines 31–94) describes 8 dimensions: Metrics, What Worked, What Failed, What Should Be Standardized, Repo-Specific Lessons, Skill Patches, Profile Patches, Follow-up Tasks
- Output template block (lines 118–174) shows: Metrics, What Worked, What Failed, What Should Be Standardized, **## 4. Repo-Specific Lessons** (numbered), **## 5. Harness Lessons** (numbered), Skill Patches, Profile Patches, Follow-up Tasks
- Template file `spec/templates/retrospective.template.md` has 6 sections: Outcome, What Worked, What Failed, Repo-Specific Lessons, Harness Lessons, Standardization Candidates — **numbered 1–6**

## 6. Existing Tests

- No direct tests on skill output
- Indirect guards:
  - `check-lesson-index-consistency.sh` checks that `## [N. ]Repo-Specific Lessons` and `## [N. ]Harness Lessons` exist in `baton-retrospective/SKILL.md` (added during this task's previous fix)
  - `validate-artifact.sh` validates `retrospective.md` has required sections — wait, actually no: retrospective is not in the validator's `case` list. It runs `return 0` (skip) for any non-listed type. So there is NO section validator for retrospective.md.

## 7. Change History

- Commit `884e4ce` (Nov 2025): added lesson-index extraction wiring — drifted immediately
- Commit `ab071c9` (recent): i18n removal, template simplification
- The skill has accumulated cruft: section numbering in skill ≠ template ≠ output template inside the skill itself

## 8. Dependency / Risk Scan

- **Drift #1 (HIGH)**: Skill prose Step 3 lists 8 dimensions in order [Metrics, WhatWorked, WhatFailed, Standardized, RepoLessons, SkillPatches, ProfilePatches, FollowUp], but the skill's own output template block lists them in a DIFFERENT order with DIFFERENT numbering. And neither matches `spec/templates/retrospective.template.md`'s 6 sections. This is exactly the failure mode the lesson-index fix was about — the skill contract and the template have diverged.
- **Drift #2 (MEDIUM)**: The real `retrospective.template.md` has no `## Metrics` section, no `## Skill Patches` section, no `## Profile Patches` section, no `## Follow-up Tasks` section. The skill asks for these but the template doesn't hold them.
- **Drift #3 (LOW)**: Skill prose §5 "Repo-Specific Lessons" and output template `## 4. Repo-Specific Lessons` — different numbering within one file.
- **Isolation**: this skill is the ONLY writer of `retrospective.md`, which is the ONLY source of truth for `knowledge/lessons.md` via the extractor. Any change to its section shape ripples into FR-7.

## 9. Change Shape

- This looks like: **analysis + recommendation**, not code change
- Estimated file count: 0 code files (this task is discussion-only); potential follow-up task would touch 1–3 files (skill + template + maybe validator)
- Preferred implementation depth: Low-risk — no Clarifier needed, no Architect, short direct recommendation

## 10. Open Questions

- Does the 8-dimension skill prose reflect an aspirational v2 design that was never applied to the template, or is the template the post-simplification reality and the skill is stale? (Need to check git log on both files.)
- Is the `baton-orchestrator` consumer of this skill depending on the 8-dimension shape, or on the 6-section template shape?

## 11. Recommendation

- **Proceed**: yes — this is a low-risk analysis task, report findings and recommendations directly to the user; no gate escalation needed
- **Suggested next step**: present (a) necessity verdict, (b) naming verdict, (c) URGENT drift finding (skill ≠ template) as a separate follow-up task candidate
- **Uncertainty flags**: haven't checked git blame on skill vs template to determine which is authoritative; haven't audited the orchestrator for which shape it expects

## 12. Historical Lessons

> Explorer MUST read `<repo-root>/knowledge/lessons.md` and record findings here.

- **Relevant prior lessons** (from `knowledge/lessons.md`, task `knowledge-compound-mvp`):
  - "When a skill's output template is the contract for a downstream extractor, updating the template is not enough — the skill prose must explicitly instruct the LLM to write the new section." → **directly applies**: `baton-retrospective` IS the skill whose output template is a contract for `start-task.sh`'s extractor. This task found that the skill prose and the actual template disagree — exactly the failure mode the lesson warns about, recursively.
  - "Cross-file regex contracts need a static checker." → `check-lesson-index-consistency.sh` already guards §4/§5 heading presence in this skill, but does NOT validate that skill prose ordering matches the template. Gap surfaced by this exploration.
- **Lessons explicitly not applicable**:
  - BSD sed BRE lesson → no sed work in this task
  - Gate 2 defaults lesson → no gate decisions being made
