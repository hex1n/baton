# Improvement Proposal: Hook Dispatch Architecture

**Depth**: Standard — Multiple viable approaches exist, and the input document contains factual inaccuracies that suggest the problem framing needs correction before solution design.

**Input sources**: input-doc.md (analysis document), plus direct codebase verification of all hook infrastructure files.

---

## Phase 1: Problem Archaeology

### 1.0 — Input Document Verification

The input document contains several claims that diverge from reality. These discrepancies are themselves findings:

| Document claim | Actual state | Impact |
|---|---|---|
| "5 个独立的 hook 脚本" | **10 hook scripts** (write-lock, phase-guide, bash-guard, post-write-tracker, quality-gate, subagent-context, stop-guard, completion-check, failure-tracker, pre-compact) | Document author may have worked from stale knowledge; any plan based on "5 hooks" would undercount scope by 2x |
| "8 个映射 in manifest.conf" | **10 mappings** (SessionStart, 2x PreToolUse, 2x PostToolUse, SubagentStart, Stop, TaskCompleted, PostToolUseFailure, PreCompact) | Same staleness signal |
| "3 个 hook 脚本" listed (write-lock, phase-guide, prompt-guard) | prompt-guard.sh **does not exist**; bash-guard.sh exists instead | Document describes a hook that was never committed or was renamed |
| "不支持条件路由" | manifest.conf **already supports matcher-based conditional routing** (e.g., `PreToolUse:Write,Edit,MultiEdit,CreateFile,NotebookEdit:write-lock`) | The stated #1 problem is partially already solved |
| No mention of adapters | Two adapter layers exist (cursor/, codex/) that translate between IDE-specific protocols | Missing a significant architectural component |
| No mention of lib/ shared code | plan-parser.sh (441 lines) + common.sh (63 lines) + junction.sh (36 lines) are the real complexity center | The document focuses on dispatch.sh (64 lines) while the real weight is in lib/ |

**Finding**: The document is substantially stale and misidentifies the architecture. A plan based on its framing would solve problems that don't exist while missing the actual pain points.

### 1.1 — The Five Whys

**Stated**: "hook dispatch 架构需要改进" (the hook dispatch architecture needs improvement)

**Why?** The document lists five problems. Let me trace each to its root:

1. "manifest.conf 是平面结构, 不支持条件路由" → **Already partially solved.** Matchers provide tool-level routing. What's actually missing is *phase-conditional* routing (e.g., only run quality-gate during IMPLEMENT phase). But: no hook currently needs this. Phase-guide.sh handles phase awareness internally.
   - Root: this is a **speculative future need**, not a current pain point.

2. "Hook 之间无通信机制" → Why would hooks need to communicate? Currently failure-tracker.sh uses /tmp files for session state. post-write-tracker.sh does the same. These work. The real question: **is the lack of shared state causing bugs or missed functionality?**
   - Root: **no evidence of a concrete problem.** Two hooks use /tmp files as ad-hoc state; it works but doesn't scale cleanly.

3. "错误处理粗糙" → dispatch.sh does surface unexpected exit codes (line 59-61). The real issue: hooks use stderr for messages and exit codes for decisions, but the protocol is implicit — there's no formal contract.
   - Root: **the hook protocol is convention-based, not contract-based.** New hook authors must read existing hooks to learn the patterns.

4. "Windows 兼容性层增加了复杂度" → run-hook.cmd is a polyglot (cmd + bash) wrapper. It's 45 lines and stable.
   - Root: **Windows Git Bash startup latency (~200ms) is the real cost**, not complexity. The wrapper itself is well-designed.

5. "测试困难" → Tests exist (test-dispatch.sh, test-phase-guide.sh etc.). The difficulty is real: mocking BATON_STDIN, BATON_PROJECT_DIR, plan files, etc. requires substantial setup.
   - Root: **hooks depend on filesystem state (plan files, marker presence) and environment variables, making test setup heavy.**

### 1.2 — Problem Statement

The hook dispatch architecture (dispatch.sh + manifest.conf) is actually simple, well-designed, and stable at 64 lines. The real suboptimalities are elsewhere:

1. **Hook scripts carry duplicated boilerplate.** Every hook independently: reads stdin/BATON_STDIN, resolves target paths, sources common.sh, calls resolve_plan_name + find_plan. This pattern repeats across 8 of 10 hooks (~15 lines of identical setup per hook).

2. **The hook protocol is implicit.** New hooks work by copying an existing hook and modifying it. There's no contract defining: what inputs a hook receives, what outputs it should produce, what exit codes mean, or what the lifecycle looks like.

3. **plan-parser.sh is a monolith.** At 441 lines, it's the largest single file in the hook system. It combines discovery (find_plan, find_research, project_root), section parsing (todo_range, todo_counts, retro_range), and write-set enforcement (writeset_extract, writeset_normalize) — three distinct concerns.

4. **Adapter duplication.** Cursor and Codex adapters each have their own dispatch.sh and adapter.sh. When a new IDE is added, the pattern must be manually replicated.

**Solved looks like**: Adding a new hook requires writing only the domain logic; boilerplate, protocol compliance, and IDE adaptation are handled by infrastructure. plan-parser.sh responsibilities are separated enough to modify one concern without risking another.

### Assumption Audit

| # | Assumption | Type | If wrong... |
|---|-----------|------|-------------|
| 1 | dispatch.sh itself is the problem | **Convention (wrong)** — document frames it this way, but it's 64 lines and clean | Plan wastes effort refactoring the wrong component |
| 2 | Hooks need inter-hook communication | Unknown — no current hook needs it | Adding a communication layer would be YAGNI overhead |
| 3 | Phase-conditional routing is needed | Unknown — phase-guide.sh handles this internally | Adding it to manifest.conf would increase dispatcher complexity for unclear benefit |
| 4 | Pure bash is a constraint | **Fact** — "Zero compiled dependencies" is a stated design principle | Plan must not introduce non-bash dependencies |
| 5 | Windows compatibility must be maintained | **Fact** — run-hook.cmd exists, NTFS junctions are used | Cannot use Unix-only features |
| 6 | Hooks must be fail-open | **Fact** — every hook has `trap ... exit 0` for unexpected errors | Cannot make hooks fail-closed by default |
| 7 | jq is optional (awk fallback required) | **Fact** — explicitly coded in dispatch.sh and multiple hooks | JSON parsing changes must maintain awk fallback |

### True Constraints vs. Conventions

**True Constraints**:
- Pure bash, zero compiled dependencies
- Windows Git Bash compatibility (via run-hook.cmd)
- jq optional, awk fallback required
- Fail-open by default (hooks are advisory/safety, not blocking-by-default)
- Exit code protocol: 0=allow, 2=block (IDE contract)
- Junction-based distribution model (hooks live in ~/.baton, projects link to them)

**Conventions (challengeable)**:
- Every hook sources common.sh and calls resolve_plan_name + find_plan itself → **could be done once by dispatch.sh**
- Every hook reads BATON_STDIN independently → **dispatch.sh already buffers it; hooks could receive pre-parsed fields**
- Each hook is a standalone .sh that's sourced via `. "$_dir/$_script.sh"` → **could be a function instead of a file, but file-per-hook aids isolation and testing**
- plan-parser.sh is one file → **could be split by concern**
- Adapters are per-IDE directories with independent dispatch logic → **could be parameterized**

---

## Phase 2: Solution Reconstruction

### 2.1 — Solution Categories

#### Category A: Dispatch-Level Boilerplate Extraction

**Mechanism**: dispatch.sh performs common setup (source common.sh, resolve plan, parse target from BATON_STDIN) once before running any hook. Hooks receive pre-resolved variables (PLAN, PLAN_NAME, TARGET, JSON_CWD) as exports.

**Why it might be best**: Eliminates ~15 lines of duplicated setup from each of 8 hooks. Single point of change for parsing logic. No architectural change needed.

**Why it might fail**: Some hooks need different setup (e.g., phase-guide.sh calls parser_find_research, which others don't). One-size-fits-all setup may compute things hooks don't need, wasting time on Windows where every ms counts.

**Conventions challenged**: "Each hook is self-contained" — moves toward "hooks are domain logic only."

#### Category B: Hook Template / Contract System

**Mechanism**: Define a formal hook contract (expected inputs, valid outputs, exit codes) in a documented template. Provide a `hook-template.sh` that new hooks copy. Add a manifest annotation for hook capabilities (needs-plan, needs-target, advisory-only).

**Why it might be best**: Solves the protocol problem directly. Makes adding hooks self-documenting. Doesn't require changing dispatch.sh at all.

**Why it might fail**: Templates go stale. Manifest annotations add another thing to maintain. Existing hooks would need migration to match the contract.

**Conventions challenged**: "Learn by reading existing hooks" → "Learn by reading the contract."

#### Category C: Parser Decomposition

**Mechanism**: Split plan-parser.sh into three files: `parser-discovery.sh` (find_plan, find_research, project_root, has_skill — ~140 lines), `parser-sections.sh` (todo/retro range/counts/items — ~120 lines), `parser-writeset.sh` (normalize/extract/contains — ~80 lines). common.sh sources all three.

**Why it might be best**: Each concern changes independently. Discovery logic (which changes when IDE support evolves) is separated from section parsing (which changes when plan format evolves) and write-set logic (which changes when enforcement policy evolves).

**Why it might fail**: More files = more sourcing overhead on Windows. Three small files vs. one large file is marginal cognitive difference. The current monolith works.

**Conventions challenged**: "One parser file" → "Parser is a concern-separated library."

#### Category D: Full Rewrite (Dispatch Pipeline)

**Mechanism**: Replace dispatch.sh + individual hooks with a pipeline architecture: dispatch reads manifest, builds a hook chain, runs pre-resolution, then executes hooks with resolved context.

**Why it might be best**: Cleanest architecture. Eliminates all duplication. Enables middleware patterns (logging, timing, error wrapping).

**Why it might fail**: Massive change for marginal benefit. Breaks all existing tests. Introduces abstraction where concrete code is easier to debug. Pure bash pipeline patterns are awkward.

**Conventions challenged**: Everything.

### 2.2 — Inversion Test

**Category A (Boilerplate Extraction):**
- Worst case: dispatch.sh becomes a bloated 200-line do-everything script. Hooks that don't need plan resolution pay the latency tax.
- Opposite: Make hooks even MORE self-contained (inline common.sh). Merit: zero coupling, but 10x more duplication.
- Fail-value: If it fails, we learn which hooks genuinely need unique setup vs. which are cargo-culting.

**Category B (Contract System):**
- Worst case: The contract document becomes another stale artifact nobody reads, like the input document for this analysis.
- Opposite: No contract, pure convention. Merit: conventions are discoverable from code; contracts require maintenance.
- Fail-value: If it fails, we learn that hook authoring is rare enough that convention-based learning is sufficient.

**Category C (Parser Decomposition):**
- Worst case: Increased sourcing time on Windows. Developers now need to know which file to look in for a given function.
- Opposite: Merge everything into one even larger file. Merit: one place to search, one file to grep.
- Fail-value: If it fails, we learn that the parser's concerns change together, not independently.

### 2.3 — Recommendation

**Primary recommendation: Category A + B (combined), with Category C as a separate follow-up.**

Reasoning chain:
1. **Root problem** (Phase 1): Hook boilerplate duplication + implicit protocol, NOT dispatch.sh architecture.
2. **True constraints satisfied**: Pure bash, Windows compatible, jq optional, fail-open preserved. No new dependencies.
3. **Convention broken**: "Every hook is fully self-contained" → "dispatch.sh handles common resolution; hooks receive pre-resolved state." This is acceptable because dispatch.sh already owns the hook lifecycle (it reads manifest, chooses hooks, runs them in subshells). Extending its responsibility to include common setup is a natural fit.
4. **Primary risk**: Hooks that currently work may break if dispatch-level resolution has subtly different behavior than per-hook resolution. **Mitigation**: Existing test suite (75+ assertions across test-dispatch.sh, test-phase-guide.sh, etc.) covers the current behavior. Run full regression after each change.

**Category D rejected**: The current architecture is fundamentally sound. dispatch.sh is 64 lines and does one thing well. Rewriting it would be change for change's sake.

### 2.4 — Dissenting Path: Document's Original Framing

The input document's framing — that manifest.conf needs conditional routing and hooks need inter-communication — **would be justified if**:
- A concrete new feature requires phase-conditional hook execution (e.g., "run quality-gate only during IMPLEMENT phase")
- Two hooks need to share state in a way that /tmp files can't handle (e.g., real-time hook chaining)

If you want to proceed with the document's original framing: add a `condition` column to manifest.conf (`event:matcher:script:condition`) where condition is a shell expression evaluated by dispatch.sh. For inter-hook state, use a `$BATON_HOOK_STATE` directory (session-scoped tmpdir). Estimated effort: 2-3 days, but the benefit is speculative.

---

## Phase 3: Plan Synthesis

## Current State

The hook dispatch system consists of:
- **dispatch.sh** (64 lines) — clean event router that reads manifest.conf, matches events to hooks, runs hooks in subshells ✅ verified
- **manifest.conf** (10 mappings) — declarative event:matcher:script format with comma-separated tool matchers ✅ verified
- **10 hook scripts** — ranging from 45 lines (quality-gate.sh) to 265 lines (phase-guide.sh) ✅ verified
- **lib/** (540 lines) — common.sh (63), plan-parser.sh (441), junction.sh (36) ✅ verified
- **Adapters** — cursor/ and codex/ directories with IDE-specific protocol translation ✅ verified
- **run-hook.cmd** (45 lines) — polyglot Windows/Unix wrapper ✅ verified

## Root Cause of Suboptimality

**Duplication of hook setup boilerplate.** 8 of 10 hooks independently perform the same ~15-line setup sequence (read stdin, source common.sh, resolve plan, handle errors). This emerged organically as hooks were added one at a time, each copying the pattern from an existing hook. The cost: each new hook requires copying boilerplate, and protocol changes must be applied to every hook.

## Hidden Assumptions in Current Approach

1. **"Hooks must be self-contained"** — They aren't really. All 8 plan-aware hooks source the same common.sh. Self-containment is an illusion; they already depend on shared infrastructure.
2. **"dispatch.sh should only route"** — It already does more than route: it buffers stdin, extracts tool_name, manages exit codes. Adding plan resolution is a natural extension of its existing responsibility.
3. **"plan-parser.sh is a single concern"** — It contains three distinct concerns (discovery, section parsing, write-set enforcement) that evolve for different reasons.

## Proposed Changes

| Priority | Change | Why (traced to root cause) | Effort | Risk |
|----------|--------|--------------------------|--------|------|
| P1 | Extract common hook setup into dispatch.sh pre-resolution | Eliminates 15-line boilerplate from 8 hooks. Single source of truth for plan/target resolution. | 3-4h | Medium — requires verifying all hooks still work with pre-resolved state |
| P2 | Add hook protocol contract documentation | Makes implicit protocol explicit. Reduces new-hook authoring from "copy and modify" to "implement contract." | 1-2h | Low — additive, no code changes |
| P3 | Split plan-parser.sh into three concern-specific files | Separation of discovery, section parsing, and write-set enforcement. Each can evolve independently. | 2-3h | Low — pure refactor, same API surface |
| P4 | Parameterize adapter layer | Reduce cursor/ and codex/ to config + one shared adapter template. | 3-4h | Medium — must not break IDE-specific protocol compliance |

### P1: Dispatch Pre-Resolution (core change)

**What specifically changes**: dispatch.sh gains a setup block after stdin buffering that sources common.sh and resolves PLAN/PLAN_NAME/TARGET/JSON_CWD. These are exported so hooks receive them pre-resolved.

**Mechanism**:

```bash
# In dispatch.sh, after BATON_STDIN buffering (line 20), add:
# --- Pre-resolve common state for hooks ---
if [ -f "$_dir/lib/common.sh" ]; then
    . "$_dir/lib/common.sh"
    resolve_plan_name
    find_plan
    export PLAN PLAN_NAME MULTI_PLAN_COUNT

    # Resolve target from stdin JSON (used by PreToolUse/PostToolUse hooks)
    export BATON_TARGET_RESOLVED=""
    export BATON_JSON_CWD=""
    if [ -n "$BATON_STDIN" ]; then
        if command -v jq >/dev/null 2>&1; then
            BATON_TARGET_RESOLVED="$(printf '%s' "$BATON_STDIN" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
            BATON_JSON_CWD="$(printf '%s' "$BATON_STDIN" | jq -r '.cwd // empty' 2>/dev/null)"
        else
            BATON_TARGET_RESOLVED="$(printf '%s' "$BATON_STDIN" | awk -F'"' '{
                for(i=1;i<=NF;i++) if($i=="file_path") print $(i+2)
            }' | head -1)"
            BATON_JSON_CWD="$(printf '%s' "$BATON_STDIN" | awk -F'"' '{
                for(i=1;i<=NF;i++) if($i=="cwd") print $(i+2)
            }' | head -1)"
        fi
    fi
fi
```

Each hook then **removes** its own stdin parsing, common.sh sourcing, resolve_plan_name, and find_plan calls, replacing them with:
```bash
# At top of hook (after trap):
TARGET="${BATON_TARGET_RESOLVED:-}"
JSON_CWD="${BATON_JSON_CWD:-}"
# PLAN, PLAN_NAME, MULTI_PLAN_COUNT already exported by dispatch.sh
```

Hooks that are invoked directly (not via dispatch.sh) still work because they check for pre-resolved state and fall back to self-resolution:
```bash
if [ -z "${PLAN+x}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
    . "$SCRIPT_DIR/lib/common.sh"
    resolve_plan_name
    find_plan
fi
```

**Expected measurable impact**: ~120 lines of duplicated code removed across 8 hooks. New hooks need ~5 lines of setup instead of ~20.

**How to verify**: Run `bash tests/test-full.sh`. All existing 75+ assertions must pass. Also verify direct invocation of write-lock.sh (used by cursor adapter).

### P2: Hook Protocol Contract

**What specifically changes**: Add `.baton/hooks/PROTOCOL.md` documenting:
- Input contract: BATON_STDIN (raw JSON), BATON_TARGET_RESOLVED, BATON_JSON_CWD, PLAN, PLAN_NAME
- Output contract: stderr for human-readable messages, stdout for structured JSON (hookSpecificOutput), exit codes (0=allow, 2=block)
- Lifecycle: dispatch.sh pre-resolution → subshell execution → exit code collection
- Template: minimal hook skeleton

**Effort**: 1-2 hours. Pure documentation.

**How to verify**: Have someone unfamiliar with the codebase write a new hook using only the protocol document. Measure time and questions asked.

### P3: Parser Decomposition

**What specifically changes**: Split plan-parser.sh (441 lines) into:
- `lib/parser-discovery.sh` (~150 lines): parser_find_plan, parser_find_research, parser_has_go, parser_has_skill, parser_project_root
- `lib/parser-sections.sh` (~120 lines): parser_todo_range, parser_todo_counts, parser_todo_items, parser_todo_remaining_items, parser_retro_range, parser_retro_valid
- `lib/parser-writeset.sh` (~80 lines): parser_writeset_normalize, parser_writeset_extract, parser_writeset_contains

common.sh sources all three (preserving the existing API surface for hooks).

**Effort**: 2-3 hours. Pure file split, no API changes.

**How to verify**: `bash tests/test-full.sh` — all tests pass. `wc -l` on each file matches expected range. No hook changes needed.

### P4: Adapter Parameterization

**What specifically changes**: Extract shared adapter logic into `adapters/adapter-common.sh`. Each IDE adapter becomes a thin config file:

```bash
# adapters/cursor/adapter.sh (simplified)
ADAPTER_IDE="cursor"
ADAPTER_CAPABILITY="reduced enforcement"
ADAPTER_PROTOCOL="json"  # {"decision":"allow|deny"}
. "$(dirname "$0")/../adapter-common.sh"
```

**Effort**: 3-4 hours. Requires careful testing with each IDE.

**How to verify**: Manual test with Cursor and Codex. Adapter output format must match current behavior exactly.

## What NOT to Change

| Element | Why it should stay |
|---------|-------------------|
| **dispatch.sh core loop** (manifest reading, matcher logic, subshell execution) | Clean, minimal (64 lines), well-tested. The routing logic is correct. ✅ |
| **manifest.conf format** (event:matcher:script) | Simple, readable, works. Adding columns (conditions, priority) would add complexity for no proven need. ✅ |
| **run-hook.cmd polyglot wrapper** | Clever, stable, handles all known Windows bash installation paths. The ~200ms Windows overhead is Git Bash's fault, not the wrapper's. ✅ |
| **Fail-open default** (trap + exit 0) | Core safety property. Hooks must not break the IDE when they crash. ✅ |
| **File-per-hook isolation** | Aids testing, debugging, and independent evolution. Merging hooks into one file would harm maintainability. ✅ |
| **/tmp session state** (failure-tracker, post-write-tracker) | Simple, works, automatically cleaned. Replacing with a proper state system is YAGNI until a third hook needs session state. ✅ |

## Success Criteria

1. **New hook authoring**: Writing a new hook requires <10 lines of boilerplate (currently ~20). Measurable by line count.
2. **Duplicate code**: Total lines of duplicated stdin-parsing / plan-resolution across hooks drops from ~120 to <20. Measurable by grep.
3. **Test regression**: All existing tests pass after each change. Binary pass/fail.
4. **Windows latency**: dispatch.sh execution time stays within 10% of current (~200ms). Measurable by `time`.
5. **Direct invocation**: write-lock.sh and phase-guide.sh still work when called directly (not through dispatch.sh), as required by the cursor adapter. Testable by running adapter.sh.

## Comparison

| Dimension | Current | Proposed | Why |
|-----------|---------|----------|-----|
| Lines of boilerplate per hook | ~15-20 | ~5 (fallback-only) | Pre-resolution in dispatch.sh |
| Hook authoring guidance | Read existing hooks | Protocol document + template | Explicit contract |
| plan-parser.sh | 441 lines, 3 concerns | 3 files, ~80-150 lines each | Concern separation |
| Adapter duplication | 2 independent adapters | Config + shared template | DRY |
| dispatch.sh size | 64 lines | ~90 lines (pre-resolution added) | Acceptable growth for 120-line savings elsewhere |
| Total hook system lines | ~1,600 | ~1,500 (net reduction from dedup) | Less code doing the same thing |
| Risk | N/A — working system | Medium for P1, Low for P2-P3 | Mitigated by existing test suite |

## 批注区
