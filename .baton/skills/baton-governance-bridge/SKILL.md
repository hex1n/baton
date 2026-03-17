---
name: baton-governance-bridge
description: Ensures workflow artifacts (from any tool) comply with Baton governance gates — BATON:GO, write-set, evidence labels
---

# Governance Bridge

When creating implementation plans (via superpowers:writing-plans, manual authoring, or any other tool):

## Plan Requirements

Every implementation plan MUST include:

1. **BATON:GO placeholder** — Add this line (commented out) for the human to uncomment when approving:
   ```
   <!-- BATON:GO -->
   ```
   The human adds this marker. AI must never add it.

2. **Write-set section** — List all files the plan is authorized to modify:
   ```markdown
   ## Write Set
   - Modify: `path/to/file.py`
   - Create: `path/to/new_file.py`
   - Test: `tests/test_file.py`
   ```

3. **Evidence labels** — Key findings should use Baton's evidence model:
   - `[CODE]` — repository evidence with file:line
   - `[DOC]` — external documentation
   - `[RUNTIME]` — observed output, logs, tests
   - `[HUMAN]` — user-provided requirement

## Before Execution

Before executing any plan, verify:
1. The plan file contains `<!-- BATON:GO -->` (added by the human, not by AI)
2. If the marker is absent, ask the human to review the plan and add it
3. Do NOT proceed with implementation until BATON:GO is present

## During Execution

- Only modify files listed in the Write Set
- If you need to modify a file not in the Write Set, check the scope boundary rules in constitution.md
- Record any unexpected discoveries as impact statements per the Discovery Protocol

## Completion

Do not claim work is complete until:
1. All approved scope is finished
2. Required validation has been executed
3. No unresolved blockers remain
4. The human has confirmed completion
