#!/usr/bin/env bash
# install-hooks.sh — register baton validate-artifact + validate-transition as platform hooks
#
# Usage: install-hooks.sh --repo-root PATH --bootstrap-dir PATH [--dry-run]
#
# --bootstrap-dir is used to compute the relative path from repo-root to the
# bootstrap scripts. That relative path is baked into all hook command strings
# at install time; at runtime $root (from git rev-parse) + relative path gives
# the correct absolute path regardless of where the repo is cloned.
#
# Installs hooks for both Claude Code and Codex:
#   Claude Code: PostToolUse + PreToolUse + Stop + SubagentStop + SessionStart
#                in .claude/settings.json
#   Codex:       PostToolUse + PreToolUse + Stop + SessionStart
#                in .codex/hooks.json; feature flag in .codex/config.toml
#
# All operations are idempotent: existing baton-owned entries (identified by
# marker strings "# baton-validate-artifact" / "# baton-validate-transition")
# are replaced, not duplicated.
#
# Exit 0: success (or dry-run)
# Exit 1: error (missing jq, missing args)
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bootstrap_root="$(cd "$script_dir/.." && pwd)"
source "$bootstrap_root/lib/paths.sh"

repo_root=""
bootstrap_dir=""
dry_run=false
print_manifest=false
hook_platform="${BATON_HOOK_PLATFORM:-auto}"

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
    --print-manifest)
      print_manifest=true
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
# Compute bootstrap path relative to repo root
# Baked into hook commands at install time; $root resolved at runtime via git.
# ---------------------------------------------------------------------------
_abs_repo="$(cd "$repo_root" && pwd)"
_abs_bootstrap="$(cd "$bootstrap_dir" && pwd)"
rel_bootstrap="$(paths_relpath_from "$_abs_repo" "$_abs_bootstrap")"
rel_bootstrap_windows="$(paths_to_windows_separators "$rel_bootstrap")"
hooks_dir="$_abs_bootstrap/hooks"

detect_hook_platform() {
  case "$hook_platform" in
    unix|windows)
      printf '%s\n' "$hook_platform"
      return
      ;;
    auto)
      ;;
    *)
      printf 'ERROR: install-hooks: unsupported hook platform: %s\n' "$hook_platform" >&2
      exit 1
      ;;
  esac

  case "${OS:-}" in
    Windows_NT)
      printf '%s\n' 'windows'
      return
      ;;
  esac

  case "$(uname -s 2>/dev/null || printf '%s' unknown)" in
    CYGWIN*|MINGW*|MSYS*)
      printf '%s\n' 'windows'
      ;;
    *)
      printf '%s\n' 'unix'
      ;;
  esac
}

resolved_hook_platform="$(detect_hook_platform)"

require_hook_script() {
  local name="$1"
  local path="$hooks_dir/$name"
  if [[ ! -f "$path" ]]; then
    printf 'ERROR: install-hooks: required hook script not found: %s\n' "$path" >&2
    exit 1
  fi
}

require_hook_script "pre-transition"
require_hook_script "post-artifact"
require_hook_script "stop-check"
require_hook_script "subagent-stop"
require_hook_script "session-start"
require_hook_script "run-hook.sh"
require_hook_script "run-hook.cmd"

build_unix_hook_cmd() {
  local handler="$1"
  local marker="$2"
  printf 'root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0; BATON_BOOTSTRAP="$root/%s" bash "$root/%s/hooks/%s" # %s' \
    "$rel_bootstrap" "$rel_bootstrap" "$handler" "$marker"
}

build_windows_hook_cmd() {
  local handler="$1"
  local marker="$2"
  printf 'cmd /d /c "\".\\%s\\hooks\\run-hook.cmd\" %s" # %s' \
    "$rel_bootstrap_windows" "$handler" "$marker"
}

build_claude_hook_cmd() {
  local handler="$1"
  local marker="$2"
  if [[ "$resolved_hook_platform" == "windows" ]]; then
    build_windows_hook_cmd "$handler" "$marker"
    return
  fi

  build_unix_hook_cmd "$handler" "$marker"
}

build_codex_unix_hook_cmd() {
  local handler="$1"
  local marker="$2"
  printf 'bash "%s/run-hook.sh" %s %s' \
    "$hooks_dir" "$handler" "$marker"
}

build_codex_windows_hook_cmd() {
  local handler="$1"
  local marker="$2"
  printf 'cmd /d /c "\".\\%s\\hooks\\run-hook.cmd\" %s %s"' \
    "$rel_bootstrap_windows" "$handler" "$marker"
}

build_codex_hook_cmd() {
  local handler="$1"
  local marker="$2"
  if [[ "$resolved_hook_platform" == "windows" ]]; then
    build_codex_windows_hook_cmd "$handler" "$marker"
    return
  fi

  build_codex_unix_hook_cmd "$handler" "$marker"
}

print_manifest_json() {
  jq -n \
    --arg platform "$resolved_hook_platform" \
    --arg cc_post "$cc_post_cmd" \
    --arg cc_pre "$cc_pre_cmd" \
    --arg cc_stop "$stop_cmd" \
    --arg cc_subagent "$subagent_stop_cmd" \
    --arg cc_session "$session_start_cmd" \
    --arg cx_post "$cx_post_cmd" \
    --arg cx_pre "$cx_pre_cmd" \
    --arg cx_stop "$cx_stop_cmd" \
    --arg cx_session "$cx_session_start_cmd" \
    '{
      platform: $platform,
      claude: {
        post: $cc_post,
        pre: $cc_pre,
        stop: $cc_stop,
        subagent_stop: $cc_subagent,
        session_start: $cc_session
      },
      codex: {
        post: $cx_post,
        pre: $cx_pre,
        stop: $cx_stop,
        session_start: $cx_session
      }
    }'
}

# ---------------------------------------------------------------------------
# Claude Code hook command strings
# Trigger: Write|Edit|MultiEdit — tool_input has file_path + content
# ---------------------------------------------------------------------------

# PostToolUse: after write to .harness/*.md → hooks/post-artifact
cc_post_cmd="$(build_claude_hook_cmd "post-artifact" "baton-validate-artifact")"

# PreToolUse: before write to task-status.md → hooks/pre-transition
cc_pre_cmd="$(build_claude_hook_cmd "pre-transition" "baton-validate-transition")"

# ---------------------------------------------------------------------------
# Codex hook command strings
# Trigger: Bash — tool_input has only .command (a bash command string)
# PreToolUse blocks on exit 2 (not exit 1)
# ---------------------------------------------------------------------------

# PostToolUse: after Bash command that wrote to .harness/*.md → hooks/post-artifact
cx_post_cmd="$(build_codex_hook_cmd "post-artifact" "baton-validate-artifact")"

# PreToolUse: before Bash command that writes to task-status.md → hooks/pre-transition
cx_pre_cmd="$(build_codex_hook_cmd "pre-transition" "baton-validate-transition")"

# ---------------------------------------------------------------------------
# Stop hook command string (Claude Code + Codex — outputs JSON)
# No matcher: Stop has no matcher support on either platform
# ---------------------------------------------------------------------------
stop_cmd="$(build_claude_hook_cmd "stop-check" "baton-validate-state baton-validate-isolation")"
cx_stop_cmd="$(build_codex_hook_cmd "stop-check" "baton-validate-state baton-validate-isolation")"

# ---------------------------------------------------------------------------
# SubagentStop command string (Claude Code only)
# Matcher: baton-evaluator|baton-verifier
# Reads agent_type field; validates fork agent wrote its required artifact
# ---------------------------------------------------------------------------
subagent_stop_cmd="$(build_claude_hook_cmd "subagent-stop" "baton-subagent-stop")"

# ---------------------------------------------------------------------------
# SessionStart command string (Claude Code + Codex)
# Matcher: startup|resume
# Reads .harness/task-status.md and injects current task state as context
# ---------------------------------------------------------------------------
session_start_cmd="$(build_claude_hook_cmd "session-start" "baton-harness-context")"
cx_session_start_cmd="$(build_codex_hook_cmd "session-start" "baton-harness-context")"

# ---------------------------------------------------------------------------
# Machine-readable manifest: emit expected Baton-managed hook commands, then exit
# ---------------------------------------------------------------------------
if [[ "$print_manifest" == true ]]; then
  print_manifest_json
  exit 0
fi

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
  --arg stop_cmd "$cx_stop_cmd" \
  --arg session_cmd "$cx_session_start_cmd" \
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
