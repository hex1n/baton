---
name: baton-explorer
context: fork
description: >
  Explore and map a codebase for a task. Trigger when the user asks to
  "explore", "map the code", "understand the codebase", "trace the call chain",
  "what does this touch", or "scope this task". Two modes: repo-wide overview
  (first adoption) and task-scoped exploration (every task). Produces a
  exploration.md artifact, not implementations or designs.
user-invocable: true
---

# Explorer

> Derived from spec/protocol/role-contracts.md — Repo Explorer + Scoped Explorer

## Claude Code Execution Note

In Claude Code, for **Repo-wide mode**, dispatch this role as an isolated
subagent via the `Agent` tool. Do NOT invoke inline via the `Skill` tool —
that executes within the current conversation and does not provide context
isolation.

Preferred (if `.claude/agents/baton-explorer` is registered):
```
Agent(subagent_type: "baton-explorer",
      prompt: "Perform a repo-wide exploration for task [task-id].")
```

Fallback (always works):
```
Agent(subagent_type: "general-purpose",
      prompt: "You are the Repo Explorer. Cold-read only the repo root
               and repo profile (if present).
               Follow baton-explorer skill instructions, Repo-wide mode.")
```

See `spec/adapters/claude-code.md` § Context Isolation for the full pattern.

## Codex Execution Note

In Codex, for Repo-wide exploration, launch this role as
`spawn_agent({ fork_context: false })` and instruct the sub-agent to
cold-read only the repo root and repo profile. See `spec/adapters/codex.md`
for the concrete spawn/wait example.

## Role Contract

### Mode 1: Repo-wide (first adoption)

- **Inputs**: repo root, repo profile
- **Outputs**: repo map, high-risk directories, default verification entry points
- **Artifact**: optional `repo-map.md`, conditionally required `codebase-map.md`

When running in repo-wide mode on an existing codebase, produce
`codebase-map.md` with structured sections (project structure, module
dependencies, data model, code style, high-risk areas). If a free-form
`repo-map.md` also exists, `codebase-map.md` is the validated artifact;
`repo-map.md` may coexist as supplementary but is not validated.

### Mode 2: Task-scoped (every task)

- **Inputs**: user request, repo map or local repo context,
  `clarification-brief.md` (if exists),
  `lesson-index.md` (if exists; subsidiary context, not constraints)
- **Outputs**: task-local call chain, data flow, direct change surfaces,
  test landing points, risk notes
- **Artifact**: required `exploration.md`

### Overlay Recommendation

When task-scoped exploration reveals higher complexity, add a
`## Overlay Recommendation` section to `exploration.md`.

Trigger signals include:

- Schema or migration directories
- Multiple module write surfaces
- Interface definition files (API specs, protobuf, GraphQL, etc.)
- Cross-module dependencies

Use one of these advisory values:

- `overlay: core`
- `overlay: strict`

**If none of the trigger signals are present, omit the Overlay
Recommendation section entirely.** Do not add the section with an
empty or "none" value — the validation hook requires a concrete
overlay value when the section exists.

Keep the recommendation brief and factual. It is advisory input for later
planning, not a forced runtime switch.

## Artifact Language Policy

Write all human-facing artifacts in the language of the user's request.
Do not localize `task-status.md`.

## Gate: Scoped Exploration Complete

All criteria must pass before handing off to Specifier:

- [ ] Primary entry points identified
- [ ] Likely write surface identified
- [ ] Test landing points identified
- [ ] High-risk directories called out

## Required Artifact: `exploration.md`

Use the template at `spec/templates/exploration.template.md` as the
starting point. Sections:

1. **Scope** — boundaries of exploration (in/out of scope, write boundary)
2. **Entry Points** — files/functions where execution enters
3. **Call Chain** — how control flows from entry to effect
4. **Data Flow** — how data propagates through the affected area
   (source → transform → sink); include data format changes and
   state mutations at each boundary.
   *Low risk: may abbreviate or merge into Call Chain.*
5. **Existing Behavior** — what the code does today in the affected area
6. **Existing Tests** — tests that cover the affected area, with paths
7. **Change History** — recent changes in the affected area from git log;
   highlight high-churn files and active contributors.
   *Low risk: may omit.*
8. **Dependency / Risk Scan** — areas of fragility, coupling, missing
   coverage, and cross-domain dependencies
9. **Change Shape** — estimated file count, change type, implementation depth
10. **Recommendation** — proceed? suggested next step for the Specifier
11. **Historical Lessons** — relevant prior lessons from `lesson-index.md`
    (subsidiary context only; omit if no lesson-index exists)

## Execution Guide

### Mode Selection

- If no `repo-map.md` or `task-status.md` exists and the user asks for a
  general overview → **Repo mode**.
- If there is a concrete task or feature request → **Scoped mode**.
- When in doubt, ask the user.
- **Repo-wide mode**: a fresh context (`context: fork`) is strongly recommended
  — the large ambient context from prior conversation can bias exploration.
- **Scoped mode**: same-session execution is acceptable for small tasks where
  the added isolation cost outweighs the benefit. Use an isolated context when
  repo scale or prior session noise would materially affect exploration quality.

### Repo Mode Steps

1. Scan top-level structure: directories, build files, config files.
2. Identify language/framework stack and build system.
3. Analyze dependency structure (imports, module boundaries).
4. Identify default entry points (main, CLI, request handlers).
5. Locate test directories and test runner configuration.
6. Flag high-risk directories (heavy coupling, no tests, generated code).
7. Write `repo-map.md` with findings.

### Scoped Mode Steps

1. Read the user request — extract the intent and any named files/features.
   If `clarification-brief.md` exists, read it to understand confirmed
   boundaries, non-goals, and success criteria. Use these to constrain
   exploration scope — do not explore areas marked as non-goals.
1b. If `.harness/lesson-index.md` exists, scan it for entries related to
   the current task's write surface. Treat as background awareness — do
   not quote lessons as requirements. Note relevant lessons in §12 of
   `exploration.md`.
2. Find entry points: search for the feature name, handler, command, or
   interface that the request targets.
3. Trace the call chain: follow from entry point through the layers of
   invocation to where state changes or output is produced.
4. Trace data flow: follow how data propagates through the affected area —
   from source through transformations to sink. Note state mutations and
   data format changes at each boundary.
5. Identify the write surface: files that must change to fulfill the request.
6. Find test landing points: existing tests for the affected code, plus where
   new tests would logically go.
7. Check change history: review recent git history on affected files to
   identify churn rate, recent changes, and active contributors.
8. Assess risks: look for tight coupling, shared state, missing error handling,
   or areas with no test coverage.
9. Write `exploration.md` with all required sections.

### Risk-Adaptive Depth

> Canonical source: orchestrator's Risk-Adaptive Matrix, row "2 Explore".

Read the risk level from `task-status.md` § State Notes and adapt exploration depth:

| Risk Level | Depth Adjustments |
|------------|-------------------|
| **Low** | Skip data flow tracing and change history; focus on entry points and write surface |
| **Medium** | Standard exploration — all steps above |
| **High** | Deep exploration: trace data flow across module boundaries, analyze git blame for ownership, check for undocumented side effects, scan for security-sensitive patterns |

### Quality Check

- Every entry point has a file path and line reference.
- Call chain is traceable (not hand-wavy "it calls something").
- Risks are concrete ("module X has no tests" not "could be risky").

## State Transition

On completion: update `task-status.md` → state `specifying`, owner `specifier`.
