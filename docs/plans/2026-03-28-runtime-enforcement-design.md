# Runtime Enforcement Design

**Date**: 2026-03-28
**Status**: Approved for implementation
**Source**: Brainstorming session on runtime-thickness-analysis.md

---

## Problem

Three failure chains identified from `docs/runtime-thickness-analysis.md`:

```
Failure Chain A: Isolation assumption is unenforced
  context: fork is a text instruction, not a technical constraint
  → main session can invoke /baton-evaluator via Skill, bypassing isolation

Failure Chain B: Artifact completeness has no validation layer
  artifact-schema.md defines required sections, nothing checks them
  → agent can produce incomplete artifacts; gates still pass

Failure Chain C: State machine has no transition enforcement
  eval_round buried in free-text State Notes
  state transitions have no legality check
  → repair round counts are unreliable; states can jump illegally
```

---

## Design

### P0 — Architecture Correctness

**P0-1: Context isolation self-check**

In `baton-evaluator.md` and `baton-verifier.md` Startup section:
- Add assertion: if running inside an existing session with Generator artifacts
  visible in context, stop immediately and instruct caller to re-dispatch via
  `Agent` tool (not `Skill` tool)
- Add to `spec/adapters/claude-code.md`: Invariant — context isolation
  responsibility belongs to the orchestrator (caller), not the invoked skill

**P0-2: Architect rejection path**

In `baton-architect.md` "Rejected — requirements misunderstood" branch:
1. Write `module-status.md` → `blocked`, `design_blocker`, with specific ambiguity notes
2. Write `generator-feedback.md` with `recommended_next_owner: specifier`
3. Document: Specifier must resolve `generator-feedback.md` before rewriting `requirements.md`

This gives Specifier an explicit entry condition and Architect a complete exit contract.

---

### P1 — Runtime Thickness via Hooks

Scripts contain logic. Hooks provide automatic triggering — enforcement becomes
platform-level, not voluntary.

```
Script layer (logic)         Hook layer (trigger)
────────────────────         ──────────────────────────────────────
validate-artifact.sh    ←    PostToolUse: Write/Edit → .harness/*.md
validate-transition.sh  ←    PreToolUse:  Write/Edit → .harness/module-status.md
```

**P1-1: `spec/bootstrap/validate-artifact.sh`**

- Input: artifact name, file path
- Logic: for each artifact type, check all required sections from `artifact-schema.md` exist (`## Section Name` headings)
- Output: lists missing sections; exits non-zero on failure
- Covers: `scoped-map`, `requirements`, `architecture`, `verification-path`, `module-status`

**P1-2: `spec/bootstrap/validate-transition.sh`**

- Input: `from_state`, `to_state`
- Logic: parse allowed transitions from `state-machine.md`; `any -> blocked` treated as wildcard
- Output: ALLOWED or ILLEGAL with reason; exits non-zero if illegal
- Called via PreToolUse hook — can block the write before it happens

**P1-3: Structured `eval_round` in `module-status.md` template**

- Add `Eval Round` column to the task table (default `0`)
- Evaluator increments this column on each BLOCKED verdict
- `baton-status.md` reads the column directly (numeric comparison, no text parsing)
- 3-round escalation becomes a reliable numeric check

**P1-4: `spec/bootstrap/install-hooks.sh`**

- Platform-aware: detects Claude Code vs Codex environment
- Claude Code: writes PostToolUse and PreToolUse entries to `.claude/settings.json`
- Codex: writes equivalent hook configuration
- Idempotent: already-registered hooks are skipped, not duplicated
- Called automatically by `install-harness.sh` and `update-harness.sh`

**P1-5: Update `install-harness.sh` and `update-harness.sh`**

- Both call `install-hooks.sh` at the end of their run
- Zero extra cognitive load for users

---

### P2 — Agent Registration Completeness

**P2-1: `check-consistency.sh` Invariant 7**

New invariant: every skill with `context: fork` in frontmatter must have a
corresponding entry in `.claude/agents/`.

- Source of truth: skill frontmatter (single source — no separate list to maintain)
- Scan: `skills/baton-*.md` → find `context: fork`
- Check: `.claude/agents/<name>.md` exists
- Failure: reports which isolated role is missing its agent registration

**P2-2: `link-skills.sh` extended for `.claude/agents/`**

- Current: creates symlinks in `.claude/skills/` and `.agents/`
- Extension: for `context: fork` skills, also create symlink in `.claude/agents/`
- Result: `install-harness.sh` → `link-skills.sh` → agents registration is automatic

---

## Delivery Map

| ID | Deliverable | Type | Depends on |
|----|-------------|------|------------|
| P0-1 | Self-check assertion in evaluator + verifier skills | Skill edit | — |
| P0-1 | claude-code.md isolation invariant | Doc edit | — |
| P0-2 | Architect rejection path in baton-architect.md | Skill edit | — |
| P1-1 | `validate-artifact.sh` | New script | — |
| P1-2 | `validate-transition.sh` | New script | — |
| P1-3 | `module-status.template.md` eval_round column | Template edit | — |
| P1-3 | `baton-evaluator.md` eval_round increment update | Skill edit | P1-3 template |
| P1-3 | `baton-status.md` eval_round read update | Skill edit | P1-3 template |
| P1-4 | `install-hooks.sh` | New script | P1-1, P1-2 |
| P1-5 | `install-harness.sh` + `update-harness.sh` call hooks | Script edit | P1-4 |
| P2-1 | `check-consistency.sh` Invariant 7 | Script edit | — |
| P2-2 | `link-skills.sh` `.claude/agents/` extension | Script edit | — |

---

## Constraints

- `.harness/` artifacts are NOT git-managed — no git hooks
- Hook trigger mechanism is platform tool-use events (Write/Edit), not git events
- Core protocol (`spec/protocol/`) is immutable — all changes are in scripts and skills
- Hook installation must be idempotent — safe to re-run on update
