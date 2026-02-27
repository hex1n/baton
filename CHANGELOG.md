# Changelog

## [2.1.0] — 2026-02-27

### Added — Architecture (P0)
- **workflow-protocol.md**: Single source of truth for all inter-skill
  relationships, mode detection, phase transitions, and responsibility
  assignment. Replaces scattered workflow logic across skill files.

### Changed — State Machine (P0)
- **detect_phase** expanded from 5 to 9 phases: added `approved`,
  `slice`, `review` (with blocking detection), and improved `done` logic.
- **cmd_next** updated with guidance for all 9 phases.
- **new-task --quick** flag creates `.quick-path` marker file and starts
  at plan phase instead of research.

### Fixed — Responsibility Conflicts (P0)
- **annotation-cycle**: No longer generates Todo checklist. Explicitly
  hands off to plan-first-plan when human approves the design.
- Todo generation is now the sole responsibility of plan-first-plan (Phase 2).

### Fixed — Layer 0 Independence (P0)
- **plan-first-plan**: Standalone mode skips research status check
  instead of blocking on missing CONFIRMED status.
- **plan-first-research**: Standalone mode outputs to current directory
  or `.baton/scratch/` without requiring task structure.
- **annotation-cycle**: `[RESEARCH-GAP]` in standalone mode writes
  inline supplements instead of failing on missing research.md.

### Changed — Phase-Lock (P1)
- **Slice scope check** changed from advisory (warning only) to
  **blocking by default**. Use `BATON_ALLOW_SCOPE_OVERRIDE=true` to
  override in emergencies.
- Locked phases expanded: research, plan, annotation, **slice, approved**
  (was 3, now 5 phases block source writes).

### Changed — Session Start Output (P1)
- When active task exists: outputs a **single concrete `cat` command**
  instead of a full skill mapping table.
- Visual phase-lock indicators: 🔒 (blocked) / 🔓 (allowed).
- Quick-path detection shown in output.
- Protocol reference added.

### Added — Quick-path Detection (P1)
- Explicit `.quick-path` file detection documented in plan-first-plan
  and workflow-protocol.md.
- session-start.sh displays quick-path status.

### Changed — Skill File Standardization (P1)
- All 8 skills now have a **Quick Reference** table (Trigger, Input,
  Output, Side effects, Sole responsibility, Exit condition).
- All 8 skills now have a **Mode Behavior** table (cross-skill deps,
  output path, gate checks per mode).
- Consistent process structure with inline ⚠️ checkpoints.

### Changed — Review Stage Closure (P1)
- **plan-first-implement** no longer triggers code review itself.
  Review is a separate phase detected by `detect_phase` and guided
  by `baton next`.
- Full implement → verify → review → done pipeline is now closed-loop.

### Added — Hard Constraints Pre-read (P2)
- **plan-first-plan**: Reads hard-constraints.md during design phase.
  Risk assessment must address each active constraint's scope.
- **context-slice**: Propagates relevant constraints into each slice's
  Hard Constraints field based on file scope intersection.

### Changed — Anti-rationalization (P2)
- Inline ⚠️ checkpoints embedded at each process step where the AI
  is most likely to deviate. Full rationalization table preserved as
  reference at end of each skill file.

### Added — Tests (P2)
- 8 new smoke tests covering: slice phase detection, approved phase
  detection, review phase detection, done-requires-review, review
  blocking detection, quick-path, phase-lock during slice, and
  baton-next slice guidance.

### Infrastructure
- `baton install` now copies `workflow-protocol.md` to global root.
- `baton doctor` checks for workflow-protocol.md presence.
- `baton generate` includes protocol reference in AGENTS.md.
- Cursor rules include Phase-Lock Self-Enforcement section.

## [2.0.0-alpha] — 2026-02-01

Initial release with 8 skills, CLI, phase-lock hook, and 3-layer
architecture (Layer 0 standalone, Layer 1 task workflow, Layer 2
project governance).
