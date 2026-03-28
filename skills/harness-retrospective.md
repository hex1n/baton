---
name: harness-retrospective
description: >
  Fill the retrospective document after task completion. Trigger when the user
  says "write retrospective", "task complete", "close task", or "post-mortem".
  Reads all task artifacts and produces retrospective.md.
user-invocable: true
---

# Retrospective

## Role Contract

- **Inputs**: all `.harness/` artifacts from the completed task
- **Outputs**: `.harness/retrospective.md`, updated `module-status.md`

## Artifact Language Policy

Before writing any human-facing artifact:

1. If `.harness/profile.local.yaml` sets `documentation.artifact_language` to
   `zh` or `en`, use that language.
2. If it is `auto`, follow the current user request language.
3. If the setting is missing, default to Chinese.

Do not localize `module-status.md`. Keep the control-plane file, owner tokens,
state tokens, and blocker categories in stable English.

## Execution Steps

1. Read all artifacts: `scoped-map.md`, `requirements.md`, `architecture.md`,
   `verification-path.md`, `module-status.md`, and `generator-feedback.md`
   (if it exists).

2. Write `.harness/retrospective.md` covering these dimensions:

   ### 1. What Worked
   Which gates, artifacts, or process steps actually prevented a problem?
   Be specific — "Gate 3 caught a missing test fixture before Generator began"
   is useful; "the process worked well" is not.

   ### 2. What Failed or Was Skipped
   Which steps were bypassed, produced low-quality output, or caused rework?
   Include repair loop rounds and what drove them.

   ### 3. What Should Be Standardized
   Findings worth writing into `profile.local.yaml` or the adapter doc for
   this repo — patterns that are repo-specific but should be default going
   forward.

   ### 4. Repo-Specific Lessons
   Discoveries that only apply to this repository (toolchain quirks,
   undocumented constraints, risky files).

   ### 5. Spec or Skill Improvement Suggestions
   Concrete suggestions for improving the harness spec or role skills.
   Reference the specific file and section if possible.

3. Update `module-status.md` → state `complete`.

## Output Template

```markdown
# Retrospective — [Task ID]

**Completed**: [date]
**Eval rounds**: [N]

## What Worked
-

## What Failed or Was Skipped
-

## What Should Be Standardized
-

## Repo-Specific Lessons
-

## Spec / Skill Improvement Suggestions
-
```
