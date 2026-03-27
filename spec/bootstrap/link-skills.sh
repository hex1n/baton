#!/usr/bin/env bash
# Link canonical skills/ to .claude/skills/ and .agents/
# Run from anywhere inside the baton repo — uses script location to find root.
#
# Tier priority (first succeeding tier wins per file):
#   1. symlink  (ln -s)  — best for edits; requires developer mode on Windows
#   2. hardlink (ln)     — no dev mode needed; same inode so edits propagate
#   3. copy     (cp)     — last resort; run sync-skills.sh after editing skills/
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
baton_root="$(cd "$script_dir/../.." && pwd)"
skills_dir="$baton_root/skills"
link_mode_file="$skills_dir/.link-mode"

dry_run="false"
if [[ "${1:-}" == "--dry-run" ]]; then
  dry_run="true"
fi

if [[ ! -d "$skills_dir" ]]; then
  printf 'Error: skills/ not found at %s\n' "$skills_dir" >&2
  exit 1
fi

# Link one file; echoes the mode used (symlink|hardlink|copy).
link_one() {
  local source="$1"
  local target="$2"

  if [[ "$dry_run" == "true" ]]; then
    printf 'symlink'
    return 0
  fi

  rm -f "$target"

  if ln -s "$source" "$target" 2>/dev/null; then
    printf 'symlink'
    return 0
  fi

  if ln "$source" "$target" 2>/dev/null; then
    printf 'hardlink'
    return 0
  fi

  cp "$source" "$target"
  printf 'copy'
}

# Link all *.md files from skills/ into target_dir.
# Returns (stdout) the worst mode used in this directory.
link_dir() {
  local target_dir="$1"
  local dir_mode="symlink"

  if [[ "$dry_run" == "true" ]]; then
    printf 'plan  mkdir -p %s\n' "$target_dir" >&2
  else
    mkdir -p "$target_dir"
  fi

  for source_file in "$skills_dir"/*.md; do
    [[ -f "$source_file" ]] || continue
    local fname
    fname="$(basename "$source_file")"
    local target_file="$target_dir/$fname"

    local mode
    mode="$(link_one "$source_file" "$target_file")"

    # Track worst mode (symlink > hardlink > copy)
    if [[ "$mode" == "copy" ]]; then
      dir_mode="copy"
    elif [[ "$mode" == "hardlink" && "$dir_mode" == "symlink" ]]; then
      dir_mode="hardlink"
    fi

    printf '%s  %s\n' "$mode" "$target_file" >&2
  done

  printf '%s' "$dir_mode"
}

printf '==> .claude/skills/\n' >&2
claude_mode="$(link_dir "$baton_root/.claude/skills")"

printf '==> .agents/\n' >&2
agents_mode="$(link_dir "$baton_root/.agents")"

# Overall mode = worst of both directories
if [[ "$claude_mode" == "copy" || "$agents_mode" == "copy" ]]; then
  final_mode="copy"
elif [[ "$claude_mode" == "hardlink" || "$agents_mode" == "hardlink" ]]; then
  final_mode="hardlink"
else
  final_mode="symlink"
fi

if [[ "$dry_run" != "true" ]]; then
  printf '%s\n' "$final_mode" > "$link_mode_file"
fi

printf '\nlink-mode: %s\n' "$final_mode" >&2
if [[ "$final_mode" == "copy" ]]; then
  printf 'Run spec/bootstrap/sync-skills.sh after editing files in skills/\n' >&2
fi
