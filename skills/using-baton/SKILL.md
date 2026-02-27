---
name: using-baton
description: >
  Meta-skill: orchestrates which skill to load based on current context.
  Load this when starting a new session, resuming work, or when the
  human says "use baton" / "follow the workflow". This skill reads the
  workflow protocol and delegates to the correct phase-specific skill.
---
# Using Baton

This is the orchestration entry point. It does not do work itself —
it determines *what work to do* and loads the right skill.

## Quick Reference

| Attribute        | Value                                                              |
|------------------|----------------------------------------------------------------------|
| Trigger          | Session start, "use baton", or when unsure which skill to load       |
| Input            | `.baton/active-task` (if exists) + workflow-protocol.md               |
| Output           | Delegates to the correct skill — no direct output                    |
| Side effects     | None                                                                 |
| Sole responsibility | Determining the correct skill to load based on current state       |
| Exit condition   | Correct skill has been loaded and is executing                       |

## Mode Behavior

| Mode              | Cross-skill deps | Output path             | Gate checks |
|-------------------|-------------------|-------------------------|-------------|
| PURE STANDALONE   | Skip              | N/A (delegates)          | Skip        |
| PROJECT STANDALONE| Skip              | N/A (delegates)          | Skip        |
| WORKFLOW MODE     | Enforce           | N/A (delegates)          | Enforce     |

See `workflow-protocol.md` for full mode detection logic.

---

## Process

### Step 1: Read workflow-protocol.md

Load `~/.baton/workflow-protocol.md` (or `<GLOBAL_ROOT>/workflow-protocol.md`).
This is the single source of truth for all inter-skill relationships.

⚠️ Checkpoint: Are you about to skip reading the protocol because you
"already know" how Baton works? → The protocol may have been updated.
Read it every time.

### Step 2: Detect current mode

Follow the Mode Detection algorithm from workflow-protocol.md:

1. Check if `.baton/active-task` exists and is non-empty
   - Exists → **WORKFLOW MODE** (Layer 1+)
   - Does not exist → continue
2. Check if `.baton/` directory exists
   - Exists → **PROJECT STANDALONE** (Layer 0 + project context)
   - Does not exist → **PURE STANDALONE** (Layer 0, zero dependencies)

### Step 3: Determine current phase (WORKFLOW MODE only)

If in WORKFLOW MODE:
1. Read `.baton/active-task` → get `<task-id> <phase>`
2. Map phase to skill using the Phase Definitions table:

| Phase      | Skill to load         |
|------------|-----------------------|
| research   | plan-first-research   |
| plan       | plan-first-plan       |
| annotation | annotation-cycle      |
| approved   | plan-first-plan (Phase 2: Todo generation) |
| slice      | context-slice         |
| implement  | plan-first-implement  |
| verify     | verification-gate     |
| review     | code-reviewer         |
| done       | (no skill — task is complete) |

3. Load the FULL skill file: `cat ~/.baton/skills/<skill-name>/SKILL.md`

⚠️ Checkpoint: Are you about to start working without loading the full
skill file? → The session-start summary is NOT enough. You must read
the complete SKILL.md before taking any action.

### Step 4: Determine intent (STANDALONE MODE)

If in STANDALONE mode, ask the human what they want to do, or infer
from context:

| Human says / Context          | Load skill            |
|-------------------------------|-----------------------|
| "research", "understand", "read code" | plan-first-research |
| "plan", "design", "how to change"     | plan-first-plan     |
| "annotate", "process annotations"     | annotation-cycle    |
| "slice", "context slices"             | context-slice       |
| "implement", "build", "code"          | plan-first-implement|
| "verify", "test", "check"             | verification-gate   |
| "review", "code review"               | code-reviewer       |

### Step 5: Load and execute the skill

1. Read the full SKILL.md for the determined skill
2. Follow its Process section exactly
3. Respect mode behavior (standalone skills skip gates and cross-skill deps)

## What this skill does NOT do

- It does NOT execute any phase's work directly
- It does NOT modify any files
- It does NOT skip reading the full skill file
- It does NOT guess the phase — it reads `.baton/active-task`

## Rationalizations to watch for

| You think | Why it's wrong | Do this instead |
|-----------|---------------|-----------------|
| "I know which skill to load, I don't need the protocol" | The protocol defines relationships you might miss | Read it |
| "I'll just start implementing, the plan is obvious" | That skips research AND plan phases | Follow the workflow |
| "The session-start output told me what to do" | Session-start is a summary; SKILL.md is the full instruction | Load the full skill file |
| "I'll combine multiple phases to save time" | Each phase has gates for a reason | One phase at a time |
| "The human didn't explicitly say 'use baton'" | If .baton/ exists, the workflow applies | Check for .baton/ and follow it |
