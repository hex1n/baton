# Improvement Proposal: Hook Dispatch Architecture

**Depth**: Standard — multiple viable approaches exist, the system works but has real friction points, and the input document contains significant factual errors that need correction before any improvement direction can be trusted.

**Input sources**: input-doc.md (architecture analysis), codebase verification of all hooks, manifest, dispatch.sh, lib/, adapters/, and test files.

## TL;DR

The input document mischaracterizes the current architecture (wrong hook count, phantom scripts, missing the entire `lib/` shared layer). The **actual** root problem is not "flat manifest" or "no communication" — it's **duplicated boilerplate across hooks** (stdin parsing, plan discovery, fail-open traps) and **the growing weight of plan-parser.sh** (441 lines sourced by most hooks). The highest-value improvement is extracting the repeated hook preamble into a shared harness, not adding conditional routing or inter-hook communication that nothing currently needs.

## Proposed Changes

| Priority | Change | Why (traced to root cause) | Effort | Risk |
|----------|--------|--------------------------|--------|------|
| P1 | Extract shared hook preamble into `lib/hook-harness.sh` | 8 of 10 hooks repeat the same ~15 lines (fail-open trap, common.sh source, resolve_plan_name, find_plan, BATON_STDIN read). Reduces per-hook boilerplate from ~20 lines to ~2 lines. | 3-4h | Low — pure refactor, existing tests cover behavior |
| P2 | Extract stdin JSON field extraction into `lib/json.sh` | write-lock.sh, bash-guard.sh, post-write-tracker.sh, failure-tracker.sh all duplicate jq-with-awk-fallback parsing (~15 lines each). Single `json_field` function eliminates 4x duplication. | 2h | Low — deterministic extraction, easy to test |
| P3 | Consolidate `resolve_plan_name` / `find_plan` legacy shims | common.sh exists purely as a shim layer delegating to plan-parser.sh. The indirection (`hook → common.sh → plan-parser.sh`) adds cognitive load without value. Hooks should source plan-parser.sh directly via the harness. | 1h | Low — remove indirection, update 8 callers |
| P4 | Add `--dry-run` / `--list` mode to dispatch.sh | Testing difficulty is real (document issue #5), but the cause is not "IDE environment variables" — it's that dispatch.sh has no introspection mode. `dispatch.sh --list SessionStart` would print matched scripts without executing. | 1h | Very low — additive |

### P1 Detail: Hook Harness

**What specifically changes**: New file `.baton/hooks/lib/hook-harness.sh`

```bash
#!/usr/bin/env bash
# hook-harness.sh — shared preamble for baton hooks
# Usage (at top of any hook): . "$SCRIPT_DIR/lib/hook-harness.sh"

# Fail-open trap
trap 'echo "⚠️ BATON $(basename "$0"): unexpected error, allowing (fail-open)" >&2; exit 0' HUP INT TERM

# Emergency bypass
[ "${BATON_BYPASS:-}" = "1" ] && exit 0

# Source shared functions
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    . "$SCRIPT_DIR/lib/common.sh"
else
    echo "⚠️ BATON $(basename "$0"): common.sh not found, allowing (fail-open)" >&2
    exit 0
fi

# Plan discovery (most hooks need this)
resolve_plan_name
find_plan
```

**Expected impact**: Each hook drops from ~20 lines of preamble to `SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"; . "$SCRIPT_DIR/lib/hook-harness.sh"`. Net reduction: ~140 lines across 8 hooks. More importantly, the fail-open behavior becomes **guaranteed consistent** — today, 2 hooks (failure-tracker.sh, quality-gate.sh) have subtly different trap behavior.

**How to verify**: Run existing test suite (`bash tests/test-full.sh`). All 8 test files covering hooks should pass unchanged.

### P2 Detail: JSON Extraction Library

**What specifically changes**: New file `.baton/hooks/lib/json.sh`

```bash
# json_field INPUT FIELD — extract string field from JSON
json_field() {
    local _input="$1" _field="$2"
    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$_input" | jq -r ".$_field // empty" 2>/dev/null
    else
        printf '%s' "$_input" | awk -F'"' -v f="$_field" '{
            for(i=1;i<=NF;i++) if($i==f) { print $(i+2); exit }
        }'
    fi
}
```

**Expected impact**: Replaces 4 independent jq+awk implementations. The awk fallback pattern currently varies slightly between hooks (write-lock uses `head -1`, failure-tracker does not) — unification eliminates these subtle inconsistencies.

**How to verify**: Add `test-json-lib.sh` with unit tests for jq and non-jq paths. Existing hook tests cover integration.

## What NOT to Change

| Element | Why it should stay |
|---------|-------------------|
| **manifest.conf flat format** | The document claims this is a problem because it "doesn't support conditional routing." But the manifest already supports matcher-based routing (`event:matcher:script`), and no hook currently needs phase-conditional routing. Adding phase conditions would require dispatch.sh to discover the current phase (expensive — plan-parser sourcing + file I/O) on every single tool call, even when no hook needs that information. The flat format is a **feature**, not a limitation. ✅ verified: all 10 manifest entries use the existing format successfully. |
| **Hook isolation model (subshell execution)** | The document calls "no communication" a problem. But hooks are intentionally isolated — dispatch.sh runs each in a subshell (line 52: `( . "$_dir/$_script.sh" )`). This is a deliberate safety property: a crashing hook cannot corrupt another hook's state. The hooks that need shared state already get it through the environment (`BATON_STDIN`, `BATON_PROJECT_DIR`) and shared library sourcing, which is sufficient. No current hook needs to pass state to a sibling hook. |
| **run-hook.cmd polyglot wrapper** | The document calls this "unnecessary complexity." It's 46 lines, it works, and it solves a real problem (Windows IDE pre-tool hooks can't invoke bash directly). The polyglot design (works as both .cmd and .sh) is elegant and zero-maintenance. ✅ verified: correctly delegates to dispatch.sh on both platforms. |
| **Exit code protocol (0=allow, 2=block)** | The document wants "structured error information." But the exit code protocol is dictated by the IDE hook API (Claude Code's hook spec), not by baton. Changing it would break IDE compatibility. The current approach — structured messages on stderr, exit code for control flow — is the correct design. |

## Comparison

| Dimension | Current | Proposed | Why |
|-----------|---------|----------|-----|
| Per-hook boilerplate | ~20 lines repeated in 8 hooks | ~2 lines (source harness) | DRY; consistent fail-open guarantee |
| JSON parsing implementations | 4 independent copies with subtle variations | 1 shared function | Eliminates inconsistency bugs |
| Plan discovery indirection | hook → common.sh → plan-parser.sh | hook → harness → plan-parser.sh (common.sh retained for back-compat but thinner) | Clearer dependency chain |
| Test introspection | Must mock full environment | `dispatch.sh --list` for mapping verification | Faster test development |
| Manifest format | Flat, matcher-based | **Unchanged** | Already sufficient; phase-routing would add cost with no current consumer |
| Hook isolation | Subshell per hook | **Unchanged** | Safety property worth preserving |

## Self-Check

1. **Did I question the problem, or just the solution?**
   Yes. The input document defined 5 problems. After codebase verification, I found that 3 of 5 are either factually wrong (prompt-guard.sh doesn't exist; hook count is wrong) or misidentified (manifest already supports conditional routing via matchers). The real problem — repeated boilerplate and inconsistent patterns across hooks — was not in the document at all. The document was solving phantom problems.

2. **Did I find any conventions worth breaking?**
   Yes: the convention that each hook script is fully self-contained with its own preamble. This made sense when there were 3 hooks; with 10, it creates maintenance burden and inconsistency. A shared harness breaks this convention deliberately.

3. **Am I recommending the first thing I thought of?**
   No. I initially considered the document's suggestion of adding inter-hook communication and conditional routing. After verifying the codebase, neither has a current consumer. The boilerplate problem emerged from reading the actual hook code, not from the document.

4. **Can the user predict what will happen from reading this plan?**
   Yes. P1 creates one new file and modifies 8 existing hooks (removing their preambles). P2 creates one new file and modifies 4 hooks (replacing inline JSON parsing). P3 thins common.sh. P4 adds a flag to dispatch.sh. Each change has a concrete mechanism and verification method.

5. **Would I bet money on this?**
   On P1-P2: yes, high confidence — pure refactoring with strong test coverage. On P3: moderate confidence — the legacy shim removal is straightforward but needs careful grep for any external callers of `resolve_plan_name` or `find_plan` (adapters, CLI). Weakest link: if any external tool sources common.sh directly and depends on the current function signatures, P3 could break it. Mitigation: keep the shim functions but have them emit a deprecation warning.

---

## Analysis (supporting reasoning)

### Current State (verified)

The input document contains **significant factual errors**. Here is the verified current state:

**Hook scripts** (10, not 5 as document claims): ✅ verified via filesystem
- `write-lock.sh` — PreToolUse gate for file writes (172 lines)
- `bash-guard.sh` — PreToolUse gate for shell write commands (165 lines)
- `phase-guide.sh` — SessionStart phase detection and guidance (265 lines)
- `stop-guard.sh` — Stop event advisory (53 lines)
- `completion-check.sh` — TaskCompleted retrospective enforcement (77 lines)
- `subagent-context.sh` — SubagentStart plan context injection (51 lines)
- `post-write-tracker.sh` — PostToolUse write-set drift detection (117 lines)
- `quality-gate.sh` — PostToolUse self-challenge check (46 lines)
- `failure-tracker.sh` — PostToolUseFailure cumulative counter (64 lines)
- `pre-compact.sh` — PreCompact context preservation (70 lines)

**No `prompt-guard.sh` exists** — the document lists it as a hook. ❓ Possibly confused with `bash-guard.sh`.

**manifest.conf has 10 mappings, not 8**: ✅ verified by reading the file. The format already supports matcher-based conditional routing (`event:matcher:script`), contradicting the document's claim #1 that it's "flat with no conditional routing."

**Shared library layer** (`lib/` directory, not mentioned in document at all): ✅ verified
- `common.sh` (64 lines) — legacy shim delegating to plan-parser.sh
- `plan-parser.sh` (441 lines) — plan discovery, section parsing, write-set extraction
- `junction.sh` (37 lines) — cross-platform directory linking

**Adapter layer** (`adapters/` directory, not mentioned in document): ✅ verified
- `cursor/adapter.sh` + `cursor/dispatch.sh` — Cursor JSON response protocol
- `codex/adapter.sh` + `codex/dispatch.sh` — Codex rules-based adapter

### Root Cause

The document's stated problems are largely misdiagnosed. The actual friction in the dispatch architecture comes from **organic growth without refactoring**:

1. When baton had 3 hooks, each hook being self-contained was fine. At 10 hooks, the repeated preamble (fail-open trap, stdin buffering, plan discovery) is ~140 lines of duplicated code with **subtle inconsistencies** (e.g., failure-tracker.sh has no BATON_BYPASS check but most others do; quality-gate.sh has a minimal trap compared to other hooks).

2. JSON field extraction was written independently 4 times because no shared utility existed when the first hooks were created. Each copy works but has minor implementation differences (some use `head -1`, some don't; field name patterns vary).

3. The `common.sh` → `plan-parser.sh` indirection exists for backward compatibility from a migration, but adds cognitive overhead when reading any hook.

**Why the document's proposed problems are wrong:**

- "Flat manifest" (issue #1): The manifest already has conditional routing via matchers. What would "phase-conditional routing" even mean? dispatch.sh would need to determine the current phase on every tool call — sourcing plan-parser.sh, reading the plan file, checking for BATON:GO, counting todos — just to decide whether to run a hook. This would add ~200ms to every tool invocation on Windows for a feature no hook currently needs.

- "No hook communication" (issue #2): Hooks communicate through the environment and shared library state. The isolation is intentional — if write-lock.sh crashes, bash-guard.sh still runs. No hook currently needs to read another hook's output from the same dispatch cycle.

- "Coarse error handling" (issue #3): The exit code protocol (0/2) is the IDE hook API contract. baton cannot change it. Structured errors go to stderr, which is the correct channel — the IDE surfaces stderr to the user.

### Assumption Audit

| # | Assumption | Type | If wrong... |
|---|-----------|------|-------------|
| 1 | No hook currently needs phase-conditional routing | fact (✅ verified: read all 10 hooks) | P1/P2 would still be valuable, but manifest format might need extending |
| 2 | The fail-open trap inconsistencies are bugs, not intentional variation | convention (❓ could be deliberate per-hook policy) | P1 harness would need per-hook trap override capability |
| 3 | External tools don't source common.sh directly | unknown (❓ haven't checked all Claude Code/Cursor integration paths) | P3 common.sh thinning could break external callers |
| 4 | Plan-parser.sh sourcing cost is acceptable at current size (441 lines) | fact (✅ manifest parsing is ~5ms per document; plan-parser is bash source, not execution) | If parser grows further, lazy-loading individual primitives would become P1 |
| 5 | Windows performance (~200ms per dispatch) is acceptable | convention (user hasn't complained, but it's 4x Unix) | Optimizing dispatch.sh to avoid sourcing plan-parser.sh when no hook needs it would become P1 |

### Solution Reconstruction

**Category A: Shared harness (recommended)**
- Mechanism: Extract common preamble into a single sourced file. Each hook becomes a focused handler.
- Why best: Directly addresses the root cause (duplicated boilerplate). Low risk, high certainty, existing tests validate behavior.
- Why might fail: If hooks need divergent preamble behavior (e.g., different trap policies), the harness becomes leaky.
- Conventions challenged: "Each hook is self-contained." This was valuable at 3 hooks; at 10, it's a maintenance hazard.

**Category B: Event bus / middleware pipeline**
- Mechanism: Replace dispatch.sh with a pipeline where hooks can register middleware (pre/post processing), share context objects, and compose.
- Why might be best: If hook count grows to 20+ or hooks need cross-cutting concerns (logging, metrics).
- Why it fails here: Massively over-engineered for 10 bash scripts in a pure-bash project. The "zero compiled dependencies" constraint means implementing this in bash, which would be painful and slow.
- Conventions challenged: "Pure bash, zero dependencies."

**Category C: Document's suggestions (conditional routing + inter-hook communication)**
- Mechanism: Extend manifest.conf with phase conditions; add shared state file for hook communication.
- Why might be best: If future hooks need phase-aware behavior or need to react to each other's output.
- Why it fails here: No current hook needs either feature. Adding them would slow down dispatch (phase detection on every call) and add complexity (state file lifecycle management) with zero current value. This is speculative architecture driven by a document that doesn't accurately describe the system.

**Inversion test for Category A:**
- Worst case: The harness becomes a "god object" that every hook depends on, making it hard to change without breaking everything. Mitigation: keep the harness minimal (~15 lines) and let hooks opt out of specific steps.
- Opposite approach: Make hooks even MORE self-contained (copy-paste all of plan-parser.sh into each hook). This has zero merit at 10 hooks.
- Fail-value: If the harness doesn't work, we learn that hooks genuinely need divergent initialization, which would inform a different abstraction.

## 批注区
