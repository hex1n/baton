# Improvement Proposal: Hook System Maintainability

**Depth**: Deep (solution-as-problem detected; assumption audit critical)
**Input sources**: User conversation + full codebase read (all 14 hook scripts, 3 shared libraries, manifest.conf, 18 test files, constitution.md, CLAUDE.md)

---

## Current State

The baton hook system is ~800 lines of bash across 14 scripts, with 3 shared library files and 18 shell-based test files. It provides governance enforcement (write locks, plan gates, scope boundaries, phase guidance) for AI coding assistants across Unix and Windows.

The system is architecturally clean: `dispatch.sh` (64 lines) reads `manifest.conf` (10 lines, declarative) and routes events to hook scripts that share `common.sh` / `plan-parser.sh` / `junction.sh`. Each hook follows a consistent pattern: fail-open trap, source common.sh, resolve plan, check conditions, exit 0 or 2.

The project's stated core principle is "Pure bash + markdown. Zero compiled dependencies." (✅ verified in CLAUDE.md). jq is optional with awk fallbacks throughout.

## Root Cause of Suboptimality

**The request "rewrite to Python" is a solution masquerading as a problem.**

The stated problem — "bash is too hard to maintain" — is insufficiently specific to guide a solution. "Too hard to maintain" could mean:

| Possible root cause | Right solution | Wrong solution |
|---------------------|----------------|----------------|
| Bash syntax is unreadable to maintainer | Language change (but must satisfy constraints) | Refactoring within bash |
| Control flow across dispatch/manifest/hooks is confusing | Architecture documentation or restructuring | Language change (same architecture in Python = same confusion) |
| JSON parsing code is ugly and duplicated | Centralize in common.sh (30-minute fix) | Full rewrite |
| Testing is slow on Windows | Improve test harness | Language change (doesn't fix test speed) |
| Error handling is fragile | Standardize patterns within bash | Language change |
| Adding new hooks requires too much boilerplate | Hook template/generator | Language change |

**Without identifying which of these is the actual friction, any solution is speculative.** A Python rewrite would cost weeks, introduce regression risk in governance-critical code, violate the zero-dependency principle, and might not solve the actual problem.

## Hidden Assumptions in Current Approach (the rewrite request)

| # | Assumption | Status | Impact if wrong |
|---|-----------|--------|-----------------|
| 1 | The problem is the language, not the architecture | ❓ unverified | Rewrite reproduces the same problem in Python |
| 2 | Python is available on all target platforms | ❓ unverified | Breaks Windows users without Python installed |
| 3 | "Zero compiled dependencies" can be relaxed | ❓ contradicts stated principle | Changes project identity and distribution model |
| 4 | Rewriting 800 lines + 18 test files is worth the cost | ❓ unverified | Weeks of effort for marginal improvement |
| 5 | Accumulated edge-case handling (CRLF, cygpath, fail-open, subshell isolation) transfers cleanly | ❓ unverified | Governance bugs during transition |

## Proposed Changes

### Step 0: Identify the actual pain points (BLOCKING — do this before anything else)

Before committing to ANY solution, answer these questions:
1. Which specific hook script was hardest to modify last time, and why?
2. When reading hook code, what causes confusion — syntax? control flow? implicit state?
3. Has a bash-specific bug caused a governance failure? Which one?
4. Is the pain about READING existing code or WRITING new code?

**Expected impact**: Determines whether the solution is a language change, architecture improvement, or targeted refactoring. Prevents weeks of wasted effort on the wrong fix.
**Risk**: None. This is information gathering.

### Step 1: Centralize JSON parsing (high-probability quick win)

Six hooks currently contain duplicated jq-with-awk-fallback blocks for extracting `tool_name`, `file_path`, `command`, `cwd`, and `session_id` from stdin JSON. This IS a legitimate maintainability issue (✅ verified).

**Change**: Add `parser_json_field()` to `common.sh` that encapsulates the jq-primary/awk-fallback pattern. Replace all 6 inline parsing blocks with single function calls.

**Expected impact**: ~60 lines of duplicated code removed. New hooks get JSON parsing for free. Single point to fix if JSON format changes.
**Risk**: Low — the logic is identical across hooks; centralizing is mechanical.

### Step 2: Add hook development guide

Create a hook authoring reference that documents:
- The dispatch flow (event → manifest → hook → library)
- Required patterns (fail-open trap, common.sh sourcing, exit codes)
- How to add a new hook (manifest line + script + test)
- Edge cases to handle (CRLF, Windows paths, missing jq)

**Expected impact**: Reduces cognitive load for hook modification. Makes the architecture explicit rather than implicit.
**Risk**: Documentation can drift. Mitigate by keeping it next to the code it describes.

### Step 3: Evaluate remaining pain points (from Step 0 findings)

Based on what Step 0 reveals:
- If syntax readability is the core issue → evaluate whether ShellCheck + better variable naming + inline comments close the gap, or whether a language change is truly needed
- If test speed is the issue → investigate parallel test execution or test-harness optimization (separate from language choice)
- If boilerplate is the issue → create a hook template generator

### Step 4 (conditional): If language change IS justified after Steps 0-3

Only if Steps 0-3 confirm that the problem is genuinely the language AND cannot be solved within bash:
1. Explicitly decide to relax "zero compiled dependencies" (record as BATON:OVERRIDE with reason)
2. Validate Python availability on all target platforms
3. Rewrite ONE hook as a pilot (e.g., `quality-gate.sh` — simplest, advisory-only, 45 lines)
4. Run it in parallel with the bash version for one release cycle
5. Measure: is the Python version actually easier to maintain? Quantify how.
6. Only proceed to full migration if the pilot demonstrates clear improvement

## What NOT to Change

1. **dispatch.sh** — 64 lines, stable, well-tested, rarely modified. Does not benefit from rewriting.
2. **manifest.conf** — declarative format, language-agnostic. Keep as-is.
3. **junction.sh** — platform-specific logic that's the same complexity in any language.
4. **The test suite** — 18 files of accumulated edge-case knowledge. Any rewrite must preserve test coverage, not start over.
5. **The fail-open/fail-closed design pattern** — this is an architectural decision, not a language artifact.

## Success Criteria

1. The specific maintainability pain point is identified and articulated (not "bash is hard" but "X specific thing about bash causes Y specific problem")
2. The identified pain point is addressed by the chosen solution
3. Governance reliability is preserved (zero regression in hook behavior)
4. The zero-dependency principle is either preserved OR explicitly overridden with documented justification
5. New hooks can be added with less friction than before (measured by: fewer files to copy-paste from, less boilerplate, clearer patterns)

## Comparison

| Dimension | Current (bash) | Full Python rewrite | Targeted bash refactoring (recommended) |
|-----------|---------------|--------------------|-----------------------------------------|
| Dependencies | Zero | Python runtime required | Zero |
| Cross-platform | Proven (Unix + Windows Git Bash) | ❓ Python availability varies | Proven |
| Effort | n/a | Weeks (800 LOC + 18 test files) | Hours to days |
| Regression risk | n/a | High (governance-critical code) | Low (incremental) |
| Edge-case knowledge | Preserved | Must be manually re-discovered | Preserved |
| JSON parsing | Duplicated across 6 hooks | Native (json module) | Centralized in common.sh |
| Solves unidentified problem | n/a | ❓ Maybe, maybe not | Addresses identified pain points |
| Project identity | Preserved | Changed ("pure bash" no longer true) | Preserved |

## Key Insight

**The most important finding is that "rewrite to Python" is the second-most-expensive possible response to an undiagnosed problem.** The request presupposes both the diagnosis (bash is the problem) and the treatment (Python is the cure) without evidence for either. The highest-value first step is spending 15 minutes identifying what specifically is hard — which may reveal that the fix is a 30-minute refactoring, not a multi-week rewrite.

## 批注区


