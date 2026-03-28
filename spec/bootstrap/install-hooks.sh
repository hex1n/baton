#!/usr/bin/env bash
# install-hooks.sh — register baton validate-artifact + validate-transition as Claude Code hooks
#
# Usage: install-hooks.sh --repo-root PATH --bootstrap-dir PATH [--dry-run]
#
# Writes PostToolUse and PreToolUse hook entries into .claude/settings.json in the
# target repo. The operation is idempotent: any existing baton-owned hook entries
# (identified by the marker string "# baton-validate-artifact" or
# "# baton-validate-transition") are replaced, not duplicated.
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

settings_file="$repo_root/.claude/settings.json"

# -- build inline hook command strings --
# PostToolUse: fire after Write/Edit on .harness/*.md → call validate-artifact.sh
post_cmd="input=\$(cat); fp=\$(echo \"\$input\" | jq -r '.tool_input.file_path // empty' 2>/dev/null); [[ \"\$fp\" == *\".harness/\"*\".md\" ]] || exit 0; at=\$(basename \"\$fp\" .md); bash ${bootstrap_dir}/validate-artifact.sh \"\$at\" \"\$fp\" # baton-validate-artifact"

# PreToolUse: fire before Write/Edit on module-status.md → call validate-transition.sh
pre_cmd="input=\$(cat); fp=\$(echo \"\$input\" | jq -r '.tool_input.file_path // empty' 2>/dev/null); [[ \"\$fp\" == *\"module-status.md\" ]] || exit 0; nc=\$(echo \"\$input\" | jq -r '.tool_input.content // empty' 2>/dev/null); [[ -n \"\$nc\" ]] || exit 0; ns=\$(echo \"\$nc\" | awk -F'|' 'NR>2 && NF>3 && \$4!~/---/{gsub(/ /,\"\",\$4); print \$4; exit}'); [[ -n \"\$ns\" ]] || exit 0; [[ -f \"\$fp\" ]] || exit 0; cs=\$(awk -F'|' 'NR>2 && NF>3 && \$4!~/---/{gsub(/ /,\"\",\$4); print \$4; exit}' \"\$fp\"); [[ -n \"\$cs\" ]] || exit 0; bash ${bootstrap_dir}/validate-transition.sh \"\$cs\" \"\$ns\" # baton-validate-transition"

if [[ "$dry_run" == true ]]; then
  printf '[dry-run] Would write hooks to: %s\n' "$settings_file"
  printf '[dry-run] PostToolUse command (matcher: Write|Edit|MultiEdit):\n  %s\n' "$post_cmd"
  printf '[dry-run] PreToolUse command (matcher: Write|Edit|MultiEdit):\n  %s\n' "$pre_cmd"
  exit 0
fi

# -- read existing settings or start fresh --
if [[ -f "$settings_file" ]]; then
  existing="$(cat "$settings_file")"
else
  existing="{}"
fi

# -- use jq to merge hook entries (idempotent: filter out baton-owned entries, then re-add) --
new_settings="$(echo "$existing" | jq \
  --arg post_cmd "$post_cmd" \
  --arg pre_cmd "$pre_cmd" \
  '
  # Remove any existing baton-owned PostToolUse entries (by marker string)
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

  # Remove any existing baton-owned PreToolUse entries (by marker string)
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

  # Build the new baton PostToolUse entry
  def new_post_entry:
    {
      "matcher": "Write|Edit|MultiEdit",
      "hooks": [
        { "type": "command", "command": $post_cmd }
      ]
    };

  # Build the new baton PreToolUse entry
  def new_pre_entry:
    {
      "matcher": "Write|Edit|MultiEdit",
      "hooks": [
        { "type": "command", "command": $pre_cmd }
      ]
    };

  .hooks.PostToolUse = ((.hooks.PostToolUse | strip_baton_post) + [new_post_entry])
  | .hooks.PreToolUse = ((.hooks.PreToolUse | strip_baton_pre) + [new_pre_entry])
  '
)"

printf '%s\n' "$new_settings" > "$settings_file"
printf 'install-hooks: wrote hooks to %s\n' "$settings_file"
