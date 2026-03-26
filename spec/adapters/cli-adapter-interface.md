# CLI Adapter Interface

## Goal

This interface defines the minimum capabilities an agent CLI should expose in
order to run the portable harness protocol.

The protocol does not depend on a specific implementation language.

## Required Capabilities

### Filesystem

- `read_file(path) -> text`
- `write_file(path, text)`
- `list_files(path) -> entries`
- `search(query, scope) -> matches`

### Commands

- `run_command(command, cwd) -> result`
- `run_command` must return:
  - exit code
  - stdout
  - stderr

### Workspace Control

- `get_repo_root() -> path`
- `get_current_branch() -> name`
- `create_worktree(path, branch)` or equivalent isolated workspace primitive

### Status Publishing

- `update_artifact(path, content)`
- `update_status(task, owner, state, notes)`

## Optional Capabilities

### Parallel Role Execution

- `spawn_agent(role, context) -> agent_id`
- `wait_agent(agent_id) -> result`
- `send_input(agent_id, message)`

If unavailable, the adapter must fall back to sequential role execution.

### Review Isolation

- `spawn_review_agent(context) -> agent_id`

If unavailable, the adapter must still support a documented local review step.

## Execution Modes

### Mode A: Multi-Agent

- preferred when the CLI supports context-isolated sub-agents
- suitable for `Explorer`, `Reviewer`, `Evaluator`

### Mode B: Sequential

- fallback when the CLI has only one execution context
- roles still exist logically
- artifacts and state transitions must remain explicit

## Adapter Responsibilities

The adapter may decide:

- how to phrase prompts for the local CLI
- how to map roles to agent invocations
- how to store transient execution logs

The adapter may not change:

- canonical states
- required gates
- required artifacts
- the need for explicit blockers
