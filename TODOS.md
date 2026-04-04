# TODOS

## S4 Follow-up: Dirty-worktree evaluation edge case
**What:** Handle the case where Generator stashes uncommitted changes before recording `base_commit`. After stash, `base_commit..HEAD` won't include stashed content.
**Why:** Current S4 fix (base_commit recording) handles multi-commit scenarios but not stash scenarios. Generator L54 allows stashing before proceeding.
**Pros:** Closes the last evaluation-surface gap.
**Cons:** Low frequency edge case. Adds complexity to evaluator diff logic.
**Context:** Generator checks `git status` at L54 and may stash. If it stashes, then records base_commit, the evaluator reviews commits only, missing stashed-then-restored changes. Discovered during Codex plan review 2026-04-04.
**Depends on:** S4 base_commit fix must land first.

## S6 Alternative: Sidecar file for machine-owned state
**What:** Consider moving machine-owned control data (risk_level, codex_available, base_commit, human_ack) to `.harness/task-meta.yaml` instead of restructuring `task-status.md` State Notes.
**Why:** task-status.md is deeply coupled to hooks (pre-transition parses table columns, checks human_ack via awk, validates blocked categories via grep). Restructuring in-place risks breaking parsers. A sidecar file keeps task-status.md human-readable and gives machine data a clean YAML format.
**Pros:** Clean separation of human-readable status vs machine data. YAML parsing is reliable. No hook migration needed for task-status.md format.
**Cons:** Hooks must now read two files. One more file in .harness/. Skills must know which file has which data.
**Context:** Suggested by Codex during plan review 2026-04-04. Codex pointed out hooks parse exact table columns and State Notes via fragile awk/grep. Current coupling: pre-transition L13 (blocked_notes_regex), L15-21 (has_human_ack awk), post-artifact checks.
**Depends on:** Decision needed before S6 implementation.

## S8 Implementation: Profile-based risk behavior instead of markdown matrix
**What:** Encode risk-adaptive behavior in profile data (java-maven.yaml, python-service.yaml, etc.) and runtime checks in hooks, rather than adding another shared markdown matrix.
**Why:** A markdown table documenting expected behavior per risk level will drift just like the current per-skill Risk-Adaptive tables. Both the eng review and Codex agree that enforcement beats documentation. Aligns with product boundary decision: core stays generic, stack-specific behavior goes in profiles.
**Pros:** Enforceable at runtime. Stack-specific behavior stays in profiles. Single source of truth.
**Cons:** Requires defining a profile schema for risk behavior. Hooks need to read profile data.
**Context:** Cross-model consensus (Claude eng review + Codex plan review, 2026-04-04). Current state: 7 skills each have independent Risk-Adaptive Depth tables with different dimensions. Orchestrator has a separate Low-Risk Fast Track table. No enforcement mechanism.
**Depends on:** S5 (orchestrator slim) should land first to reduce churn.
