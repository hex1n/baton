# Improvement Proposal: Hook System Maintainability

**Depth**: Deep — "We've always done it this way" energy detected. The request to rewrite to Python carries an implicit assumption that bash is the root cause of maintainability problems. That assumption needs interrogation before committing to a language migration.

**Input sources**: Full codebase read of all 11 hook scripts, 3 library files, 2 adapters, manifest.conf, dispatch.sh, run-hook.cmd, setup.sh, 18 test files. Conversation context for stated motivation.

---

## TL;DR

The stated problem is "bash is hard to maintain." The root problem is different: **the hook system's maintainability friction comes from structural issues (duplicated boilerplate, implicit conventions, no type safety on interfaces) — not from the language itself.** Rewriting to Python would solve some of these issues but would break a core design constraint (zero compiled dependencies) and introduce a new dependency that doesn't exist on all target platforms without configuration. The recommended approach is to improve bash maintainability through targeted refactoring — extracting the repeated ~15-line boilerplate into shared initialization, formalizing the hook interface contract, and adding a hook scaffolding tool. If maintainability remains insufficient after that, a Python rewrite becomes justified — and the refactored architecture makes migration easier.

## Proposed Changes

| Priority | Change | Why (traced to root cause) | Effort | Risk |
|----------|--------|--------------------------|--------|------|
| P1 | Extract shared hook boilerplate into `lib/hook-init.sh` | Every hook repeats the same 10-15 lines: fail-open trap, BATON_BYPASS check, SCRIPT_DIR resolution, common.sh sourcing, resolve_plan_name, find_plan. This duplication is the #1 maintainability drag. | 2-3h | Low — mechanical extraction, high test coverage exists |
| P2 | Formalize hook interface contract in `lib/hook-contract.md` | Hook inputs (BATON_STDIN, BATON_TARGET, JSON_CWD) and outputs (exit codes, stderr messages, stdout JSON) are implicit conventions learned by reading dispatch.sh. A formal spec reduces the cost of writing new hooks from "study 3 existing hooks" to "read the contract." | 1-2h | Low — documentation, no code change |
| P3 | Extract JSON field access into `lib/json.sh` | jq-with-awk-fallback pattern is duplicated across write-lock.sh, bash-guard.sh, post-write-tracker.sh, failure-tracker.sh, dispatch.sh (5 files). Each reimplements the same logic slightly differently. | 2-3h | Low — consolidation with existing fallback pattern |
| P4 | Add `baton hook new <name> <event>` scaffolding command | New hooks require: (1) script with correct boilerplate, (2) manifest.conf line, (3) IDE registration. Missing any step causes silent failure. A generator eliminates this error class entirely. | 3-4h | Low — additive, no existing code changes |
| P5 | Add ShellCheck enforcement to CI with strict mode | Some hooks use patterns ShellCheck flags (unquoted variables, missing local declarations). Catching these mechanically prevents the class of "bash is error-prone" bugs. | 1h | Low — CI already uses ShellCheck, just needs stricter config |

For each P1-P3 change:

### P1: Shared hook initialization

**Mechanism**: Create `lib/hook-init.sh` that every hook sources as its first line after the shebang. It handles:
- Fail-open trap
- BATON_BYPASS early exit
- SCRIPT_DIR resolution
- common.sh sourcing (which chains to plan-parser.sh)
- STDIN buffering (from BATON_STDIN or raw stdin)
- resolve_plan_name + find_plan

**Before** (every hook, ~15 lines each):
```bash
trap 'echo "..." >&2; exit 0' HUP INT TERM
if [ "${BATON_BYPASS:-}" = "1" ]; then exit 0; fi
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    . "$SCRIPT_DIR/lib/common.sh"
else
    exit 0
fi
resolve_plan_name
find_plan
```

**After** (one line):
```bash
. "$(cd "$(dirname "$0")" 2>/dev/null && pwd)/lib/hook-init.sh"
```

**Expected impact**: Eliminates ~120 lines of duplicated boilerplate across 9 hooks. New hooks go from "copy-paste from existing hook and modify" to "source hook-init, write your logic."

**Verification**: Run full test suite (`bash tests/test-full.sh`). All 18 test files exercise hooks through dispatch.sh, so regressions surface immediately.

### P2: Hook interface contract

**Mechanism**: Document in `lib/hook-contract.md`:
- Input contract: what env vars are set by dispatch.sh (BATON_STDIN, BATON_PROJECT_DIR, event name, args), what JSON fields are available (tool_name, tool_input, cwd, session_id)
- Output contract: exit codes (0=allow, 2=block, other=error logged), stderr (messages to AI), stdout (hookSpecificOutput JSON)
- Lifecycle: subshell isolation, stdin buffering, matcher filtering

**Expected impact**: Reduces time-to-write-new-hook from ~1 hour of studying dispatch.sh + existing hooks to ~15 minutes of reading the contract.

**Verification**: Cross-reference contract against dispatch.sh and all existing hooks. Run existing tests to confirm no behavioral change.

### P3: Consolidated JSON access

**Mechanism**: Create `lib/json.sh` with functions:
- `json_get <field_path>` — extracts a field from BATON_STDIN (jq with awk fallback)
- `json_get_input <field>` — shorthand for `.tool_input.<field>`

**Before** (duplicated in 5 files):
```bash
if command -v jq >/dev/null 2>&1; then
    TARGET="$(printf '%s' "$STDIN" | jq -r '.tool_input.file_path // empty')"
else
    TARGET="$(printf '%s' "$STDIN" | awk -F'"' '{ for(i=1;i<=NF;i++) if($i=="file_path") print $(i+2) }' | head -1)"
fi
```

**After**:
```bash
TARGET="$(json_get_input file_path)"
```

**Expected impact**: Eliminates ~60 lines of duplicated JSON parsing. Fixes the subtle inconsistency where different hooks handle the jq/awk fallback slightly differently (some use `2>/dev/null`, some don't; some use `head -1`, some don't).

**Verification**: Run full test suite. Specifically `test-write-lock.sh`, `test-bash-guard.sh`, `test-dispatch.sh` exercise JSON parsing paths.

## What NOT to Change

| Element | Why it should stay |
|---------|-------------------|
| **Bash as the hook language** | Bash is the only language guaranteed present on all three target platforms (Linux, macOS, Windows via Git Bash) with zero installation. Python requires ensuring `python3` is available and on PATH — a real friction point on Windows where Python may not be installed, or may be the Microsoft Store stub. The current hooks total ~1,100 lines of bash — this is not a scale where language choice dominates maintainability. |
| **dispatch.sh architecture** | The event dispatcher + manifest.conf + subshell isolation pattern is clean, well-tested (17 assertions), and does exactly one thing well. It's 64 lines. Rewriting this gains nothing. |
| **plan-parser.sh as a shared library** | At 441 lines, this is the largest single file and the most parser-like code. It's also the best candidate for Python rewrite IF a language migration were justified. But it's well-tested (1,105 assertion lines in test-plan-parser.sh), stable, and its awk-based parsing is actually well-suited to the line-oriented markdown format. |
| **jq-optional design** | The awk fallback for JSON parsing exists because jq is the only optional dependency. Removing this fallback (by requiring Python) trades one optional dependency for one mandatory dependency — net negative for the "zero dependencies" principle. |
| **run-hook.cmd polyglot wrapper** | This 45-line file is the Windows bridge. It's inherently a batch/bash polyglot — Python can't replace it because the problem it solves (finding bash on Windows) requires batch script execution by cmd.exe before any interpreter is available. |

## Comparison

| Dimension | Current (bash) | Proposed (bash refactored) | Alternative (Python rewrite) |
|-----------|---------------|---------------------------|------------------------------|
| Dependencies | Zero (jq optional) | Zero (jq optional) | Python 3.x required on all platforms |
| Total hook code | ~1,100 lines | ~850 lines (-23%) | ~600 lines (-45%) but +Python runtime |
| New hook effort | ~1 hour (study + copy-paste) | ~15 min (read contract + scaffold) | ~15 min (read contract + scaffold) |
| Windows compat | Native via Git Bash | Same | Requires Python install verification |
| Test suite | 7,034 lines, all bash | Same, no rewrite needed | Full rewrite of 7,034 lines of tests |
| CI (ShellCheck) | Works | Works, stricter | Replaced by pylint/mypy — new toolchain |
| Cross-platform stdin | Buffered in dispatch.sh | Same | Python handles natively (minor win) |
| JSON parsing | jq + awk fallback | Consolidated, same approach | `json` stdlib (real win for complex JSON) |
| Risk | Known, stable | Low — mechanical refactor | High — full rewrite of tested system |

## Dissenting Path: If You Still Want Python

Conditions that **would** justify a Python rewrite:

1. **Hook complexity grows significantly** — if hooks start needing complex data structures (nested dicts, sets, queues), structured error handling (try/except), or HTTP calls, bash becomes genuinely painful. The current hooks are simple enough that bash works.
2. **New hooks need to call external APIs** — if governance hooks need to call LLM APIs, GitHub APIs, or databases, Python is clearly better. Bash's `curl` + `jq` pipeline becomes unmaintainable for anything beyond simple GETs.
3. **The test suite needs rethinking anyway** — the 7,034 lines of bash tests are the largest rewrite cost. If the test suite is already being overhauled, the marginal cost of Python conversion drops significantly.
4. **Python is guaranteed on all target platforms** — if baton drops Windows support, or if a Python prerequisite becomes acceptable, the dependency argument dissolves.

**Concrete "if you proceed" plan:**

| Step | Action | Effort | Dependency |
|------|--------|--------|------------|
| 1 | Add `python3` availability check to setup.sh, with clear error message | 1h | None |
| 2 | Rewrite `lib/plan-parser.sh` (441 lines) as `lib/plan_parser.py` | 4-6h | Step 1 |
| 3 | Create `lib/hook_base.py` — shared hook class with init, JSON parsing, plan access | 2-3h | Step 2 |
| 4 | Rewrite dispatch.sh as `dispatch.py` — preserve manifest.conf format, subprocess isolation | 3-4h | Step 3 |
| 5 | Port hooks one-by-one (write-lock, bash-guard, phase-guide first) | 6-8h | Step 4 |
| 6 | Update run-hook.cmd to find python3 instead of bash | 1h | Step 5 |
| 7 | Port test suite (7,034 lines) to pytest | 10-15h | Step 5 |
| 8 | Update CI: replace ShellCheck with pylint/mypy | 2h | Step 7 |
| **Total** | | **25-40h** | |

Note: Steps 2-5 require maintaining bash/Python dual-mode during migration (both must work). This doubles the testing surface temporarily. The "zero compiled dependencies" principle in CLAUDE.md would need an explicit exception or rewrite.

## Self-Check

1. **Did I question the problem, or just the solution?**
   Yes. The stated request was "rewrite to Python." I traced the actual pain — duplicated boilerplate, implicit interfaces, copy-paste-driven hook creation — and found that these are structural problems solvable in any language, including the current one. The root cause is not "bash" but "no abstraction layer between dispatch.sh and individual hooks."

2. **Did I find any conventions worth breaking?**
   Yes. The convention that each hook manages its own initialization (trap, bypass check, sourcing, plan discovery) is the main maintainability drag. Breaking this convention — by extracting it into a shared `hook-init.sh` — eliminates the #1 source of duplication without changing the language. I also identified that the jq/awk dual-path JSON parsing is duplicated 5 times with subtle inconsistencies — consolidating it breaks the "each hook is self-contained" convention, but that convention creates more bugs than it prevents.

3. **Am I recommending the first thing I thought of?**
   No. My first instinct was to assess whether Python was genuinely better. After reading all 11 hooks and 3 library files, I realized the hooks are simple enough (most are under 70 lines) that language choice is secondary to structural organization. The Python rewrite would be a real improvement for `plan-parser.sh` (441 lines of awk-heavy parsing), but the cost-benefit doesn't extend to the other hooks.

4. **Can the user predict what will happen from reading this plan?**
   Yes. P1 creates `lib/hook-init.sh` and modifies 9 hook scripts to source it. P2 creates `lib/hook-contract.md`. P3 creates `lib/json.sh` and modifies 5 files. P4 adds a CLI subcommand. P5 updates CI config. Each step is independently deployable and testable.

5. **Would I bet money on this?**
   On the recommendation (refactor > rewrite): yes, high confidence. The ~1,100 lines of hook code is simply not large enough for language choice to be the dominant maintainability factor. The weakest link is P1's execution — the shared initialization must handle the subtle differences between hooks (some don't need find_plan, quality-gate.sh uses BATON_TARGET differently). The `hook-init.sh` may need optional parameters or early-exit hooks to accommodate these differences without becoming a new source of complexity.

---

## Analysis (supporting reasoning)

### Current State (verified)

The hook system consists of: ✅ verified by reading all files

- **dispatch.sh** (64 lines): Event router. Reads manifest.conf, buffers stdin, extracts tool_name, runs matching hooks in subshells. Clean, well-isolated.
- **manifest.conf** (10 lines): Event-to-script mapping with optional tool matchers. Simple, effective format.
- **11 hook scripts** (~1,100 lines total):
  - write-lock.sh (171 lines) — PreToolUse gate: blocks source writes without BATON:GO
  - phase-guide.sh (264 lines) — SessionStart: phase detection + guidance output
  - bash-guard.sh (164 lines) — PreToolUse(Bash): blocks shell writes when gate closed
  - post-write-tracker.sh (116 lines) — PostToolUse: warns on out-of-write-set modifications
  - completion-check.sh (76 lines) — TaskCompleted: enforces retrospective before completion
  - failure-tracker.sh (63 lines) — PostToolUseFailure: session failure counter
  - pre-compact.sh (69 lines) — PreCompact: preserves context before compression
  - stop-guard.sh (52 lines) — Stop: reminds about incomplete tasks
  - subagent-context.sh (50 lines) — SubagentStart: injects plan context
  - quality-gate.sh (45 lines) — PostToolUse: checks for self-challenge sections
  - run-hook.cmd (45 lines) — Windows polyglot batch/bash bridge
- **3 library files** (540 lines total):
  - plan-parser.sh (441 lines) — Discovery + parsing primitives (awk-heavy)
  - common.sh (63 lines) — Legacy wrappers + test command resolution
  - junction.sh (36 lines) — Cross-platform directory linking
- **2 IDE adapters** (165 lines total):
  - Cursor adapter (69 lines) — Translates to Cursor JSON protocol
  - Codex adapter (96 lines) — Translates to Codex stdout protocol
- **18 test files** (7,034 lines total) — All bash, exercising hooks through dispatch.sh
- **setup.sh** (683 lines) — Installation script

### Root Cause

The maintainability complaints trace to three specific structural issues, not to bash-the-language:

**1. Boilerplate duplication (~120 lines across 9 hooks)** ✅ verified by diff

Every hook that needs plan access repeats the same initialization sequence:
```
trap → bypass check → SCRIPT_DIR → source common.sh → resolve_plan_name → find_plan
```
This is 10-15 lines per hook, repeated 9 times. When the initialization pattern changes (e.g., adding BATON_PROJECT_DIR export), every hook must be updated. This is the primary source of "bash is hard to maintain" — but the duplication would exist in Python too without a base class.

**2. Implicit interface contract** ✅ verified by reading dispatch.sh

Hooks communicate through a mix of environment variables (BATON_STDIN, BATON_PROJECT_DIR, BATON_TARGET), exit codes (0, 2), stderr (messages), and stdout (JSON). This contract is not documented anywhere — it's learned by reading dispatch.sh and existing hooks. This means writing a new hook requires studying the dispatcher and at least 2-3 existing hooks to understand the protocol.

**3. Duplicated JSON parsing (~60 lines across 5 files)** ✅ verified

The jq-with-awk-fallback pattern appears in: dispatch.sh, write-lock.sh, bash-guard.sh, post-write-tracker.sh, failure-tracker.sh. Each implementation is slightly different (different error handling, different field paths). A single consolidated function would eliminate the duplication and the subtle inconsistencies.

### Assumption Audit

| # | Assumption | Type | If wrong... |
|---|-----------|------|-------------|
| 1 | "Bash is the root cause of maintainability problems" | Convention (challenged) | Plan collapses — if bash IS the root cause (e.g., because of undebuggable failures in production), then refactoring bash doesn't solve the problem. ✅ Evidence suggests structural issues dominate: the largest file (plan-parser.sh, 441 lines) is stable and well-tested; the maintainability pain is in the duplicated boilerplate and implicit contracts, which are language-independent. |
| 2 | "Python is available on all target platforms" | Unknown — needs verification | Plan collapses for Python path. ❓ Windows machines may have Python installed, or may have the Microsoft Store stub that launches the Store instead of running Python. Git Bash is guaranteed on Windows (it's required for git), Python is not. |
| 3 | "The hook system will grow significantly in complexity" | Unknown | If yes: Python becomes more justified over time. If no: bash refactoring is sufficient. Current trajectory: 2 new hooks added in recent months (failure-tracker, pre-compact), both simple (<70 lines). Growth rate doesn't suggest imminent complexity explosion. |
| 4 | "Zero compiled dependencies is a true constraint, not a convention" | Fact (stated in CLAUDE.md) | If this is actually a convention that can be relaxed, Python becomes viable. But it's written in the project's core design principles file, which suggests it's load-bearing. ✅ CLAUDE.md states: "Pure bash + markdown. Zero compiled dependencies. jq optional." |
| 5 | "Test suite rewrite cost is prohibitive" | Fact (7,034 lines) | If tests are easy to port (e.g., via a bash-to-pytest transpiler or because test structure is simple), the cost argument weakens. ✅ Tests use a custom assertion framework (assert_eq, assert_contains, etc.) with setup/teardown per test. Porting is mechanical but voluminous — 25-40 hours is a realistic estimate. |

**True Constraints:**
- Must work on Linux, macOS, Windows (via Git Bash) — ✅ stated in CLAUDE.md
- Zero compiled dependencies — ✅ stated in CLAUDE.md as design principle
- Hook execution model: dispatch.sh runs hooks in subshells, reads exit codes — ✅ this is the architectural contract with Claude Code / Cursor / Codex
- Hooks must be fast (run on every tool use) — ✅ latency-sensitive path

**Conventions (challengeable):**
- Each hook manages its own initialization → **worth breaking** (P1)
- Each hook implements its own JSON parsing → **worth breaking** (P3)
- Hooks are self-contained files → partially worth breaking (shared init is fine; hooks should still be readable as standalone units)
- "Zero dependencies" includes Python → this is the key question. If Python is reclassified as acceptable (like jq is "optional"), the rewrite path opens up. But Python is a much heavier dependency than jq.

### Solution Reconstruction

**Category A: Bash refactoring (recommended)**
- Mechanism: Extract duplication, formalize contracts, add tooling
- Why best: Lowest risk, preserves all existing constraints, addresses root cause (structure, not language), enables future migration if needed
- Why might fail: If the real pain is bash's lack of type safety, debuggability, or IDE support — structural improvements don't fix those
- Conventions challenged: "each hook is self-contained"

**Category B: Full Python rewrite (user's stated approach)**
- Mechanism: Rewrite all hooks, dispatcher, parser, adapters, and tests in Python
- Why best: Real type safety, better error handling, stdlib JSON, easier debugging, broader contributor pool
- Why might fail: Breaks zero-dependency constraint, ~30h effort for a system that works and is well-tested, Python availability on Windows is not guaranteed, test suite rewrite is the largest cost
- Conventions challenged: "zero compiled dependencies"

**Category C: Hybrid — Python parser, bash hooks**
- Mechanism: Rewrite plan-parser.sh (the most complex, most awk-heavy file) in Python, keep hooks in bash but have them call the Python parser
- Why best: Targets the file where Python's advantages are largest (complex string parsing) while keeping hooks in bash (where they're simple enough)
- Why might fail: Two languages = two toolchains, two CI configs, two mental models. The integration point (bash calling Python) adds latency and error modes. Worst of both worlds if not carefully scoped.
- Conventions challenged: partial break of zero-dependency

**Inversion test for Category A (recommended):**
- What would make this the worst approach? If the team grows and new contributors refuse to write bash. If hooks need to make HTTP calls or handle complex data structures. If bash-specific bugs (word splitting, quoting) cause production incidents that Python would prevent.
- Opposite approach (full rewrite): Has merit if the project is about to undergo major architectural changes anyway — a rewrite during a larger refactor has lower marginal cost.
- If this approach fails: We learn that structural improvements are insufficient and language-level issues (debugging, type safety) are the actual bottleneck. The refactored architecture (shared init, formal contracts) makes a subsequent Python migration easier.

## 批注区
