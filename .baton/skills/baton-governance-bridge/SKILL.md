---
name: baton-governance-bridge
description: Enforces Baton's artifact invariants on any skill's output — location (baton-tasks/), annotation cycle (批注区), evidence labels, BATON:GO gate
---

# Governance Bridge

This skill ensures that ANY workflow tool's output complies with Baton's
constitution. It applies to all skills — baton, superpowers, or future systems.

## Artifact Location

All task-related documents MUST be saved to `baton-tasks/<topic>/`:

```
baton-tasks/<topic>/research.md     (or research-<topic>.md)
baton-tasks/<topic>/plan.md         (or plan-<topic>.md)
```

Simple tasks may use root-level `plan.md` / `research.md`.

When a skill defaults to a different location (e.g., `docs/specs/`,
`docs/plans/`), override and save to `baton-tasks/<topic>/` instead.
The parser, write-lock, and all governance hooks depend on this location.

## Annotation Cycle (批注区)

Every research or plan document MUST end with:

```markdown
## 批注区
```

This is non-negotiable. The annotation cycle is Baton's core mechanism:

1. Human writes feedback here (free text, or `[PAUSE]`)
2. AI infers intent, responds with file:line evidence
3. AI records exchange in `## Annotation Log`
4. Repeat until shared understanding
5. Human adds `<!-- BATON:GO -->` when satisfied

**If a skill produces a document without `## 批注区`, append it immediately.**

## BATON:GO Gate

Every plan MUST include a `<!-- BATON:GO -->` placeholder for the human:

```markdown
<!-- Add BATON:GO below when approving this plan -->
```

AI must never add `<!-- BATON:GO -->`. Only the human adds it.
Do NOT proceed with implementation until BATON:GO is present.

## Evidence Labels

Findings in any working document must use:
- `[CODE]` — repository evidence with file:line
- `[DOC]` — external documentation
- `[RUNTIME]` — observed output, logs, tests
- `[HUMAN]` — user-provided requirement

With status: `✅` confirmed, `❌` contradicted, `❓` unverified.

## Write Set

Plans SHOULD include a write-set listing:

```markdown
## Write Set
- Modify: `path/to/file.py`
- Create: `path/to/new_file.py`
- Test: `tests/test_file.py`
```

## During Execution

- Only modify files listed in the write set
- Unexpected discoveries → follow Discovery Protocol (constitution.md)
- Same approach fails twice → STOP, surface the pattern
