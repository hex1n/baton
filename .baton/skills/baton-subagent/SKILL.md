---
normative-status: This skill is an optional implementation extension owned by baton-implement, not a standalone top-level phase. It provides coordination protocol for parallel subagent dispatch during the IMPLEMENT phase.
name: baton-subagent
description: >
  Use when a task's Todo list contains multiple independent items (no dependencies,
  no write-write or write-read conflicts) whose parallelization benefit outweighs
  dispatch and integration overhead. Provides task extraction, context construction,
  dispatch, and integration review. Not triggered via phase-guide — invoked from
  baton-implement when parallelization is beneficial.
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

The decision to parallelize is a cost-benefit judgment, not a fixed threshold.

**Conditions** (all must hold):
- Todo list has multiple independent items (no dependency chain, no write-write
  or write-read conflicts between parallel candidates)
- Each candidate item is substantial enough that dispatch + review + integration
  overhead is justified. Trivial items (one-line changes, simple renames) are
  cheaper to execute sequentially.
- baton-implement detects parallelization opportunity and suggests invocation

**When NOT to use**: Items have dependencies. Write sets overlap or write-read
conflicts exist. Items are trivial (overhead exceeds benefit). Only one
parallelizable item exists (nothing to parallelize).

## Prerequisites

This skill inherits baton-implement execution preconditions; it does not weaken
or replace them.

It assumes it is invoked from baton-implement with a Todo list already in place.
Each Todo item dispatched to a subagent MUST have:

- `Files:` — explicit write set (list of files this item modifies). Must include
  any human-edited shared surface the item is expected to touch (exports, index
  files, registries, config). Centrally regenerated artifacts (lockfiles, codegen
  output) are excluded — those are handled in Step 5.
- `Verify:` — executable verification command that the subagent runs and the
  orchestrator can independently re-run. If only qualitative criteria exist
  (e.g., "matches the design"), convert them to a runnable check before dispatch.
- `Deps:` — dependency declaration (`none` or list of prerequisite items)

If any candidate item lacks these fields, do not dispatch it as a subagent task.
Fix the Todo list first.

## The Process

### Step 1: Task Extraction

From the Todo list, identify parallelizable items:

1. **Dependency analysis** — items with `Deps: none` or whose dependencies are
   already complete
2. **Write set analysis** — compare `Files:` fields. Any write-write overlap
   = sequential.
3. **Group** — partition into preliminary parallel batches and sequential chains.
   This grouping is based on write-write conflicts only. Write-read conflicts
   cannot be detected yet (read sets are determined in Step 2) and are checked
   after context construction.

Any write-write overlap = sequential, even if items are logically independent.
Any write-read conflict discovered after Step 2 also forces sequential execution.

Conflict granularity is file-level by default. Region-level exception MAY apply
only when ALL of the following hold:
- The regions are provably non-overlapping (different functions, different sections)
- No shared mutable state within the file (no module-level variables, shared
  caches, or state both regions read/write)
- Interface semantics are independent (one region's changes cannot alter the
  behavioral contract the other region depends on)

When in doubt, file-level is correct. The region-level exception is narrow by
design — it exists for cases like two items each adding a new independent
function to the same utility file, not for loosening the default.

### Step 2: Context Construction

Each subagent receives a focused context package:

- **Plan summary** — the recommended approach (not the full plan)
- **Single Todo item** — exactly one item per subagent
- **Write set** — explicit list of files this subagent may modify
- **Write set content** — default: full current content of each file in the
  write set. For files too large for the context window: the minimal fragment
  relevant to the Todo item (the function or class being modified, plus
  immediate surroundings).
- **Read set** — files the subagent needs to understand but must NOT modify.
  Determine this by tracing what the write set files depend on: modules they
  import, type definitions they reference, interfaces they implement,
  configuration they read. When the item modifies a public API, shared
  contract, cross-module behavioral semantic, or global invariant, also
  include representative consumers, contract tests, or key call sites —
  the subagent needs to see who depends on what it is changing, not only
  what it depends on. Default: full current content. For large files:
  minimal relevant fragments.
- **Verification method** — from the Todo item's Verify field

The read set is what prevents a subagent from working with incomplete
understanding. A subagent that can modify `handler.ts` but cannot see
the interface it implements will either guess wrong or return NEEDS_CONTEXT.

Do NOT send the full plan or full Todo list. Subagents work best with minimal,
focused context — but "minimal" means sufficient, not smallest possible.

**Write-read conflict check** — after constructing read sets for all items in
a proposed parallel batch, verify: no item's write set overlaps with another
item's read set at the relevant granularity (see Step 1 conflict granularity
rules — the same file-level default and region-level exception apply here).
If a conflict is found, the reader would see stale content that the writer
is about to change. Move the conflicting pair to sequential execution (writer
before reader) and re-check the remaining batch. Only dispatch after all
write-read conflicts are resolved.

### Step 3: Dispatch

Use the Agent tool with clear instructions:

- Specify `subagent_type` appropriate to the task. Match the agent type to the
  Todo item's nature: `general-purpose` for implementation work, `Explore` for
  read-heavy investigation, or a domain-specific type if available. Do not
  default to `general-purpose` for every item.
- Include the write set boundary: "Only modify these files: ..."
- Include the verification command
- Include discovery handling rule: "If you encounter an unexpected discovery
  (missing dependency, broken assumption, interface mismatch), do NOT attempt
  to resolve it. Record the discovery in your output and return status
  NEEDS_CONTEXT or BLOCKED. The orchestrating agent will evaluate it via
  the Discovery Protocol."

Required return format — include this in the subagent prompt. The subagent must
produce all fields in this order; equivalent markdown structure is acceptable
if all fields are present and unambiguous:

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

If the subagent's response does not end with this report, re-dispatch once
with the format requirement emphasized. If the second attempt also lacks
the report, do not retry — fall back to sequential execution for that item
by the orchestrating agent directly.

Executor selection — choose the lightest executor that can reliably satisfy the
item's difficulty. The host environment determines what executors are available;
the principle is constant:

- **Lightweight executor** when the task has no design decisions: renaming,
  moving code, updating imports, adding assertions to existing test patterns,
  formatting changes.
- **Most capable executor** when the task involves creating new abstractions,
  choosing between design alternatives, writing logic with non-obvious edge
  cases, or modifying public API surface.
- **When in doubt**, use the more capable executor. The cost of a wrong
  lightweight dispatch (bad output requiring redo) exceeds the cost of a
  slower capable dispatch.

<!-- Host-specific mapping (Claude Code):
     lightweight = fast/haiku model; most capable = opus/sonnet model.
     Other hosts should map to their equivalent capability tiers. -->

### Step 4: Completion Review

When each subagent returns, parse the Subagent Report (see Step 3) and check:

1. **Report present and complete** — guaranteed by Step 3 retry handling.
   If the item reached Step 4, a report with all required fields exists.
   (If both dispatch attempts lacked a complete report, Step 3 already
   fell back to sequential execution — the item never enters Step 4.)
2. **Spec compliance** — does the Summary match the Todo item's intent?
3. **Write set adherence** — compare Files modified against the approved write set.
   Any file not in the approved set is a violation.
4. **Verification** — confirm the Verification field shows PASS. If it shows FAIL,
   or if the subagent ran a different command than specified, re-run the original
   verification command independently.
5. **Discoveries** — if non-empty, evaluate each via Discovery Protocol before
   marking the item complete.

Orchestrator-side failure handling — when the orchestrating agent's own checks
find problems beyond what the subagent reported:

- **Verification re-run fails** → revert the subagent's changes for this item
  and fall back to sequential execution by the orchestrating agent directly.
  Do not re-dispatch to another subagent — the task is doable but the subagent
  produced broken code, and a second subagent dispatch with the same context
  is unlikely to succeed.
- **Write set violation** (subagent modified files outside approved set) →
  if the unauthorized changes cannot be cleanly separated from the authorized
  patch (e.g., authorized code references something introduced in an
  unauthorized file), revert the entire item and fall back to sequential
  execution. If they can be cleanly separated: revert the unauthorized file
  changes, re-run verification on the remaining authorized changes, and
  evaluate whether they alone satisfy the Todo item's intent. If yes,
  proceed as DONE or DONE_WITH_CONCERNS. If no, fall back to sequential
  execution.
- **Spec compliance failure** (Summary does not match Todo item's intent) →
  evaluate the actual changes, not just the Summary. If the changes do satisfy
  the intent despite a misleading Summary, proceed with verification. If the
  changes genuinely miss the intent, revert and fall back to sequential
  execution.

Status categories:
- **DONE** — passes all checks, mark Todo item complete
- **DONE_WITH_CONCERNS** — subagent reports completion with concerns; orchestrator
  must classify before completion is decided (see handling below)
- **NEEDS_CONTEXT** — subagent couldn't complete without more information
- **BLOCKED** — subagent hit an obstacle requiring human input

Handling by status:

- **DONE** — mark Todo item complete. No further action.
- **DONE_WITH_CONCERNS** — evaluate each concern by its tag:
  - **CORRECTNESS concerns** → do NOT mark complete. The orchestrating agent
    must evaluate the concern independently. If it can be resolved with a
    targeted fix within the approved write set, apply the fix and re-verify.
    If not, treat as BLOCKED.
  - **QUALITY concerns only** → mark Todo item complete. Record concerns in the
    plan as findings for the human to review at closure.
  - If the subagent did not tag its concerns, the orchestrating agent must
    classify them before proceeding. Default to CORRECTNESS when ambiguous.
- **NEEDS_CONTEXT** — do NOT re-dispatch immediately. Evaluate what
  context was missing. If the missing context is available, construct
  a new context package and re-dispatch (max one re-dispatch per item;
  second failure → BLOCKED). If not, treat as BLOCKED.
- **BLOCKED** — escalate to the human. Record the blocking reason in
  the plan. Do not attempt to unblock via another subagent.

### Step 5: Integration

After ALL subagents in a batch complete:

1. **Sequential absorption** — apply subagent results one at a time, not all at once.

2. **Per-absorption check** (cheapest, highest signal) — after absorbing each
   subagent's result, run the cheapest high-signal validation appropriate to
   the repo (for example: build, typecheck, lint, or targeted tests for the
   modified files). This catches type errors, import breaks, and regressions
   immediately, before the next result is layered on top.

3. **Interface consistency** — if multiple subagents touched files that share
   imports, types, or API boundaries, verify that:
   - Shared type definitions are used consistently
   - No subagent introduced an abstraction that another subagent's code ignores
   - Import paths resolve correctly after all changes are applied

4. **Generated artifact consistency** — if the project uses lockfiles, codegen,
   or schema snapshots, regenerate them once after all subagent changes are absorbed.
   Do not trust individually-generated artifacts from parallel runs.

5. **Per-batch verification** — after the batch is fully absorbed, run
   integration-level tests covering the cross-item boundaries. This confirms
   the independently-built pieces compose correctly. This does NOT need to be
   the full suite — target tests that exercise the interaction between items
   in this batch.

6. **Full suite** — run the complete verification suite at least once: either
   after the final batch, or before closure. Intermediate batches may skip the
   full suite if per-batch verification passes and no discoveries surfaced.

7. **Discovery feedback** — if any verification tier reveals issues not caught
   by individual subagents, record them in the plan/Todo list as new findings.
   Evaluate via Discovery Protocol before proceeding to the next batch.

## Red Flags

These thoughts mean STOP — you're rationalizing:

| Thought | Reality |
|---------|---------|
| "These items mostly don't overlap" | Mostly ≠ never. Treat any write-write overlap or write-read conflict as sequential unless you can prove a safe region-level exception (clearly separable regions, no shared mutable state, no interface-semantic coupling). |
| "The subagent can figure out the context" | Subagents have no memory. Provide everything they need. |
| "Let me dispatch all items at once" | Batch by dependency level. Earlier batches must complete first. |
| "Two subagents can coordinate on this file" | Do not assume same-file parallelism is safe. Treat as sequential unless provably non-overlapping regions with no shared mutable state. |
| "I can skip the completion review for subagent output" | Every subagent result needs spec compliance + write set adherence check |
| "This task is small enough to not need subagent isolation" | Size doesn't determine isolation need. No write-write overlap and no write-read conflict do. Evaluate overhead vs. benefit per item. |
