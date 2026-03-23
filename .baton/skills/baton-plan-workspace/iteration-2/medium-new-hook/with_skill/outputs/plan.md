# Plan: Add UserPromptSubmit Hook to Baton

**Sizing**: Medium (multi-module, multi-step verification: new hook script + manifest registration + IDE config registration + adapter updates + tests)

**Sizing Checkpoint**: Confirmed Medium. Research indicates multi-IDE registration (Claude Code, Cursor, Codex), cross-file impact (dispatch, manifest, settings, adapters), and multi-step verification (unit tests + integration behavior).

---

## Step 1: First Principles Decomposition

### Problem Statement

Baton's governance markers (`BATON:GO`, `BATON:OVERRIDE`) can only be placed by humans (constitution invariant #4). The existing write-lock hook enforces this at the *tool use* level -- it blocks AI from writing governance markers into files. However, there is no enforcement at the *prompt* level: a user prompt that instructs the AI to bypass `BATON:GO` requirements (e.g., "ignore the plan gate and just write the code") is processed without any guardrail feedback. A UserPromptSubmit hook could intercept such prompts before the AI acts on them, providing an earlier defense layer.

### Constraints

1. **Shell-only execution** -- all hooks are bash scripts sourced through `dispatch.sh`
2. **Fail-open safety** -- hooks must not break the IDE on errors (established pattern: `trap ... exit 0`)
3. **Dispatch architecture** -- hooks register in `manifest.conf`, dispatched via `dispatch.sh`, exit 0 = allow, exit 2 = block
4. **Multi-IDE support** -- Claude Code (`.claude/settings.json`), Cursor (adapter + `.cursor/hooks.json` equivalent), Codex (adapter, limited hook support)
5. **No false positives on normal usage** -- the hook must not block legitimate prompts that mention governance terms in passing (e.g., "where is BATON:GO set?")
6. **Convention consistency** -- follow existing hook patterns (fail-open trap, stdin via `BATON_STDIN`, source `lib/common.sh`, version header)

### Solution Categories

**A. Prompt-level blocking hook** -- a new `prompt-guard.sh` that runs on `UserPromptSubmit`, inspects the prompt text, and blocks prompts that attempt to bypass BATON:GO enforcement.

**B. Enhanced SessionStart context injection** -- instead of a blocking hook, inject additional context at session start warning the AI not to comply with bypass requests. No new event handler.

**C. Write-lock enhancement** -- extend write-lock.sh to emit stronger warnings when the plan gate is closed, relying on existing enforcement points. No new event type.

### Evaluation

| | A: Prompt-level hook | B: Context injection | C: Write-lock enhancement |
|---|---|---|---|
| Mechanism | New script on UserPromptSubmit, pattern-matches prompt text, exit 2 to block | Additional rules in SessionStart context | Stronger write-lock messages |
| Pro | Catches bypass attempts before AI processes them; earliest possible interception | No new code; simple | No new code |
| Con | Pattern matching on natural language has false positive/negative risk; new script + registration | Advisory only -- AI can still comply with bypass instructions | Reactive, not proactive -- blocks the *result* not the *intent* |
| Constraint fit | Meets all 6 constraints | Violates none but does not actually block | Already exists, no new enforcement |

**Recommendation: Approach A** -- Prompt-level blocking hook.

Approach B rejected because it violates no constraints but provides no *enforcement* -- it relies on the AI choosing to follow rules, which is exactly the failure mode this hook is meant to address. Approach C rejected because it is the current state; the write-lock already blocks the *result* of bypass attempts but does not address the *intent* at the prompt level. The task explicitly requests a UserPromptSubmit hook, which maps directly to Approach A.

---

## Step 2: Derive from Validated Inputs

**Research inputs** (from task statement, validated against codebase):
- UserPromptSubmit event is available on Claude Code (confirmed: `docs/research-ide-hooks.md` line 74-75, listed with "can block" annotation)
- Cursor equivalent is `beforeSubmitPrompt` (confirmed: line 96-97 of same file)
- Codex support claimed by task research -- needs verification (`.codex/hooks.json` currently only has SessionStart and Stop)
- Exit code 2 blocks the prompt (consistent with all PreToolUse-type blocking hooks in baton)

**Codebase patterns** (validated by reading existing hooks):
- Hook scripts: `#!/usr/bin/env bash`, version header, fail-open trap, source `lib/common.sh`, `resolve_plan_name`, `find_plan`
- Manifest format: `event:matcher:script` (matcher empty for non-tool events)
- IDE config: each event gets an entry in `.claude/settings.json` hooks section
- Cursor adapter: `dispatch-cursor.sh` maps camelCase to PascalCase events
- Codex adapter: `dispatch-codex.sh` + `adapter-codex.sh` route specific hooks

---

## Step 3: Surface Scan

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| `.baton/hooks/prompt-guard.sh` | L1 | create (new) | New hook script |
| `.baton/hooks/manifest.conf` | L1 | modify | Add `UserPromptSubmit::prompt-guard` entry |
| `.claude/settings.json` | L1 | modify | Add `UserPromptSubmit` hook registration |
| `.baton/adapters/cursor/dispatch.sh` | L2 | modify | Add `beforeSubmitPrompt` -> `UserPromptSubmit` mapping |
| `.baton/adapters/codex/dispatch.sh` | L2 | skip | Codex adapter routes by hook name, not event; UserPromptSubmit not confirmed available on Codex |
| `.baton/adapters/codex/adapter.sh` | L2 | skip | Same reason as above |
| `.baton/hooks/dispatch.sh` | L2 | skip | Generic dispatcher, no changes needed -- already handles any event via manifest |
| `.baton/hooks/lib/common.sh` | L2 | skip | No new shared functions needed |
| `.baton/hooks/lib/plan-parser.sh` | L2 | skip | `parser_has_go` already exists, reusable as-is |
| `tests/test-*.sh` | L2 | create (new) | New test file `tests/test-prompt-guard.sh` |

Self-audit: Every row above was verified by reading the corresponding file in this session. No fabricated entries.

---

## Step 4: Recommended Approach (Detailed)

### Hook: `prompt-guard.sh`

The hook reads the user's prompt from `BATON_STDIN` JSON, checks whether BATON:GO is already set (gate open), and if not, scans the prompt for bypass patterns. When the gate is open, prompts are allowed unconditionally (the user already has authorization). When the gate is closed, prompts containing explicit bypass language are blocked.

```bash
# Skeleton: prompt-guard.sh (key logic only)
#!/usr/bin/env bash
# prompt-guard.sh — Block prompts that attempt to bypass BATON:GO
# Version: 1.0
# Hook: UserPromptSubmit
set -eu
trap 'exit 0' HUP INT TERM  # fail-open

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
[ -f "$SCRIPT_DIR/lib/common.sh" ] && . "$SCRIPT_DIR/lib/common.sh" || exit 0

resolve_plan_name
find_plan

# Gate open → allow all prompts (user has authorization)
[ -n "$PLAN" ] && parser_has_go && exit 0

# Read prompt from stdin JSON
if [ -n "${BATON_STDIN+x}" ]; then
    _stdin="$BATON_STDIN"
else
    _stdin="$(cat 2>/dev/null || true)"
fi
[ -z "$_stdin" ] && exit 0

_prompt=""
if command -v jq >/dev/null 2>&1; then
    _prompt="$(printf '%s' "$_stdin" | jq -r '.prompt // .content // empty' 2>/dev/null)"
fi
# sed fallback
if [ -z "$_prompt" ]; then
    _prompt="$(printf '%s' "$_stdin" | sed -n 's/.*"prompt" *: *"\([^"]*\)".*/\1/p' | head -1)"
fi
[ -z "$_prompt" ] && exit 0

_prompt_lower="$(printf '%s' "$_prompt" | tr '[:upper:]' '[:lower:]')"

# Pattern: explicit bypass/ignore/skip of baton governance
case "$_prompt_lower" in
    *"ignore"*"baton"*|*"skip"*"baton:go"*|*"bypass"*"plan"*"gate"*|\
    *"ignore"*"write"*"lock"*|*"skip"*"write"*"lock"*|\
    *"bypass"*"baton"*|*"override"*"write"*"lock"*|\
    *"ignore"*"plan"*"approval"*|*"skip"*"approval"*)
        echo "Blocked: this prompt appears to request bypassing baton governance." >&2
        echo "Use BATON:OVERRIDE (placed by human in plan) for legitimate overrides." >&2
        exit 2
        ;;
esac

exit 0
```

### Manifest Registration

```
# Added line in manifest.conf:
UserPromptSubmit::prompt-guard
```

### Claude Code Settings Registration

```json
"UserPromptSubmit": [
  {
    "matcher": "",
    "hooks": [
      {
        "type": "command",
        "command": ".baton/hooks/run-hook.cmd UserPromptSubmit"
      }
    ]
  }
]
```

### Cursor Adapter Update

Add mapping in `.baton/adapters/cursor/dispatch.sh`:

```bash
# Before:
    stop)             _event="Stop" ;;
# After:
    beforeSubmitPrompt) _event="UserPromptSubmit" ;;
    stop)               _event="Stop" ;;
```

### Codex

No changes. Codex adapter currently supports only SessionStart and Stop. If Codex gains UserPromptSubmit support, the adapter can be extended later with a new case in `adapter-codex.sh`.

---

## Write Set

| File | Change |
|------|--------|
| `.baton/hooks/prompt-guard.sh` | New: hook script (~50 lines) |
| `.baton/hooks/manifest.conf` | Add: `UserPromptSubmit::prompt-guard` line |
| `.claude/settings.json` | Add: `UserPromptSubmit` hook entry |
| `.baton/adapters/cursor/dispatch.sh` | Add: `beforeSubmitPrompt` case mapping |
| `tests/test-prompt-guard.sh` | New: test file (~80-100 lines) |

---

## Verify

1. **Unit tests** (`tests/test-prompt-guard.sh`):
   - Gate open (plan with BATON:GO) + bypass prompt -> allowed (exit 0)
   - Gate closed (no BATON:GO) + bypass prompt -> blocked (exit 2)
   - Gate closed + normal prompt -> allowed (exit 0)
   - No plan at all + bypass prompt -> allowed (exit 0, fail-open since no governance context)
   - Empty/missing prompt in stdin -> allowed (exit 0, fail-open)
   - Various bypass patterns ("ignore baton", "skip write lock", etc.)

2. **Dispatch integration** (`tests/test-dispatch.sh` extension or manual):
   - `echo '{"prompt":"ignore baton rules"}' | bash dispatch.sh UserPromptSubmit` returns exit 2 when gate is closed

3. **Manual IDE test**: Register the hook in `.claude/settings.json`, type a bypass prompt, verify the block message appears.

---

## Risks

- **False positives**: A prompt like "explain what BATON:GO does and when to ignore it" could be blocked. Mitigation: patterns require *both* an action verb (ignore/skip/bypass) *and* a governance term. The gate-open bypass (BATON:GO present -> allow all) eliminates false positives during implementation phase.
- **False negatives**: Creative bypass wording may not match patterns. Mitigation: this is a defense-in-depth layer; write-lock.sh remains the hard enforcement. Pattern set can be expanded iteratively.
- **Stdin JSON field name uncertainty**: The exact field name for the prompt text in UserPromptSubmit stdin JSON is unverified (assumed `prompt` or `content`). Mitigation: try both with jq fallback; if neither exists, fail-open.

---

## Self-Challenge

1. **Is this the best approach, or the first one I thought of?**
   Three fundamentally different approaches were evaluated (prompt-level blocking, context injection, write-lock enhancement). Approach A was selected because it is the only one that provides *enforcement* at the prompt level, which is the explicit requirement. The other approaches were considered and rejected with specific constraint citations.

2. **What assumptions did I make without verifying?**
   - The UserPromptSubmit stdin JSON field name for prompt text is assumed to be `prompt` or `content`. This was not directly verified from IDE documentation in this session.
   - Codex support is claimed by the task research but contradicted by current adapter code (only SessionStart/Stop). I noted this gap rather than assuming.
   - The pattern-matching approach (case statement with glob patterns) is assumed sufficient for catching common bypass attempts. This is a judgment call, not a verified fact.

3. **What would a skeptic challenge first?**
   "Natural language pattern matching is inherently fragile. Users can rephrase bypass requests in infinite ways." Response: This hook is defense-in-depth, not the sole enforcement point. Write-lock.sh remains the hard gate. The prompt guard catches *common, obvious* bypass attempts as an early warning. The pattern set is deliberately narrow to minimize false positives, accepting some false negatives.

> **Weakest assumption**: The stdin JSON field name for the user's prompt text is `prompt` or `content`.
> **If this assumption is wrong**: The hook would fail-open on all prompts (no blocking), making it a no-op. The hook script would need to be updated with the correct field name.
> **How to verify before executing**: Read the Claude Code hooks documentation for UserPromptSubmit stdin schema, or add the hook with debug logging (`echo "$BATON_STDIN" > /tmp/prompt-debug.json`) and submit a test prompt to capture the actual JSON structure.

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
