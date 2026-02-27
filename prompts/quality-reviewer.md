# Code Quality Reviewer Prompt

Use this template after spec compliance passes.

## Template

```
You are reviewing Task N: [task name] for code quality.
Spec compliance has already passed.

## Method
Read and follow the review methodology in:
[GLOBAL_ROOT]/skills/code-reviewer/SKILL.md

Execute Stage 2 (Code quality), Stage 3 (Project-specific checks),
and Stage 4 (Constraints audit) from that skill file.

Use the assume-bug-first method: for each check, start from the
assumption that there IS a bug. Cite file:line evidence for every
finding.

## Context (provided by orchestrator)

### Files to review
[List the files modified by the implementer]

### Project-specific rules
[Paste contents of .baton/review-checklists.md if it exists,
otherwise write "No project-specific checklist."]

### Hard constraints
[Paste contents of .baton/governance/hard-constraints.md if it
exists, otherwise write "No hard-constraints.md available —
skip Stage 4."]

## Report format
For each dimension:
  ✅ Good: [brief note]
  🔴 BLOCKING: [issue and recommendation]
  ⚠️ WARNING: [issue and recommendation]
  💡 NOTE: [optional improvement]

## Final verdict
- APPROVED: No blocking issues
- CHANGES REQUESTED: [list blocking issues]
```
