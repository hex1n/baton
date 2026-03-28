# Hooks Extension Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add `Stop`, `SubagentStop`, and `SessionStart` hooks to baton's enforcement layer, and migrate all hook commands from hardcoded install-time paths to dynamic `git rev-parse` resolution.

**Architecture:** Each task is strictly TDD — write a failing test, implement until it passes, commit. All blocking hook output is JSON (works on both Claude Code and Codex). `stop_cmd` calls a new `validate-state-artifacts.sh` script; `subagent_stop_cmd` is inline; `session_start_cmd` calls a new `harness-context.sh` script.

**Tech Stack:** bash 3.2+ (macOS compatible), jq, awk, git

**Key files to read before starting:**
- `spec/bootstrap/install-hooks.sh` — current hook installer (lines 60–85 are the command strings)
- `tests/test-install-hooks.sh` — current test suite (17 tests)
- `spec/bootstrap/validate-artifact.sh` — existing validation script (reference for style)
- `docs/plans/2026-03-28-hooks-extension-design.md` — the approved design

---

## Task 1: Migrate hook commands to dynamic `git rev-parse` paths

The four existing command strings in `install-hooks.sh` have `${bootstrap_dir}` baked in at install time. Replace with `git rev-parse --show-toplevel` so hooks survive repo moves.

**Files:**
- Modify: `spec/bootstrap/install-hooks.sh` (lines 66, 69, 79, 84)
- Modify: `tests/test-install-hooks.sh`

**Step 1: Add a failing test**

Add to `tests/test-install-hooks.sh`, after the existing CC assertions (after line 42):

```bash
assert_file_contains "CC commands use git rev-parse" \
  "$repo/.claude/settings.json" "git rev-parse"
assert_file_contains "Codex commands use git rev-parse" \
  "$repo/.codex/hooks.json" "git rev-parse"
```

**Step 2: Run test to verify it fails**

```bash
bash tests/test-install-hooks.sh 2>&1 | grep -E "FAIL|pass|Results"
```

Expected: 2 FAIL lines for git rev-parse assertions.

**Step 3: Replace the four command strings in `install-hooks.sh`**

Replace lines 66–84 (the four `*_cmd` variables) with:

```bash
# ---------------------------------------------------------------------------
# Claude Code hook command strings
# Trigger: Write|Edit|MultiEdit — tool_input has file_path + content
# ---------------------------------------------------------------------------

# PostToolUse: after write to .harness/*.md → validate-artifact.sh
cc_post_cmd="input=\$(cat); fp=\$(echo \"\$input\" | jq -r '.tool_input.file_path // empty' 2>/dev/null); [[ \"\$fp\" == *\".harness/\"*\".md\" ]] || exit 0; root=\$(git rev-parse --show-toplevel 2>/dev/null) || exit 0; at=\$(basename \"\$fp\" .md); bash \"\$root/.vendor/baton-harness/spec/bootstrap/validate-artifact.sh\" \"\$at\" \"\$fp\" # baton-validate-artifact"

# PreToolUse: before write to module-status.md → validate-transition.sh
cc_pre_cmd="input=\$(cat); fp=\$(echo \"\$input\" | jq -r '.tool_input.file_path // empty' 2>/dev/null); [[ \"\$fp\" == *\"module-status.md\" ]] || exit 0; nc=\$(echo \"\$input\" | jq -r '.tool_input.content // empty' 2>/dev/null); [[ -n \"\$nc\" ]] || exit 0; ns=\$(echo \"\$nc\" | awk -F'|' 'NR>2 && NF>3 && \$4!~/---/{gsub(/ /,\"\",\$4); print \$4; exit}'); [[ -n \"\$ns\" ]] || exit 0; [[ -f \"\$fp\" ]] || exit 0; cs=\$(awk -F'|' 'NR>2 && NF>3 && \$4!~/---/{gsub(/ /,\"\",\$4); print \$4; exit}' \"\$fp\"); [[ -n \"\$cs\" ]] || exit 0; root=\$(git rev-parse --show-toplevel 2>/dev/null) || exit 0; bash \"\$root/.vendor/baton-harness/spec/bootstrap/validate-transition.sh\" \"\$cs\" \"\$ns\" # baton-validate-transition"

# ---------------------------------------------------------------------------
# Codex hook command strings
# Trigger: Bash — tool_input has only .command (a bash command string)
# PreToolUse blocks on exit 2 (not exit 1)
# ---------------------------------------------------------------------------

# PostToolUse: after Bash command that wrote to .harness/*.md → validate-artifact.sh
cx_post_cmd="input=\$(cat); cmd=\$(echo \"\$input\" | jq -r '.tool_input.command // empty' 2>/dev/null); [[ -n \"\$cmd\" ]] || exit 0; root=\$(git rev-parse --show-toplevel 2>/dev/null) || exit 0; for fp in \$(echo \"\$cmd\" | grep -oE '\\.harness/[A-Za-z0-9_-]+\\.md' | sort -u); do [[ -f \"\$fp\" ]] || continue; at=\$(basename \"\$fp\" .md); bash \"\$root/.vendor/baton-harness/spec/bootstrap/validate-artifact.sh\" \"\$at\" \"\$fp\"; done # baton-validate-artifact"

# PreToolUse: before Bash command that writes to module-status.md → validate-transition.sh
cx_state_names="exploring|specifying|architecting|awaiting_human_arch|verification_check|generating|reviewing|ready_for_human_close|complete|blocked"
cx_pre_cmd="input=\$(cat); cmd=\$(echo \"\$input\" | jq -r '.tool_input.command // empty' 2>/dev/null); echo \"\$cmd\" | grep -qF '.harness/module-status.md' || exit 0; ns=\$(echo \"\$cmd\" | grep -oE '\\| *(${cx_state_names}) *\\|' | head -1 | tr -d '| '); [[ -n \"\$ns\" ]] || exit 0; [[ -f \".harness/module-status.md\" ]] || exit 0; root=\$(git rev-parse --show-toplevel 2>/dev/null) || exit 0; cs=\$(awk -F'|' 'NR>2 && NF>3 && \$4!~/---/{gsub(/ /,\"\",\$4); print \$4; exit}' \".harness/module-status.md\"); [[ -n \"\$cs\" ]] || exit 0; bash \"\$root/.vendor/baton-harness/spec/bootstrap/validate-transition.sh\" \"\$cs\" \"\$ns\" || exit 2 # baton-validate-transition"
```

**Step 4: Run tests to verify they pass**

```bash
bash tests/test-install-hooks.sh 2>&1 | tail -3
```

Expected: `Results: 19 passed, 0 failed of 19 total`

**Step 5: Commit**

```bash
git add spec/bootstrap/install-hooks.sh tests/test-install-hooks.sh
git commit -m "refactor(hooks): migrate command strings to git rev-parse dynamic paths"
```

---

## Task 2: `validate-state-artifacts.sh` — script + tests

New script: checks that required artifacts for the current harness state exist. Used by the `Stop` hook.

**Files:**
- Create: `spec/bootstrap/validate-state-artifacts.sh`
- Create: `tests/test-validate-state-artifacts.sh`

**Step 1: Write the failing tests**

Create `tests/test-validate-state-artifacts.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../spec/bootstrap/validate-state-artifacts.sh"
PASS=0; FAIL=0; TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

assert_exit() {
  local label="$1" expected="$2"; shift 2
  TOTAL=$((TOTAL+1))
  local actual=0; "$@" >/dev/null 2>&1 || actual=$?
  if [[ "$actual" -eq "$expected" ]]; then echo "  pass: $label"; PASS=$((PASS+1))
  else echo "  FAIL: $label — expected exit $expected got $actual"; FAIL=$((FAIL+1)); fi
}

assert_json_block() {
  local label="$1" harness="$2"
  TOTAL=$((TOTAL+1))
  local out; out=$(bash "$SCRIPT" "$harness" 2>/dev/null || true)
  if echo "$out" | jq -e '.decision == "block"' >/dev/null 2>&1; then
    echo "  pass: $label"; PASS=$((PASS+1))
  else
    echo "  FAIL: $label — output is not valid JSON block: $out"; FAIL=$((FAIL+1))
  fi
}

make_status() {
  local dir="$1" state="$2"
  mkdir -p "$dir"
  cat > "$dir/module-status.md" <<EOF
| Scope | Owner | State | Eval Round | Updated At | Notes |
|-------|-------|-------|------------|------------|-------|
| task1 | generator | $state | 0 | 2026-03-28 | - |
EOF
}

# no module-status.md → exit 0
assert_exit "no module-status → pass" 0 bash "$SCRIPT" "$tmp/empty"

# state=exploring → no artifacts required → exit 0
make_status "$tmp/t1" "exploring"
assert_exit "exploring → no artifacts required" 0 bash "$SCRIPT" "$tmp/t1"

# state=blocked → no artifact check → exit 0
make_status "$tmp/t2" "blocked"
assert_exit "blocked → no artifact check" 0 bash "$SCRIPT" "$tmp/t2"

# state=specifying, scoped-map.md present → exit 0
make_status "$tmp/t3" "specifying"
touch "$tmp/t3/scoped-map.md"
assert_exit "specifying + scoped-map present → pass" 0 bash "$SCRIPT" "$tmp/t3"

# state=specifying, scoped-map.md missing → exit 2
make_status "$tmp/t4" "specifying"
assert_exit "specifying + scoped-map missing → block" 2 bash "$SCRIPT" "$tmp/t4"

# state=generating, all artifacts present → exit 0
make_status "$tmp/t5" "generating"
touch "$tmp/t5/scoped-map.md" "$tmp/t5/requirements.md" "$tmp/t5/architecture.md" "$tmp/t5/verification-path.md"
assert_exit "generating + all artifacts → pass" 0 bash "$SCRIPT" "$tmp/t5"

# state=generating, verification-path.md missing → exit 2
make_status "$tmp/t6" "generating"
touch "$tmp/t6/scoped-map.md" "$tmp/t6/requirements.md" "$tmp/t6/architecture.md"
assert_exit "generating + verification-path missing → block" 2 bash "$SCRIPT" "$tmp/t6"

# exit 2 output is valid JSON with decision:block
assert_json_block "block output is JSON with decision:block" "$tmp/t6"

echo ""; echo "Results: $PASS passed, $FAIL failed of $TOTAL total"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
```

**Step 2: Run tests to verify they fail**

```bash
bash tests/test-validate-state-artifacts.sh 2>&1
```

Expected: multiple FAIL lines (script doesn't exist yet).

**Step 3: Create `spec/bootstrap/validate-state-artifacts.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

harness_dir="${1:-.harness}"
module_status="$harness_dir/module-status.md"

[[ -f "$module_status" ]] || exit 0

state=$(awk -F'|' 'NR>2 && NF>3 && $4!~/---/{gsub(/ /,"",$4); print $4; exit}' "$module_status")
[[ -n "$state" ]] || exit 0

required_for_state() {
  case "$1" in
    specifying)
      echo "scoped-map.md" ;;
    architecting)
      echo "scoped-map.md requirements.md" ;;
    awaiting_human_arch|verification_check)
      echo "scoped-map.md requirements.md architecture.md" ;;
    generating|reviewing|ready_for_human_close|complete)
      echo "scoped-map.md requirements.md architecture.md verification-path.md" ;;
    *)
      echo "" ;;
  esac
}

missing=()
for artifact in $(required_for_state "$state"); do
  [[ -f "$harness_dir/$artifact" ]] || missing+=("$harness_dir/$artifact")
done

[[ ${#missing[@]} -eq 0 ]] && exit 0

list=""
for f in "${missing[@]}"; do
  list+="  - $f"$'\n'
done

reason="State is \"$state\" but missing required artifacts:"$'\n'"${list}"$'Write the missing artifacts before finishing this turn.'
jq -n --arg r "$reason" '{"decision":"block","reason":$r}'
exit 2
```

**Step 4: Make executable and run tests**

```bash
chmod +x spec/bootstrap/validate-state-artifacts.sh
bash tests/test-validate-state-artifacts.sh 2>&1
```

Expected: `Results: 8 passed, 0 failed of 8 total`

**Step 5: Commit**

```bash
git add spec/bootstrap/validate-state-artifacts.sh tests/test-validate-state-artifacts.sh
git commit -m "feat(bootstrap): add validate-state-artifacts.sh for Stop hook enforcement"
```

---

## Task 3: Add `Stop` hook to `install-hooks.sh`

Fires when Claude finishes a turn. Calls `validate-state-artifacts.sh`. Works on both CC and Codex. No matcher.

**Files:**
- Modify: `spec/bootstrap/install-hooks.sh`
- Modify: `tests/test-install-hooks.sh`

**Step 1: Write failing tests**

Add to `tests/test-install-hooks.sh` after the SessionStart section (before the dry-run test):

```bash
# Stop hooks
assert_file_contains "CC Stop hook written"             "$repo/.claude/settings.json" '"Stop"'
assert_file_contains "CC Stop uses validate-state"      "$repo/.claude/settings.json" "validate-state-artifacts"
assert_file_contains "Codex Stop hook written"          "$repo/.codex/hooks.json"     '"Stop"'
assert_file_contains "Codex Stop has statusMessage"     "$repo/.codex/hooks.json"     "Checking harness state"

# Stop idempotent
bash "$INSTALL_HOOKS" --repo-root "$repo" --bootstrap-dir "$bootstrap" >/dev/null 2>&1
cc_stop_count="$(grep -c '"Stop"' "$repo/.claude/settings.json")"
TOTAL=$((TOTAL+1))
if [[ "$cc_stop_count" -eq 1 ]]; then
  echo "  pass: CC Stop idempotent — not duplicated"
  PASS=$((PASS+1))
else
  echo "  FAIL: CC Stop appears $cc_stop_count times"
  FAIL=$((FAIL+1))
fi
```

**Step 2: Run tests to verify they fail**

```bash
bash tests/test-install-hooks.sh 2>&1 | grep -E "FAIL|Results"
```

Expected: 5 FAIL lines for Stop assertions.

**Step 3: Add Stop hook support to `install-hooks.sh`**

After the `cx_pre_cmd` block (around line 85), add:

```bash
# ---------------------------------------------------------------------------
# Stop hook command string (same for Claude Code and Codex — outputs JSON)
# No matcher: Stop has no matcher support on either platform
# ---------------------------------------------------------------------------
stop_cmd="root=\$(git rev-parse --show-toplevel 2>/dev/null) || exit 0; [[ -f \"\$root/.harness/module-status.md\" ]] || exit 0; bash \"\$root/.vendor/baton-harness/spec/bootstrap/validate-state-artifacts.sh\" \"\$root/.harness\" # baton-validate-state"
```

In the `# Install Claude Code hooks` jq block, add to the jq program (after the existing `new_pre_entry` def):

```jq
def strip_baton_stop:
  if type == "array" then
    map(
      if type == "object" and (.hooks // [] | map(.command // "") | any(test("baton-validate-state"))) then
        empty
      else .
      end
    )
  else [] end;

def new_cc_stop_entry:
  {"hooks": [{"type": "command", "command": $stop_cmd}]};

.hooks.Stop = ((.hooks.Stop | strip_baton_stop) + [new_cc_stop_entry])
```

Add `--arg stop_cmd "$stop_cmd"` to the jq call.

In the `# Install Codex hooks` jq block, add similarly but with `statusMessage` and `timeout`:

```jq
def new_cx_stop_entry:
  {"hooks": [{"type": "command", "command": $stop_cmd, "statusMessage": "Checking harness state", "timeout": 30}]};

.hooks.Stop = ((.hooks.Stop | strip_baton_stop) + [new_cx_stop_entry])
```

Add `--arg stop_cmd "$stop_cmd"` to the Codex jq call.

After writing both files, add the printf:

```bash
printf 'install-hooks: wrote Stop hook to %s and %s\n' "$cc_settings" "$cx_hooks"
```

**Step 4: Run tests to verify they pass**

```bash
bash tests/test-install-hooks.sh 2>&1 | tail -3
```

Expected: `Results: 24 passed, 0 failed of 24 total`

**Step 5: Commit**

```bash
git add spec/bootstrap/install-hooks.sh tests/test-install-hooks.sh
git commit -m "feat(hooks): add Stop hook — turn-end artifact completeness enforcement"
```

---

## Task 4: Add `SubagentStop` hook to `install-hooks.sh`

Claude Code only. Fires when `baton-evaluator` or `baton-verifier` subagent completes. Validates the subagent wrote its required artifact.

**Files:**
- Modify: `spec/bootstrap/install-hooks.sh`
- Modify: `tests/test-install-hooks.sh`

**Step 1: Write failing tests**

Add to `tests/test-install-hooks.sh`:

```bash
# SubagentStop (CC only)
assert_file_contains "CC SubagentStop written"            "$repo/.claude/settings.json" '"SubagentStop"'
assert_file_contains "CC SubagentStop matcher is agents"  "$repo/.claude/settings.json" "baton-evaluator"
assert_file_contains "CC SubagentStop checks agent_type"  "$repo/.claude/settings.json" "agent_type"
TOTAL=$((TOTAL+1))
if ! grep -q '"SubagentStop"' "$repo/.codex/hooks.json" 2>/dev/null; then
  echo "  pass: Codex has no SubagentStop"
  PASS=$((PASS+1))
else
  echo "  FAIL: Codex should not have SubagentStop"
  FAIL=$((FAIL+1))
fi
```

**Step 2: Run tests to verify they fail**

```bash
bash tests/test-install-hooks.sh 2>&1 | grep -E "FAIL|Results"
```

Expected: 4 FAIL lines for SubagentStop assertions.

**Step 3: Add SubagentStop to `install-hooks.sh`**

Add command string after the `stop_cmd` block:

```bash
# ---------------------------------------------------------------------------
# SubagentStop command string (Claude Code only)
# Matcher: baton-evaluator|baton-verifier
# Validates fork agent wrote its required artifact before parent is notified
# ---------------------------------------------------------------------------
subagent_stop_cmd="input=\$(cat); agent=\$(echo \"\$input\" | jq -r '.agent_type // empty' 2>/dev/null); case \"\$agent\" in baton-verifier|baton-evaluator) ;; *) exit 0 ;; esac; root=\$(git rev-parse --show-toplevel 2>/dev/null) || exit 0; bootstrap=\"\$root/.vendor/baton-harness/spec/bootstrap\"; case \"\$agent\" in baton-verifier) [[ -f \"\$root/.harness/verification-path.md\" ]] || { jq -n '{\"decision\":\"block\",\"reason\":\"baton-verifier completed without writing verification-path.md\"}'; exit 2; }; bash \"\$bootstrap/validate-artifact.sh\" verification-path \"\$root/.harness/verification-path.md\" || exit 2 ;; baton-evaluator) state=\$(awk -F'|' 'NR>2 && NF>3 && \$4!~/---/{gsub(/ /,\"\",\$4); print \$4; exit}' \"\$root/.harness/module-status.md\" 2>/dev/null); case \"\$state\" in blocked|reviewing|ready_for_human_close) ;; *) jq -n --arg s \"\$state\" '{\"decision\":\"block\",\"reason\":(\"baton-evaluator completed but module-status state is \\\\\"\" + \$s + \"\\\\\"\")}'; exit 2 ;; esac ;; esac # baton-subagent-stop"
```

In the Claude Code jq block, add:

```jq
def strip_baton_subagent:
  if type == "array" then
    map(
      if type == "object" and (.hooks // [] | map(.command // "") | any(test("baton-subagent-stop"))) then
        empty
      else .
      end
    )
  else [] end;

def new_subagent_stop_entry:
  {"matcher": "baton-evaluator|baton-verifier",
   "hooks": [{"type": "command", "command": $subagent_cmd}]};

.hooks.SubagentStop = ((.hooks.SubagentStop | strip_baton_subagent) + [new_subagent_stop_entry])
```

Add `--arg subagent_cmd "$subagent_stop_cmd"` to the CC jq call only (not Codex).

**Step 4: Run tests to verify they pass**

```bash
bash tests/test-install-hooks.sh 2>&1 | tail -3
```

Expected: `Results: 28 passed, 0 failed of 28 total`

**Step 5: Commit**

```bash
git add spec/bootstrap/install-hooks.sh tests/test-install-hooks.sh
git commit -m "feat(hooks): add SubagentStop hook — fork agent output validation (CC only)"
```

---

## Task 5: `harness-context.sh` — script + tests

New script: reads `.harness/module-status.md` and outputs JSON for `SessionStart` context injection.

**Files:**
- Create: `spec/bootstrap/harness-context.sh`
- Create: `tests/test-harness-context.sh`

**Step 1: Write failing tests**

Create `tests/test-harness-context.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../spec/bootstrap/harness-context.sh"
PASS=0; FAIL=0; TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

assert_json_field() {
  local label="$1" harness="$2" jq_expr="$3"
  TOTAL=$((TOTAL+1))
  local out; out=$(bash "$SCRIPT" "$harness" 2>/dev/null)
  if echo "$out" | jq -e "$jq_expr" >/dev/null 2>&1; then
    echo "  pass: $label"; PASS=$((PASS+1))
  else
    echo "  FAIL: $label — jq '$jq_expr' failed on: $out"; FAIL=$((FAIL+1))
  fi
}

make_status() {
  local dir="$1" state="$2"
  mkdir -p "$dir"
  cat > "$dir/module-status.md" <<EOF
| Scope | Owner | State | Eval Round | Updated At | Notes |
|-------|-------|-------|------------|------------|-------|
| task-abc | generator | $state | 1 | 2026-03-28 | - |
EOF
}

# no module-status → valid JSON, hookEventName=SessionStart, "No active"
assert_json_field "no task: valid JSON"           "$tmp/empty" '.hookSpecificOutput.hookEventName == "SessionStart"'
assert_json_field "no task: no-task message"      "$tmp/empty" '.hookSpecificOutput.additionalContext | test("No active")'

# active task: contains state and task id
make_status "$tmp/t1" "generating"
assert_json_field "active task: hookEventName"    "$tmp/t1" '.hookSpecificOutput.hookEventName == "SessionStart"'
assert_json_field "active task: contains state"   "$tmp/t1" '.hookSpecificOutput.additionalContext | test("generating")'
assert_json_field "active task: contains task-id" "$tmp/t1" '.hookSpecificOutput.additionalContext | test("task-abc")'
assert_json_field "active task: contains owner"   "$tmp/t1" '.hookSpecificOutput.additionalContext | test("generator")'
assert_json_field "active task: contains eval_round" "$tmp/t1" '.hookSpecificOutput.additionalContext | test("1")'

# missing artifacts appear in output
make_status "$tmp/t2" "generating"
touch "$tmp/t2/scoped-map.md" "$tmp/t2/requirements.md"
assert_json_field "missing artifacts listed"      "$tmp/t2" '.hookSpecificOutput.additionalContext | test("missing")'

# present artifacts appear in output
touch "$tmp/t2/architecture.md" "$tmp/t2/verification-path.md"
assert_json_field "present artifacts listed"      "$tmp/t2" '.hookSpecificOutput.additionalContext | test("present")'

echo ""; echo "Results: $PASS passed, $FAIL failed of $TOTAL total"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
```

**Step 2: Run tests to verify they fail**

```bash
bash tests/test-harness-context.sh 2>&1
```

Expected: multiple FAIL lines.

**Step 3: Create `spec/bootstrap/harness-context.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

harness_dir="${1:-.harness}"
module_status="$harness_dir/module-status.md"

if [[ ! -f "$module_status" ]]; then
  jq -n '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"No active harness task."}}'
  exit 0
fi

state=$(awk    -F'|' 'NR>2 && NF>3 && $4!~/---/{gsub(/ /,"",$4); print $4; exit}' "$module_status")
owner=$(awk    -F'|' 'NR>2 && NF>3 && $3!~/---/{gsub(/ /,"",$3); print $3; exit}' "$module_status")
task_id=$(awk  -F'|' 'NR>2 && NF>2 && $2!~/---/{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2; exit}' "$module_status")
eval_round=$(awk -F'|' 'NR>2 && NF>5 && $5!~/---/{gsub(/ /,"",$5); print $5; exit}' "$module_status")

required_for_state() {
  case "$1" in
    specifying)           echo "scoped-map.md" ;;
    architecting)         echo "scoped-map.md requirements.md" ;;
    awaiting_human_arch|verification_check) echo "scoped-map.md requirements.md architecture.md" ;;
    generating|reviewing|ready_for_human_close|complete) echo "scoped-map.md requirements.md architecture.md verification-path.md" ;;
    *)                    echo "" ;;
  esac
}

present="" missing=""
for artifact in $(required_for_state "$state"); do
  if [[ -f "$harness_dir/$artifact" ]]; then
    present="${present:+$present, }$artifact"
  else
    missing="${missing:+$missing, }$artifact"
  fi
done

ctx="Harness task active:"
ctx+=$'\n'"  task: ${task_id:-?}  state: ${state:-?}  owner: ${owner:-?}  eval_round: ${eval_round:-0}"
[[ -n "$present" ]] && ctx+=$'\n'"  present: $present"
[[ -n "$missing" ]] && ctx+=$'\n'"  missing: $missing"

jq -n --arg ctx "$ctx" \
  '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":$ctx}}'
```

**Step 4: Make executable and run tests**

```bash
chmod +x spec/bootstrap/harness-context.sh
bash tests/test-harness-context.sh 2>&1
```

Expected: `Results: 9 passed, 0 failed of 9 total`

**Step 5: Commit**

```bash
git add spec/bootstrap/harness-context.sh tests/test-harness-context.sh
git commit -m "feat(bootstrap): add harness-context.sh for SessionStart context injection"
```

---

## Task 6: Add `SessionStart` hook to `install-hooks.sh`

Both CC and Codex. Matcher: `startup|resume`. Calls `harness-context.sh`. Codex gets `statusMessage`.

**Files:**
- Modify: `spec/bootstrap/install-hooks.sh`
- Modify: `tests/test-install-hooks.sh`

**Step 1: Write failing tests**

Add to `tests/test-install-hooks.sh`:

```bash
# SessionStart
assert_file_contains "CC SessionStart written"           "$repo/.claude/settings.json" '"SessionStart"'
assert_file_contains "CC SessionStart matcher"           "$repo/.claude/settings.json" "startup|resume"
assert_file_contains "CC SessionStart calls harness-context" "$repo/.claude/settings.json" "harness-context"
assert_file_contains "Codex SessionStart written"        "$repo/.codex/hooks.json"     '"SessionStart"'
assert_file_contains "Codex SessionStart has statusMessage" "$repo/.codex/hooks.json"  "Loading harness context"
```

**Step 2: Run tests to verify they fail**

```bash
bash tests/test-install-hooks.sh 2>&1 | grep -E "FAIL|Results"
```

Expected: 5 FAIL lines for SessionStart assertions.

**Step 3: Add SessionStart to `install-hooks.sh`**

Add command string after the `subagent_stop_cmd` block:

```bash
# ---------------------------------------------------------------------------
# SessionStart command string (Claude Code + Codex)
# Matcher: startup|resume
# Reads .harness/module-status.md and injects current task state as context
# ---------------------------------------------------------------------------
session_start_cmd="root=\$(git rev-parse --show-toplevel 2>/dev/null) || exit 0; bash \"\$root/.vendor/baton-harness/spec/bootstrap/harness-context.sh\" \"\$root/.harness\" # baton-harness-context"
```

In the Claude Code jq block, add:

```jq
def strip_baton_session:
  if type == "array" then
    map(
      if type == "object" and (.hooks // [] | map(.command // "") | any(test("baton-harness-context"))) then
        empty
      else .
      end
    )
  else [] end;

def new_cc_session_entry:
  {"matcher": "startup|resume",
   "hooks": [{"type": "command", "command": $session_cmd}]};

.hooks.SessionStart = ((.hooks.SessionStart | strip_baton_session) + [new_cc_session_entry])
```

Add `--arg session_cmd "$session_start_cmd"` to the CC jq call.

In the Codex jq block, add similarly with `statusMessage`:

```jq
def new_cx_session_entry:
  {"matcher": "startup|resume",
   "hooks": [{"type": "command", "command": $session_cmd, "statusMessage": "Loading harness context"}]};

.hooks.SessionStart = ((.hooks.SessionStart | strip_baton_session) + [new_cx_session_entry])
```

Add `--arg session_cmd "$session_start_cmd"` to the Codex jq call.

**Step 4: Run tests to verify they pass**

```bash
bash tests/test-install-hooks.sh 2>&1 | tail -3
```

Expected: `Results: 33 passed, 0 failed of 33 total`

**Step 5: Commit**

```bash
git add spec/bootstrap/install-hooks.sh tests/test-install-hooks.sh
git commit -m "feat(hooks): add SessionStart hook — harness context injection on session start"
```

---

## Task 7: Full verification + reinstall dev repo hooks

**Step 1: Run all test suites**

```bash
bash tests/test-validate-artifact.sh && \
bash tests/test-validate-transition.sh && \
bash tests/test-install-hooks.sh && \
bash tests/test-validate-state-artifacts.sh && \
bash tests/test-harness-context.sh
```

Expected: all suites pass.

**Step 2: Run check-consistency.sh**

```bash
bash spec/bootstrap/check-consistency.sh 2>&1 | tail -3
```

Expected: `all invariants OK`

**Step 3: Reinstall hooks in dev repo**

```bash
bash spec/bootstrap/install-hooks.sh \
  --repo-root . \
  --bootstrap-dir spec/bootstrap 2>&1
```

Expected output (all 5 hook types written):
```
install-hooks: wrote Claude Code hooks to ./.claude/settings.json
install-hooks: wrote Codex hooks to ./.codex/hooks.json
install-hooks: wrote Codex feature flag to ./.codex/config.toml
```

**Step 4: Verify settings.json has all hooks**

```bash
python3 -c "
import sys, json
d = json.load(open('.claude/settings.json'))
hooks = d.get('hooks', {})
for k in ['PostToolUse','PreToolUse','Stop','SubagentStop','SessionStart']:
    n = len(hooks.get(k, []))
    print(f'{k}: {n} entr{\"ies\" if n != 1 else \"y\"}')"
```

Expected:
```
PostToolUse: 1 entry
PreToolUse: 1 entry
Stop: 1 entry
SubagentStop: 1 entry
SessionStart: 1 entry
```

**Step 5: Commit**

```bash
git add .claude/settings.json .codex/hooks.json .codex/config.toml
git commit -m "chore(hooks): reinstall hooks in dev repo — all 5 hook types active"
```
