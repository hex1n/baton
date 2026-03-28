# Improvement Proposal: Hook System Maintainability

**Depth**: Deep — "we've always done it this way" energy detected. The request frames a solution (rewrite to Python) as the problem (bash is hard to maintain). The assumption audit is the whole point.

**Input sources**: User request + codebase exploration of `.baton/hooks/`, `manifest.conf`, `tests/`, `.baton/adapters/`, `CLAUDE.md`.

---

## Phase 1: Problem Archaeology

### 1.1 — The Five Whys

```
Stated:  "We need to rewrite all bash hooks to Python"
Why?   → "Bash is too hard to maintain"
Why?   → (what specifically is hard to maintain?)
```

Full stop. The chain cannot continue without decomposing "hard to maintain" into concrete symptoms. "Bash is hard to maintain" is not a root problem — it is a judgment that presupposes the language is the cause. Before accepting it, we need to ask: **what specific maintenance activities are painful, and is bash actually the cause?**

Possible concrete symptoms (each would point to different solutions):

| Symptom | Would rewriting to Python fix it? |
|---------|----------------------------------|
| Hard to understand control flow in individual hooks | Partially — Python is more readable for complex logic, but the hooks are 45-264 lines each. At this size, readability is a function of code quality, not language. |
| Hard to add new hooks | No — the friction is in the manifest + dispatch + test wiring, not the language of the hook itself. |
| Hard to test | No — tests are shell-based (7034 lines across 18 files), and they test hook *behavior* via the dispatch system. Rewriting hooks to Python means rewriting or adapting all tests too, doubling the migration cost. |
| Cross-platform issues (Windows/Git Bash) | Partially — Python's cross-platform story is better, but baton already works on Windows via Git Bash, and Python would introduce a compiled runtime dependency. |
| String parsing / JSON handling is fragile | Yes — the jq-with-awk-fallback pattern in dispatch.sh and write-lock.sh is the single most maintenance-painful pattern in the codebase. But this can be fixed without leaving bash. |
| Hard to refactor shared logic | Partially — bash sourcing is less structured than Python imports. But `lib/common.sh` and `lib/plan-parser.sh` already provide shared functions (504 lines of library code). |

**Without knowing which symptom is dominant, "rewrite to Python" is a solution looking for a problem.** The five whys cannot reach a root cause from the stated request alone.

### 1.2 — Problem Statement

**Bad** (solution masquerading as problem): "We need to rewrite bash hooks to Python because bash is hard to maintain."

**Good** (outcome-focused, solution-free): "The hook system's maintenance cost is higher than it should be for its complexity. Adding new hooks, modifying existing ones, or debugging failures takes more effort than the logic warrants. Solved = a developer can add a new hook, modify an existing one, or trace a bug with confidence and minimal friction."

### Assumption Audit

#### 1.4 — Surface Assumptions

| # | Assumption | Type | If wrong... |
|---|-----------|------|-------------|
| 1 | Bash is the primary cause of maintenance difficulty | **unknown** — not decomposed into concrete symptoms | Plan collapses — if the pain is in architecture (dispatch, manifest, test wiring), Python doesn't help |
| 2 | Python is available on all target environments | **convention** — baton's design principle is "zero compiled dependencies" | Plan collapses — Python is a compiled runtime dependency; violates core project identity |
| 3 | The hooks are complex enough to benefit from Python's features | **fact, verifiable** — hooks range 45-264 lines | Plan weakens — at this scale, Python's advantages (typing, imports, OOP) provide marginal benefit |
| 4 | Rewriting is cheaper than improving the bash code | **unknown** — depends on rewrite scope | Plan collapses — 1,134 lines of hooks + 540 lines of lib + 7,034 lines of tests = ~8,700 lines to migrate |
| 5 | The test suite can be adapted to Python hooks | **convention** — tests assume bash dispatch | Plan cost explodes if tests must also be rewritten |
| 6 | "Hard to maintain" is about the hook scripts themselves | **unknown** — could be about dispatch architecture, test infrastructure, or documentation | Solution targets wrong layer if the pain is architectural |

#### 1.5 — True Constraints vs. Conventions

**True Constraints:**
- Hooks must integrate with Claude Code's hook protocol (stdin JSON, exit codes 0/2) — this is an external API contract
- Must work on both Unix and Windows (Git Bash) — existing user base depends on this
- Must be fast — hooks run on every tool invocation; latency directly impacts UX
- Hook dispatch model is event-based (SessionStart, PreToolUse, PostToolUse, etc.) — defined by Claude Code, not baton

**Conventions (candidates for questioning):**
- "Pure bash + markdown, zero compiled dependencies" — this is a *design choice*, not a law of physics. **However**, it is a *load-bearing* design choice: it means baton works everywhere bash exists with no install step. Dropping it is possible but carries real costs (dependency management, version conflicts, install complexity).
- jq-with-awk-fallback for JSON parsing — this is a maintenance-pain convention that could be improved *within* bash (e.g., require jq, or use a simpler parsing strategy).
- Each hook is a standalone script sourced by dispatch — could be restructured (e.g., single dispatch with inline logic, or a plugin registry).
- Tests are shell assertions — could use a test framework (bats-core) for better structure without leaving bash.

---

## Phase 2: Solution Reconstruction

Working with: root problem is "maintenance friction in the hook system," true constraints are the Claude Code hook protocol + cross-platform + performance + zero-install, and the key convention worth questioning is the code quality/structure *within* bash rather than the language choice.

### 2.1 — Solution Categories

#### Category A: Rewrite to Python (the stated request)

- **Mechanism**: Replace all .sh hook scripts with .py equivalents. Adapt dispatch.sh to call Python. Rewrite or adapt test suite.
- **Why it might be best**: Python has better string handling, native JSON (no jq dependency), proper import system, type hints, established testing frameworks (pytest). If hooks grow significantly more complex, Python's expressiveness pays off.
- **Why it might fail**: Introduces a compiled runtime dependency (violating core design principle). Python startup time is ~100ms vs. bash's ~5ms — multiplied across every tool invocation, this adds 0.5-1s latency to every edit/write operation. Requires rewriting ~8,700 lines (hooks + lib + tests). Creates two maintenance worlds during migration. Windows Python pathing is notoriously fragile.
- **Conventions challenged**: "Zero compiled dependencies." This is the big one.

#### Category B: Improve Bash Code Quality (targeted refactoring)

- **Mechanism**: Address the specific pain points *within* bash — require jq (dropping awk fallback), extract repeated patterns into lib functions, adopt bats-core for testing, add ShellCheck strict mode, improve documentation/comments.
- **Why it might be best**: Zero migration risk. Incremental. Preserves the zero-dependency property. The hooks are small enough (45-264 lines) that bash is not the bottleneck — code structure is.
- **Why it might fail**: Bash fundamentally lacks types, imports, and IDE support. If hooks need to become significantly more complex, bash's ceiling is lower than Python's.
- **Conventions challenged**: "jq is optional" (require it instead). "Tests use raw shell assertions" (adopt bats-core).

#### Category C: Hybrid — Bash Dispatch + Python Hooks (optional)

- **Mechanism**: Keep dispatch.sh and the manifest system in bash. Allow individual hooks to be written in *either* bash or Python. Dispatch already runs hooks in subshells — it could detect `.py` extension and call `python3` instead of sourcing.
- **Why it might be best**: Lets complex hooks (bash-guard, phase-guide, write-lock) migrate to Python while keeping simple hooks in bash. No big-bang rewrite. Gradual.
- **Why it might fail**: Two-language maintenance is worse than one. Need to ensure Python is available. Still has the startup-time cost for Python hooks.
- **Conventions challenged**: Language homogeneity.

### 2.2 — Inversion Test

**Category A (Python rewrite) — Pre-mortem:**
What would make this the worst possible approach? If the actual maintenance pain is in the *architecture* (dispatch system, manifest wiring, test infrastructure) rather than the *language*. Rewriting from bash to Python without changing the architecture just translates the same problems into a new syntax — with a massive migration cost and a new runtime dependency. **This is the most likely failure mode**, because the request didn't identify specific bash-language pain points.

**Category A — Opposite approach:**
The opposite is "double down on bash" — make the bash code excellent rather than replacing it. Merit: the hooks are small, the language is adequate for the task, and the zero-dependency property is genuinely valuable.

**Category B (Improve bash) — Pre-mortem:**
What would make this the worst possible approach? If the hooks need to become dramatically more complex (e.g., AST parsing, complex state machines, network calls). At that point, bash genuinely becomes the bottleneck. **However**, the current trajectory shows hooks staying in the 50-300 line range, doing text processing and JSON field extraction — bash's sweet spot.

### 2.3 — Recommendation

**Recommended: Category B — Improve Bash Code Quality.**

Reasoning chain:
1. **Root problem**: Maintenance friction in the hook system (Phase 1)
2. **True constraints satisfied**: Zero compiled dependencies preserved. Cross-platform preserved. Performance preserved. Claude Code protocol compatibility preserved.
3. **Convention broken**: Drop the "jq is optional" convention. Require jq. This eliminates the single most maintenance-painful pattern in the codebase (the jq-with-awk-fallback duplicated across dispatch.sh, write-lock.sh, bash-guard.sh).
4. **Primary risk**: If hooks grow dramatically in complexity, bash becomes a ceiling. **Mitigation**: The hooks have been stable at 45-264 lines for their entire history. If a hook needs to exceed ~500 lines, that specific hook can be evaluated for extraction — but that is a future decision, not today's.

### 2.4 — Dissenting Path

**Conditions that WOULD justify the Python rewrite:**
- If hooks need to grow to 500+ lines with complex state management
- If you plan to add hooks that do network calls, AST parsing, or complex data transformations
- If you are willing to add `python3` as an install prerequisite and accept the startup-time cost
- If the jq dependency is unacceptable (Python has native JSON) and awk fallback is the primary pain point but you want to go further than just requiring jq

**If you still want to proceed with the Python rewrite, here is the concrete plan:**

| # | Step | Effort | Risk |
|---|------|--------|------|
| 1 | Make dispatch.sh detect `.py` hooks and call `python3` | 2h | Low |
| 2 | Create a `hook_base.py` library with stdin parsing, exit code protocol, plan-parser equivalents | 1d | Med — must replicate plan-parser.sh's 441 lines of logic exactly |
| 3 | Port hooks one at a time, starting with simplest (quality-gate.sh, 45 lines) | 3d | Med — each port needs parallel testing |
| 4 | Port tests from shell assertions to pytest | 3-5d | High — 7,034 lines of test logic to migrate |
| 5 | Validate on Windows with Python + Git Bash | 1d | High — Python pathing on Windows is fragile |
| 6 | Remove bash hooks, update documentation | 0.5d | Low |
| **Total** | | **~2 weeks** | Full system risk during migration |

---

## Phase 3: Plan Synthesis (Category B — Improve Bash)

## Current State

The hook system consists of: ✅ verified by codebase exploration

- **Dispatcher**: `dispatch.sh` (64 lines) — reads `manifest.conf`, routes events to hook scripts
- **Manifest**: `manifest.conf` (12 lines) — event:matcher:script mapping
- **Hook scripts**: 11 scripts totaling 1,134 lines (range: 45-264 lines each)
- **Shared libraries**: `lib/common.sh` (63 lines), `lib/plan-parser.sh` (441 lines), `lib/junction.sh` (36 lines)
- **Tests**: 18 test files totaling 7,034 lines
- **Adapters**: 4 files for Cursor and Codex IDE integration
- **Linting**: ShellCheck in CI

The hooks are well-structured: each is a standalone script with fail-open semantics, clear version headers, and consistent patterns (stdin reading, jq-with-awk-fallback, exit code protocol).

## Root Cause of Suboptimality

The maintenance friction is not caused by bash-the-language. It is caused by:

1. **Duplicated JSON parsing pattern**: The jq-with-awk-fallback pattern is repeated in dispatch.sh, write-lock.sh, bash-guard.sh, and other hooks. Each instance is slightly different. This is the #1 maintenance pain point. ✅ verified — seen in dispatch.sh:26-30, write-lock.sh:35-45, bash-guard.sh:42-48
2. **No structured test framework**: Tests use raw shell assertions (`[ "$result" = "expected" ] && echo PASS || echo FAIL`). No setup/teardown, no test isolation, no failure context. This makes test authoring and debugging harder than it needs to be. ✅ verified — 7,034 lines of test code
3. **plan-parser.sh complexity**: At 441 lines, this is the largest shared library and the most complex piece of bash. It handles markdown parsing, write-set extraction, todo counting — tasks where bash's string handling is genuinely clunky. ✅ verified

## Hidden Assumptions in Current Approach

- "jq must be optional" — this forces every JSON access to have an awk fallback, doubling the parsing code. jq is available on virtually every modern system and is a single static binary (zero transitive dependencies). Requiring it eliminates the most painful pattern in the codebase.
- "Tests must be raw shell" — bats-core is a bash test framework that provides structured assertions, setup/teardown, and TAP output, while remaining pure bash.

## Proposed Changes

| Priority | Change | Why (traced to root cause) | Effort | Risk |
|----------|--------|--------------------------|--------|------|
| P1 | Require jq; remove all awk fallback code | Eliminates root cause #1 (duplicated parsing). Cuts ~30-50 lines of fragile awk across 4+ files. | 2h | Low — jq is already used as primary path; awk is fallback only |
| P1 | Extract JSON field access into `lib/json.sh` helper | Centralizes the remaining jq calls into one `json_field()` function, replacing 3-4 inline jq invocations per hook | 1h | Low |
| P2 | Add inline comments to plan-parser.sh's complex functions | Root cause #3 — the parser is the hardest-to-maintain piece. Better documentation reduces "WTF per minute" | 2h | None |
| P2 | Migrate test suite to bats-core | Root cause #2 — structured testing. Can be done incrementally (bats can coexist with raw shell tests). Provides `@test` blocks, `setup`/`teardown`, `run` helper, and failure diffs. | 1-2d | Low — incremental migration, old tests keep working |
| P3 | Add a `hook-scaffold.sh` generator script | Reduces friction of adding new hooks by generating boilerplate (fail-open trap, stdin reading, common.sh sourcing) | 2h | None |
| P3 | Add ShellCheck strict directives to hook headers | Catches more issues at lint time. Currently ShellCheck runs but without strict options. | 1h | None |

### P1 Detail: Require jq + Extract json.sh

**What specifically changes:**
- New file: `.baton/hooks/lib/json.sh` (~20 lines)
- Function: `json_field <json_string> <jq_filter>` — wraps jq with error handling
- Remove awk fallback blocks from: `dispatch.sh`, `write-lock.sh`, `bash-guard.sh`, and any other hook using the pattern
- Add jq check to `dispatch.sh` entry point (fail with clear message if jq missing)
- Update `CLAUDE.md` to list jq as a requirement

```bash
# lib/json.sh — centralized JSON field access
json_field() {
    local _json="$1" _filter="$2"
    printf '%s' "$_json" | jq -r "$_filter" 2>/dev/null
}

json_field_or_empty() {
    local _json="$1" _filter="$2"
    printf '%s' "$_json" | jq -r "$_filter // empty" 2>/dev/null
}
```

**Expected impact**: Eliminates ~40 lines of duplicated awk fallback code. Every future JSON access is a one-liner instead of a 6-line jq-then-awk block.

**Verification**: Run `bash tests/test-full.sh` — all existing tests pass. Run `shellcheck .baton/hooks/*.sh` — no new warnings.

### P2 Detail: bats-core Migration

**What specifically changes:**
- Add bats-core as a test dependency (single bash script, no compiled dependencies)
- Convert one test file (e.g., `test-dispatch.sh`, 210 lines) as a proof of concept
- Each test case becomes a `@test "description" { ... }` block with `run` and assertion helpers

**Expected impact**: Test authoring time decreases. Test failure output includes context (expected vs. actual). Setup/teardown eliminates repeated boilerplate.

**Verification**: Converted test file produces same pass/fail results as original.

## What NOT to Change

| Element | Why it should stay |
|---------|-------------------|
| **Bash as the hook language** | Hooks are 45-264 lines of text processing and JSON field extraction — bash's sweet spot. Zero-dependency property is a genuine competitive advantage. ✅ No hook has grown beyond bash's reasonable ceiling. |
| **dispatch.sh architecture** | Event-based dispatch with manifest routing is clean, extensible, and proven. The architecture is not the maintenance pain — the code patterns within it are. |
| **Fail-open semantics** | Every hook has `trap '...; exit 0' HUP INT TERM`. This is a critical safety property — hook crashes must never block the user. |
| **Shell-based test suite** (the tests themselves, not the framework) | The test logic is sound and comprehensive (7,034 lines). The issue is the *framework* (raw assertions), not the test *content*. bats-core wraps the same logic in better structure. |
| **Adapter system** | Cursor and Codex adapters translate between IDE-specific formats. These are thin and stable. |

## Success Criteria

1. A developer can add a new hook without copying a jq-with-awk-fallback block — `json_field()` is the only JSON access pattern
2. No awk fallback code remains in any hook script
3. All existing tests pass after changes
4. ShellCheck passes on all modified files
5. At least one test file migrated to bats-core as proof of concept

## Comparison

| Dimension | Current | Proposed (Cat B) | Python Rewrite (Cat A) |
|-----------|---------|-----------------|----------------------|
| Runtime dependencies | bash only (jq optional) | bash + jq (required) | bash + jq + python3 |
| JSON parsing | 6-line jq+awk blocks, duplicated | 1-line `json_field()` calls | Native `json.loads()` |
| Migration effort | n/a | 1-2 days | ~2 weeks |
| Migration risk | n/a | Low (incremental) | High (big-bang for tests) |
| Test framework | Raw shell assertions | bats-core (incremental) | pytest (full rewrite) |
| Hook startup time | ~5ms | ~5ms (unchanged) | ~100ms per Python hook |
| Lines of code changed | n/a | ~100 lines modified | ~8,700 lines rewritten |
| Future complexity ceiling | ~500 lines/hook | ~500 lines/hook | Effectively unlimited |
| Core identity preserved | Yes | Yes | No — "zero compiled deps" lost |

---

## Self-Check

1. **Did I question the problem, or just the solution?** Yes — Phase 1 spent the majority of effort decomposing "bash is hard to maintain" into concrete symptoms and finding that the language is not the root cause.
2. **Did I find conventions worth breaking?** Yes — "jq is optional" is a convention that directly causes the #1 maintenance pain point. Breaking it is the core of the recommendation.
3. **Am I recommending the first thing I thought of?** No — three fundamentally different categories were evaluated. The recommendation is specifically *not* what the user asked for.
4. **Can the user predict what will happen?** Yes — specific files, line counts, and code examples provided.
5. **Would I bet money on this?** Yes, with one caveat: if the user's actual pain is in plan-parser.sh specifically (the 441-line markdown parser), that single file might genuinely benefit from Python. But that would be "port one library" not "rewrite all hooks."

## 批注区
