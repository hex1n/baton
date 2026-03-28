# First-Principles Planning Transcript: Hook Dispatch Architecture Improvement

**Depth**: Deep -- the input document describes an existing system with "we've always done it this way" characteristics, the problem space involves recurring architectural tension (flat manifest vs. growing hook complexity), and the stated issues suggest convention-level assumptions worth challenging.

**Input sources**: Input analysis document + actual codebase files (dispatch.sh, manifest.conf, all 10 hook scripts, run-hook.cmd, lib/common.sh, lib/plan-parser.sh).

---

## Phase 0: Input Synthesis

### From the input document

**Stated goals**: The document asks for an "improvement plan" for the hook dispatch architecture.

**Evidence and data points**:
- dispatch.sh reads manifest.conf to route IDE events to hook scripts
- manifest.conf is a flat `event:matcher:script` format
- 10 manifest entries, 10 hook scripts (document says 8/5 -- outdated)
- Performance: ~50ms Unix, ~200ms Windows per dispatch
- run-hook.cmd is a Windows compatibility layer

**Stated problems**:
1. manifest.conf is flat -- no conditional routing (e.g., phase-aware hooks)
2. No inter-hook communication / shared state
3. Error handling is coarse (exit codes only)
4. Windows compatibility layer adds complexity
5. Testing difficulty due to IDE environment dependencies

**Conclusions already reached**: The document presents these as "known issues" without proposing solutions, implicitly framing them as things that need fixing.

**Unresolved questions**: The document doesn't establish which of these issues actually cause real pain in practice, versus which are theoretical concerns.

### From codebase verification

After reading every hook script, I can verify and refine the input document's claims:

1. **Manifest count is outdated** -- actual manifest has 10 entries, not 8. There are 10 hook scripts (excluding dispatch.sh itself), not 5. The document's data is stale.

2. **"Flat structure" problem is real but nuanced** -- hooks like phase-guide.sh already implement their own phase detection internally (checking for plan, BATON:GO, todo items). The "no conditional routing" claim is accurate for manifest.conf, but hooks compensate by doing their own condition checking. This means the problem is partially solved at the wrong layer.

3. **"No inter-hook communication" is partially false** -- hooks DO share state through:
   - `BATON_STDIN` (buffered stdin, exported by dispatch.sh)
   - `BATON_PROJECT_DIR` (exported by dispatch.sh)
   - Environment variables generally
   - The plan file itself (read by nearly every hook via common.sh)
   - Temp files (failure-tracker.sh, post-write-tracker.sh use `/tmp/baton-*`)
   What's missing is a structured mechanism -- but ad-hoc communication exists.

4. **"Error handling is coarse" overstates the problem** -- dispatch.sh handles exit codes 0 (allow) and 2 (block) deliberately. Non-0-non-2 exits get a warning. This is appropriate for the hook protocol. The real issue isn't error handling granularity -- it's that hooks can only communicate with the IDE through exit codes + stderr text. Structured error responses would require changing the IDE hook protocol, which is an external constraint.

5. **Windows complexity is a genuine constraint** -- run-hook.cmd is a polyglot (cmd + bash) that finds Git Bash and delegates. This is inherently complex but well-implemented. The 4x performance penalty on Windows (~200ms vs ~50ms) is a real concern for hooks that fire on every tool use.

6. **Testing difficulty is real** -- hooks source common.sh which sources plan-parser.sh, depend on BATON_STDIN/BATON_PROJECT_DIR env vars, read plan files from disk, and write to /tmp. But the test suite exists (test-phase-guide.sh with 58 assertions, test-dispatch.sh with 17 assertions) and works. The testing problem is not "impossible" but "slow and requires fixture setup."

### Synthesis

The input document presents five issues with the hook dispatch system. After codebase verification:
- Issue 1 (flat manifest) is a genuine architectural limitation, but hooks compensate internally
- Issue 2 (no communication) is overstated -- ad-hoc communication exists via env vars, temp files, and the plan file
- Issue 3 (coarse error handling) is a protocol constraint, not really dispatch's problem
- Issue 4 (Windows layer) is a true constraint that can be mitigated but not eliminated
- Issue 5 (testing difficulty) is real but already partially addressed by existing test infrastructure

The document frames these as things needing architectural fixes, but hasn't established which ones actually cause user-facing pain.

---

## Phase 1: Problem Archaeology

### 1.1 -- The Five Whys

**Stated problem**: "Hook dispatch architecture needs improvement."

**Why?** -- The manifest is flat and hooks can't conditionally route or share state.

**Why does that matter?** -- As more hooks are added, each hook independently re-derives context (phase detection, plan finding, write-set extraction). This means:
- Repeated work across hooks in the same dispatch cycle
- Each hook independently handles edge cases (multi-plan, missing common.sh) with slightly different error handling
- Adding a new hook requires understanding which other hooks' assumptions might conflict

**Why is that a problem?** -- Because the system's complexity scales linearly with hook count, not sub-linearly. Every new hook is a full independent program that happens to share a library (common.sh).

**Why does linear scaling matter here?** -- Because the system is approaching a threshold where the hook count and their interactions are hard to reason about. With 10 hooks and 10 manifest entries, there's already significant boilerplate (every hook has the same fail-open trap, sources common.sh, calls resolve_plan_name + find_plan). Adding hook #11 means copying this boilerplate again.

**Root**: The real problem is not that the manifest is flat or that hooks can't communicate. The real problem is **duplicated context derivation** -- the same work (find plan, determine phase, extract write set, parse stdin JSON) is done independently by each hook, because the dispatch architecture treats hooks as fully independent programs rather than as functions that operate on shared derived context.

### 1.2 -- Problem Statement

The hook dispatch system requires each hook to independently derive its operating context (plan location, phase state, write set, parsed stdin), leading to:
- Redundant computation across hooks firing in the same dispatch cycle (every PreToolUse:Write fires write-lock.sh AND bash-guard.sh separately, each re-parsing stdin and finding the plan)
- Boilerplate accumulation (every hook has the same 15-20 lines of setup: trap, source common.sh, resolve_plan_name, find_plan)
- Inconsistent edge-case handling (each hook handles multi-plan ambiguity and missing common.sh slightly differently)
- Performance penalty proportional to hook count rather than work count (on Windows, each additional hook in a dispatch cycle adds ~200ms)

**Who is affected**: The developer maintaining baton (adding/modifying hooks), and end users on Windows (cumulative latency).

**What "solved" looks like**: New hooks can be added with minimal boilerplate, hooks in the same dispatch cycle share a single context derivation pass, and Windows dispatch latency scales with work done rather than hook count.

---

## Phase 2: Assumption Audit

### 2.1 -- Surface Assumptions

| # | Assumption | Source | Type |
|---|-----------|--------|------|
| 1 | Each hook must be a separate .sh file | inherited convention | convention |
| 2 | Hooks must run in isolated subshells | dispatch.sh design (line 52) | convention/fact |
| 3 | manifest.conf must be the routing mechanism | inherited convention | convention |
| 4 | Hooks need to be independently testable as standalone scripts | testing approach | convention |
| 5 | The event:matcher:script format is sufficient | dispatch.sh design | convention |
| 6 | stdin JSON parsing must happen in each hook | current architecture | convention |
| 7 | Plan discovery must happen in each hook | current architecture | convention |
| 8 | Windows compatibility requires a separate .cmd wrapper | IDE limitation | fact |
| 9 | The hook protocol (exit 0/2 + stderr) is fixed | IDE constraint | fact |
| 10 | Hooks should be fail-open by default | design principle | fact |
| 11 | Hook execution order within an event doesn't matter | dispatch.sh design | unknown |
| 12 | Zero compiled dependencies is a hard constraint | project principle | fact |
| 13 | Each hook invocation starts from scratch (no persistent daemon) | architecture | convention |

### 2.2 -- Challenge Each One

**Assumption 1: Each hook must be a separate .sh file**
- Convention, not constraint. Hooks could be functions in a single file, or phases in a dispatch pipeline.
- Evidence: The current separation exists because hooks were added incrementally. Nothing requires them to be separate files.
- If wrong: hooks could be consolidated into fewer files organized by event type, reducing boilerplate.
- Load-bearing? No -- the system would work fine with hooks organized differently.

**Assumption 2: Hooks must run in isolated subshells**
- Part convention, part fact. Subshell isolation prevents one hook's failure from crashing dispatch.sh. But the current implementation already handles non-0/non-2 exit codes gracefully.
- Evidence: dispatch.sh line 52 uses `( . "$_dir/$_script.sh" )` -- subshell sourcing.
- If wrong: hooks could run in the same shell, sharing variables, with explicit error handling.
- Load-bearing? Partially. Subshell isolation is a safety net. But if hooks are well-tested, the safety net is less necessary.

**Assumption 3: manifest.conf must be the routing mechanism**
- Convention. The manifest is nice for declarative configuration, but the same routing could be done in code.
- Evidence: dispatch.sh reads manifest.conf on every invocation.
- If wrong: routing could be hardcoded in dispatch.sh (fewer files, faster), or manifest could be compiled to a lookup function.
- Load-bearing? No. The manifest is a convenience, not a necessity.

**Assumption 6: stdin JSON parsing must happen in each hook**
- Convention. dispatch.sh already buffers stdin into BATON_STDIN. It could also pre-parse common fields (tool_name, file_path, cwd, command) and export them.
- If wrong: hooks wouldn't need jq/awk fallback code for common fields.
- Load-bearing? No. This is pure duplication.

**Assumption 7: Plan discovery must happen in each hook**
- Convention. dispatch.sh could find the plan once and export PLAN, PLAN_NAME, etc.
- If wrong: 7 out of 10 hooks would lose 3-5 lines of boilerplate each.
- Load-bearing? No. Pure duplication.

**Assumption 11: Hook execution order within an event doesn't matter**
- Unknown. Currently, dispatch.sh runs hooks in manifest.conf order. For PreToolUse events, if write-lock blocks (exit 2), subsequent hooks still run (dispatch.sh records the exit code but continues). This is potentially wasteful -- if write-lock blocks a write, quality-gate and post-write-tracker run unnecessarily. But this is PreToolUse vs PostToolUse, so the tools are different. Actually checking: write-lock and bash-guard are both PreToolUse, so if write-lock blocks, bash-guard still evaluates. This is harmless (bash-guard only matches Bash tool, write-lock matches Write/Edit tools) but points to a general issue with unconditional execution.

**Assumption 13: No persistent daemon**
- Convention. A daemon could maintain state (phase, plan location, write set) and hooks could be fast lookups. But this violates the "zero compiled dependencies" constraint and adds operational complexity.
- If wrong: performance would be excellent but maintenance burden would increase significantly.
- Load-bearing? The "zero compiled dependencies" constraint is load-bearing (Assumption 12), and a daemon in pure bash is fragile. This assumption should stay.

### 2.3 -- True Constraints vs. Conventions

**True Constraints** (cannot change):
- C1: Hook protocol is exit 0/2 + stderr + stdout JSON (IDE-defined)
- C2: Zero compiled dependencies (project principle, confirmed in CLAUDE.md)
- C3: Windows must work via Git Bash (user base includes Windows)
- C4: Fail-open default (safety principle -- hooks should not break the IDE)
- C5: Pure bash implementation (follows from C2)
- C6: Junction-based distribution means hooks exist in ~/.baton/ and are symlinked into projects

**Conventions worth challenging**:
- V1: **Each hook is a standalone script** -- could be functions or modules within a dispatcher
- V2: **Every hook independently derives context** -- dispatch could pre-derive and export
- V3: **manifest.conf is parsed per-invocation** -- could be a bash associative array or cached
- V4: **Subshell isolation per hook** -- could use function calls with explicit error handling
- V5: **Each hook handles its own boilerplate** -- could be centralized in dispatch

---

## Phase 3: Solution Reconstruction

Working with:
- Root problem: duplicated context derivation across hooks
- True constraints: C1-C6 (bash-only, fail-open, exit code protocol, Windows support)
- Conventions to challenge: V1-V5

### 3.1 -- Solution Categories

#### Category A: "Pre-derive and Export" (Incremental)

**Mechanism**: dispatch.sh pre-computes common context (plan location, phase, parsed stdin fields, write set) and exports as environment variables before running hooks. Hooks still run as separate scripts but skip their own context derivation.

**Why it might be best**: Minimal disruption. Every hook already reads env vars (BATON_STDIN, BATON_PROJECT_DIR). Adding BATON_PLAN_PATH, BATON_PHASE, BATON_TARGET_PATH, BATON_HAS_GO, etc. is a natural extension. Each hook script shrinks by 10-15 lines. No architectural change needed.

**Why it might fail**: Still runs N subshells per event. Windows latency remains O(N) per hook count. Doesn't solve the "copy boilerplate for new hook" problem entirely -- hooks still need fail-open traps and library sourcing.

**Which conventions does it challenge**: V2 (independent context derivation), partially V5 (centralized boilerplate).

#### Category B: "Single-File Event Handlers" (Moderate)

**Mechanism**: Replace separate hook scripts with function definitions loaded by dispatch.sh. Each "hook" is a function in an event-specific file (e.g., `handlers/pre-tool-use.sh` contains write_lock(), bash_guard() as functions). dispatch.sh sources the handler file once and calls functions, not subshells.

**Why it might be best**: Eliminates subshell overhead entirely. Functions share the dispatch.sh process context, so pre-derived variables are available without export. Adding a new hook = adding a function, no boilerplate. Windows latency drops from O(N*200ms) to O(1*200ms + N*5ms).

**Why it might fail**: Loses subshell isolation -- a bug in one hook function could crash the entire dispatch. Function naming collisions become possible. Existing test infrastructure (which invokes hooks as scripts) would need adaptation.

**Which conventions does it challenge**: V1 (hooks as standalone scripts), V2 (independent context), V4 (subshell isolation), V5 (per-hook boilerplate).

#### Category C: "Compiled Manifest + Context Cache" (Major)

**Mechanism**: At install/update time, compile manifest.conf into a self-contained dispatch script that hardcodes routing logic and pre-computes a context derivation preamble. Runtime dispatch becomes a single script invocation with no manifest parsing, no dynamic file lookups.

**Why it might be best**: Maximum performance. No manifest parsing overhead. Could also inline small hooks directly into the compiled dispatcher.

**Why it might fail**: Introduces a build step into a "zero build" system. Debugging compiled output is harder than reading manifest.conf. Must be re-compiled on any hook or manifest change. Violates the "human-readable at rest" principle of the current design.

**Which conventions does it challenge**: V3 (manifest parsed per-invocation), V1 (hooks as files).

#### Category D: "Context Bus" (Major)

**Mechanism**: dispatch.sh computes context once, serializes it to a temp file or env var blob, and hooks read from that instead of re-deriving. Like Category A but with richer structured data (JSON or key=value format).

**Why it might be best**: Hooks remain independent scripts (testable individually), but skip expensive derivation. Could also enable inter-hook data passing (hook A writes to the bus, hook B reads it).

**Why it might fail**: Serialization/deserialization overhead in bash. JSON in bash is painful without jq (and jq is optional). Key=value format limits data structure expressiveness.

**Which conventions does it challenge**: V2 (independent context derivation), partially V3 (manifest could encode bus schema).

### 3.2 -- Inversion Test

**Category A (Pre-derive and Export)**:
- *Worst case*: Too incremental -- solves boilerplate but not the fundamental O(N) subshell problem. If hook count doubles to 20, Windows is still slow.
- *Opposite approach*: Don't pre-derive anything, let each hook be fully self-contained. This is the current state, and it's the source of the problem.
- *Fail-value*: If it fails, we learn which pre-derived values hooks actually need (useful for any other approach).

**Category B (Single-File Event Handlers)**:
- *Worst case*: A bug in one hook function corrupts shared state and causes a different hook to behave incorrectly, producing a hard-to-debug failure. The isolation loss is a real risk.
- *Opposite approach*: Maximum isolation -- each hook runs in its own bash process (not subshell). This is even more isolated than current state, and would be even slower.
- *Fail-value*: If it fails, we learn that hook isolation is genuinely load-bearing, not just cautious engineering.

**Category C (Compiled Manifest)**:
- *Worst case*: The compiled script gets out of sync with the source hooks, causing stale behavior. User edits a hook, forgets to recompile, spends hours debugging.
- *Opposite approach*: Fully dynamic, interpret everything at runtime. This is the current state.
- *Fail-value*: If it fails, we learn that a build step is not viable for this project's workflow.

### 3.3 -- Recommendation

**Recommended approach: Category A (Pre-derive and Export) + selective elements from Category B.**

Reasoning chain:

1. **Root problem** (Phase 1): duplicated context derivation. Category A directly solves this by centralizing derivation in dispatch.sh.

2. **True constraints** (Phase 2):
   - C2/C5 (pure bash, zero deps): Category A and B both satisfy. Category C introduces a build step that strains this.
   - C4 (fail-open): Category A preserves subshell isolation, maintaining fail-open safety. Category B would need explicit error handling to maintain it.
   - C3 (Windows): Category A reduces per-hook work but doesn't reduce subshell count. Selective Category B elements (combining hooks that fire on the same event) would reduce subshell count.

3. **Conventions deliberately broken**:
   - V2 (independent context derivation): dispatch.sh becomes the single context authority. Hooks become simpler, focused on their decision logic.
   - V5 (per-hook boilerplate): The standard "trap + source common.sh + resolve_plan_name + find_plan" preamble moves into dispatch.sh.
   - Selectively V1 (hooks as standalone scripts): for hooks that always fire together on the same event AND are simple enough, they could be combined into a single script. This is optional and applies to specific cases (e.g., post-write-tracker + quality-gate both fire on PostToolUse:Write,Edit).

4. **Primary risk**: Hooks that currently work standalone (for testing or other invocation) would need adaptation to work both with and without pre-derived env vars. Mitigation: each hook checks if the var is set, and falls back to self-derivation if not. This is backward-compatible.

**Why not pure Category B**: The loss of subshell isolation is a real risk in a bash system with no type safety. A misbehaving hook function that sets a global variable or calls `exit` would affect all subsequent hooks. The performance gain on Windows (reducing subshell count) is real but can be partially achieved by combining same-event hooks selectively, without converting the entire system to functions.

---

## Phase 4: Plan Synthesis (Mode B -- Improvement Proposal)

See plan.md for the final output.

---

## Self-Check

1. **Did I question the problem, or just the solution?** Yes. Phase 1 reframed the problem from "flat manifest / no communication / coarse errors" (symptoms) to "duplicated context derivation" (root cause). The input document's issues 2 and 3 were partially refuted with evidence.

2. **Did I find conventions worth breaking?** Yes. Five conventions identified (V1-V5), three directly targeted by the recommendation (V2, V5, selective V1).

3. **Am I recommending the first thing I thought of?** No. Four fundamentally different approaches were evaluated. Category A was chosen not because it was first, but because it best matches the constraint profile (pure bash, fail-open, backward compatible). Category B elements are selectively incorporated.

4. **Can the user predict what will happen from reading this plan?** The plan specifies exactly which variables dispatch.sh would export, which boilerplate each hook would lose, and which hooks are candidates for combination. Outcomes are concrete.

5. **Would I bet money on this?** Yes on the pre-derive approach (low risk, high certainty of reducing boilerplate). Moderate confidence on the selective hook combination (needs careful testing on Windows to verify latency improvement). Low confidence that any approach will fully solve the Windows latency issue -- Git Bash startup overhead is the dominant cost and is outside baton's control.
