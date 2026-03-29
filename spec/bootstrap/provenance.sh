#!/usr/bin/env bash

provenance_clean_value() {
  printf '%s' "${1:-}" \
    | sed -E 's/[`"'"'"']//g; s/^[[:space:]]+//; s/[[:space:]]+$//'
}

provenance_normalize_value() {
  provenance_clean_value "${1:-}" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[[:space:]]+/_/g'
}

provenance_read_field() {
  local file="$1"
  shift
  local key line value

  for key in "$@"; do
    line="$(grep -iE "^[[:space:]]*-[[:space:]]*${key}:[[:space:]]*" "$file" | head -n 1 || true)"
    [[ -n "$line" ]] || continue
    value="$(printf '%s\n' "$line" | sed -E "s/^[[:space:]]*-[[:space:]]*${key}:[[:space:]]*//I")"
    printf '%s\n' "$value"
    return 0
  done

  return 1
}
