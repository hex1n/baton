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
  local relative_source

  if [[ "$dry_run" == "true" ]]; then
    printf 'symlink'
    return 0
  fi

  rm -f "$target"

  relative_source="$(relative_link_target "$source" "$target")"

  if ln -s "$relative_source" "$target" 2>/dev/null; then
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

# Compute a repo-relative symlink target so committed links stay portable.
relative_link_target() {
  local source="$1"
  local target="$2"
  local source_dir target_dir source_name
  local -a source_parts=() target_parts=()
  local common=0 index rel=""

  source_dir="$(dirname "$source")"
  target_dir="$(dirname "$target")"
  source_name="$(basename "$source")"

  IFS='/' read -r -a source_parts <<< "$source_dir"
  IFS='/' read -r -a target_parts <<< "$target_dir"

  while [[ $common -lt ${#source_parts[@]} && $common -lt ${#target_parts[@]} && "${source_parts[$common]}" == "${target_parts[$common]}" ]]; do
    common=$((common + 1))
  done

  for ((index = common; index < ${#target_parts[@]}; index++)); do
    rel+="../"
  done

  for ((index = common; index < ${#source_parts[@]}; index++)); do
    rel+="${source_parts[$index]}/"
  done

  printf '%s%s' "$rel" "$source_name"
}

# Link all *.md files from skills/ into target_dir.
# Also links skills/*/SKILL.md subdirectory-style skills as <dirname>.md.
# Returns (stdout) the worst mode used in this directory.
link_dir() {
  local target_dir="$1"
  local dir_mode="symlink"

  if [[ "$dry_run" == "true" ]]; then
    printf 'plan  mkdir -p %s\n' "$target_dir" >&2
  else
    mkdir -p "$target_dir"
  fi

  # Flat files: skills/*.md
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

  # Subdirectory skills: skills/<name>/ → target_dir/<name>/ (directory link)
  # Claude Code discovers skills by scanning for <dir>/SKILL.md, so we must
  # preserve the directory structure rather than flattening to a .md file.
  for source_file in "$skills_dir"/*/SKILL.md; do
    [[ -f "$source_file" ]] || continue
    local source_subdir dirname target_subdir
    source_subdir="$(dirname "$source_file")"
    dirname="$(basename "$source_subdir")"
    target_subdir="$target_dir/$dirname"

    # Clean up stale flat-file symlink from previous link-skills runs
    [[ -L "$target_dir/${dirname}.md" ]] && rm -f "$target_dir/${dirname}.md"

    if [[ "$dry_run" == "true" ]]; then
      printf 'symlink  %s/\n' "$target_subdir" >&2
      continue
    fi

    # Remove previous target (file symlink, directory symlink, or copy dir)
    rm -rf "$target_subdir"

    local rel_dir mode
    # For directory symlinks, compute relative path from the symlink's parent
    # (target_dir) to source_subdir — NOT from inside the target directory.
    rel_dir="$(relative_link_target "$source_file" "$target_dir/dummy")"
    rel_dir="$(dirname "$rel_dir")"

    if ln -s "$rel_dir" "$target_subdir" 2>/dev/null; then
      mode="symlink"
    elif cp -R "$source_subdir" "$target_subdir" 2>/dev/null; then
      mode="copy"
    else
      printf 'ERROR: could not link or copy %s\n' "$source_subdir" >&2
      continue
    fi

    if [[ "$mode" == "copy" ]]; then
      dir_mode="copy"
    fi

    printf '%s  %s/\n' "$mode" "$target_subdir" >&2
  done

  printf '%s' "$dir_mode"
}

# Link only skills with `context: fork` into target_dir.
link_fork_dir() {
  local target_dir="$1"
  local dir_mode="symlink"

  if [[ "$dry_run" == "true" ]]; then
    printf 'plan  mkdir -p %s\n' "$target_dir" >&2
  else
    mkdir -p "$target_dir"
  fi

  # Flat skills: skills/*.md with context: fork
  for source_file in "$skills_dir"/*.md; do
    [[ -f "$source_file" ]] || continue
    grep -q '^context: fork' "$source_file" 2>/dev/null || continue
    local fname
    fname="$(basename "$source_file")"
    local target_file="$target_dir/$fname"

    local mode
    mode="$(link_one "$source_file" "$target_file")"

    if [[ "$mode" == "copy" ]]; then
      dir_mode="copy"
    elif [[ "$mode" == "hardlink" && "$dir_mode" == "symlink" ]]; then
      dir_mode="hardlink"
    fi

    printf '%s  %s\n' "$mode" "$target_file" >&2
  done

  # Subdirectory skills: skills/*/SKILL.md with context: fork
  for source_file in "$skills_dir"/*/SKILL.md; do
    [[ -f "$source_file" ]] || continue
    grep -q '^context: fork' "$source_file" 2>/dev/null || continue
    local source_subdir dirname target_subdir
    source_subdir="$(dirname "$source_file")"
    dirname="$(basename "$source_subdir")"
    target_subdir="$target_dir/$dirname"

    [[ -L "$target_dir/${dirname}.md" ]] && rm -f "$target_dir/${dirname}.md"

    if [[ "$dry_run" == "true" ]]; then
      printf 'symlink  %s/\n' "$target_subdir" >&2
      continue
    fi

    rm -rf "$target_subdir"

    local rel_dir mode
    # For directory symlinks, compute relative path from the symlink's parent
    # (target_dir) to source_subdir — NOT from inside the target directory.
    rel_dir="$(relative_link_target "$source_file" "$target_dir/dummy")"
    rel_dir="$(dirname "$rel_dir")"

    if ln -s "$rel_dir" "$target_subdir" 2>/dev/null; then
      mode="symlink"
    elif cp -R "$source_subdir" "$target_subdir" 2>/dev/null; then
      mode="copy"
    else
      printf 'ERROR: could not link or copy %s\n' "$source_subdir" >&2
      continue
    fi

    if [[ "$mode" == "copy" ]]; then
      dir_mode="copy"
    fi

    printf '%s  %s/\n' "$mode" "$target_subdir" >&2
  done

  printf '%s' "$dir_mode"
}

printf '==> .claude/skills/\n' >&2
claude_mode="$(link_dir "$baton_root/.claude/skills")"

printf '==> .agents/\n' >&2
agents_mode="$(link_dir "$baton_root/.agents")"

printf '==> .claude/agents/ (context:fork only)\n' >&2
claude_agents_mode="$(link_fork_dir "$baton_root/.claude/agents")"

# Overall mode = worst of all directories
if [[ "$claude_mode" == "copy" || "$agents_mode" == "copy" || "$claude_agents_mode" == "copy" ]]; then
  final_mode="copy"
elif [[ "$claude_mode" == "hardlink" || "$agents_mode" == "hardlink" || "$claude_agents_mode" == "hardlink" ]]; then
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
