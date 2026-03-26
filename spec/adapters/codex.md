# Codex Adapter Mapping

## Intent

Map the portable harness protocol onto a Codex-style coding agent environment.

This document assumes a typical Codex environment provides:

- filesystem read/write
- terminal command execution
- optional isolated sub-agents

If sub-agents are unavailable, use the sequential fallback described below.

## Recommended Operating Mode

- Main thread: orchestrator
- Optional isolated agents:
  - `Scoped Explorer`
  - `Reviewer`
  - `Evaluator`
- Generator:
  - run in a dedicated git worktree when code changes are non-trivial

## Capability Mapping

| Harness Need | Codex Mapping |
|---|---|
| Read/write artifacts | Local file tools in the repo workspace |
| Run repo checks | Shell command execution |
| Isolated implementation workspace | `git worktree` via shell |
| Independent review | Sub-agent if available; otherwise a separate sequential review pass |
| Control plane | `.harness/module-status.md` |

## Role Execution

### Repo Explorer

- Run in the main thread unless the repository is large enough to benefit from an isolated reader.

### Scoped Explorer

- Preferred: isolated explorer agent
- Fallback: main thread, but write `scoped-map.md` before moving on

### Specifier / Architect

- Usually safe in the main thread
- Keep outputs explicit in `.harness/`

### Verification Explorer

- Always run before generator
- Dry-run the intended build/test path

### Generator

- Preferred workspace: dedicated worktree
- Keep `.harness/` in the primary repo and code changes in the worktree

### Reviewer

- Preferred: isolated review agent with findings-first output
- Fallback: explicit local review pass after implementation

## Sequential Fallback

If sub-agents are not available:

1. Keep the same role order
2. Treat each artifact boundary as a hard handoff
3. Do not skip `module-status.md`
4. Do not merge `verification_check` into `generating`

## Codex-Specific Advice

- Do not let the main thread silently role-play all roles after harness has started.
- Use worktrees for medium-plus implementation tasks.
- Keep the control plane file-based; do not rely on chat history as the source of truth.
- Use the adapter contract in [cli-adapter-interface.md](./cli-adapter-interface.md) as the hard boundary, not the current prompt wording.
