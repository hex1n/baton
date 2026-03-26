# Cursor Adapter Mapping

## Intent

Map the portable harness protocol onto a Cursor-based workflow.

Cursor is often editor-centric rather than CLI-centric, so the portable harness
should remain file-driven. The chat or agent layer should orchestrate, but the
source of truth must stay in `.harness/`.

## Recommended Operating Mode

- Main chat or agent: orchestrator
- Terminal: build, test, git, and worktree control
- Optional extra chats or agent contexts:
  - `Scoped Explorer`
  - `Reviewer`

If your current Cursor setup does not support true isolated agents, use separate
chat contexts or sequential role execution.

## Capability Mapping

| Harness Need | Cursor Mapping |
|---|---|
| Artifact creation | Files under `.harness/` in the repo |
| Repo inspection | Editor search plus terminal commands |
| Worktree creation | `git worktree` in terminal |
| Independent review | Separate chat/agent context when possible; otherwise explicit second-pass review |
| Control plane | `.harness/module-status.md` |

## Role Execution

### Explorer

- Use editor search and terminal inspection to create `scoped-map.md`
- Prefer a separate chat context if available

### Specifier / Architect

- Run in the main orchestrator context
- Keep outputs file-based and reviewable

### Verification Explorer

- Must use terminal-backed dry-runs
- Do not assume the editor can substitute for executable verification

### Generator

- Preferred workspace: dedicated worktree opened in Cursor
- Keep source changes in the worktree while `.harness/` remains the control plane

### Reviewer

- Prefer a separate chat or review context
- Findings should be written against concrete files and lines

## Cursor-Specific Advice

- Do not let Cursor Rules become the only protocol definition. Keep the canonical protocol in files.
- Treat the editor as an interaction layer, not the control plane.
- In repositories with fragile build graphs, verify test/build reachability before generating code.
- If multiple chats are used, synchronize through `.harness/module-status.md`, not by assuming shared memory.
