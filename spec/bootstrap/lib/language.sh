#!/usr/bin/env bash
set -euo pipefail

language_normalize() {
  local value="${1:-}"
  value="${value%%#*}"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | sed "s/^[[:space:]\"']*//;s/[[:space:]\"']*$//")"
  printf '%s' "$value"
}

language_resolve_locale() {
  local locale_value="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
  local normalized
  normalized="$(printf '%s' "$locale_value" | tr '[:upper:]' '[:lower:]')"

  if [[ "$normalized" == zh* ]]; then
    printf '%s' 'zh'
    return
  fi

  printf '%s' 'en'
}

language_resolve_artifact() {
  local policy
  policy="$(language_normalize "${1:-}")"

  if [[ -z "$policy" || "$policy" == 'auto' ]]; then
    language_resolve_locale
    return
  fi

  printf '%s' "$policy"
}
