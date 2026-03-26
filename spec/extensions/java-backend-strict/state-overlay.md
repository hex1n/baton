# State And Loop Overlay

## Goal

Add the stricter module-oriented loop used by Java backend strict mode.

Portable core is task-oriented. This extension introduces module-oriented
execution inside a task.

## Module Loop

Recommended loop:

```text
repo-explorer
  -> specifier
  -> architect
  -> human architecture approval
  -> verification_check
  -> generator(module-1)
  -> evaluator(module-1)
  -> generator(module-1 repair)
  -> evaluator(module-1 rerun)
  -> next module
  -> cross-cutter
  -> human close
```

## Generator Policy

For Java backend work, generator should usually operate:

- by module or bounded context
- in small related batches
- with compile or test checkpoints between batches

This is stricter than the core v1 task-level default.

## Recommended `module-status.md` Convention

Keep the same file, but encode richer scope information in the `Scope` column:

- `task-id/module-1`
- `task-id/module-1#eval-1`
- `task-id/module-1#eval-2`
- `task-id/cross-cutter`

This avoids changing the core file shape while still exposing module and round
information.

## Additional Human Gates

In strict mode, add these practical checkpoints:

1. requirements confirmation
2. architecture confirmation
3. migration approval when DDL is introduced
4. escalation after three failed evaluator rounds
5. final close after cross-cutter

## Error Recovery Guidance

Strict mode allows stronger recovery patterns, but keep them conservative:

- prefer worktree isolation over in-place rollback
- prefer explicit checkpoint commits over destructive reset
- only use destructive recovery when the human explicitly approves it

Portable core should stay conservative here.

## What This Extension Does Not Require

- a central scheduler implementation
- mandatory parallel sub-agents
- automatic git rollback in the protocol core

Those may exist in a local runtime, but they are not required for the extension
document itself.
