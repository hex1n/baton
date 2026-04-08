---
name: using-baton
description: >
  Thin bootstrap for Baton-enabled repos. Use when starting work in a repository
  that uses Baton, when task state is unclear, or when you need to re-enter the
  Baton loop without bypassing its control plane. Routes through /dispatch,
  reads canonical artifacts first, treats .context/baton as scratch only, and
  runs Baton validators before declaring core changes done.
user-invocable: true
allowed-tools: Read Grep Glob Bash Write
---

# Using Baton

This is a thin bootstrap skill. It does not add a new workflow. It keeps Baton's
existing workflow from being bypassed or diluted.

## When to Use

- Starting work in a repo that already uses Baton
- Returning to a task and the current state is unclear
- Changing Baton core files and wanting to preserve the artifact-first control plane

If the user explicitly asks for `/planner`, `/builder`, or `/verifier`, follow that.
Otherwise, prefer entering through `/dispatch`.

## The Four Rules

1. **Enter through `/dispatch` unless state is already explicit.**
   - New task → `/dispatch <task>`
   - Existing task but unclear state → `/dispatch`
   - Only bypass Dispatcher when the user explicitly requests a direct role

2. **Read canonical artifacts before inferring state.**
   Read in this order:
   - `project-profile.md`
   - `.harness/plan.md`
   - `.harness/review.md`

3. **Treat `.context/baton/active/` as scratch only.**
   - Scratch files may help investigation
   - Scratch files never decide routing, approval, or recovery
   - If something matters for human judgment or routing, it must also appear in `.harness/plan.md` or `.harness/review.md`

4. **Before declaring Baton core changes done, run the validators.**
   Always run:
   - `bash v2/tools/check-consistency.sh`

   If live artifacts changed or you touched `.harness/`:
   - `bash v2/tools/validate-live-state.sh`
   - `bash v2/tools/validate-round-sync.sh`

## Guardrails

- Do not turn companion skills into mandatory workflow steps
- Do not invent a thicker workflow than Baton already defines
- Do not route from conversation history when canonical artifacts already answer the question
- Do not leave routing-relevant findings only in scratch state

## Success Condition

The task still flows through Baton's existing control plane:

- `/dispatch` remains the stable public entry
- `project-profile.md`, `.harness/plan.md`, and `.harness/review.md` remain canonical
- `.context/baton/active/` remains scratch only
