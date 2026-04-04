# Cursor Adapter Mapping

## Intent

Map the portable harness protocol onto a Cursor-based workflow.

Cursor is often editor-centric rather than CLI-centric, so the portable harness
should remain file-driven. The chat or agent layer should orchestrate, but the
source of truth must stay in `.harness/`.

Root governance entrypoint for the simple shared setup: `AGENTS.md`.
This keeps Cursor aligned with Codex while `CLAUDE.md` remains available for
Claude Code.

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
| Control plane | `.harness/task-status.md` |

## Role Execution

### Explorer

- Use editor search and terminal inspection to create `exploration.md`
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

### Evaluator

- Open a new chat or agent context before starting evaluation
- Load only: `.harness/requirements.md`, `architecture.md`,
  `verification.md`, and the diff
- Known limitation: Cursor has no programmatic spawn — isolation
  depends on user discipline. If context isolation cannot be
  guaranteed, note this in `task-status.md` and have the human
  perform a separate manual review pass before close.

## Cursor-Specific Advice

- Prefer `AGENTS.md` as the lightweight shared root rule entrypoint before
  introducing a more complex `.cursor/rules` setup
- Do not let Cursor Rules become the only protocol definition. Keep the canonical protocol in files.
- Treat the editor as an interaction layer, not the control plane.
- In repositories with fragile build graphs, verify test/build reachability before generating code.
- If multiple chats are used, synchronize through `.harness/task-status.md`, not by assuming shared memory.
