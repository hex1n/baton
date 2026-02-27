# Baton Workflow Protocol v2.1

> **Single source of truth** for all inter-skill relationships,
> mode detection, and phase transitions. All skill files reference
> this protocol instead of defining workflow logic independently.

## Mode Detection (run before every skill execution)

1. Check if `.baton/active-task` exists and is non-empty
   - Exists → **WORKFLOW MODE** (Layer 1+), follow phase constraints
   - Does not exist → continue to step 2
2. Check if `.baton/` directory exists
   - Exists → **PROJECT STANDALONE** (Layer 0 + project context)
   - Does not exist → **PURE STANDALONE** (Layer 0, zero dependencies)

## Mode Behavior Matrix

| Behavior               | PURE STANDALONE | PROJECT STANDALONE | WORKFLOW MODE    |
|------------------------|-----------------|---------------------|------------------|
| Cross-skill dependency | Skip            | Skip                | Enforce          |
| Phase-lock             | Not active      | Not active          | Enforce          |
| Gate checks            | Not active      | Not active          | Enforce          |
| Output path            | Current dir     | .baton/scratch/     | .baton/tasks/    |
| hard-constraints       | Not read        | Read as advisory    | Read & enforce   |

## Phase Definitions and Transitions

| Phase      | Entry Condition                         | Exit Condition                          | Load Skill              |
|------------|-----------------------------------------|-----------------------------------------|-------------------------|
| research   | new-task created                        | RESEARCH-STATUS: CONFIRMED              | plan-first-research     |
| plan       | research CONFIRMED or quick-path        | Human annotates or STATUS: APPROVED     | plan-first-plan         |
| annotation | plan.md has unprocessed annotations     | All annotations processed               | annotation-cycle        |
| approved   | STATUS: APPROVED (transition phase)     | Todo checklist generated                | plan-first-plan (Ph. 2) |
| slice      | Todo exists, Context Slices do not      | Context Slices generated                | context-slice           |
| implement  | Todo + Slices exist (or slice skipped)  | All todo items complete                 | plan-first-implement    |
| verify     | All todo items complete                 | TASK-STATUS: DONE                       | verification-gate       |
| review     | Verification complete                   | review.md written, no BLOCKING          | code-reviewer           |
| done       | Review complete, no BLOCKING            | (terminal state)                        | (none)                  |

## Responsibility Assignment (disambiguation)

| Action                      | Sole Owner              | Other Skills' Behavior         |
|-----------------------------|-------------------------|--------------------------------|
| Generate Todo checklist     | plan-first-plan         | annotation-cycle does NOT generate Todo; notifies user to load plan-first-plan |
| Generate Context Slices     | context-slice           | implement suggests generation if slices missing; does NOT self-generate |
| Update hard-constraints     | code-reviewer           | Other skills read-only         |
| Change active-task phase    | CLI (detect_phase)      | Skills do NOT modify active-task directly |

## Skill Interface Contract

Every skill declares:
- **Input:** Required files/state
- **Output:** Produced files
- **Side effects:** Modified existing files
- **Mode behavior:** Differences across the three modes

## Quick-path Detection

Quick-path tasks skip the research gate. Detection method:

- **WORKFLOW MODE:** Check for `.baton/tasks/<task-id>/.quick-path` file
  - Exists → quick-path mode, skip research check
  - Does not exist → normal mode, enforce research check
- **STANDALONE MODE:** No quick-path concept (standalone already skips all gates)
