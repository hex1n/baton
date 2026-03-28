# Hooks Extension Design

**Date**: 2026-03-28
**Status**: Draft — awaiting approval
**Follows**: `docs/plans/2026-03-28-runtime-enforcement-design.md`
**Sources**: https://code.claude.com/docs/en/hooks · https://developers.openai.com/codex/hooks

---

## Platform Hook Matrix

| Hook | Claude Code | Codex | Can block (CC) | Can block (Codex) |
|------|-------------|-------|----------------|-------------------|
| `PreToolUse` | ✅ | ✅ Bash only | exit 2 / `permissionDecision: deny` | exit 2 / `decision: block` |
| `PostToolUse` | ✅ | ✅ Bash only | exit 2 / `decision: block` | `continue: false` |
| `Stop` | ✅ | ✅ | exit 2 / `decision: block` | `decision: block` (JSON required) |
| `SessionStart` | ✅ | ✅ | no | no |
| `SubagentStop` | ✅ | ✗ | exit 2 / `decision: block` | — |
| `UserPromptSubmit` | ✅ | ✅ | exit 2 / `decision: block` | exit 2 / `decision: block` |
| `SubagentStart` | ✅ | ✗ | no | — |
| `PostToolUseFailure` | ✅ | ✅ | no | no |
| `InstructionsLoaded` | ✅ | ✗ | no | — |
| `ConfigChange` | ✅ | ✗ | exit 2 / `decision: block` | — |
| `PreCompact` / `PostCompact` | ✅ | ✗ | no | — |
| `WorktreeCreate` / `WorktreeRemove` | ✅ | ✗ | exit non-zero | — |
| `Notification` | ✅ | ✗ | no | — |
| `TaskCreated` / `TaskCompleted` | ✅ | ✗ | exit 2 / `continue: false` | — |
| `TeammateIdle` | ✅ | ✗ | exit 2 / `continue: false` | — |
| `CwdChanged` / `FileChanged` | ✅ | ✗ | no | — |
| `StopFailure` | ✅ | ✗ | no | — |
| `Elicitation` / `ElicitationResult` | ✅ | ✗ | exit 2 / `action: decline` | — |

**Currently installed** (from `runtime-enforcement-design.md`): `PostToolUse`, `PreToolUse`

---

## Context

`runtime-enforcement-design.md` added `PostToolUse` + `PreToolUse` to enforce:
- artifact section completeness (after write)
- state transition legality (before write)

This document covers the next layer: turn-end gate enforcement, fork agent output
validation, and session-start context injection.

---

## Problem

Three gaps remain after the first enforcement pass:

```
Gap A: Turn-end artifact completeness is not checked
  state can advance to "generating" and Claude can finish the turn
  without verification-path.md existing
  → gate 3 is bypassed silently

Gap B: Fork agent output is not validated
  baton-evaluator and baton-verifier can complete without producing
  their required artifacts
  → parent agent has no signal that the subagent failed its contract

Gap C: Session-start harness state is invisible
  Claude starts a fresh session with no awareness of current task state
  → relies on human to paste module-status.md or Claude to read it manually
```

---

## Design

### H1 — `Stop` hook: turn-end gate enforcement

**When**: Claude finishes each turn (`Stop` event).
**Can block**: yes.
**Platform**: Claude Code + Codex.

**Blocking output**:
- Claude Code: exit 2, OR JSON `{"decision": "block", "reason": "..."}`
- Codex: JSON required — `{"decision": "block", "reason": "..."}` (plain text + exit 2 not sufficient)

Since Codex requires JSON, the script always outputs JSON. Claude Code accepts both,
so JSON output works on both platforms.

**Logic**:
1. If `.harness/module-status.md` does not exist → exit 0 (no active task).
2. Read current state from the task table.
3. Look up required artifacts for that state.
4. For each required artifact, check it exists in `.harness/`.
5. If any are missing → output JSON block with list and instruction.

**State → required artifacts** (derived from `protocol/gates.md`):

| State | Required artifacts |
|-------|--------------------|
| `exploring` | *(none)* |
| `specifying` | `scoped-map.md` |
| `architecting` | `scoped-map.md`, `requirements.md` |
| `awaiting_human_arch` | `scoped-map.md`, `requirements.md`, `architecture.md` |
| `verification_check` | `scoped-map.md`, `requirements.md`, `architecture.md` |
| `generating` | `scoped-map.md`, `requirements.md`, `architecture.md`, `verification-path.md` |
| `reviewing` | `scoped-map.md`, `requirements.md`, `architecture.md`, `verification-path.md` |
| `ready_for_human_close` | `scoped-map.md`, `requirements.md`, `architecture.md`, `verification-path.md` |
| `complete` | `scoped-map.md`, `requirements.md`, `architecture.md`, `verification-path.md` |
| `blocked` | *(intentionally incomplete — no artifact check)* |

**New script**: `spec/bootstrap/validate-state-artifacts.sh`
- Input: `<harness_dir>` (default `.harness`)
- Output: JSON to stdout; exit 0 = pass, exit 2 = block
- Also callable standalone for debugging

**JSON block output**:
```json
{
  "decision": "block",
  "reason": "State is \"generating\" but missing required artifacts:\n  - .harness/verification-path.md\nWrite the missing artifact before finishing this turn."
}
```

---

### H2 — `SubagentStop` hook: fork agent output validation

**When**: a `context: fork` subagent completes (`SubagentStop` event).
**Can block**: yes — exit 2 or `{"decision": "block", "reason": "..."}`.
**Platform**: Claude Code only (`SubagentStop` not available in Codex).
**Matcher**: `baton-evaluator|baton-verifier`
**Stdin field**: `agent_type` (not `agent_name`)

**Logic per agent**:

| Agent | Check | Failure action |
|-------|-------|----------------|
| `baton-verifier` | `verification-path.md` exists + sections valid | exit 2, parent must re-dispatch |
| `baton-evaluator` | `module-status.md` state is `blocked`, `reviewing`, or `ready_for_human_close` | exit 2, parent must re-dispatch |

**Implementation**: inline hook command using existing `validate-artifact.sh`:

```bash
input=$(cat)
agent=$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null)
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
bootstrap="$root/.vendor/baton-harness/spec/bootstrap"
case "$agent" in
  baton-verifier)
    [[ -f "$root/.harness/verification-path.md" ]] || {
      printf '{"decision":"block","reason":"baton-verifier completed without writing verification-path.md"}\n'
      exit 2
    }
    bash "$bootstrap/validate-artifact.sh" verification-path "$root/.harness/verification-path.md" || exit 2
    ;;
  baton-evaluator)
    state=$(awk -F'|' 'NR>2 && NF>3 && $4!~/---/{gsub(/ /,"",$4); print $4; exit}' \
            "$root/.harness/module-status.md" 2>/dev/null)
    case "$state" in
      blocked|reviewing|ready_for_human_close) ;;
      *)
        printf '{"decision":"block","reason":"baton-evaluator completed but module-status state is \"%s\" (expected blocked/reviewing/ready_for_human_close)"}\n' "$state"
        exit 2
        ;;
    esac
    ;;
esac
# baton-subagent-stop
```

---

### H3 — `SessionStart` hook: harness context injection

**When**: session starts or resumes (`SessionStart` event).
**Can block**: no — injects context only.
**Platform**: Claude Code + Codex (both confirmed).
**Matcher**: `startup|resume`

**Output format**:
- Claude Code: `{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "..."}}`
- Codex: plain text OR same JSON — use JSON for consistency across both platforms

**Logic**:
1. If `.harness/module-status.md` does not exist → minimal no-task context.
2. Read task id, owner, state, eval round from table.
3. List which required artifacts for the current state exist vs. missing.
4. Output JSON `additionalContext`.

**Output examples**:

Active task:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Harness task active:\n  task: <id>  state: generating  owner: generator  eval_round: 0\n  present: scoped-map.md, requirements.md, architecture.md\n  missing: verification-path.md"
  }
}
```

No active task:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "No active harness task."
  }
}
```

**New script**: `spec/bootstrap/harness-context.sh`
- Input: `<harness_dir>` (default `.harness`)
- Output: JSON to stdout
- Standalone: `bash harness-context.sh` for debugging

---

## Implementation Notes

### Dynamic bootstrap path

All hook commands use `git rev-parse --show-toplevel` instead of the path baked in
at install time. Repo can be moved without reinstalling hooks.

```bash
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
bootstrap="$root/.vendor/baton-harness/spec/bootstrap"
```

This change applies to **all existing hooks** (PostToolUse, PreToolUse) as well as
the new ones. `install-hooks.sh` removes the `BOOTSTRAP_DIR` substitution logic.

### `statusMessage` for Codex

All Codex hook entries include `statusMessage` for user-visible progress:

| Hook | statusMessage |
|------|---------------|
| `PostToolUse` | `"Validating artifact"` |
| `PreToolUse` | `"Checking state transition"` |
| `Stop` | `"Checking harness state"` |
| `SessionStart` | `"Loading harness context"` |

### Stop output must be JSON

The `validate-state-artifacts.sh` script always outputs JSON (not plain text + exit 2),
so it works on both Claude Code and Codex without branching.

---

## Delivery Map

| ID | Deliverable | Type | Depends on |
|----|-------------|------|------------|
| H0 | Migrate existing hooks to `git rev-parse` dynamic path | Script edit | — |
| H1-1 | `validate-state-artifacts.sh` | New script | — |
| H1-2 | `tests/test-validate-state-artifacts.sh` | New tests | H1-1 |
| H1-3 | `Stop` hook in `install-hooks.sh` (CC + Codex) | Script edit | H1-1 |
| H2-1 | `SubagentStop` hook in `install-hooks.sh` (CC only) | Script edit | — |
| H2-2 | SubagentStop tests in `test-install-hooks.sh` | Test edit | H2-1 |
| H3-1 | `harness-context.sh` | New script | — |
| H3-2 | `tests/test-harness-context.sh` | New tests | H3-1 |
| H3-3 | `SessionStart` hook in `install-hooks.sh` (CC + Codex) | Script edit | H3-1 |

---

## Constraints

- `Stop` must not block when no `.harness/module-status.md` exists —
  hooks run on all sessions, not just harness sessions
- `Stop` skips check on `blocked` state — intentionally incomplete
- `SubagentStop` is a soft signal to parent — parent decides whether to re-dispatch
- `SessionStart` context must be short (< 150 words) — injected into every session
- All hook commands idempotent via marker strings
- All blocking output in JSON — no platform branching in scripts

---

## Out of Scope

- `UserPromptSubmit`: both platforms support it; deferred — lower ROI than `Stop`
  for harness enforcement; can add later for `blocked` state reminder injection
- `PostToolUseFailure`: `.harness/` write failures are rare; deferred
- `WorktreeCreate`: not yet used by baton protocol; deferred
