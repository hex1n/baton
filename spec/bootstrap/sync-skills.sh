#!/usr/bin/env bash
# Sync canonical skills/ to .claude/skills/ and .agents/.
# Skip only when the actual targets are symlinks or hardlinks. Do not trust
# .link-mode as the deciding signal because fresh clones may materialize
# intended symlinks as plain file copies.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
baton_root="$(cd "$script_dir/../.." && pwd)"
skills_dir="$baton_root/skills"
link_mode_file="$skills_dir/.link-mode"

if [[ ! -f "$link_mode_file" ]]; then
  printf 'No .link-mode file found. Run spec/bootstrap/link-skills.sh first.\n' >&2
  exit 1
fi

declared_mode="$(cat "$link_mode_file")"

inode_of() {
  local path="$1"
  if stat -f '%i' "$path" >/dev/null 2>&1; then
    stat -f '%i' "$path"
  else
    stat -c '%i' "$path"
  fi
}

detect_file_mode() {
  local source="$1"
  local target="$2"

  if [[ ! -e "$target" ]]; then
    printf 'missing'
    return 0
  fi

  if [[ -L "$target" ]]; then
    printf 'symlink'
    return 0
  fi

  if [[ "$(inode_of "$source")" == "$(inode_of "$target")" ]]; then
    printf 'hardlink'
  else
    printf 'copy'
  fi
}

inspect_dir() {
  local target_dir="$1"
  local dir_mode="symlink"

  for source_file in "$skills_dir"/*.md; do
    [[ -f "$source_file" ]] || continue
    local fname
    fname="$(basename "$source_file")"
    local target_file="$target_dir/$fname"
    local mode
    mode="$(detect_file_mode "$source_file" "$target_file")"

    if [[ "$mode" == "missing" || "$mode" == "copy" ]]; then
      dir_mode="copy"
      break
    fi

    if [[ "$mode" == "hardlink" && "$dir_mode" == "symlink" ]]; then
      dir_mode="hardlink"
    fi
  done

  printf '%s' "$dir_mode"
}

sync_dir() {
  local target_dir="$1"
  mkdir -p "$target_dir"
  for source_file in "$skills_dir"/*.md; do
    [[ -f "$source_file" ]] || continue
    local fname
    fname="$(basename "$source_file")"
    cp "$source_file" "$target_dir/$fname"
    printf 'sync  %s\n' "$target_dir/$fname"
  done
}

claude_mode="$(inspect_dir "$baton_root/.claude/skills")"
agents_mode="$(inspect_dir "$baton_root/.agents")"

if [[ "$claude_mode" == "copy" || "$agents_mode" == "copy" ]]; then
  actual_mode="copy"
elif [[ "$claude_mode" == "hardlink" || "$agents_mode" == "hardlink" ]]; then
  actual_mode="hardlink"
else
  actual_mode="symlink"
fi

if [[ "$actual_mode" != "copy" ]]; then
  printf 'actual link-mode is %s — edits propagate automatically. No sync needed.\n' "$actual_mode"
  if [[ "$declared_mode" != "$actual_mode" ]]; then
    printf 'note: .link-mode declares %s, but the current workspace is %s.\n' "$declared_mode" "$actual_mode"
  fi
  exit 0
fi

if [[ "$declared_mode" != "$actual_mode" ]]; then
  printf 'note: .link-mode declares %s, but the current workspace is %s. Syncing copies.\n' "$declared_mode" "$actual_mode"
fi

printf '==> .claude/skills/\n'
sync_dir "$baton_root/.claude/skills"

printf '==> .agents/\n'
sync_dir "$baton_root/.agents"

printf '\nSync complete.\n'
