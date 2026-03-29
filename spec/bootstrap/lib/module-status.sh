#!/usr/bin/env bash
set -euo pipefail

module_status_trim() {
  printf '%s' "$1" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

module_status_current_header() {
  printf '%s\n' '| Scope | Owner | State | Eval Round | Updated At | Notes |'
}

module_status_legacy_header() {
  printf '%s\n' '| Scope | Owner | State | Updated At | Notes |'
}

module_status_schema() {
  local path="$1"
  local line=""

  if [[ ! -f "$path" ]]; then
    printf '%s\n' 'missing'
    return 0
  fi

  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line="$(module_status_trim "$raw_line")"
    case "$line" in
      "$(module_status_current_header)")
        printf '%s\n' 'current'
        return 0
        ;;
      "$(module_status_legacy_header)")
        printf '%s\n' 'legacy'
        return 0
        ;;
      '## State Notes')
        break
        ;;
    esac
  done < "$path"

  printf '%s\n' 'unknown'
}

module_status_rows_tsv() {
  local path="$1"
  local schema=""
  local in_table="false"
  local line=""
  local trimmed_line=""
  local scope=""
  local owner=""
  local state=""
  local eval_round=""
  local updated_at=""
  local notes=""
  local scope_column="" owner_column="" state_column="" eval_round_column="" updated_column="" notes_column=""

  schema="$(module_status_schema "$path")"
  case "$schema" in
    current|legacy) ;;
    *)
      return 0
      ;;
  esac

  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line="$(module_status_trim "$raw_line")"

    if [[ "$line" == '## State Notes' ]]; then
      break
    fi

    if [[ "$schema" == 'current' && "$line" == "$(module_status_current_header)" ]]; then
      in_table="true"
      continue
    fi

    if [[ "$schema" == 'legacy' && "$line" == "$(module_status_legacy_header)" ]]; then
      in_table="true"
      continue
    fi

    if [[ "$in_table" != 'true' ]]; then
      continue
    fi

    if [[ -z "$line" || "$line" == '|------'* ]]; then
      continue
    fi

    if [[ "$line" != \|* ]]; then
      continue
    fi

    trimmed_line="${line#|}"
    trimmed_line="${trimmed_line%|}"

    if [[ "$schema" == 'current' ]]; then
      IFS='|' read -r scope_column owner_column state_column eval_round_column updated_column notes_column <<< "$trimmed_line"
      eval_round="$(module_status_trim "$eval_round_column")"
      updated_at="$(module_status_trim "$updated_column")"
      notes="$(module_status_trim "$notes_column")"
    else
      IFS='|' read -r scope_column owner_column state_column updated_column notes_column <<< "$trimmed_line"
      eval_round='0'
      updated_at="$(module_status_trim "$updated_column")"
      notes="$(module_status_trim "$notes_column")"
    fi

    scope="$(module_status_trim "$scope_column")"
    owner="$(module_status_trim "$owner_column")"
    state="$(module_status_trim "$state_column")"

    if [[ -z "$scope" || "$scope" == '<task-id>' ]]; then
      continue
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$scope" "$owner" "$state" "${eval_round:-0}" "$updated_at" "$notes"
  done < "$path"
}

module_status_current_row_tsv() {
  local path="$1"
  module_status_rows_tsv "$path" | tail -n 1
}

module_status_current_field() {
  local path="$1"
  local field="$2"
  local row=""
  local scope="" owner="" state="" eval_round="" updated_at="" notes=""

  row="$(module_status_current_row_tsv "$path")"
  [[ -n "$row" ]] || return 0

  IFS=$'\t' read -r scope owner state eval_round updated_at notes <<< "$row"

  case "$field" in
    scope) printf '%s\n' "$scope" ;;
    owner) printf '%s\n' "$owner" ;;
    state) printf '%s\n' "$state" ;;
    eval_round) printf '%s\n' "$eval_round" ;;
    updated_at) printf '%s\n' "$updated_at" ;;
    notes) printf '%s\n' "$notes" ;;
    *)
      printf 'Unknown field: %s\n' "$field" >&2
      return 1
      ;;
  esac
}

module_status_row_count() {
  local path="$1"
  local count=0
  while IFS= read -r _; do
    count=$((count + 1))
  done < <(module_status_rows_tsv "$path")
  printf '%s\n' "$count"
}

module_status_non_complete_count() {
  local path="$1"
  local count=0
  local state=""

  while IFS=$'\t' read -r _ _ state _ _ _; do
    if [[ "$state" != 'complete' ]]; then
      count=$((count + 1))
    fi
  done < <(module_status_rows_tsv "$path")

  printf '%s\n' "$count"
}

module_status_set_eval_round() {
  local path="$1"
  local new_value="$2"
  local schema=""
  local target_line=""
  local tmp_file=""

  if [[ ! -f "$path" ]]; then
    printf 'module-status not found: %s\n' "$path" >&2
    return 1
  fi

  if [[ ! "$new_value" =~ ^[0-9]+$ ]]; then
    printf 'Eval round must be a non-negative integer: %s\n' "$new_value" >&2
    return 1
  fi

  schema="$(module_status_schema "$path")"
  if [[ "$schema" != 'current' ]]; then
    printf 'Eval round write requires current schema, found: %s\n' "$schema" >&2
    return 1
  fi

  target_line="$(
    awk '
      /^## State Notes$/ { exit }
      /^\|[[:space:]]*Scope[[:space:]]*\|[[:space:]]*Owner[[:space:]]*\|[[:space:]]*State[[:space:]]*\|[[:space:]]*Eval Round[[:space:]]*\|[[:space:]]*Updated At[[:space:]]*\|[[:space:]]*Notes[[:space:]]*\|$/ { in_table = 1; next }
      in_table && /^\|[-|[:space:]]+\|$/ { next }
      in_table && /^\|/ { line = NR }
      END { if (line > 0) print line }
    ' "$path"
  )"

  if [[ -z "$target_line" ]]; then
    printf 'Unable to locate current task row in %s\n' "$path" >&2
    return 1
  fi

  tmp_file="$(mktemp)"
  awk -v target_line="$target_line" -v new_value="$new_value" '
    function trim(value) {
      sub(/^[ \t\r\n]+/, "", value)
      sub(/[ \t\r\n]+$/, "", value)
      return value
    }

    NR == target_line {
      raw = $0
      sub(/^\|/, "", raw)
      sub(/\|$/, "", raw)
      n = split(raw, cols, /\|/)

      if (n != 6) {
        print $0
        next
      }

      printf("| %s | %s | %s | %s | %s | %s |\n",
        trim(cols[1]), trim(cols[2]), trim(cols[3]), new_value, trim(cols[5]), trim(cols[6]))
      next
    }

    { print }
  ' "$path" > "$tmp_file"

  mv "$tmp_file" "$path"
}

module_status_usage() {
  cat <<'EOF'
Usage:
  module-status.sh schema <module-status-path>
  module-status.sh rows <module-status-path>
  module-status.sh current-field <module-status-path> <scope|owner|state|eval_round|updated_at|notes>
  module-status.sh row-count <module-status-path>
  module-status.sh non-complete-count <module-status-path>
  module-status.sh set-eval-round <module-status-path> <value>
EOF
}

module_status_main() {
  local command="${1:-}"
  case "$command" in
    schema)
      [[ $# -eq 2 ]] || { module_status_usage >&2; return 1; }
      module_status_schema "$2"
      ;;
    rows)
      [[ $# -eq 2 ]] || { module_status_usage >&2; return 1; }
      module_status_rows_tsv "$2"
      ;;
    current-field)
      [[ $# -eq 3 ]] || { module_status_usage >&2; return 1; }
      module_status_current_field "$2" "$3"
      ;;
    row-count)
      [[ $# -eq 2 ]] || { module_status_usage >&2; return 1; }
      module_status_row_count "$2"
      ;;
    non-complete-count)
      [[ $# -eq 2 ]] || { module_status_usage >&2; return 1; }
      module_status_non_complete_count "$2"
      ;;
    set-eval-round)
      [[ $# -eq 3 ]] || { module_status_usage >&2; return 1; }
      module_status_set_eval_round "$2" "$3"
      ;;
    *)
      module_status_usage >&2
      return 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  module_status_main "$@"
fi
