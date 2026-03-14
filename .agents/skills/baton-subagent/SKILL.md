---
normative-status: This skill is an optional implementation extension owned by baton-implement, not a standalone top-level phase. It provides coordination protocol for parallel subagent dispatch during the IMPLEMENT phase.
name: baton-subagent
description: >
  Use when a Large task's todolist contains 3+ independent items (no dependencies,
  non-overlapping write sets) that can be parallelized via subagents. Provides
  task extraction, context construction, dispatch, and integration review.
  Not triggered via phase-guide — invoked from baton-implement when parallelization
  is beneficial.
user-invocable: true
---

## Iron Law

```
EACH SUBAGENT GETS ISOLATED CONTEXT
NO OVERLAPPING WRITE SETS
```

Subagents cannot coordinate in real-time. If two subagents touch the same file,
one will overwrite the other's work. Write set isolation is the only safe model.

## When to Use

- Todolist has 3+ independent items (no dependency chain, non-overlapping write sets)
- Task is Large complexity with clear file ownership boundaries
- baton-implement detects parallelization opportunity and suggests invocation

**When NOT to use**: Items have dependencies. Write sets overlap. Fewer than 3
independent items (overhead exceeds benefit). Small/Medium tasks.

## The Process

### Step 1: Task Extraction

From the todolist, identify parallelizable items:

1. **Dependency analysis** — items with `Deps: none` or whose dependencies are
   already complete
2. **Write set analysis** — compare `Files:` fields. Any overlap = sequential
3. **Group** — partition into parallel batches and sequential chains

Items with overlapping write sets MUST run sequentially, even if logically independent.

### Step 2: Context Construction

Each subagent receives a focused context package:

- **Plan summary** — the recommended approach (not the full plan)
- **Single todo item** — exactly one item per subagent
- **Write set** — explicit list of files this subagent may modify
- **Relevant code** — current content of files in the write set
- **Verification method** — from the todo item's Verify field

Do NOT send the full plan or full todolist. Subagents work best with minimal,
focused context.

### Step 3: Dispatch

Use the Agent tool with clear instructions:

- Specify `subagent_type` appropriate to the task
- Include the write set boundary: "Only modify these files: ..."
- Include the verification command
- For mechanical tasks (renames, assertion updates): use a fast/lightweight model
- For architectural tasks (new modules, design decisions): use the most capable available model

### Step 4: Completion Review

When each subagent returns:

1. **Spec compliance** — does the result match the todo item's intent?
2. **Write set adherence** — did it only modify approved files?
3. **Verification** — run the verification command specified in the todo

Status categories:
- **DONE** — passes all checks, mark todo complete
- **DONE_WITH_CONCERNS** — works but has issues worth noting
- **NEEDS_CONTEXT** — subagent couldn't complete without more information
- **BLOCKED** — subagent hit an obstacle requiring human input

### Step 5: Integration

After ALL subagents complete:

1. Run integration tests covering the combined changes
2. Check for conflicts between independently-made changes
3. If conflicts found, resolve sequentially (not via more subagents)

## Red Flags — STOP

| Thought | Reality |
|---------|---------|
| "These items mostly don't overlap" | Mostly ≠ never. Any overlap = sequential. |
| "The subagent can figure out the context" | Subagents have no memory. Provide everything they need. |
| "Let me dispatch all items at once" | Batch by dependency level. Earlier batches must complete first. |
| "Two subagents can coordinate on this file" | They cannot. No overlapping write sets. Ever. |

## 批注区

<!-- 写下你的反馈，AI 会判断如何处理。 -->
<!-- 如果需要暂停当前工作去做其他调查，写 [PAUSE]。 -->