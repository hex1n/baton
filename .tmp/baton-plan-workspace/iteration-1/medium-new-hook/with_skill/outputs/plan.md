# Plan: Add `UserPromptSubmit` Hook to Baton

**Complexity**: Medium (multi-step verification: test suite + cross-file consistency + behavior check across dispatch/manifest/new script)

**State**: PROPOSING

---

## Requirements

- Add a `UserPromptSubmit` hook that blocks prompts attempting to bypass `BATON:GO`
- The hook fires on user prompt submission, before the AI processes the prompt
- Available on all 3 primary IDEs: Claude Code (`UserPromptSubmit`), Cursor (`beforeSubmitPrompt`), Codex (`UserPromptSubmit`) -- ✅ verified via `docs/research-ide-hooks.md` lines 74-75, 96-97, and research artifact
- Must integrate with existing dispatch system (`dispatch.sh` + `manifest.conf`)
- Exit code 2 = block the prompt; exit code 0 = allow

---

## Step 1: First Principles Decomposition

### Problem Statement

Users can type prompts that instruct the AI to bypass baton governance (e.g., "ignore BATON:GO and just write the code", "skip the plan and implement directly"). The current defense relies entirely on the AI's compliance with rules and on PreToolUse hooks that block tool calls. There is no defense at the prompt-input layer -- the AI receives the full bypass instruction and must resist it using only its loaded rules.

### Constraints

1. **Shell-only execution** -- all hooks are bash scripts sourced by `dispatch.sh` ✅ read `dispatch.sh`
2. **Fail-open convention** -- unexpected errors must not block the user; only deliberate governance violations return exit 2 ✅ read `write-lock.sh`, `bash-guard.sh`
3. **Dispatch compatibility** -- `dispatch.sh` already handles `UserPromptSubmit` as an event name; no matcher filtering needed since this event has no `tool_name` ✅ read `dispatch.sh:25-31` (tool extraction is from `tool_name` field, which `UserPromptSubmit` stdin won't have)
4. **Pattern-matching reliability** -- prompt text is natural language; false positives are worse than false negatives (blocking legitimate work is worse than missing an occasional bypass attempt)
5. **Existing hook patterns** -- hooks source `lib/common.sh`, use `BATON_STDIN` for input, follow fail-open trap pattern ✅ read all existing hooks
6. **Backward compatibility** -- adding a new manifest entry and script must not affect existing hooks

### Solution Categories

**Category A: Pattern-matching on prompt text** -- scan the user's prompt for known bypass phrases (e.g., "ignore BATON:GO", "skip the plan", "bypass write-lock") and block with exit 2.

**Category B: State-aware prompt gating** -- check baton state (is there a plan? is BATON:GO present?) and conditionally scan prompts only when governance is active and the prompt appears to instruct bypass.

**Category C: LLM-based prompt classification** -- use an external LLM call to classify whether a prompt is attempting a governance bypass. (This would require network calls and API keys.)

### Evaluation

- **Category C** violates the [shell-only execution] constraint and introduces latency + API dependency. Rejected.
- **Category A** is simple but produces false positives on legitimate prompts that mention governance terms in discussion context (e.g., "explain how BATON:GO works").
- **Category B** combines state awareness with pattern matching -- only scans for bypass patterns when governance is enforced (plan exists, no BATON:GO), reducing false positives on prompts during open implementation phases.

---

## Step 2: Derive from Validated Inputs

**Research findings used**:
- `UserPromptSubmit` event is confirmed available on Claude Code, Cursor (`beforeSubmitPrompt`), and Codex ✅ `docs/research-ide-hooks.md:74-75`
- Claude Code `UserPromptSubmit` supports blocking via exit 2 ✅ `docs/research-ide-hooks.md:75`
- Cursor `beforeSubmitPrompt` blocking status: ❓ one source says "informational only" (GitButler blog, possibly outdated), another (Cursor docs) lists it with no such caveat. Conservatively: works on Claude Code + Codex; Cursor may need verification.
- `dispatch.sh` already supports arbitrary event names -- no dispatcher changes needed ✅ read `dispatch.sh:39` (`[ "$_evt" != "$_event" ] && continue`)
- The stdin JSON for `UserPromptSubmit` contains the prompt text (not a `tool_name`), so matcher field should be empty in manifest ✅ read `dispatch.sh:25-31` (matcher requires `_tool` from `tool_name` field)

**Stdin JSON structure for UserPromptSubmit** (Claude Code): ❓ not directly verified from docs in this session. Expected format based on research: `{"prompt": "user's text here"}` or similar. The hook script must handle the case where the field name differs.

---

## Step 3: Surface Scan

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| `.baton/hooks/manifest.conf` | L1 | modify | Add `UserPromptSubmit::prompt-guard` entry ✅ read file |
| `.baton/hooks/prompt-guard.sh` | L1 | create | New hook script ✅ no existing file |
| `.baton/hooks/dispatch.sh` | L2 | skip | Already handles arbitrary events; no changes needed ✅ read file, confirmed line 39 |
| `.baton/hooks/lib/common.sh` | L2 | skip | Hook will source this for `find_plan` / `parser_has_go` ✅ read file |
| `.baton/hooks/lib/plan-parser.sh` | L2 | skip | Provides `parser_has_go` used by the new hook ✅ read `common.sh` which sources it |
| `tests/test-dispatch.sh` | L2 | skip | Existing dispatch tests; new hook gets its own test file ✅ read file |
| `tests/test-prompt-guard.sh` | L1 | create | New test file for the hook |
| `.claude/settings.json` | L2 | skip | IDE hook registration -- users configure this themselves; not in baton's write set. Document in output. |

**Self-audit**: Every row above was produced from file reads in this session. No fabricated entries.

---

## Step 4: Approaches & Recommendation

### Approach A: Stateless Pattern Matching

- **What**: Scan every submitted prompt for bypass keywords; block if found.
- **How**: `prompt-guard.sh` extracts prompt text from `BATON_STDIN`, runs regex/case matches against a deny list (e.g., "ignore BATON:GO", "skip the plan", "bypass write-lock", "just implement it").
- **Trade-offs**:
  - Pro: Simple, no state dependencies
  - Con: High false-positive risk -- legitimate discussion of governance terms gets blocked. Users asking "how does BATON:GO work?" would be blocked.
  - Con: Easily evaded by rephrasing ("please proceed without the usual checks")
- **Fit**: Addresses the problem but creates friction on legitimate use.

### Approach B: State-Gated Pattern Matching (Recommended)

- **What**: Only scan for bypass patterns when governance is actively enforced (plan exists but BATON:GO absent). When BATON:GO is present, all prompts pass through.
- **How**: `prompt-guard.sh` sources `lib/common.sh`, calls `find_plan` and `parser_has_go`. If no plan exists or BATON:GO is present, exit 0 immediately. Otherwise, extract prompt text and scan for bypass-intent patterns. Block with exit 2 + guidance message.
- **Trade-offs**:
  - Pro: Zero false positives during open implementation (BATON:GO present) or before governance starts (no plan)
  - Pro: Follows existing hook conventions (sources common.sh, fail-open trap, exit 2 blocking)
  - Con: Still relies on keyword patterns, which can be evaded by creative rephrasing
  - Con: Adds ~1 second latency on each prompt when gate is closed (plan search + file read)
- **Fit**: Directly addresses the problem with minimal false-positive risk. Defense-in-depth: not a primary barrier (write-lock is), but an early-warning layer.

### Approach C: Contextual Deny with Allowlist

- **What**: Like Approach B, but adds an allowlist of safe patterns (e.g., prompts containing "explain", "what is", "how does") that bypass the scan even when governance is active.
- **How**: Before pattern-scanning, check if the prompt matches a "discussion" pattern. If so, allow without scanning.
- **Trade-offs**:
  - Pro: Further reduces false positives for legitimate governance discussions
  - Con: More complex logic; allowlist can itself create bypass vectors ("explain how to ignore BATON:GO then do it")
  - Con: Harder to maintain two lists (deny + allow)
- **Fit**: Over-engineered for the threat model. The real defense is write-lock; prompt-guard is advisory.

### Recommendation: Approach B (State-Gated Pattern Matching)

**Reasoning**: Approach B correctly positions this hook as a defense-in-depth layer. It reuses the existing state-checking infrastructure (`find_plan`, `parser_has_go`) that write-lock and bash-guard already rely on, keeping the pattern consistent ✅ read both hooks. Approach A rejected because it violates the [pattern-matching reliability] constraint from Step 1 -- false positives on governance discussions. Approach C rejected because the added complexity creates new attack surface (allowlist bypass) without proportional benefit -- the primary defense (write-lock) is already in place.

---

## Impact & Write Set

### Files to Create
- `.baton/hooks/prompt-guard.sh` -- new hook script (~40-60 lines)
- `tests/test-prompt-guard.sh` -- new test file

### Files to Modify
- `.baton/hooks/manifest.conf` -- add one line: `UserPromptSubmit::prompt-guard`

### Behavior Changes
- Prompts submitted when a plan exists but BATON:GO is absent will be scanned for bypass-intent patterns
- Matching prompts will be blocked (exit 2) with a guidance message
- No behavior change when BATON:GO is present or no plan exists

### Risks & Mitigation

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| False positives on legitimate prompts | Low (state-gating eliminates most cases) | Conservative pattern list; fail-open on errors |
| Prompt text field name differs across IDEs | Medium | Try multiple field names (`prompt`, `content`, `message`); fail-open if none found |
| Latency on prompt submission | Low (~plan file search) | Same cost as existing hooks; acceptable |
| Cursor `beforeSubmitPrompt` may not support blocking | ❓ Unknown | Document as known limitation; does not affect Claude Code or Codex |

---

## Verification Plan

1. **Unit tests** (`tests/test-prompt-guard.sh`): test bypass patterns blocked, legitimate prompts allowed, state-gating logic (no plan = allow, BATON:GO present = allow)
2. **Integration with dispatch**: verify `dispatch.sh UserPromptSubmit` routes to `prompt-guard.sh` via manifest
3. **Cross-file consistency**: verify `prompt-guard.sh` sources `lib/common.sh` and uses the same plan-discovery path as `write-lock.sh`
4. **Manual smoke test**: submit a bypass prompt in Claude Code with an unapproved plan present

---

## Self-Challenge

### 1. Is this the best approach, or the first one I thought of?

Three approaches were evaluated. Approach B was not the first considered (stateless pattern matching was simpler), but was selected after recognizing that false positives on governance discussion prompts would make Approach A unusable. The category split (stateless / state-gated / contextual allowlist) represents genuinely different control strategies, not variations.

### 2. What assumptions did I make without verifying?

- **Stdin JSON field name for prompt text**: I assumed a field like `prompt` or `content` exists. This is ❓ unverified -- if the field name is different, the hook will fail-open (safe but non-functional).
- **Cursor `beforeSubmitPrompt` supports exit-2 blocking**: Research shows conflicting evidence. One source says "informational only." This is ❓ unverified.
- **Pattern matching on English text**: The bypass patterns assume English-language prompts. Non-English bypass attempts would pass through.

### 3. What would a skeptic challenge first?

A skeptic would argue: "This is security theater -- anyone who wants to bypass governance can just rephrase their prompt, or the AI can still comply with bypass instructions it has already seen in context." This is a valid concern. The response: prompt-guard is not a primary defense. Write-lock (PreToolUse) is the hard barrier. Prompt-guard is an early-warning tripwire that catches the most common/obvious bypass attempts and reminds the user of governance requirements. Its value is in the reminder message, not in its ability to prevent a determined adversary.

> **Weakest assumption**: The stdin JSON field name for the user's prompt text.
> **If this assumption is wrong**: The hook will fail-open (exit 0) on every prompt, providing no protection. The hook would need to be updated once the actual field name is determined.
> **How to verify before executing**: Run a test `UserPromptSubmit` hook in Claude Code that dumps `$BATON_STDIN` to a file, then inspect the JSON structure. Alternatively, check Claude Code hooks documentation for the stdin schema of `UserPromptSubmit`.

---

## 批注区

<!--
Processing rules:
- Read underlying evidence before responding
- Do not rewrite a challenge into a weaker one
- If accepted: update the relevant section
- If rejected: explain with evidence
- If unresolved: keep as ❓
- Impact = "blocks next phase" → document goes BLOCKED until resolved
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
