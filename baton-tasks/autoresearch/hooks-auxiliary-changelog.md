# Hooks Auxiliary Changelog

**Date**: 2026-03-20
**Branch**: claude/confident-chaum
**Motivation**: autoresearch pass over the five baton auxiliary hook scripts to identify
gaps in functional completeness, boundary handling, constitution/skill consistency,
error message quality, and performance/side-effects.

---

## Scoring Summary

Each hook scored across 5 dimensions (max 5 pts each, total 25):

| Hook | Functional | Boundary | Constitution | Messages | Performance | Total |
|------|-----------|----------|--------------|----------|-------------|-------|
| phase-guide.sh | 4 | 4 | 3 | 4 | 5 | **20/25** |
| post-write-tracker.sh | 4 | 3 | 4 | 4 | 3 | **18/25** |
| subagent-context.sh | 3 | 3 | 2 | 3 | 4 | **15/25** |
| bash-guard.sh | 3 | 4 | 4 | 4 | 5 | **20/25** |
| pre-compact.sh | 3 | 4 | 3 | 3 | 4 | **17/25** |

---

## Test Scenarios and Findings

### phase-guide.sh (SessionStart)

**Scenario A — PLAN state with research that changed scope**
- Entry: research.md exists, no plan.md, `_dim_count` = 3 (multi-dimension research)
- Finding: Hook emitted investigation-dimension warning but gave no sizing re-assessment prompt.
  The constitution's Sizing Checkpoint requires explicit re-assessment at research→plan boundary.
  Gap: No Sizing Checkpoint reminder in PLAN state.

**Scenario B — RESEARCH state with a trivial typo fix**
- Entry: nothing exists; task is a one-word typo fix
- Finding: Hook directed user to create research.md, with generic "Simple changes may skip
  research" note in the else-branch only (when no skills installed). With skills, no skip
  guidance at all.
  Gap: Trivial task note not shown when research skills are available.

**Scenario C — Unexpected error in skill scanner**
- Entry: `$_ALL_SKILLS` assignment fails (skills dir missing)
- Finding: `_scan_all_skills()` returns empty string; all `_skills_matching` calls return
  empty; fallback hardcoded paths activate correctly.
  Handled correctly via fail-open design.

### post-write-tracker.sh (PostToolUse)

**Scenario A — Two simultaneous Claude sessions on the same machine**
- Entry: Session A (PPID=1234) writes out-of-set; Session B coincidentally has PPID=1234
- Finding: Both sessions share `/tmp/baton-writeset-violations-1234`; Session B sees
  Session A's violations as its own and escalates prematurely.
  Gap: PPID-based session ID collides across sessions.

**Scenario B — jq unavailable; JSON has deeply nested `cwd`**
- Entry: No jq; cwd field is present but awk parser splits on `"` and picks wrong token
  when path contains spaces.
  Gap: awk fallback is fragile for paths with spaces or escaped characters.
  (Noted — not fixed in this pass; fix requires broader JSON parsing refactor.)

**Scenario C — Markdown file edited during IMPLEMENT phase**
- Entry: Gate open; user edits `docs/ARCHITECTURE.md`
- Finding: Hook exits early at the markdown extension check (line 61-63).
  Handled correctly — markdown always allowed.

### subagent-context.sh (SubagentStart)

**Scenario A — Subagent dispatched during ANNOTATION phase**
- Entry: plan.md exists, gate closed; subagent spawned for read-only research subtask
- Finding: Hook exited silently (guard: no GO marker → exit 0). Subagent received
  no context about the current phase or plan existence.
  Gap: ANNOTATION-phase subagents get zero context.

**Scenario B — Subagent dispatched during IMPLEMENT phase; writes out-of-set file**
- Entry: Gate open; plan has Files: `src/foo.py`; subagent writes `src/bar.py`
- Finding: Subagent had no knowledge of the write set. post-write-tracker catches it
  after the fact, but the subagent had no upfront signal.
  Gap: Write set not injected at subagent start.

**Scenario C — No plan at all (RESEARCH phase subagent)**
- Entry: No plan.md; subagent spawned for research assistance
- Finding: Hook exits silently at `[ -z "$PLAN" ] && exit 0`. Correct — no misleading
  context injected.

### bash-guard.sh (PreToolUse/Bash)

**Scenario A — `patch -p1 < fix.patch` run pre-GO**
- Entry: Gate closed; command is `patch -p1 < fix.patch`
- Finding: `patch` not in block list; the `<` is input redirection (not output), so
  `has_output_redirection` returns false. Command passes through.
  Gap: `patch` applies diffs in-place — destructive write not caught.

**Scenario B — `rm -rf build/` run pre-GO**
- Entry: Gate closed; command is `rm -rf build/`
- Finding: `rm` not in block or warn-only lists. Destructive deletion passes silently.
  Gap: `rm` not warned.

**Scenario C — `git checkout -- src/foo.py` run pre-GO**
- Entry: Gate closed; command discards working-tree changes
- Finding: No output redirection; not in any block/warn list. Passes silently.
  Acceptable — git operations are out of scope for this guard; git's own safeguards apply.

### pre-compact.sh (PreCompact)

**Scenario A — IMPLEMENT phase with recent annotation decisions**
- Entry: Gate open; plan has `## Annotation Log` with 3 rounds of decisions; compression triggered
- Finding: Hook output "Recent decisions from Annotation Log available in plan.md" — a
  pointer only. After compression, the AI has no access to that file without re-reading it.
  Gap: Annotation log content not preserved in the snapshot.

**Scenario B — IMPLEMENT phase; plan has 8 Files: entries in Todo**
- Entry: Gate open; 8 files in write set; compression triggered mid-implementation
- Finding: Write set not included in snapshot. After compression, AI may not know which
  files are authorized.
  Gap: Write set absent from pre-compact snapshot.

**Scenario C — No plan at all**
- Entry: No plan.md; compression triggered during research phase
- Finding: Hook exits at `[ -z "$PLAN" ] && exit 0`. No output. Correct.

---

## Changes Made

### 1. `phase-guide.sh` — Version 7.0 → 7.1

**Change A: Sizing Checkpoint reminder in PLAN state (State 5)**

Added a 5-line sizing checkpoint block after the investigation-dimension heuristic.
Emits:
```
📐 Sizing Checkpoint — before creating the plan, re-assess sizing:
   · Did research reveal more verification steps than assumed at entry?
   · Were cross-module dependencies or interface impacts discovered?
   · Is the validation strategy more complex than originally assumed?
   If sizing increases: record reason at top of plan; add process steps for the higher level.
```

**Why**: Constitution §Sizing Checkpoint requires explicit re-assessment at the
research→plan transition. Without this prompt, AI would often proceed to plan creation
with the original (possibly stale) sizing estimate.

**Change B: Trivial task note in RESEARCH state (State 6)**

Added a universal note shown regardless of skill availability:
```
💡 Trivial tasks (verification by visual inspection only) may skip research — use an inline plan instead.
```

**Why**: The note was previously only in the `else` branch (no skills installed). With
skills registered, the Trivial skip path was invisible. Constitution defines Trivial as
"目视检查即可验证" — research is not required.

---

### 2. `subagent-context.sh` — Version 1.1 → 1.2

**Change A: ANNOTATION-phase context for subagents**

Changed from silently exiting when the GO marker is absent to emitting a phase signal:
```
📋 Baton: $PLAN_NAME exists — ANNOTATION phase (awaiting BATON:GO).
```

**Why**: A subagent dispatched during ANNOTATION phase had no context that a plan
existed or what phase was active. Even without the gate open, the phase signal prevents
subagents from treating the project as if it were in RESEARCH.

**Change B: Write set injection in IMPLEMENT phase**

After outputting Todo items, added write-set output via `parser_writeset_extract`:
```
🔒 Authorized write set:
   src/foo.py
   src/bar.py
```

**Why**: Subagents were unaware of their authorized scope. The post-write-tracker
catches violations after the fact, but the write set signal at SubagentStart prevents
the violation — consistent with the constitution's defense-model principle that each
layer should enforce what it can.

---

### 3. `bash-guard.sh` — Version 3.2 → 3.3

**Change A: `patch` added to block list**

Added after `truncate` in the file-mutation block:
```bash
elif [ -z "$_blocked" ] && _is_cmd_token 'patch'; then
    _blocked="patch (in-place diff application)"
fi
```

**Why**: `patch` applies diff files directly to source files in-place. Its write
semantics are equivalent to `sed -i` (already blocked). The `<` in
`patch -p1 < fix.patch` is input redirection, so `has_output_redirection` did not
catch it. `_is_cmd_token` handles bare and path-qualified variants (`/usr/bin/patch`).

**Change B: `rm` added to warn-only list**

Added before the `touch` warn:
```bash
if _is_cmd_token 'rm'; then
    echo "⚠️ Bash guard: 'rm' detected while plan gate is closed (destructive — verify intent)."
fi
```

**Why**: `rm` is destructive (permanent deletion) but not a write in the content-creation
sense — blocking it would be too aggressive for a pre-GO context where cleanup commands
are legitimate. Warn-only is consistent with `touch` treatment. Uses `_is_cmd_token` for
word-boundary safety (avoids false matches on `grep`, `stream`, etc.).

---

### 4. `pre-compact.sh` — Version 1.1 → 1.2

**Change A: Write set included in snapshot**

Added write-set block via `parser_writeset_extract` (up to 10 files):
```
   Authorized write set:
     src/foo.py
     src/bar.py
```

**Why**: Post-compression AI needs to know authorized scope to avoid out-of-set writes.
A pointer to the plan file is insufficient — the AI must re-read the file to recover
the write set, which is unreliable under compression pressure.

**Change B: Annotation Log content output (last 10 lines)**

Replaced the pointer-only message with actual content extraction via awk
(`/^## Annotation Log/ → /^## /` section, last 10 lines):
```
   Recent Annotation Log:
     [last 10 lines of ## Annotation Log section]
```

**Why**: Annotation Log records negotiated decisions (e.g., "human approved approach X,
rejected Y"). These decisions must survive compression. "Available in plan.md" is useless
once the conversation has been compressed and the AI can no longer assume it has seen
the plan recently.

---

### 5. `post-write-tracker.sh` — Version 1.0 → 1.1

**Change: Prefer `CLAUDE_SESSION_ID` env var over PPID as session ID fallback**

Changed fallback from `${PPID:-unknown}` to `${CLAUDE_SESSION_ID:-${PPID:-unknown}}`.

**Why**: PPID is the PID of the parent process (Claude). PIDs are reused by the OS: if
a Claude session exits and a new one starts and coincidentally gets the same PPID, the
new session inherits the old session's violation file. `CLAUDE_SESSION_ID` (if set by
the runtime) is unique per logical session. The JSON `session_id` extraction (already
present) takes highest priority and overrides both.

**Known remaining gap**: The awk fallback for JSON field extraction (used when jq is
unavailable) is fragile for paths containing spaces or escaped characters. This requires
a broader JSON parsing refactor and was deferred.

---

## Simulation Against Scoring Dimensions

| Issue | Old behavior | New behavior | Resolved? |
|-------|-------------|--------------|-----------|
| PLAN state missing Sizing Checkpoint | No prompt at research→plan boundary | 5-line checkpoint block emitted | ✅ |
| Trivial skip note hidden when skills present | Only in else-branch | Universal note, both branches | ✅ |
| ANNOTATION-phase subagents get no context | Silent exit | Phase label emitted | ✅ |
| Subagents unaware of write set | No injection | `parser_writeset_extract` on SubagentStart | ✅ |
| `patch` not blocked pre-GO | Passes through | Added to block list | ✅ |
| `rm` not warned pre-GO | Passes silently | `_is_cmd_token 'rm'` warn-only | ✅ |
| Write set absent from pre-compact snapshot | Not included | Added via `parser_writeset_extract` | ✅ |
| Annotation log pointer only | "Available in plan.md" | Last 10 lines extracted and emitted | ✅ |
| PPID collision across sessions | Only PPID fallback | `CLAUDE_SESSION_ID` preferred | ✅ |
| awk JSON fallback fragile for space-paths | Fragile | Deferred — needs JSON parsing refactor | ❌ deferred |

---

## What Was NOT Changed

- **manifest.conf**: Event-to-hook routing is correct; no gaps found.
- **dispatch.sh**: Subshell isolation, stdin buffering, exit-2 propagation all correct.
- **lib/common.sh** / **lib/plan-parser.sh**: No issues found in the shared library layer.
- **Hook error-handling (`trap 'exit 0'`)**: Fail-open pattern correct and consistent.
- **Markdown exclusion in post-write-tracker.sh**: Correct behavior.
- **Version headers**: Updated in each modified hook's comment block.

---

## 批注区
