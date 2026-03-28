#!/usr/bin/env bash
# install-hooks.sh — register baton validate-artifact + validate-transition as platform hooks
#
# Usage: install-hooks.sh --repo-root PATH --bootstrap-dir PATH [--dry-run]
#
# Installs hooks for both Claude Code and Codex:
#   Claude Code: PostToolUse + PreToolUse in .claude/settings.json
#   Codex:       PostToolUse + PreToolUse in .codex/hooks.json
#                feature flag in .codex/config.toml
#
# All operations are idempotent: existing baton-owned entries (identified by
# marker strings "# baton-validate-artifact" / "# baton-validate-transition")
# are replaced, not duplicated.
#
# Exit 0: success (or dry-run)
# Exit 1: error (missing jq, missing args)
set -euo pipefail

repo_root=""
bootstrap_dir=""
dry_run=false

# -- argument parsing --
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      repo_root="${2:-}"
      shift 2
      ;;
    --bootstrap-dir)
      bootstrap_dir="${2:-}"
      shift 2
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    *)
      printf 'ERROR: install-hooks: unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$repo_root" ]]; then
  printf 'ERROR: install-hooks: --repo-root is required\n' >&2
  exit 1
fi

if [[ -z "$bootstrap_dir" ]]; then
  printf 'ERROR: install-hooks: --bootstrap-dir is required\n' >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  printf 'ERROR: install-hooks: jq is required but not found in PATH\n' >&2
  exit 1
fi

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
# Extract target state from known state names present in the command string.
# Exit 2 (not 1) to signal Codex to block the pending tool call.
cx_state_names="exploring|specifying|architecting|awaiting_human_arch|verification_check|generating|reviewing|ready_for_human_close|complete|blocked"
cx_pre_cmd="input=\$(cat); cmd=\$(echo \"\$input\" | jq -r '.tool_input.command // empty' 2>/dev/null); echo \"\$cmd\" | grep -qF '.harness/module-status.md' || exit 0; ns=\$(echo \"\$cmd\" | grep -oE '\\| *(${cx_state_names}) *\\|' | head -1 | tr -d '| '); [[ -n \"\$ns\" ]] || exit 0; [[ -f \".harness/module-status.md\" ]] || exit 0; root=\$(git rev-parse --show-toplevel 2>/dev/null) || exit 0; cs=\$(awk -F'|' 'NR>2 && NF>3 && \$4!~/---/{gsub(/ /,\"\",\$4); print \$4; exit}' \".harness/module-status.md\"); [[ -n \"\$cs\" ]] || exit 0; bash \"\$root/.vendor/baton-harness/spec/bootstrap/validate-transition.sh\" \"\$cs\" \"\$ns\" || exit 2 # baton-validate-transition"

# ---------------------------------------------------------------------------
# Stop hook command string (Claude Code + Codex — outputs JSON)
# No matcher: Stop has no matcher support on either platform
# ---------------------------------------------------------------------------
stop_cmd="[[ -f \".harness/module-status.md\" ]] || exit 0; root=\$(git rev-parse --show-toplevel 2>/dev/null) || exit 0; bash \"\$root/.vendor/baton-harness/spec/bootstrap/validate-state-artifacts.sh\" \"\$root/.harness\" # baton-validate-state"

# ---------------------------------------------------------------------------
# SubagentStop command string (Claude Code only)
# Matcher: baton-evaluator|baton-verifier
# Reads agent_type field; validates fork agent wrote its required artifact
# ---------------------------------------------------------------------------
subagent_stop_cmd="input=\$(cat); agent=\$(echo \"\$input\" | jq -r '.agent_type // empty' 2>/dev/null); case \"\$agent\" in baton-verifier|baton-evaluator) ;; *) exit 0 ;; esac; root=\$(git rev-parse --show-toplevel 2>/dev/null) || exit 0; bootstrap=\"\$root/.vendor/baton-harness/spec/bootstrap\"; case \"\$agent\" in baton-verifier) [[ -f \"\$root/.harness/verification-path.md\" ]] || { jq -n '{\"decision\":\"block\",\"reason\":\"baton-verifier completed without writing verification-path.md\"}'; exit 2; }; bash \"\$bootstrap/validate-artifact.sh\" verification-path \"\$root/.harness/verification-path.md\" || exit 2 ;; baton-evaluator) state=\$(awk -F'|' 'NF>3 && \$4!~/---/ && \$4!~/^[[:space:]]*State[[:space:]]*\$/{gsub(/ /,\"\",\$4); print \$4; exit}' \"\$root/.harness/module-status.md\" 2>/dev/null); case \"\$state\" in blocked|reviewing|ready_for_human_close) ;; *) jq -n --arg s \"\$state\" '{\"decision\":\"block\",\"reason\":(\"baton-evaluator completed but module-status state is \\\\\"\" + \$s + \"\\\\\"\")}'; exit 2 ;; esac ;; esac # baton-subagent-stop"

# ---------------------------------------------------------------------------
# SessionStart command string (Claude Code + Codex)
# Matcher: startup|resume
# Reads .harness/module-status.md and injects current task state as context
# ---------------------------------------------------------------------------
session_start_cmd="root=\$(git rev-parse --show-toplevel 2>/dev/null) || exit 0; bash \"\$root/.vendor/baton-harness/spec/bootstrap/harness-context.sh\" \"\$root/.harness\" # baton-harness-context"

# ---------------------------------------------------------------------------
# Dry-run: print what would be written, then exit
# ---------------------------------------------------------------------------
if [[ "$dry_run" == true ]]; then
  printf '[dry-run] Claude Code: would write hooks to: %s/.claude/settings.json\n' "$repo_root"
  printf '[dry-run] CC PostToolUse command:\n  %s\n' "$cc_post_cmd"
  printf '[dry-run] CC PreToolUse command:\n  %s\n' "$cc_pre_cmd"
  printf '[dry-run] Codex: would write hooks to: %s/.codex/hooks.json\n' "$repo_root"
  printf '[dry-run] Codex feature flag: %s/.codex/config.toml\n' "$repo_root"
  printf '[dry-run] Codex PostToolUse command:\n  %s\n' "$cx_post_cmd"
  printf '[dry-run] Codex PreToolUse command:\n  %s\n' "$cx_pre_cmd"
  exit 0
fi

# ---------------------------------------------------------------------------
# Install Claude Code hooks → .claude/settings.json
# ---------------------------------------------------------------------------
cc_settings="$repo_root/.claude/settings.json"
mkdir -p "$repo_root/.claude"

if [[ -f "$cc_settings" ]]; then
  cc_existing="$(cat "$cc_settings")"
else
  cc_existing="{}"
fi

cc_new="$(echo "$cc_existing" | jq \
  --arg post_cmd "$cc_post_cmd" \
  --arg pre_cmd "$cc_pre_cmd" \
  --arg stop_cmd "$stop_cmd" \
  --arg subagent_cmd "$subagent_stop_cmd" \
  --arg session_cmd "$session_start_cmd" \
  '
  def strip_baton_post:
    if type == "array" then
      map(
        if type == "object" and (.hooks // [] | map(.command // "") | any(test("baton-validate-artifact"))) then
          empty
        else
          .
        end
      )
    else
      []
    end;

  def strip_baton_pre:
    if type == "array" then
      map(
        if type == "object" and (.hooks // [] | map(.command // "") | any(test("baton-validate-transition"))) then
          empty
        else
          .
        end
      )
    else
      []
    end;

  def strip_baton_stop:
    if type == "array" then
      map(
        if type == "object" and (.hooks // [] | map(.command // "") | any(test("baton-validate-state"))) then
          empty
        else .
        end
      )
    else [] end;

  def new_post_entry:
    {
      "matcher": "Write|Edit|MultiEdit",
      "hooks": [
        { "type": "command", "command": $post_cmd }
      ]
    };

  def new_pre_entry:
    {
      "matcher": "Write|Edit|MultiEdit",
      "hooks": [
        { "type": "command", "command": $pre_cmd }
      ]
    };

  def new_cc_stop_entry:
    {"hooks": [{"type": "command", "command": $stop_cmd}]};

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

  .hooks.PostToolUse = ((.hooks.PostToolUse | strip_baton_post) + [new_post_entry])
  | .hooks.PreToolUse = ((.hooks.PreToolUse | strip_baton_pre) + [new_pre_entry])
  | .hooks.Stop = ((.hooks.Stop | strip_baton_stop) + [new_cc_stop_entry])
  | .hooks.SubagentStop = ((.hooks.SubagentStop | strip_baton_subagent) + [new_subagent_stop_entry])
  | .hooks.SessionStart = ((.hooks.SessionStart | strip_baton_session) + [new_cc_session_entry])
  '
)"

printf '%s\n' "$cc_new" > "$cc_settings"
printf 'install-hooks: wrote Claude Code hooks to %s\n' "$cc_settings"

# ---------------------------------------------------------------------------
# Install Codex hooks → .codex/hooks.json
# ---------------------------------------------------------------------------
cx_dir="$repo_root/.codex"
cx_hooks="$cx_dir/hooks.json"
mkdir -p "$cx_dir"

if [[ -f "$cx_hooks" ]]; then
  cx_existing="$(cat "$cx_hooks")"
else
  cx_existing="{}"
fi

cx_new="$(echo "$cx_existing" | jq \
  --arg post_cmd "$cx_post_cmd" \
  --arg pre_cmd "$cx_pre_cmd" \
  --arg stop_cmd "$stop_cmd" \
  --arg session_cmd "$session_start_cmd" \
  '
  def strip_baton_post:
    if type == "array" then
      map(
        if type == "object" and (.hooks // [] | map(.command // "") | any(test("baton-validate-artifact"))) then
          empty
        else
          .
        end
      )
    else
      []
    end;

  def strip_baton_pre:
    if type == "array" then
      map(
        if type == "object" and (.hooks // [] | map(.command // "") | any(test("baton-validate-transition"))) then
          empty
        else
          .
        end
      )
    else
      []
    end;

  def strip_baton_stop:
    if type == "array" then
      map(
        if type == "object" and (.hooks // [] | map(.command // "") | any(test("baton-validate-state"))) then
          empty
        else .
        end
      )
    else [] end;

  def new_post_entry:
    {
      "matcher": "Bash",
      "hooks": [
        { "type": "command", "command": $post_cmd }
      ]
    };

  def new_pre_entry:
    {
      "matcher": "Bash",
      "hooks": [
        { "type": "command", "command": $pre_cmd }
      ]
    };

  def new_cx_stop_entry:
    {"hooks": [{"type": "command", "command": $stop_cmd, "statusMessage": "Checking harness state", "timeout": 30}]};

  def strip_baton_session:
    if type == "array" then
      map(
        if type == "object" and (.hooks // [] | map(.command // "") | any(test("baton-harness-context"))) then
          empty
        else .
        end
      )
    else [] end;

  def new_cx_session_entry:
    {"matcher": "startup|resume",
     "hooks": [{"type": "command", "command": $session_cmd, "statusMessage": "Loading harness context"}]};

  .hooks.PostToolUse = ((.hooks.PostToolUse | strip_baton_post) + [new_post_entry])
  | .hooks.PreToolUse = ((.hooks.PreToolUse | strip_baton_pre) + [new_pre_entry])
  | .hooks.Stop = ((.hooks.Stop | strip_baton_stop) + [new_cx_stop_entry])
  | .hooks.SessionStart = ((.hooks.SessionStart | strip_baton_session) + [new_cx_session_entry])
  '
)"

printf '%s\n' "$cx_new" > "$cx_hooks"
printf 'install-hooks: wrote Codex hooks to %s\n' "$cx_hooks"

# ---------------------------------------------------------------------------
# Codex feature flag → .codex/config.toml (idempotent)
# ---------------------------------------------------------------------------
cx_config="$cx_dir/config.toml"

if [[ -f "$cx_config" ]] && grep -q 'codex_hooks' "$cx_config"; then
  printf 'install-hooks: Codex feature flag already present in %s\n' "$cx_config"
else
  printf '\n[features]\ncodex_hooks = true\n' >> "$cx_config"
  printf 'install-hooks: wrote Codex feature flag to %s\n' "$cx_config"
fi
