# Plan: Rewrite Bash Hooks to Python

## Recommendation: Do Not Proceed

### The Request Contradicts a Core Design Principle

Baton's architecture is explicitly built on "pure bash + markdown, zero compiled dependencies." This is not an incidental choice — it is a load-bearing design decision documented in CLAUDE.md and reflected throughout the entire system. Rewriting to Python would:

1. **Introduce a compiled dependency.** Python is not guaranteed on all target environments. Windows machines may have Python 3.11 or 3.8 or none. Git Bash ships zero Python. This breaks the "zero compiled dependencies" invariant that currently makes baton trivially portable.

2. **Not solve the stated problem.** "Bash is hard to maintain" is true in general, but baton's bash is not general-purpose bash — it is 1,896 lines across 14 files, each following a rigid pattern (fail-open trap, source common.sh, parse JSON input, check plan state, emit stderr/exit code). The actual complexity lives in the governance logic (plan discovery, write-set enforcement, phase detection), which would be equally complex in Python.

3. **Require rewriting 7,034 lines of shell tests.** The test suite is bash-native, testing bash scripts by invoking them directly, mocking stdin JSON, checking exit codes. A Python rewrite would require either (a) rewriting all tests in pytest (massive effort, no governance value), or (b) keeping shell tests that invoke Python scripts (awkward, two-language test infrastructure).

4. **Break the Windows integration path.** `run-hook.cmd` is a polyglot that finds Git Bash and invokes `dispatch.sh`. With Python, you'd need to find Python instead — which is a harder problem (py launcher, python3 vs python, virtualenv, PATH discovery). The current approach works because Git Bash is a near-universal constant on Windows developer machines (it ships with Git for Windows).

---

## If You Still Want to Proceed: The Least-Bad Approach

Despite the above, here is how I would plan it if the decision is made to proceed regardless.

### Approach: Incremental Migration via Polyglot Dispatch

Keep `dispatch.sh` and `run-hook.cmd` as the entry points. Rewrite individual hook scripts to Python one at a time. The dispatcher invokes `.py` files the same way it invokes `.sh` files — just change the subshell line.

#### Phase 0: Prerequisites & Infrastructure (1-2 days)

**Objective:** Establish the Python hook runtime without breaking anything.

1. **Define Python version floor.** Minimum Python 3.8 (oldest non-EOL at time of writing; Windows 10 ships with py launcher). Document this in CLAUDE.md.

2. **Create `lib/hook_common.py`** — Python equivalent of `common.sh` + `plan-parser.sh`:
   - `parse_stdin_json()` — read `BATON_STDIN` env or stdin, extract `tool_name`, `tool_input.file_path`, `cwd`
   - `find_plan()` — walk-up plan discovery (replicate `parser_find_plan` logic)
   - `find_research()` — paired research discovery
   - `has_go()` — BATON:GO marker check
   - `project_root()` — marker-based root detection
   - `todo_counts()` / `todo_items()` — section parsing
   - `writeset_extract()` / `writeset_normalize()` — write-set enforcement
   - `emit_block(msg)` — print to stderr + `sys.exit(2)`
   - `emit_warn(msg)` — print to stderr + `sys.exit(0)`
   - `emit_context_json(data)` — output hookSpecificOutput JSON to stdout

   **Write set:** `.baton/hooks/lib/hook_common.py`

3. **Modify `dispatch.sh`** to support `.py` scripts:
   - When `manifest.conf` references a script name, try `$_dir/$_script.py` first, fall back to `$_dir/$_script.sh`
   - Python invocation: `python3 "$_dir/$_script.py"` (or `python` on Windows)
   - Pass `BATON_STDIN` and `BATON_PROJECT_DIR` as env vars (already exported)
   - Exit code contract: 0 = allow, 2 = block (same as bash)

   **Write set:** `.baton/hooks/dispatch.sh`

4. **Update `run-hook.cmd`** to verify Python availability (advisory warning if missing, not blocking — fall back to bash version of hook).

   **Write set:** `.baton/hooks/run-hook.cmd`

5. **Create `tests/test-python-hooks.py`** — pytest-based test infrastructure:
   - Helper to invoke hooks via subprocess with mocked stdin JSON
   - Assert exit codes, stderr content, stdout JSON
   - Mirror the assertion patterns from the bash test suite

   **Write set:** `tests/test-python-hooks.py`, `tests/conftest.py`

#### Phase 1: Low-Risk Advisory Hooks (2-3 days)

Rewrite hooks that **cannot block** (always exit 0). If the Python version fails, nothing breaks.

**Migration order** (by risk, lowest first):

| # | Hook | Lines | Risk | Reason |
|---|------|-------|------|--------|
| 1 | `quality-gate.sh` | 45 | Minimal | PostToolUse advisory, simplest logic |
| 2 | `failure-tracker.sh` | 63 | Minimal | PostToolUseFailure advisory, temp file counter |
| 3 | `post-write-tracker.sh` | 116 | Low | PostToolUse advisory, write-set check |
| 4 | `pre-compact.sh` | 69 | Low | PreCompact advisory, plan summary |
| 5 | `subagent-context.sh` | 50 | Low | SubagentStart advisory, plan injection |
| 6 | `stop-guard.sh` | 52 | Low | Stop advisory, progress reminder |

For each hook:
1. Write Python version (`.py` alongside `.sh`)
2. Add pytest tests mirroring the bash test assertions
3. Run both bash and Python tests to confirm parity
4. Remove `.sh` version only after full test parity confirmed

**Write set per hook:** `.baton/hooks/<name>.py`, `tests/test-<name>.py`

#### Phase 2: Blocking Hooks (3-5 days)

These hooks can **block operations** (exit 2). Bugs here stop the developer from writing code. Higher risk requires more careful testing.

| # | Hook | Lines | Risk | Reason |
|---|------|-------|------|--------|
| 7 | `completion-check.sh` | 76 | Medium | TaskCompleted blocker, retro validation |
| 8 | `bash-guard.sh` | 164 | High | PreToolUse(Bash) blocker, quote-stripping parser, regex patterns |
| 9 | `write-lock.sh` | 171 | High | PreToolUse(Edit/Write) blocker, core governance gate |

`bash-guard.sh` deserves special attention: its `strip_quoted_segments` function is a character-by-character state machine for shell quote parsing. Python's string handling makes this cleaner, but the regex patterns for detecting shell writes (`heredoc with redirect`, `output redirection`, `tee`, `sed -i`) need exact parity testing.

`write-lock.sh` is the most critical hook — it enforces the plan gate. Any regression here silently allows unauthorized writes or silently blocks authorized ones.

**Write set per hook:** `.baton/hooks/<name>.py`, `tests/test-<name>.py`

#### Phase 3: Orchestration & Discovery (2-3 days)

| # | Component | Lines | Risk | Reason |
|---|-----------|-------|------|--------|
| 10 | `lib/plan-parser.sh` | 441 | High | Core discovery engine, used by all hooks |
| 11 | `lib/common.sh` | 63 | Medium | Legacy wrapper layer |
| 12 | `phase-guide.sh` | 264 | High | SessionStart orchestrator, skill scanning, phase detection |

`plan-parser.sh` is the foundation — every other hook depends on it. Rewriting it to Python means all hooks must use the Python version. This is the point of no return for the migration.

`phase-guide.sh` has the most complex logic: directory scanning, skill detection, state machine with 6+ states, JSON escaping for governance context injection, and junction creation via `junction.sh`. The junction logic (`atomic_junction`) uses platform-specific commands (`cmd /c mklink /J`, `ln -sf`, `cp -r`) that would need Python equivalents (`os.symlink`, `_winapi.CreateJunction` or subprocess).

**Write set:** `.baton/hooks/lib/hook_common.py` (consolidate parser), `.baton/hooks/phase-guide.py`

#### Phase 4: Adapters & Entry Points (1-2 days)

| # | Component | Lines | Risk |
|---|-----------|-------|------|
| 13 | `adapters/cursor/adapter.sh` | 36 | Low |
| 14 | `adapters/cursor/dispatch.sh` | 33 | Low |
| 15 | `adapters/codex/adapter.sh` | 62 | Low |
| 16 | `adapters/codex/dispatch.sh` | 34 | Low |
| 17 | `lib/junction.sh` | 36 | Medium |

Adapters translate between IDE-specific formats and baton's hook protocol. They are thin wrappers. `junction.sh` uses OS-level commands and may benefit most from Python's `os` module.

**Write set:** `.baton/adapters/cursor/*.py`, `.baton/adapters/codex/*.py`, `.baton/hooks/lib/junction.py`

#### Phase 5: Test Suite Migration & Cleanup (3-5 days)

1. Port remaining bash test assertions to pytest (7,034 lines)
2. Ensure CI runs pytest alongside or instead of bash tests
3. Remove all `.sh` hook files once Python versions have full test coverage
4. Update `setup.sh` to check for Python availability during install
5. Update CLAUDE.md to reflect new dependency and architecture
6. Update ShellCheck CI targets (remove hook .sh files, keep setup.sh)

**Write set:** `tests/test-*.py`, `setup.sh`, `CLAUDE.md`, CI config

### Total Estimated Effort

| Phase | Effort | Risk |
|-------|--------|------|
| Phase 0: Infrastructure | 1-2 days | Low |
| Phase 1: Advisory hooks (6 hooks) | 2-3 days | Low |
| Phase 2: Blocking hooks (3 hooks) | 3-5 days | High |
| Phase 3: Orchestration (3 components) | 2-3 days | High |
| Phase 4: Adapters (5 components) | 1-2 days | Medium |
| Phase 5: Tests & cleanup | 3-5 days | Medium |
| **Total** | **12-20 days** | |

### Key Risks

1. **Python availability on Windows.** The py launcher (`py -3`) is installed with Python from python.org but not from Windows Store. Git Bash does not include Python. You would need to add Python discovery logic to `run-hook.cmd` that is at least as complex as the current bash discovery logic.

2. **Behavioral parity.** Bash and Python handle edge cases differently (empty strings, glob expansion, path separators, exit code propagation in subshells). Each hook's Python version must match the bash version's behavior exactly across all edge cases — the 7,034 lines of tests exist precisely because these edge cases matter.

3. **Atomic migration of plan-parser.** Once `plan-parser.sh` is rewritten to Python, every hook must use the Python version. You cannot have some hooks using the bash parser and others using the Python parser — they must agree on plan discovery, write-set extraction, and todo counting. This creates a hard cutover point.

4. **Two-language maintenance window.** During incremental migration, you maintain both bash and Python versions. Any governance logic change must be applied to both. This doubles maintenance burden for weeks.

---

## Alternative: Improve Bash Maintainability Without Rewriting

If the root problem is "bash is hard to maintain," consider these lower-cost alternatives:

1. **Consolidate `plan-parser.sh`.** The 441-line parser could be simplified. Several functions share walk-up logic that could be factored into a single `_walk_up` helper.

2. **Add ShellCheck strictness.** Enable more ShellCheck warnings (SC2086, SC2155) to catch common bash pitfalls.

3. **Improve test readability.** The bash test files use a hand-rolled assertion framework. Adding named test functions and a summary reporter would improve maintainability.

4. **Document the patterns.** Each hook follows the same structure (fail-open trap, source common, parse JSON, check state, emit result). A contributor guide documenting this pattern would reduce the "hard to maintain" perception.

Estimated effort: 2-3 days. Zero risk of regression. No new dependency.

## Self-Challenge

- **Is "bash is hard to maintain" actually the bottleneck?** The hook system has been stable — most changes are governance logic changes, not bash infrastructure changes. Python would not reduce the complexity of governance logic.
- **Am I biased toward the status quo?** Possibly. But the evidence is concrete: zero compiled dependencies is documented as a core principle, and the migration cost (12-20 days) far exceeds the maintenance cost of the existing 1,896 lines of structured bash.
- **What if the codebase grows 10x?** If baton's hook system grew to 20,000 lines, the Python argument becomes much stronger. But current trajectory suggests the hook system is stabilizing, not growing.

## 批注区
