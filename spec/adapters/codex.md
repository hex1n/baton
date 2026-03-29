# Codex Adapter Mapping

## Intent

Map the portable harness protocol onto a Codex-style coding agent environment.

This document assumes a typical Codex environment provides:

- filesystem read/write
- terminal command execution
- optional isolated sub-agents

Root governance entrypoint for this adapter: `AGENTS.md`.
In the baton reference implementation, `AGENTS.md` is materialized from the
same shared template as `CLAUDE.md`, so Codex and Claude Code read the same
repo-level governance summary.

If sub-agents are unavailable, only repos that explicitly run in `compat` mode
may use the sequential fallback described below. `strict` mode must block.

## Recommended Operating Mode

- Main thread: orchestrator
- Isolated agents for strict mode:
  - `Verification Explorer`
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
| Independent review | Sub-agent in `strict`; explicit sequential review only in `compat` |
| Control plane | `.harness/module-status.md` |

## Role Execution

### Repo Explorer

- Run in the main thread unless the repository is large enough to benefit from an isolated reader.

### Scoped Explorer

- Main thread is acceptable by default
- Use an isolated explorer agent only when the repo is large enough that a
  cold-read materially improves exploration quality

### Specifier / Architect

- Usually safe in the main thread
- Keep outputs explicit in `.harness/`

### Verification Explorer

- Always run before generator
- Strict mode: isolated sub-agent via `spawn_agent({ fork_context: false })`
- Explicitly pass only:
  - `.harness/requirements.md`
  - `.harness/architecture.md`
  - repo profile or relevant validation config
- Do not rely on prior main-thread reasoning as the verification baseline
- Dry-run the intended build/test path
- If strict isolation is unavailable, block instead of continuing
- Compat mode may fall back to a same-thread cold-read only if
  `verification-path.md` records `Verification mode: compat`,
  `Execution context: sequential_fallback`, and a concrete fallback reason

### Generator

- Preferred workspace: dedicated worktree
- Keep `.harness/` in the primary repo and code changes in the worktree

### Reviewer

- Preferred: isolated review agent with findings-first output
- Compat fallback: explicit local review pass after implementation

### Evaluator

- Strict mode: spawn as an isolated sub-agent:
  `spawn_agent({ fork_context: false })`
- Explicitly pass only:
  - `.harness/requirements.md`
  - `.harness/architecture.md`
  - `.harness/verification-path.md`
  - implementation diff
- Do NOT use `fork_context: true` — this copies Generator's reasoning chain
  and defeats context independence
- Write `.harness/evaluation.md` with verdict and isolation provenance before
  handoff to human close
- If strict isolation is unavailable, block instead of continuing
- Compat mode may fall back to sequential execution only if `evaluation.md`
  records `Review mode: compat`, `Execution context: sequential_fallback`,
  and a concrete fallback reason

## Concrete Execution Examples

### Verifier Example

```text
verifier_id = spawn_agent({
  agent_type: "default",
  fork_context: false,
  message: "
    You are the Verification Explorer for the current harness task.
    Cold-read only:
    - .harness/requirements.md
    - .harness/architecture.md
    - repo validation config such as .harness/profile.local.yaml if present
    Do not rely on prior conversation history.
    Produce .harness/verification-path.md and report blockers explicitly.
  "
})

# Continue local work that does not depend on Gate 3.
verifier_result = wait_agent({
  ids: [verifier_id],
  timeout_ms: 600000
})
```

Observed in baton: the verifier is most valuable when it starts from artifacts
only. Do not use `fork_context: true`.

### Evaluator Example

```text
evaluator_id = spawn_agent({
  agent_type: "default",
  fork_context: false,
  message: "
    You are the Evaluator for the current harness task.
    Cold-read only:
    - .harness/requirements.md
    - .harness/architecture.md
    - .harness/verification-path.md
    - the implementation diff from git
    Do not inherit Generator reasoning or prior conversation history.
    Run verification first, then produce findings-first output and a
    PASS / PASS WITH WARNINGS / BLOCKED verdict.
  "
})

# Wait only when evaluation is the next blocking step.
evaluation = wait_agent({
  ids: [evaluator_id],
  timeout_ms: 600000
})
```

Observed in baton: isolated evaluation catches contradictions that same-thread
role-play can miss. Load only explicit artifacts; findings first, verdict second.

Do not `wait_agent` by reflex immediately after spawning if the main thread can
still do non-overlapping work.

## Compat Fallback

If the repo explicitly opts into `compat` mode and sub-agents are not available:

1. Keep the same role order
2. Treat `Verification Explorer` and `Evaluator` as hard cold-read boundaries
3. Record `Execution context: sequential_fallback` in the produced artifact
4. Record a concrete fallback reason, not "not available"
5. Do not skip `module-status.md`
6. Do not merge `verification_check` into `generating`

## Codex-Specific Advice

- Keep root governance in `AGENTS.md`, not only `CLAUDE.md`
- Do not let the main thread silently role-play all roles after harness has started.
- Use worktrees for medium-plus implementation tasks.
- Keep the control plane file-based; do not rely on chat history as the source of truth.
- Use the adapter contract in [cli-adapter-interface.md](./cli-adapter-interface.md) as the hard boundary, not the current prompt wording.
