#!/usr/bin/env bash
# Sync canonical skills/ to .claude/skills/ and .agents/.
# Only needed when link-mode is "copy" (symlink/hardlink modes propagate automatically).
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
baton_root="$(cd "$script_dir/../.." && pwd)"
skills_dir="$baton_root/skills"
link_mode_file="$skills_dir/.link-mode"

if [[ ! -f "$link_mode_file" ]]; then
  printf 'No .link-mode file found. Run spec/bootstrap/link-skills.sh first.\n' >&2
  exit 1
fi

link_mode="$(cat "$link_mode_file")"

if [[ "$link_mode" != "copy" ]]; then
  printf 'link-mode is %s — edits propagate automatically. No sync needed.\n' "$link_mode"
  exit 0
fi

sync_dir() {
  local target_dir="$1"
  for source_file in "$skills_dir"/*.md; do
    [[ -f "$source_file" ]] || continue
    local fname
    fname="$(basename "$source_file")"
    cp "$source_file" "$target_dir/$fname"
    printf 'sync  %s\n' "$target_dir/$fname"
  done
}

printf '==> .claude/skills/\n'
sync_dir "$baton_root/.claude/skills"

printf '==> .agents/\n'
sync_dir "$baton_root/.agents"

printf '\nSync complete.\n'
