# First-Principles Planner Transcript

**Request**: "我们需要把所有 bash hooks 重写成 Python，因为 bash 太难维护了。请规划一下最佳方案。"
**Translation**: "We need to rewrite all bash hooks into Python because bash is too hard to maintain. Please plan the best approach."
**Depth**: **Deep** — "We've always done it this way" energy detected in reverse: the request presupposes a specific solution (Python rewrite) to a vaguely stated problem ("bash is too hard to maintain"). Assumption audit is critical.
**Input sources**: Conversation context + full codebase read of all hook scripts, shared libraries, manifest, tests, constitution, and CLAUDE.md.

---

## Phase 0: Input Synthesis

**What the user stated**:
- All bash hooks should be rewritten in Python
- The reason given is that bash is "too hard to maintain"
- They want a plan for the best approach

**What I observe from the codebase** (✅ verified by reading every file):
- The hook system consists of 11 bash scripts: `dispatch.sh` (dispatcher), plus 10 hook scripts (`write-lock.sh`, `phase-guide.sh`, `bash-guard.sh`, `quality-gate.sh`, `stop-guard.sh`, `post-write-tracker.sh`, `completion-check.sh`, `failure-tracker.sh`, `pre-compact.sh`, `subagent-context.sh`)
- Shared library: 3 files in `lib/` (`common.sh`, `plan-parser.sh`, `junction.sh`)
- `manifest.conf` maps events to scripts
- Total: ~14 shell scripts, roughly 700-800 lines of bash
- The project's stated core principle is "Pure bash + markdown. Zero compiled dependencies." (✅ CLAUDE.md line)
- jq is optional — every hook has an awk fallback for JSON parsing
- Tests are all shell-based: 18 test files, hundreds of assertions
- The system runs on both Unix and Windows (via Git Bash), with NTFS junction support and `run-hook.cmd` for Windows IDE integration
- The constitution explicitly prohibits introducing compiled dependencies

**Constraints mentioned**:
- Cross-platform: Unix + Windows (Git Bash)
- Zero compiled dependencies (project design principle)
- Junction-based distribution model

**What's not stated but implied**:
- The user finds bash syntax hard to read or debug
- The user may have hit specific pain points (string manipulation? error handling? testing?)
- "Python" is presented as the obvious solution, but the actual problem is unspecified beyond "too hard to maintain"

> **Key question for the user**: The request says "bash is too hard to maintain" — but what specifically is hard? Is it reading the code? Debugging failures? Adding new hooks? Testing? Understanding the control flow? The answer determines whether Python is the right solution, or whether something else would solve the actual pain with less cost.

**For this exercise, I will proceed through the full analysis without user confirmation, since this is an evaluation run.**

---

## Phase 1: Problem Archaeology

### 1.1 — The Five Whys

```
Stated: "We need to rewrite all bash hooks into Python"
         ↑ This is a SOLUTION, not a problem.

What's the problem?
→ "Bash is too hard to maintain"

Why is bash hard to maintain?
→ Possible reasons (unspecified — each leads to different solutions):
  a) Bash syntax is arcane (string manipulation, quoting, arrays)
  b) Error handling is fragile (set -e gotchas, subshell exit codes)
  c) Testing is slow and painful (15s per assertion on Windows)
  d) No type safety or IDE support (no autocomplete, no linting beyond shellcheck)
  e) Control flow is hard to follow across dispatch → manifest → hook → lib
  f) Cross-platform edge cases (CRLF, path separators, cygpath)

Why does maintainability matter?
→ Because hooks are governance-critical: they enforce write locks, plan gates,
  scope boundaries. A bug in a hook can either block all work (fail-closed
  crash) or silently allow unauthorized writes (fail-open bug).

Root: The real problem is GOVERNANCE RELIABILITY — the hook system is
safety-critical infrastructure, and the current implementation has
characteristics that make it harder to verify correctness than desired.
```

### 1.2 — Problem Statement

**Solution masquerading as problem**: "Rewrite hooks to Python" is a specific mechanism, not a problem description. The problem it's trying to solve is never stated precisely.

**Actual problem statement (reconstructed)**:
The baton hook system is safety-critical governance infrastructure (~800 lines across 14 scripts). Maintaining correctness and extending it carries friction from [unspecified source]. The consequence is [unspecified]: slower development? More bugs? Reluctance to modify hooks? The desired outcome is: hooks that are easier to [read / debug / test / extend] without sacrificing the project's zero-dependency, cross-platform design constraints.

**What "solved" looks like (outcome-focused, mechanism-free)**:
- New hooks can be added with less friction
- Existing hooks can be modified with higher confidence in correctness
- The root causes of maintainability pain are addressed
- Governance reliability is preserved or improved

---

## Phase 2: Assumption Audit

### 2.1 — Surface Assumptions

| # | Assumption | Source | Type |
|---|-----------|--------|------|
| 1 | Python is the right replacement language | Stated by user | **convention** |
| 2 | The problem is the language (bash), not the architecture | Implied by user | **unknown** |
| 3 | Rewriting will improve maintainability | Implied by user | **unknown** |
| 4 | "Zero compiled dependencies" can be relaxed | Implied by user (Python is a compiled dependency) | **contradicts stated project principle** |
| 5 | Python is available on all target platforms | Inferred | **unknown** — ❓ Windows Git Bash environments don't always have Python |
| 6 | Rewriting 800 lines of bash + 18 test files is worth the cost | Inferred | **unknown** |
| 7 | The test infrastructure (shell assertions) would also need rewriting | Inferred | **fact** — tests call hooks directly via bash |
| 8 | The junction/distribution model works the same with Python | Inferred | **unknown** — Python files need an interpreter path; shebangs differ across platforms |
| 9 | The hooks' JSON parsing (jq with awk fallback) is a maintainability pain point | Inferred | **unknown** |
| 10 | Bash is inherently hard to maintain for this use case | Stated by user | **convention** — depends on what's actually hard |

### 2.2 — Challenge Each One

**Assumption 1: Python is the right replacement language**
- Convention, not fact. Python is one option. Others: keep bash but restructure; use a shell-compatible scripting language (e.g., dash-compatible POSIX sh); use a single compiled binary (Go/Rust) distributed as a tool.
- What if wrong: choosing the wrong language adds a dependency without solving the problem.
- Evidence: none provided. ❓

**Assumption 2: The problem is the language, not the architecture**
- This is the most dangerous assumption. The hook architecture is actually well-structured: dispatch.sh is 64 lines, manifest.conf is declarative, hooks share a common library. If the pain is "I can't follow the control flow," that's architecture, not language — and rewriting in Python with the same architecture produces the same problem.
- What if wrong: you spend months rewriting and the maintainability pain persists because it was architectural.
- Evidence: ❓ — need to know specifically what's hard.

**Assumption 3: Rewriting will improve maintainability**
- Rewrites are among the riskiest engineering decisions. Joel Spolsky's "Things You Should Never Do, Part I" applies. The existing code is battle-tested, handles edge cases (CRLF stripping, fail-open traps, cygpath normalization), and has 18 test files validating behavior.
- A rewrite discards all accumulated edge-case knowledge and starts the bug-discovery cycle over.
- What if wrong: you introduce new bugs in governance-critical code.
- Evidence: ❓ — depends entirely on what specific problems exist.

**Assumption 4: "Zero compiled dependencies" can be relaxed**
- This is a **stated core design principle** of the project (✅ CLAUDE.md: "Pure bash + markdown. Zero compiled dependencies."). Python is a compiled dependency — it requires a Python interpreter.
- Relaxing this changes the project's identity and distribution model.
- Load-bearing: if this assumption is wrong, Python is ruled out entirely.
- Evidence: the user has not explicitly said they want to change this principle.

**Assumption 5: Python is available everywhere**
- ❓ Not guaranteed. Windows machines may have Git Bash but not Python. CI environments vary. The current system works with only bash (universally available).
- What if wrong: adds an installation prerequisite that didn't exist before.

**Assumption 6: The cost is worth it**
- ~800 lines of bash + 18 test files + Windows hook integration (`run-hook.cmd`) + junction distribution would all need rewriting.
- Estimated effort: weeks of work for a solo maintainer, plus regression risk.
- What if wrong: massive effort spent, governance gaps during transition, for marginal improvement.

**Assumption 9: JSON parsing is a pain point**
- Every hook that reads stdin has a jq-primary / awk-fallback pattern. This IS verbose and repeated across hooks. But it's also isolated in a few functions.
- ✅ Verified: 6 hooks contain JSON parsing logic. `common.sh` doesn't centralize it yet.
- This might be a legitimate friction point — but can be solved by refactoring within bash (centralize JSON field extraction in common.sh) without rewriting everything.

### 2.3 — True Constraints vs Conventions

**True Constraints** (cannot change within scope):
1. Hooks must run on Unix AND Windows (Git Bash) — cross-platform is non-negotiable
2. Hooks fire from IDE tool-use events — the integration points are fixed
3. Hooks are governance-critical — correctness failures have real consequences (unauthorized writes, or blocking all work)
4. The existing 18 test files represent accumulated edge-case knowledge
5. Junction-based distribution requires hooks to be self-contained (no package manager install step)

**Conventions** (could be changed):
1. "Must be bash" — could use another language IF it satisfies constraints 1-5
2. "Zero compiled dependencies" — this is a project design choice, not a law of physics. But changing it requires explicit decision and has cascade effects.
3. "jq with awk fallback" pattern — could be centralized or replaced
4. "Each hook is a separate .sh file" — could be restructured
5. "Tests use shell assertions" — could use a different test framework

---

## Phase 3: Solution Reconstruction

Working with:
- Root problem: governance-critical hook code has maintainability friction (specific source unknown)
- True constraints: cross-platform, correctness-critical, self-contained distribution, accumulated edge-case knowledge must be preserved
- Key convention worth questioning: the scattered JSON parsing pattern and lack of centralized utilities

### 3.1 — Solution Categories

#### Category A: Full Python Rewrite (the stated request)

**Mechanism**: Rewrite all 14 shell scripts and 18 test files in Python. Add Python as a project dependency.
**Why it might be best**: Python has better string handling, native JSON support, type hints, richer testing frameworks, better IDE support.
**Why it might fail**:
- Violates "zero compiled dependencies" principle without explicit override
- Python availability is not guaranteed on all target platforms
- Discards accumulated edge-case handling (CRLF, cygpath, fail-open traps, subshell isolation)
- Rewrite risk: governance gaps during transition
- Estimated cost: weeks of work for a solo maintainer
- Windows IDE hook integration (`run-hook.cmd`) would need reworking
- Does not necessarily solve the actual problem if the problem is architectural, not syntactic
**Which conventions it challenges**: zero-dependency principle, bash-native identity

#### Category B: Targeted Bash Refactoring (address root causes without rewriting)

**Mechanism**: Identify the specific maintainability pain points and fix them within bash. Likely candidates:
1. Centralize JSON parsing in `common.sh` (eliminate 6 duplicated jq/awk blocks)
2. Add inline documentation and architecture comments
3. Standardize error handling patterns
4. Extract shared patterns into library functions
5. Improve test harness (reduce per-assertion overhead on Windows)
**Why it might be best**: Preserves all accumulated knowledge, zero risk to governance, stays within project principles, can be done incrementally.
**Why it might fail**: If the problem truly IS the language (e.g., "I can't read bash syntax at all"), refactoring doesn't help.
**Which conventions it challenges**: none — this is evolutionary improvement.

#### Category C: Hybrid — Bash Dispatch + Python Logic

**Mechanism**: Keep `dispatch.sh` and `manifest.conf` in bash (they're thin and stable). Rewrite individual hook logic in Python, called from thin bash wrappers.
**Why it might be best**: Gets Python benefits for complex logic while preserving the distribution model and dispatch architecture.
**Why it might fail**: Two languages means two sets of knowledge. The bash wrappers still need maintenance. Python availability issue remains. Adds complexity rather than removing it.
**Which conventions it challenges**: zero-dependency principle (partially).

#### Category D: Single Compiled Binary (Go/Rust)

**Mechanism**: Compile all hook logic into a single binary (`baton-hooks`). Dispatch calls the binary with the event name. Distribute the binary alongside the project.
**Why it might be best**: True zero-runtime-dependency (static binary). Fast. Type safe. Single file to distribute.
**Why it might fail**: Massive increase in project complexity. Requires a build step. Cross-compilation needed. Completely changes project identity. Overkill for ~800 lines of logic.
**Which conventions it challenges**: everything about the project's current identity.

### 3.2 — Inversion Test

**Category A (Python Rewrite) — Pre-mortem**:
- Worst case: 3 weeks of rewrite effort, governance bugs in production during transition, Python not available on a user's Windows machine, and the maintainability pain persists because it was actually about architecture (control flow across dispatch/manifest/hooks) which is identical in Python.
- Opposite approach: don't rewrite at all, just improve documentation. Merit: zero risk, forces articulation of what's actually confusing.
- Fail-value: if the rewrite fails, you learn that the problem wasn't the language.

**Category B (Targeted Refactoring) — Pre-mortem**:
- Worst case: you spend time refactoring and the user still finds bash fundamentally unreadable. The effort improves structure but doesn't solve the subjective readability problem.
- Opposite approach: full rewrite. Merit: clean slate, modern language features.
- Fail-value: if refactoring doesn't help, you've confirmed the problem IS the language, and can rewrite with better understanding of what matters.

### 3.3 — Recommendation with Reasoning

**Recommended approach: Category B (Targeted Bash Refactoring) as the default path, with an explicit problem-identification step first.**

**Reasoning chain**:
1. **Root problem trace (Phase 1)**: The stated problem is "bash is too hard to maintain" but the specific friction source is unidentified. Without knowing what's actually hard, any solution is speculative.
2. **True constraint satisfaction (Phase 2)**: Category B satisfies all true constraints — cross-platform, correctness-critical, self-contained, preserves edge-case knowledge. Category A violates the zero-dependency principle and introduces regression risk.
3. **Convention challenge (Phase 2)**: The duplicated JSON parsing pattern across 6 hooks is a legitimate maintainability issue that can be solved without rewriting. This is the most likely "low-hanging fruit."
4. **Primary risk**: The user might genuinely find bash syntax unreadable regardless of refactoring. Mitigation: the first step is to identify the SPECIFIC pain points before committing to any solution.

**Critical insight**: "Rewrite to Python" is the second-most-expensive possible response to an undiagnosed problem. Before any execution, the user needs to articulate what specifically is hard about maintaining the bash hooks. The answer determines the solution:
- "I can't read bash syntax" → consider language change (but validate Python satisfies all constraints first)
- "I can't follow the control flow" → architecture improvement, not language change
- "JSON parsing is ugly" → centralize it (30-minute fix)
- "Testing is slow" → improve test harness (different problem entirely)
- "Error handling is fragile" → standardize patterns (bash-internal fix)

---

## Phase 4: Plan Synthesis (Mode B — Improvement Proposal)

See `plan.md` for the final output.

---

## Self-Check

1. **Did I question the problem, or just the solution?** Yes — Phase 1 identified that "rewrite to Python" is a solution masquerading as a problem, and the actual root problem ("bash is too hard to maintain") needs decomposition before any solution is valid.

2. **Did I find conventions worth breaking?** Yes — the duplicated JSON parsing pattern is a real maintainability issue. The "zero compiled dependencies" principle was identified as a convention that COULD be broken but SHOULDN'T be without explicit decision and specific justification.

3. **Am I recommending the first thing I thought of?** No — four fundamentally different approaches were compared. The recommendation (targeted refactoring) emerged from constraint analysis, not initial intuition.

4. **Can the user predict what will happen from reading the plan?** Yes — the plan specifies concrete steps with success criteria.

5. **Would I bet money on this?** Yes on the process (identify pain points first, then fix). The specific fixes depend on what pain points emerge, but the highest-probability candidate (JSON parsing centralization) is a safe, high-value improvement.
