#!/usr/bin/env bash
set -euo pipefail

paths_relpath_from() {
  local target_dir="$1"
  local source_path="$2"
  local source_dir source_name
  local -a source_parts=() target_parts=()
  local common=0 index rel=""

  source_dir="$(dirname "$source_path")"
  source_name="$(basename "$source_path")"

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

paths_to_windows_separators() {
  printf '%s' "$1" | sed 's/\//\\/g'
}
