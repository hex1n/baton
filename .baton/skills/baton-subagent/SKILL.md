---
normative-status: This skill is an optional implementation extension owned by baton-implement, not a standalone top-level phase. It provides coordination protocol for parallel subagent dispatch during the IMPLEMENT phase.
name: baton-subagent
description: >
  Use when a task's Todo list contains multiple independent items (no dependencies,
  no write-write or write-read conflicts) whose parallelization benefit outweighs
  dispatch and integration overhead. Invoked from baton-implement when parallelization
  is beneficial.
user-invocable: false
---

## Iron Law

```
EACH SUBAGENT GETS ISOLATED CONTEXT
NO OVERLAPPING WRITE SETS
NO WRITE-READ CONFLICTS BETWEEN PARALLEL ITEMS
```

Subagents cannot coordinate in real-time. If two subagents touch the same file,
one will overwrite the other's work. If one subagent writes a file that another
reads, the reader works with stale content. Both forms of conflict require
sequential execution.

## When to Use

**Conditions** (all must hold):
- Multiple independent Todo items (no dependency chain, no write-write or write-read conflicts)
- Each item substantial enough to justify dispatch + review + integration overhead
- baton-implement detects parallelization opportunity

**When NOT to use**: Items have dependencies. Write sets overlap or write-read
conflicts exist. Items are trivial. Only one parallelizable item.

## Prerequisites

Inherits baton-implement execution preconditions. Each dispatched Todo item MUST have:

- `Files:` — explicit write set. Include human-edited shared surfaces (exports, registries, config). Regenerated artifacts (lockfiles, codegen) excluded — handled in Step 5.
- `Verify:` — executable verification command. Convert qualitative criteria to runnable checks before dispatch.
- `Deps:` — dependency declaration (`none` or list of prerequisite items)

If any candidate item lacks these fields, fix the Todo list before dispatch.

## The Process

### Step 1: Task Extraction

From the Todo list, identify parallelizable items:

1. **Dependency analysis** — items with `Deps: none` or whose dependencies are already complete
2. **Write set analysis** — compare `Files:` fields. Any write-write overlap = sequential.
3. **Group** — partition into parallel batches and sequential chains. Write-read conflicts checked after Step 2.

File-level conflict granularity by default. Region-level only when provably non-overlapping with no shared state.

### Step 2: Context Construction

Each subagent receives: plan summary, single Todo item, write set with file content, read set with file content, and verification method.

Read set = files subagent needs to understand but NOT modify. Trace dependencies of write set files (imports, types, interfaces, config). When modifying public APIs, include representative consumers.

Do NOT send the full plan or full Todo list.

**Write-read conflict check** — after constructing read sets, verify no item's write set overlaps another's read set. Conflicts force sequential execution (writer before reader).

### Step 3: Dispatch

Use the Agent tool with: write set boundary, verification command, and discovery handling rule ("record and return NEEDS_CONTEXT or BLOCKED; do not attempt to resolve").

Choose the lightest executor that reliably satisfies the item's difficulty; when in doubt, use more capable.

Required return format — include this in the subagent prompt:

```
When you are finished, end your response with a structured report containing
these fields in this order:

## Subagent Report
- **Status**: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
- **Files modified**: [list each file path, one per line]
- **Summary**: [1-2 sentences describing what was changed and why]
- **Verification**: [command run] → [PASS | FAIL + reason]
- **Discoveries**: [any unexpected findings, or "none"]
- **Unresolved concerns**: [list each concern with a tag]
  - CORRECTNESS: [concern affecting functional correctness, data integrity, or safety]
  - QUALITY: [concern about style, naming, minor improvement opportunity]
  - or "none"
```

If the subagent's response lacks this report after one retry, fall back to sequential execution.

### Step 4: Completion Review

Check: report completeness, spec compliance (Summary matches Todo intent), write set adherence, verification PASS, and discoveries.

Failure handling:
- **Verification re-run fails** → revert, fall back to sequential. Do not re-dispatch.
- **Write set violation** → revert unauthorized changes (or entire item if inseparable), re-verify or fall back to sequential.
- **Spec compliance failure** → evaluate actual changes. If they genuinely miss intent, revert and fall back to sequential.

Status handling:
- **DONE** — mark Todo item complete.
- **DONE_WITH_CONCERNS** — evaluate by tag:
  - **CORRECTNESS** → do NOT mark complete. Resolve with targeted fix or treat as BLOCKED.
  - **QUALITY only** → mark complete. Record for human review at closure.
  - Untagged concerns default to CORRECTNESS.
- **NEEDS_CONTEXT** — re-dispatch once with better context; second failure → BLOCKED.
- **BLOCKED** — escalate to human. Do not attempt to unblock via another subagent.

### Step 5: Integration

After ALL subagents in a batch complete:

- Apply results one at a time; run cheapest high-signal validation after each absorption
- Verify interface consistency across subagents sharing imports, types, or API boundaries
- Regenerate lockfiles, codegen, and schema snapshots once after all changes absorbed
- Run integration tests covering cross-item boundaries after full batch absorption
- Record new issues as findings; evaluate via Discovery Protocol before next batch

## Red Flags

| Thought | Reality |
|---------|---------|
| "These items mostly don't overlap" | Mostly ≠ never. Any overlap = sequential unless provably safe. |
| "The subagent can figure out the context" | Subagents have no memory. Provide everything they need. |
| "Let me dispatch all items at once" | Batch by dependency level. Earlier batches must complete first. |
| "Two subagents can coordinate on this file" | Treat as sequential unless provably non-overlapping with no shared mutable state. |
| "I can skip the completion review" | Every subagent result needs spec compliance + write set adherence check. |
| "This task is small enough to not need isolation" | Size doesn't determine isolation need. Evaluate conflicts and overhead. |

## Gotchas

> Operational failure patterns. Add entries when observed in real usage.
> Empty until then — do not pre-fill with theory.
