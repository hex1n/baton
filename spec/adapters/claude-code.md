# Claude Code Adapter Mapping

## Intent

Map the portable harness protocol onto a Claude Code style environment.

This document is intentionally capability-based. If your current Claude Code setup
supports extra features such as parallel task agents, use them. If not, fall back
to sequential execution without changing the protocol.

## Recommended Operating Mode

- Main session: orchestrator
- Separate task contexts when available:
  - `Scoped Explorer`
  - `Reviewer`
  - `Evaluator`
- Code generation:
  - preferred in a dedicated worktree

## Capability Mapping

| Harness Need | Claude Code Mapping |
|---|---|
| Artifact creation | Markdown and YAML files under `.harness/` |
| Repo inspection | Terminal plus file reads |
| Worktree creation | `git worktree` from terminal |
| Independent review | Separate task context or explicit second-pass review |
| State control | `.harness/module-status.md` |

## Role Execution

### Explorer Roles

- Prefer separate task contexts for `Repo Explorer` and `Scoped Explorer`
- If separate contexts are unavailable, keep their outputs explicit and do not skip local artifacts

### Specifier / Architect

- Usually run in the main orchestrator context
- Human approval should occur after `architecture.md`

### Verification Explorer

- Must run before implementation
- Confirm the intended validation path is executable in the current repo

### Generator

- Use a worktree for isolated code changes
- Keep artifacts and source changes logically separated

### Reviewer / Evaluator

- Prefer an isolated review context
- Review output should focus on bugs, regressions, missing tests, and residual risk

## Context Isolation

The following roles MUST run in an isolated context — they must not inherit
the orchestrator's conversation history or Generator's reasoning chain:

- `Scoped Explorer` (repo-wide mode)
- `Verification Explorer`
- `Evaluator`

In Claude Code, use the `Agent` tool to dispatch these roles. The `Skill` tool
executes within the current conversation and does NOT provide isolation.

### Preferred dispatch (if `.claude/agents/` custom type is registered)

```
Agent(
  subagent_type: "baton-evaluator",
  prompt: "Evaluate the implementation for task [task-id]."
)
```

The agent is pre-loaded with the role's instructions from
`.claude/agents/baton-evaluator.md`. It starts with a blank context and must
cold-read `.harness/requirements.md`, `.harness/architecture.md`,
`.harness/verification-path.md`, and the implementation diff.

### Fallback dispatch (always works)

```
Agent(
  subagent_type: "general-purpose",
  prompt: "
    You are the Evaluator for the current harness task.
    Cold-read only:
    - .harness/requirements.md
    - .harness/architecture.md
    - .harness/verification-path.md
    - the implementation diff from git
    Do not inherit Generator reasoning or prior conversation history.
    Run verification first, then produce findings-first output and a
    PASS / PASS WITH WARNINGS / BLOCKED verdict.
    Follow the full baton-evaluator skill instructions in
    skills/baton-evaluator.md.
  "
)
```

Substitute `baton-verifier` or `baton-explorer` and the matching artifact list
for the Verification Explorer and Scoped Explorer roles respectively.

For Codex, see `spec/adapters/codex.md` for the equivalent `spawn_agent`
pattern. For Cursor, see `spec/adapters/cursor.md`.

## Sequential Fallback

If Claude Code is operating without separate task contexts:

1. Keep the role order unchanged
2. Persist each role output to `.harness/`
3. Record state transitions in `module-status.md`
4. Run an explicit review pass before asking for human close

## Claude Code-Specific Advice

- Do not depend on session memory as the control plane.
- File-based artifacts matter more than prompt conventions.
- Treat verification-path discovery as mandatory in older or environment-heavy repos.
- Keep repo-specific rules in the repo profile, not in the adapter.
