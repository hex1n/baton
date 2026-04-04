# TODOS

## ~~S4 Follow-up: Dirty-worktree evaluation edge case~~ ✓ DONE
**Resolved:** Generator now records base_commit BEFORE stash operations, and sets `stash_restored: true` in State Notes if stash is popped. Evaluator checks this flag and reviews stash diff alongside committed diff.

## S6 Alternative: Sidecar file for machine-owned state (DEFERRED)
**Status:** S6 landed with structured State Notes approach (fixed `- key: value` keys in task-status.md). Sidecar file (`task-meta.yaml`) remains a future migration option if hook parsing becomes fragile.
**When to revisit:** If hooks need to parse more than ~10 State Notes keys, or if YAML parsing would simplify hook logic significantly.

## S8 Evolution: Profile-based risk behavior enforcement (DEFERRED)
**Status:** S8 landed with unified Risk-Adaptive Matrix in orchestrator + per-skill cross-references. Profile-based enforcement is the next evolution — encode risk behavior in profiles (`java-maven.yaml` etc.) and validate via hooks at runtime.
**When to revisit:** When adding a second profile (e.g., `python-service.yaml`), which forces the risk behavior to be parameterized rather than hardcoded in markdown.
