---
name: baton-retrospective
description: >
  Fill the retrospective document after task completion. Trigger when the user
  says "write retrospective", "task complete", "close task", or "post-mortem".
  Reads all task artifacts and produces retrospective.md.
user-invocable: true
---

# Retrospective

## Role Contract

- **Inputs**: all `.harness/` artifacts from the completed task
- **Outputs**: `.harness/retrospective.md`, updated `task-status.md`

## Artifact Language Policy

Read `artifact_language` from `task-status.md` § State Notes (`zh` or `en`).
Write all human-facing artifacts in that language.
Do not localize `task-status.md`.

## Execution Steps

1. Read all artifacts: `scoped-map.md`, `requirements.md`, `architecture.md`,
   `verification-path.md`, `evaluation.md`, `task-status.md`,
   `clarification-brief.md` (if exists), and `generator-feedback.md`
   (if exists).

2. Extract metrics from the artifacts (see Metrics section below).

3. Write `.harness/retrospective.md` covering these dimensions:

   ### 1. Metrics
   Quantitative data extracted from the task run. These accumulate across
   tasks to reveal systemic patterns.

   ### 2. What Worked
   Which gates, artifacts, or process steps actually prevented a problem?
   Be specific — "Gate 3 caught a missing test fixture before Generator began"
   is useful; "the process worked well" is not.

   ### 3. What Failed or Was Skipped
   Which steps were bypassed, produced low-quality output, or caused rework?
   Include repair loop rounds and what drove them. If the evaluator's repair
   loop memory classified findings, reference the classifications (FIXED,
   RECURRING, REGRESSED, NEW).

   ### 4. What Should Be Standardized
   Findings worth writing into `profile.local.yaml` or the adapter doc for
   this repo — patterns that are repo-specific but should be default going
   forward.

   ### 5. Repo-Specific Lessons
   Discoveries that only apply to this repository (toolchain quirks,
   undocumented constraints, risky files).

   ### 6. Skill Patches
   Concrete, actionable improvements to specific skills. Each patch must
   reference the target skill and section:

   ```markdown
   - **Target**: baton-generator, Section "Checkpoint Validation"
     **Finding**: Generator did not lint per batch; evaluator Round 1
     spent entirely on lint fixes
     **Suggested Rule**: Add lint to checkpoint validation commands
   ```

   Only suggest patches for issues that actually caused problems in this
   task — not hypothetical improvements.

   ### 7. Profile Patches
   Configuration changes that can be directly applied to
   `profile.local.yaml` based on this task's experience:

   ```markdown
   - `generator.checkpoint_includes_lint: true`
   - `evaluator.layer1_includes: [build, test, lint, typecheck]`
   ```

   ### 8. Follow-up Tasks
   Concrete next steps that emerged from this task but are out of scope:
   - Tech debt to address
   - Tests to add for uncovered edge cases
   - Documentation to update
   - Monitoring or alerting to add

4. Update `task-status.md` → state `complete`.

## Metrics

Extract these metrics from the task artifacts:

| Metric | Source | Purpose |
|--------|--------|---------|
| Clarification questions asked | `clarification-brief.md` interview log | Measures requirement ambiguity |
| Risk level assessed | `task-status.md` | Calibrates risk assessment accuracy |
| Exploration depth used | `scoped-map.md` | Validates risk-adaptive depth |
| Requirements count (P0/P1/P2) | `requirements.md` | Tracks scope creep |
| Architecture approaches considered | `architecture.md` | Measures design rigor |
| Verification commands count | `verification-path.md` | Measures test coverage planning |
| Eval rounds | `task-status.md` / `evaluation.md` | Measures implementation quality |
| Repair finding classification | `evaluation.md` | FIXED/RECURRING/REGRESSED/NEW ratio |
| Blocked count | `task-status.md` | Measures flow interruptions |
| Phases skipped | `task-status.md` | Tracks process shortcuts |
| Actual vs predicted write surface | `architecture.md` vs `git diff --stat` | Measures architecture accuracy |
| Self-review failures caught | Generator notes | Measures pre-handoff quality |

## Output Template

```markdown
# Retrospective — [Task ID]

**Completed**: [date]
**Risk level**: [Low/Medium/High]
**Eval rounds**: [N]

## Metrics

| Metric | Value |
|--------|-------|
| Clarification questions | N |
| Requirements (P0/P1/P2) | N/N/N |
| Architecture approaches | N |
| Verification commands | N |
| Eval rounds | N |
| Repair findings | N FIXED, N RECURRING, N REGRESSED, N NEW |
| Blocked count | N |
| Write surface accuracy | N predicted / N actual files |

## What Worked
-

## What Failed or Was Skipped
-

## What Should Be Standardized
-

## Repo-Specific Lessons
-

## Skill Patches
- **Target**: [skill], Section "[section]"
  **Finding**: [what went wrong]
  **Suggested Rule**: [concrete improvement]

## Profile Patches
- `[config.key]: [value]`

## Follow-up Tasks
- [ ] [concrete next step]
```
