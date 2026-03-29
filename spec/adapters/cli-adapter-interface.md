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

## Workspace Execution Modes

### Mode A: Multi-Agent

- preferred when the CLI supports context-isolated sub-agents
- suitable for `Explorer`, `Reviewer`, `Evaluator`

### Mode B: Sequential

- fallback when the CLI has only one execution context
- roles still exist logically
- artifacts and state transitions must remain explicit

## Isolation Policy Modes

### `strict`

- `Verification Explorer` and `Evaluator` must run with true context isolation
- if the current host or session policy cannot provide that isolation, the task
  must transition to `blocked`
- sequential fallback is not valid in this mode

### `compat`

- sequential fallback is allowed only if the repo or task explicitly opts in
- verifier / evaluator artifacts must record:
  - isolation mode
  - actual execution context
  - explicit fallback reason when degraded
- human close must surface that independence was degraded

## Context Isolation Requirement

The following roles MUST derive judgment from artifacts only,
without inheriting prior role reasoning:

- Verification Explorer
- Evaluator

Adapters MUST document how they implement this isolation.
Acceptable mechanisms:
- New context initialized from artifacts only (preferred)
- Isolated sub-agent with explicit artifact inputs, no context fork
- Explicit session reset followed by artifact reload

Sequential execution WITHOUT isolation is not sufficient for Verification
Explorer or Evaluator in `strict` mode. Adapters may only describe sequential
fallback for repos that explicitly run in `compat` mode.

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
- the strict/compat meaning of isolation policy
