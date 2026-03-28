---
name: harness-explorer
description: >
  Explore and map a codebase for a task. Trigger when the user asks to
  "explore", "map the code", "understand the codebase", "trace the call chain",
  "what does this touch", or "scope this task". Two modes: repo-wide overview
  (first adoption) and task-scoped exploration (every task). Produces a
  scoped-map.md artifact, not implementations or designs.
user-invocable: true
---

# Explorer

> Derived from spec/protocol/role-contracts.md — Repo Explorer + Scoped Explorer

## Role Contract

### Mode 1: Repo-wide (first adoption)

- **Inputs**: repo root, repo profile
- **Outputs**: repo map, high-risk directories, default verification entry points
- **Artifact**: optional `repo-map.md`

### Mode 2: Task-scoped (every task)

- **Inputs**: user request, repo map or local repo context
- **Outputs**: task-local call chain, direct change surfaces, test landing points, risk notes
- **Artifact**: required `scoped-map.md`

## Artifact Language Policy

Before writing any human-facing artifact:

1. If `.harness/profile.local.yaml` sets `documentation.artifact_language` to
   `zh` or `en`, use that language.
2. If it is `auto`, follow the current user request language.
3. If the setting is missing, default to Chinese.

Do not localize `module-status.md`. Keep the control-plane file, owner tokens,
state tokens, and blocker categories in stable English.

## Gate: Scoped Exploration Complete

All criteria must pass before handing off to Specifier:

- [ ] Primary entry points identified
- [ ] Likely write surface identified
- [ ] Test landing points identified
- [ ] High-risk directories called out

## Required Artifact: `scoped-map.md`

Sections (all required):

1. **Task Statement** — what was requested, in one sentence
2. **Scope** — boundaries of exploration
3. **Entry Points** — files/functions where execution enters
4. **Call Chain** — how control flows from entry to effect
5. **Existing Behavior** — what the code does today in the affected area
6. **Existing Tests** — tests that cover the affected area, with paths
7. **Risks** — areas of fragility, coupling, or missing coverage
8. **Suggested Next Step** — what the Specifier should focus on

## Execution Guide

### Mode Selection

- If no `repo-map.md` or `module-status.md` exists and the user asks for a
  general overview → **Repo mode**.
- If there is a concrete task or feature request → **Scoped mode**.
- When in doubt, ask the user.
- Same-session execution is acceptable by default. Use an isolated context
  only when repo scale or noise would materially improve exploration quality.

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
2. Find entry points: search for the feature name, endpoint, command, or UI
   element that the request targets.
3. Trace the call chain: follow from entry point through the layers of
   invocation to where state changes or output is produced.
4. Identify the write surface: files that must change to fulfill the request.
5. Find test landing points: existing tests for the affected code, plus where
   new tests would logically go.
6. Assess risks: look for tight coupling, shared state, missing error handling,
   or areas with no test coverage.
7. Write `scoped-map.md` with all required sections.

### Quality Check

- Every entry point has a file path and line reference.
- Call chain is traceable (not hand-wavy "it calls something").
- Risks are concrete ("module X has no tests" not "could be risky").

## State Transition

On completion: update `module-status.md` → state `specifying`, owner `specifier`.
