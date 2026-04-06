---
name: baton-retrospective
description: >
  Close the task: write `retrospective.md` AND feed `knowledge/lessons.md`.
  Reads all task artifacts, records non-obvious lessons in §4/§5 that the
  next `start-task.sh` run will extract into the cross-task lesson index.
  Trigger when the user says "write retrospective", "task complete",
  "close task", or "post-mortem".
user-invocable: true
---

# Retrospective

## Role Contract

- **Inputs**: all `.harness/` artifacts from the completed task
- **Outputs**: `.harness/retrospective.md`, updated `task-status.md`
- **Downstream consumer**: `spec/bootstrap/commands/start-task.sh` extracts
  `## 4. Repo-Specific Lessons` and `## 5. Harness Lessons` into
  `<repo-root>/knowledge/lessons.md` when the next task starts. The heading
  format is a machine-parseable contract — do not rename or re-number.

## Artifact Language Policy

Write all human-facing artifacts in the language of the user's request.
Do not localize `task-status.md`.

## Execution Steps

1. Read all artifacts: `exploration.md`, `requirements.md`, `architecture.md`,
   `verification.md`, `evaluation.md`, `task-status.md`,
   `clarification-brief.md` (if exists), and `escalation.md` (if exists).

2. Write `.harness/retrospective.md` covering exactly these 6 sections, in
   this order (matches `spec/templates/retrospective.template.md`):

   ### 1. Outcome
   How the task closed: completed / blocked / deferred. Name the main
   blocker (if any) and the human decision that resolved it.

   ### 2. What Worked
   Which gates, artifacts, or process steps actually prevented a problem?
   Be specific — "Gate 3 caught a missing test fixture before Generator began"
   is useful; "the process worked well" is not.

   ### 3. What Failed
   Which steps were bypassed, produced low-quality output, or caused rework?
   Include repair loop rounds and what drove them. If the evaluator's repair
   loop memory classified findings, reference the classifications (FIXED,
   RECURRING, REGRESSED, NEW).

   ### 4. Repo-Specific Lessons
   Record only **non-obvious** lessons: something the task actually got
   burned on + likely to re-bite a future similar task + not generic process
   advice. Leave empty if nothing non-obvious occurred. `start-task.sh`
   extracts this section into `knowledge/lessons.md` on next task start —
   low-signal bullets will pollute future explorer runs.

   ### 5. Harness Lessons
   Same non-obvious bar as §4, but scoped to the baton harness itself
   (skill contracts, gates, state machine, templates). Empty is acceptable.

   ### 6. Standardization Candidates
   Findings worth promoting into the protocol or profile: patterns that
   should be default going forward, validator gaps worth filling, or
   standardization candidates for adapter docs. One bullet per candidate.

3. Update `task-status.md` → state `complete`.

## Output Template

```markdown
# Retrospective: [Task ID]

## 1. Outcome

- Closed as: [completed / blocked / deferred]
- Main blocker: [if any]
- Human decision: [date — decision summary]

## 2. What Worked

- [specific gate/artifact/step that prevented a concrete problem]

## 3. What Failed

- [specific step that was bypassed, produced low quality, or caused rework]

## 4. Repo-Specific Lessons

> Record only **non-obvious** lessons: something the task actually got
> burned on + likely to re-bite a future similar task + not generic process
> advice. Leave empty if nothing non-obvious occurred. `start-task.sh`
> extracts this section into `knowledge/lessons.md` on next task start.

- [lesson]

## 5. Harness Lessons

> Same non-obvious bar as §4, but scoped to the baton harness itself.
> Empty is acceptable — don't pad.

- [lesson]

## 6. Standardization Candidates

- [candidate for protocol / profile / adapter doc]
```
