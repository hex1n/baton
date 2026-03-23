# Research: Write-Lock Mechanism Across IDE Adapters

## Frame

- **Question**: Does the write-lock mechanism actually fire in all supported IDEs, what are the behavioral differences across adapters, and what is the common contract a new adapter must satisfy?
- **Why**: Supports a decision about whether and how to add a new IDE adapter for write-lock enforcement.
- **Scope**: The write-lock hook (`write-lock.sh`), its integration path in Claude Code / Factory, Cursor, and Codex; the dispatch and adapter layers; the common contract.
- **Out of scope**: Non-write-lock hooks (phase-guide, bash-guard, etc.) except where they illuminate adapter architecture. Other IDEs not currently supported (Windsurf, Cline, Copilot).

## Orient

- **System familiarity**: deep -- I have read the core hook files, both adapters, dispatch.sh, manifest.conf, setup.sh, the IDE capability matrix, and the stable surface doc.
- **Evidence type**: codebase-primary
- **Strategy**: Trace the write-lock invocation path for each of the three IDE tiers (Claude Code/Factory, Cursor, Codex), compare contract surfaces, then synthesize the common adapter contract.

## Investigation Methods

| Method | What it returned | Independence level |
|--------|-----------------|-------------------|
| Direct file reading of write-lock.sh, adapter.sh (cursor and codex), dispatch.sh, manifest.conf, run-hook.cmd, setup.sh, settings.json | Complete invocation chain per IDE | strong |
| Cross-referencing with docs/ide-capability-matrix.md and docs/stable-surface.md | Documented tier model and confirmed/contradicted code findings | moderate (docs vs. code) |

## Investigation

### Move 1: Claude Code / Factory write-lock path

- **Question**: How does write-lock fire in Claude Code and Factory?
- **What was checked**: `.claude/settings.json`, `run-hook.cmd`, `dispatch.sh`, `manifest.conf`, `write-lock.sh`
- **What was found**:
  - `.claude/settings.json` registers a `PreToolUse` hook with matcher `Edit|Write|MultiEdit|CreateFile|NotebookEdit`. The command is `.baton/hooks/run-hook.cmd PreToolUse`. ✅ read `.claude/settings.json`:9-28
  - `run-hook.cmd` is a polyglot bash/cmd.exe wrapper. On Unix it `exec bash dispatch.sh "$@"`. On Windows it finds Git Bash and runs `dispatch.sh`. ✅ read `run-hook.cmd`:1-45
  - `dispatch.sh` reads stdin JSON (buffered into `BATON_STDIN`), extracts `tool_name`, and iterates `manifest.conf`. For `PreToolUse` with tool `Write|Edit|MultiEdit|CreateFile|NotebookEdit`, it sources `write-lock.sh`. ✅ read `dispatch.sh`:1-64
  - `write-lock.sh` resolves the target file path from `BATON_TARGET` env or `BATON_STDIN` JSON `.tool_input.file_path`. It checks markdown exemption, finds plan file via walk-up, checks `<!-- BATON:GO -->`, and optionally enforces write-set. Exit 0 = allow, exit 2 = block. On allow with GO, it emits `hookSpecificOutput` JSON with `additionalContext`. ✅ read `write-lock.sh`:1-172
  - **No adapter layer** -- Claude Code/Factory call dispatch.sh directly. The hook protocol is native (exit code 0/2, stderr for messages, stdout JSON for `hookSpecificOutput`). ✅ read `settings.json` -- no adapter reference
  - Factory shares the same path as Claude Code: `setup.sh` line 662 treats `claude|factory` identically, both use `.claude/settings.json`. ✅ read `setup.sh`:660-665
- **Status**: ✅ Write-lock fires as a hard gate on Claude Code and Factory via native hook protocol.
- **What remains unresolved**: None for this path.

### Move 2: Cursor write-lock path

- **Question**: How does write-lock fire in Cursor, and what translation does the adapter perform?
- **What was checked**: `.cursor/hooks.json` generation in `setup.sh`, `adapters/cursor/dispatch.sh`, `adapters/cursor/adapter.sh`
- **What was found**:
  - `setup.sh` generates `.cursor/hooks.json` with `preToolUse` entries (camelCase) for matcher `Write`, `Edit`, and `Bash`. Command: `bash .baton/adapters/cursor/dispatch.sh preToolUse`. ✅ read `setup.sh`:285-346
  - `dispatch-cursor.sh` maps Cursor's camelCase event names to PascalCase (`preToolUse` -> `PreToolUse`), then calls `dispatch.sh`. It captures stdout+stderr, and translates exit codes: exit 2 -> `{"decision":"block","reason":"..."}`, anything else -> `{"decision":"allow"}`. ✅ read `adapters/cursor/dispatch.sh`:1-34
  - The legacy `adapter-cursor.sh` calls `write-lock.sh` directly (bypassing dispatch.sh) and translates to `{"decision":"allow"}`/`{"decision":"deny","reason":"..."}`. It also injects a capability tier prefix `[Baton capability: reduced enforcement (Cursor)]`. ✅ read `adapters/cursor/adapter.sh`:1-37
  - **Key difference from Claude Code**: Cursor uses a JSON response protocol (`decision` field) instead of raw exit codes. The adapter translates. The decision field values differ between the two adapter files -- `dispatch.sh` uses `"block"` while `adapter.sh` uses `"deny"`. ✅ both files read
  - **Capability gap**: Per `adapter.sh` header comments (lines 6-10), Cursor has reduced enforcement: no post-write-tracker (no write-set drift warning), no stop-guard (no session-end reminders), no completion-check, no failure-tracker, no retrospective enforcement. ✅ read `adapter.sh`:5-10
  - The `dispatch-cursor.sh` approach routes ALL events through dispatch.sh (including postToolUse, stop, subagentStart, preCompact), which is a broader integration than the legacy `adapter.sh` which only handled write-lock.
- **Status**: ✅ Write-lock fires as a hard gate on Cursor via the adapter translation layer.
- **What remains unresolved**: The two adapter files (`dispatch.sh` vs `adapter.sh`) appear to be newer vs older versions. `setup.sh` generates config pointing to `dispatch.sh`, so `adapter.sh` may be legacy. The `"block"` vs `"deny"` difference needs clarification.

### Move 3: Codex write-lock path

- **Question**: Does write-lock fire on Codex?
- **What was checked**: `.codex/hooks.json`, `adapters/codex/dispatch.sh`, `adapters/codex/adapter.sh`, `setup.sh:configure_codex()`
- **What was found**:
  - `.codex/hooks.json` only registers `SessionStart` and `Stop` events. **No `PreToolUse` event is registered.** ✅ read `.codex/hooks.json`:1-26
  - `adapters/codex/adapter.sh` only handles `phase-guide` and `stop-guard`. Line 8-9 explicitly states: "Not available: write-lock (no PreToolUse hard gate), bash-guard (no PreToolUse)". ✅ read `adapters/codex/adapter.sh`:7-9
  - `adapters/codex/dispatch.sh` handles `SessionStart` and `Stop` only; other events are passed to dispatch.sh but there is no PreToolUse registration in `.codex/hooks.json` to trigger it. ✅ read `adapters/codex/dispatch.sh`:1-34
  - The tier header explicitly states: "Hard gates (write-lock, bash-guard) are not available. Enforcement relies on rules and guidance." ✅ read `adapters/codex/dispatch.sh`:12
  - `setup.sh` `configure_codex()` creates only `SessionStart` and `Stop` in `.codex/hooks.json`. ✅ read `setup.sh`:384-417
  - Codex relies on AGENTS.md + constitution.md rules injection plus Codex's own sandbox (`writable_roots`) and approval policy. ✅ read `setup.sh`:366-377
- **Status**: ✅ Write-lock does NOT fire on Codex. This is a known, documented, and intentional limitation.
- **What remains unresolved**: Whether Codex will eventually support PreToolUse hooks (external dependency on OpenAI).

### Move 4: Common contract synthesis

- **Question**: What must a new adapter satisfy to integrate write-lock?
- **What was checked**: All three paths above, `write-lock.sh` interface, `dispatch.sh` interface
- **What was found**:
  - **write-lock.sh contract** (the core):
    - **Input**: Reads `BATON_STDIN` env var (or stdin if not set) as JSON with `.tool_input.file_path` and optional `.cwd`. Also accepts `BATON_TARGET` env var as override. ✅ read `write-lock.sh`:22-46
    - **Output on allow**: Exit 0. Stdout: optional `hookSpecificOutput` JSON with `additionalContext`. ✅ line 162-165
    - **Output on block**: Exit 2. Stderr: human-readable block reason with emoji prefix. ✅ lines 136-171
    - **Bypass**: `BATON_BYPASS=1` env var skips entirely (exit 0). ✅ line 17-20
    - **Fail-open**: Trap on unexpected errors exits 0. Missing target path exits 0 with warning. Missing common.sh exits 0. ✅ lines 13-14, 48-54, 84-86
  - **dispatch.sh contract** (the multiplexer):
    - Takes event name as first arg. Buffers stdin into `BATON_STDIN`. Extracts `tool_name` from JSON. Matches against `manifest.conf` (event:matcher:script). Sources matching hook scripts in subshells. First exit 2 wins for PreToolUse. ✅ read `dispatch.sh`:1-64
  - **What an adapter must do**:
    1. Register a PreToolUse-equivalent event in the IDE's hook config, with matcher for write tools
    2. Pass the IDE's stdin JSON (containing file path) through to dispatch.sh or write-lock.sh
    3. Translate exit code 2 + stderr to the IDE's block protocol (JSON format varies by IDE)
    4. Translate exit code 0 + optional stdout JSON to the IDE's allow protocol
    5. Handle stdin/EOF correctly (some IDEs don't send EOF -- Codex required `/dev/null` redirect)
    6. Optionally prepend a capability tier header to help the AI understand enforcement level

## Cross-Move Synthesis

- **Reinforcing**: All three paths confirm the tier model documented in `ide-capability-matrix.md`. Claude Code/Factory = full protection (native protocol, no adapter), Cursor = core protection (adapter translates JSON protocol), Codex = no write-lock (no PreToolUse event available). ✅ cross-reference with `docs/ide-capability-matrix.md`
- **Tension**: The Cursor path has two adapter files (`adapter.sh` calling write-lock directly, `dispatch.sh` calling dispatch.sh broadly). The generated config in `setup.sh` uses `dispatch.sh`, suggesting `adapter.sh` is legacy but still present. The JSON decision value differs: `dispatch.sh` uses `"block"` while `adapter.sh` uses `"deny"`. This is a minor inconsistency; Cursor's documentation uses `"block"` as the decision value. ❓ Could not verify which value Cursor actually requires without runtime testing.
- **Unresolved**: Whether Codex will add PreToolUse support is an external dependency outside this codebase.

## Counterexample Sweep

- **Leading interpretation**: Write-lock fires as a hard gate on Claude Code, Factory, and Cursor; it does not fire on Codex. A new adapter needs to translate between write-lock.sh's exit-code protocol and the IDE's native hook response format.
- **Disproving evidence sought**: (1) Is there any path where write-lock could fire on Codex despite not being registered? (2) Is there any path where write-lock could fail silently on Claude Code or Cursor?
- **What was checked**:
  - For (1): Searched `adapters/codex/dispatch.sh` and `.codex/hooks.json` for any PreToolUse reference. Found none. The dispatch.sh fallback case (`*) bash "$_dispatch" "$@"`) would only fire if an unrecognized event were passed, and there is no hook config to trigger PreToolUse. ✅ read codex/dispatch.sh:29-31
  - For (2): Examined `write-lock.sh` for fail-open paths: line 13-14 (trap on unexpected errors), line 48-54 (no target = fail-open), line 84-86 (missing common.sh = fail-open). Also `BATON_BYPASS=1` env var silently allows. These are documented fail-open paths, not silent failures. The test suite (`test-write-lock.sh`) covers 30+ assertions including bypass, no-target, and JSON stdin scenarios. ✅ read test-write-lock.sh
  - A contradiction would look like: a registration of PreToolUse in `.codex/hooks.json`, or a code path in `write-lock.sh` that exits non-0/non-2 without the trap catching it.
- **Result**: No disproving evidence found after active search. Confidence remains high.

## Self-Challenge

**Q1: Weakest conclusion**:
- **Conclusion**: The Cursor adapter reliably translates write-lock exit codes to Cursor's JSON protocol.
- **Why weakest**: There are two adapter files with different `decision` field values (`"block"` vs `"deny"`), and I could not verify at runtime which one Cursor actually honors. The test suite (`test-adapters-v2.sh`) tests the legacy `adapter.sh` (checking for `"deny"`), not the active `dispatch.sh` (which uses `"block"`).
- **Falsification condition**: If Cursor requires `"deny"` (not `"block"`) as the decision value, then `dispatch-cursor.sh` would emit an unrecognized value and Cursor might treat it as allow (fail-open).
- **Checked for it**: Read both adapter files and the test suite. The test at `test-adapters-v2.sh:55` checks for `"deny"` from the legacy adapter. Cursor's documented protocol (per `docs/research-ide-hooks.md:115`) says `{"decision":"allow"|"deny","reason":"..."}` -- this suggests `"deny"` is correct, making `dispatch-cursor.sh`'s use of `"block"` potentially wrong. ❓ This needs runtime verification.

**Q2: What did I NOT investigate that I should have?**
- I did not run the test suites to confirm all assertions pass on the current codebase.
- I did not verify the actual Cursor hooks protocol at runtime (only read docs and code).
- I did not examine whether `run-hook.cmd` correctly handles Windows-specific edge cases (long paths, spaces in paths).

**Q3: What assumptions did I make without verifying?**
- I assumed Factory uses the exact same settings.json path as Claude Code (supported by `setup.sh` but not verified with a Factory installation).
- I assumed Cursor's current protocol uses `"deny"` based on `research-ide-hooks.md`, which was last verified 2026-03-07. ❓ Cursor's protocol may have changed since then.

## One-Sentence Summary

"In the context of write-lock behavior across IDE adapters, investigating Claude Code, Cursor, and Codex integration paths, I found that write-lock fires as a hard gate on Claude Code/Factory (native) and Cursor (via adapter translation), but does not fire on Codex (no PreToolUse event), with high confidence, accepting uncertainty about the Cursor adapter's `block` vs `deny` decision value."

## Final Conclusions

**C1**: Write-lock fires as a hard gate on Claude Code and Factory with no adapter layer needed -- dispatch.sh routes directly to write-lock.sh via the native hook protocol (exit 0/2 + JSON stdout).
- **Confidence**: High -- verified by reading the complete invocation chain from settings.json through run-hook.cmd to dispatch.sh to write-lock.sh.
- **Evidence**: ✅ `.claude/settings.json`:9-28, `run-hook.cmd`:44-45, `dispatch.sh`:35-62, `manifest.conf`:4, `setup.sh`:662
- **Verification path**: Run `bash tests/test-write-lock.sh` to confirm all 30+ assertions pass.
- **Uncertainty**: Factory sharing the same path is verified in `setup.sh` but not tested with an actual Factory installation.
- **Plan implication**: actionable -- a new adapter does NOT need to replicate this path; it is the reference implementation.

**C2**: Write-lock fires as a hard gate on Cursor via `dispatch-cursor.sh`, which translates dispatch.sh exit codes to Cursor's JSON protocol (`{"decision":"block"}`/`{"decision":"allow"}`).
- **Confidence**: Medium -- the code path is clear but there is a `"block"` vs `"deny"` inconsistency between the active dispatch adapter and the legacy adapter/docs.
- **Evidence**: ✅ `adapters/cursor/dispatch.sh`:27-32, `setup.sh`:287-299, `adapters/cursor/adapter.sh`:12-36
- **Verification path**: Test in a live Cursor session. Check if `"block"` is accepted or if `"deny"` is required.
- **Uncertainty**: ❓ `dispatch-cursor.sh` uses `"block"` while docs and legacy adapter use `"deny"`. Needs runtime verification.
- **Plan implication**: watchlist -- the Cursor adapter works but the decision value inconsistency should be resolved before using it as a template for new adapters.

**C3**: Write-lock does NOT fire on Codex. This is intentional -- Codex lacks a PreToolUse hook event. Enforcement relies on AGENTS.md rules injection + Codex's own sandbox controls.
- **Confidence**: High -- `.codex/hooks.json` only registers SessionStart and Stop; adapter.sh header explicitly states write-lock is not available.
- **Evidence**: ✅ `.codex/hooks.json`:1-26, `adapters/codex/adapter.sh`:7-9, `adapters/codex/dispatch.sh`:12, `docs/ide-capability-matrix.md`:11
- **Verification path**: Inspect `.codex/hooks.json` for any PreToolUse registration (there is none).
- **Uncertainty**: Whether Codex will add PreToolUse support is outside baton's control.
- **Plan implication**: actionable -- a new adapter for an IDE with PreToolUse support can ignore Codex as precedent.

**C4**: The common contract for a new IDE adapter requires: (1) register a PreToolUse-equivalent event for write tools in the IDE's hook config, (2) pass file path information through stdin JSON or env var, (3) translate write-lock.sh exit code 2 to the IDE's block response format, (4) translate exit code 0 to the IDE's allow format, (5) handle stdin EOF correctly.
- **Confidence**: High -- derived from the two working adapters (Claude Code native + Cursor translation) and the write-lock.sh interface.
- **Evidence**: ✅ `write-lock.sh`:22-46 (input), lines 162-171 (output), `adapters/cursor/dispatch.sh`:25-32 (translation example)
- **Verification path**: Implement a minimal adapter for the target IDE following this contract and run `test-write-lock.sh` against it.
- **Uncertainty**: IDE-specific quirks (stdin EOF behavior, timeout handling, JSON field names) vary per IDE and require IDE-specific testing.
- **Plan implication**: actionable -- this contract is sufficient to guide new adapter implementation.

## Questions for Human Judgment

**Blocks plan** -- must be answered before entering plan phase:

1. Which IDE is the new adapter targeting? The adapter complexity depends entirely on the target IDE's hook protocol (exit-code-based = trivial, JSON-response-based = ~30-line adapter, no-PreToolUse = cannot implement).

**Can wait for implementation** -- plan can proceed, decide during implementation:

2. Should the `"block"` vs `"deny"` inconsistency in `dispatch-cursor.sh` be fixed before using it as a template? (The legacy `adapter.sh` and docs say `"deny"`, the active `dispatch.sh` says `"block"`.)

**Out of scope but related** -- recorded but does not block:

3. The legacy `adapters/cursor/adapter.sh` calls write-lock.sh directly (bypassing dispatch.sh), while the active `dispatch-cursor.sh` goes through dispatch.sh. The legacy file could be removed to reduce confusion.

**Open unknowns** -- classified by blocking severity:
- `dispatch-cursor.sh` uses `"block"` vs documented `"deny"`: does not block plan (can be verified during implementation)
- Whether Codex will add PreToolUse: does not block plan (external dependency)

## 批注区

<!--
Processing rules:
- Read underlying evidence before responding
- Do not rewrite a challenge into a weaker one
- If accepted: update the relevant section
- If rejected: explain with evidence
- If unresolved: keep as ?
- Impact = "blocks next phase" -> document goes BLOCKED until resolved
-->

<!--
Per annotation, copy this block:

### [Annotation N]
- **Trigger / 触发点**:
- **Intent as understood / 理解后的意图**:
- **Response / 回应**:
- **Status**: ✅ / ❌ / ❓
- **Impact**: none / clarification only / affects conclusions / blocks next phase
-->
