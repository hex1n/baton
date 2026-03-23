# Improvement Proposal: Hook Dispatch Context Centralization

**Planning depth**: Deep
**Input sources**: Hook dispatch analysis document + verified against all codebase files (dispatch.sh, manifest.conf, 10 hook scripts, run-hook.cmd, lib/common.sh, lib/plan-parser.sh)

---

## Current State

dispatch.sh routes IDE events to hook scripts via a declarative manifest (manifest.conf). Each hook is an independent bash script that:
1. Sets a fail-open trap
2. Sources lib/common.sh (which sources lib/plan-parser.sh)
3. Calls resolve_plan_name + find_plan to locate the plan file
4. Parses BATON_STDIN (JSON) for tool-specific fields (file_path, command, cwd)
5. Performs its actual logic (block/allow/advise)

Currently: 10 manifest entries, 10 hook scripts (the input document's count of 8/5 is stale -- ✅ verified against actual manifest.conf and file listing). dispatch.sh runs each matching hook in a subshell, buffering stdin once and exporting BATON_STDIN + BATON_PROJECT_DIR.

**What works well**: The buffered BATON_STDIN mechanism, the fail-open principle, the exit code protocol (0/2), manifest-based declarative routing, and the extensive test coverage (75+ assertions across test suites).

---

## Root Cause of Suboptimality

The core issue is **duplicated context derivation**, not the five symptoms listed in the input document.

Every hook independently performs the same expensive work:
- **Plan discovery**: 8 of 10 hooks call `resolve_plan_name` + `find_plan`, which walks the directory tree, checks for plan files, handles multi-plan ambiguity, and reads plan content. ✅ verified: write-lock.sh, bash-guard.sh, phase-guide.sh, stop-guard.sh, post-write-tracker.sh, completion-check.sh, subagent-context.sh, pre-compact.sh all do this.
- **JSON field extraction**: write-lock.sh and post-write-tracker.sh independently parse `file_path` and `cwd` from BATON_STDIN using jq-with-awk-fallback. bash-guard.sh independently parses `command`. ✅ verified in source.
- **GO marker checking**: 6 hooks independently grep for `<!-- BATON:GO -->` in the plan file.
- **Boilerplate setup**: Every hook has the same ~15-line preamble (trap, source common.sh, resolve_plan_name, find_plan).

This means a single PreToolUse:Write event triggers write-lock.sh, which finds the plan, parses stdin, checks GO marker -- then post-write-tracker.sh and quality-gate.sh fire on the PostToolUse side and do it all again.

**Consequence**: On Windows (where each subshell costs ~200ms), adding a hook that fires on Write events adds ~200ms per write tool invocation, regardless of whether the hook's actual logic takes 1ms. The overhead is in context derivation and subshell startup, not decision-making.

The input document lists five issues. Root-cause analysis shows:
- Issue 1 (flat manifest): Real but secondary. Hooks compensate internally with their own phase detection.
- Issue 2 (no inter-hook communication): Overstated. ❓ Hooks already communicate via env vars, temp files (/tmp/baton-failures-*, /tmp/baton-writeset-violations-*), and the plan file itself. What's missing is *structured* shared context, which is the root cause restated.
- Issue 3 (coarse error handling): Misattributed. The exit code protocol is an IDE constraint (C1), not a dispatch deficiency. dispatch.sh already surfaces unexpected exit codes as warnings.
- Issue 4 (Windows complexity): True constraint. run-hook.cmd is a well-crafted polyglot; the complexity is inherent to cross-platform bash.
- Issue 5 (testing difficulty): Real but already mitigated (58 + 17 assertions in existing test suites).

---

## Hidden Assumptions in Current Approach

| # | Assumption | Reality | Impact |
|---|-----------|---------|--------|
| 1 | Each hook must independently derive its context | dispatch.sh could pre-derive once and export | Root cause of duplication |
| 2 | Hooks must run in subshells for isolation | Isolation is valuable for safety, but subshell startup is the dominant cost on Windows | Performance bottleneck |
| 3 | Every hook needs its own fail-open trap and common.sh sourcing | This boilerplate could live in dispatch.sh's hook runner | 15 lines of boilerplate per hook |
| 4 | Hooks that fire on the same event must be separate scripts | Same-event hooks with coupled logic (e.g., post-write-tracker + quality-gate) could be a single script | Unnecessary subshell count |
| 5 | manifest.conf needs re-parsing on every invocation | At 10 lines this is ~5ms -- not worth optimizing yet | Non-issue at current scale |

---

## Proposed Changes

### Change 1: Pre-derive common context in dispatch.sh

dispatch.sh already computes BATON_STDIN and BATON_PROJECT_DIR. Extend this to derive and export the fields that 8+ hooks independently compute:

```bash
# After existing BATON_STDIN buffering, add:
export BATON_PLAN_PATH=""
export BATON_PLAN_NAME=""
export BATON_HAS_GO=""
export BATON_PHASE=""        # RESEARCH|PLAN|ANNOTATION|AWAITING_TODO|IMPLEMENT|FINISH
export BATON_TARGET_PATH=""  # parsed from stdin JSON .tool_input.file_path
export BATON_TARGET_CWD=""   # parsed from stdin JSON .cwd
export BATON_CMD=""          # parsed from stdin JSON .tool_input.command

# Pre-parse stdin JSON fields (once, not per-hook)
if [ -n "$BATON_STDIN" ]; then
    if command -v jq >/dev/null 2>&1; then
        BATON_TARGET_PATH="$(printf '%s' "$BATON_STDIN" | jq -r '.tool_input.file_path // empty')"
        BATON_TARGET_CWD="$(printf '%s' "$BATON_STDIN" | jq -r '.cwd // empty')"
        BATON_CMD="$(printf '%s' "$BATON_STDIN" | jq -r '.tool_input.command // empty')"
    else
        # awk fallback (single pass, extract all fields)
        eval "$(printf '%s' "$BATON_STDIN" | awk -F'"' '{
            for(i=1;i<=NF;i++) {
                if($i=="file_path") printf "BATON_TARGET_PATH=%s\n", $(i+2)
                if($i=="cwd") printf "BATON_TARGET_CWD=%s\n", $(i+2)
                if($i=="command") printf "BATON_CMD=%s\n", $(i+2)
            }
        }')"
    fi
fi

# Pre-derive plan location (source common.sh once in dispatch)
. "$_dir/lib/common.sh" 2>/dev/null && {
    resolve_plan_name
    find_plan
    BATON_PLAN_PATH="${PLAN:-}"
    BATON_PLAN_NAME="${PLAN_NAME:-}"
    if [ -n "$PLAN" ] && grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null; then
        BATON_HAS_GO="1"
    fi
}
```

**Expected impact**: Each hook drops 10-20 lines of context derivation code. Plan discovery happens once per dispatch cycle instead of N times. JSON parsing happens once instead of per-hook. ✅ Backward-compatible: hooks can check `if [ -z "${BATON_PLAN_PATH:-}" ]` and fall back to self-derivation for standalone testing.

**Risk**: dispatch.sh becomes heavier (sources common.sh even for events that don't need plan context, like PostToolUseFailure). Mitigation: only pre-derive plan context for events that need it (PreToolUse, PostToolUse, Stop, TaskCompleted, SubagentStart, PreCompact). SessionStart (phase-guide.sh) already does its own heavy derivation and would benefit too.

### Change 2: Centralize hook boilerplate in a runner function

Replace the current hook invocation:

```bash
# Current (dispatch.sh line 51-52):
_rc=0
( . "$_dir/$_script.sh" ) || _rc=$?
```

With a runner that provides the standard preamble:

```bash
_run_hook() {
    local _script="$1"
    trap 'echo "BATON dispatch: $_script unexpected error, allowing (fail-open)" >&2; exit 0' HUP INT TERM
    . "$_dir/$_script.sh"
}
_rc=0
( _run_hook "$_script" ) || _rc=$?
```

**Expected impact**: Hooks no longer need their own fail-open traps or common.sh sourcing. A new hook is pure logic -- typically 10-30 lines instead of 30-60.

**Risk**: Hooks lose the ability to customize their trap behavior. Mitigation: hooks that need custom traps (currently none do -- all use the same fail-open pattern) can override the trap within their script.

### Change 3: Combine same-event hooks with coupled logic

Two PostToolUse hook pairs always fire together on the same matcher:
- post-write-tracker.sh + quality-gate.sh (both fire on Write,Edit,MultiEdit,CreateFile,NotebookEdit)

These could become a single script (e.g., `post-write-hooks.sh`) with clearly separated sections.

**Expected impact**: One fewer subshell per PostToolUse:Write event. On Windows, this saves ~200ms per write operation. Small maintenance benefit from reducing file count.

**Risk**: Reduced separation of concerns within the file. Mitigation: use clear section headers and keep functions separate within the combined script. If either hook's logic grows significantly, split them back out.

**Candidates NOT to combine**:
- write-lock.sh and bash-guard.sh: different matchers (Write,Edit vs Bash), different logic. Keep separate.
- stop-guard.sh and completion-check.sh: different events (Stop vs TaskCompleted). Keep separate.
- phase-guide.sh: unique (SessionStart), complex (265 lines). Keep separate.

### Change 4: Short-circuit on block

When a PreToolUse hook returns exit 2 (block), subsequent PreToolUse hooks for the same event are unnecessary. dispatch.sh currently continues executing all hooks even after a block.

```bash
# After _rc check, add early termination for PreToolUse blocks:
if [ "$_rc" -eq 2 ]; then
    _exit_code=2
    case "$_event" in
        PreToolUse) break ;;  # no point running more hooks if already blocked
    esac
fi
```

**Expected impact**: When write-lock blocks a write, bash-guard doesn't run. Saves one subshell invocation per blocked write on Windows (~200ms). On Unix, saves ~50ms. Purely a performance optimization -- no behavioral change since blocked writes don't proceed regardless.

**Risk**: If a later hook has important side-effects (logging, tracking) that should run even on blocks, this would skip them. ✅ Verified: no current PreToolUse hook has side-effects that need to run after a block.

---

## What NOT to Change

1. **manifest.conf** -- The declarative format is clear, human-readable, and fast enough at current scale (~5ms parse). Adding conditional routing (phase-aware hooks) would add complexity that hooks already handle internally. Don't fix what isn't broken.

2. **Subshell isolation** -- Despite the performance cost, running hooks in subshells prevents one hook's crash from affecting others. This is especially important in bash where there's no exception handling. The performance cost should be reduced by having fewer subshells (Changes 3-4), not by removing isolation.

3. **run-hook.cmd** -- The polyglot wrapper is well-crafted and handles multiple Git Bash installation paths. The Windows performance overhead (~200ms) is Git Bash startup time, not run-hook.cmd overhead. No change to run-hook.cmd would meaningfully improve this.

4. **fail-open principle** -- Hooks should never break the IDE experience. This is a safety-critical design decision, not a convention to challenge.

5. **Test infrastructure** -- The existing test suites (test-phase-guide.sh, test-dispatch.sh, test-junction.sh) work. Changes 1-4 should be validated against existing tests, not by rewriting the test approach.

6. **Error handling granularity** -- Exit 0/2 + stderr text is the IDE protocol. Richer error reporting would require IDE-side changes. dispatch.sh's handling of unexpected exit codes (warning on non-0, non-2) is already good.

---

## Success Criteria

1. **Boilerplate reduction**: New hooks require < 15 lines of setup code (currently ~20-25 lines). Measured by line count of a new trivial hook.
2. **Context derivation count**: Plan discovery (resolve_plan_name + find_plan) executes at most once per dispatch cycle, not once per hook. Measurable by adding a counter or debug log.
3. **Windows latency**: A PreToolUse:Write dispatch cycle completes in < 600ms (currently ~400-600ms for write-lock alone, then additional hooks add more). Measurable with `time`.
4. **Backward compatibility**: All existing tests pass without modification after Changes 1-2. Tests may need minor updates for Change 3 (combined hooks).
5. **Standalone hook invocation**: Hooks can still be invoked directly (for testing) without dispatch.sh, by falling back to self-derivation when pre-derived env vars are absent.

---

## Comparison

| Dimension | Current | Proposed | Why |
|-----------|---------|----------|-----|
| Context derivation per dispatch | N times (once per hook) | 1 time (in dispatch.sh) | Root cause elimination |
| Boilerplate per hook | ~20 lines (trap, source, resolve, find) | ~5 lines (pure logic) | Centralized in runner |
| Subshell count for PostToolUse:Write | 2 (post-write-tracker + quality-gate) | 1 (combined) | Selective consolidation |
| Blocked PreToolUse dispatch | Runs all hooks, ignores results | Stops at first block | Short-circuit optimization |
| JSON parsing per dispatch | N times (per hook that needs it) | 1 time (in dispatch.sh) | Centralized pre-parse |
| manifest.conf format | Unchanged | Unchanged | Not the root cause |
| Test compatibility | Baseline | Must pass all existing tests | Non-negotiable |
| Windows worst-case latency | O(hook_count * 200ms) | O(hook_count * 200ms) but with fewer effective hooks | Subshell reduction |

---

## Implementation Sequencing

If this proposal is approved, recommended implementation order:

1. **Change 1** (pre-derive context) -- highest value, lowest risk. Can be done incrementally: add exports to dispatch.sh, then update hooks one at a time to use them.
2. **Change 4** (short-circuit on block) -- 3-line change in dispatch.sh, immediate performance benefit, zero risk to existing behavior.
3. **Change 2** (runner function) -- moderate value, needs careful testing to ensure trap behavior is preserved.
4. **Change 3** (combine hooks) -- lowest priority, highest risk of merge conflicts if hooks are being actively developed.

## 批注区
