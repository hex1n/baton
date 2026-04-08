#!/usr/bin/env bash
set -euo pipefail

# Host-neutral helper for Baton's optional Builder delegation flow.
# It manages scratch artifacts for one delegated slice:
#   init-slice     -> scaffold packet/report files from templates
#   run-worker     -> record a worker handoff in scratch state
#   collect-report -> write concrete worker reports
#   show-status    -> inspect current slice delegation state

REPO_ROOT="."
ACTION="${1:-}"
if [[ $# -gt 0 ]]; then
  shift
fi

ROUND=""
SLICE=""
TRIGGER="plan slice"
MODE="advisory"
START_SHA=""
WORKER_LABEL=""
STATUS=""
SUMMARY=""
PATCH_PATH=""
FORCE=false

FILES=()
CONCERNS=()
QUESTIONS=()
TEST_ENTRIES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    --round) ROUND="$2"; shift 2 ;;
    --slice) SLICE="$2"; shift 2 ;;
    --trigger) TRIGGER="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --start-sha) START_SHA="$2"; shift 2 ;;
    --worker-label) WORKER_LABEL="$2"; shift 2 ;;
    --status) STATUS="$2"; shift 2 ;;
    --summary) SUMMARY="$2"; shift 2 ;;
    --patch-path) PATCH_PATH="$2"; shift 2 ;;
    --file) FILES+=("$2"); shift 2 ;;
    --concern) CONCERNS+=("$2"); shift 2 ;;
    --question) QUESTIONS+=("$2"); shift 2 ;;
    --test-entry) TEST_ENTRIES+=("$2"); shift 2 ;;
    --force) FORCE=true; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

STATE_BASE="${REPO_ROOT}/.context/baton/active/slices"
TEMPLATE_PACKET="${REPO_ROOT}/v2/templates/slice-packet.template.md"
TEMPLATE_REPORT_MD="${REPO_ROOT}/v2/templates/worker-report.template.md"
TEMPLATE_REPORT_JSON="${REPO_ROOT}/v2/templates/worker-report.template.json"

usage() {
  cat <<'EOF'
Usage:
  bash v2/tools/builder-slice.sh init-slice \
    --round <N> --slice <M> [--trigger <text>] [--mode advisory|isolated] [--start-sha <sha>] [--repo-root <path>] [--force]

  bash v2/tools/builder-slice.sh run-worker \
    --round <N> --slice <M> [--worker-label <label>] [--mode advisory|isolated] [--repo-root <path>]

  bash v2/tools/builder-slice.sh collect-report \
    --round <N> --slice <M> --status complete|complete_with_concerns|needs_context|blocked \
    --summary <text> [--worker-label <label>] [--patch-path <path>] [--file <path>]... \
    [--concern <text>]... [--question <text>]... [--test-entry "<command>::<result>::<notes>"]... \
    [--repo-root <path>]

  bash v2/tools/builder-slice.sh show-status \
    [--round <N> [--slice <M>]] [--repo-root <path>]
EOF
}

require_action() {
  if [[ -z "$ACTION" ]]; then
    usage >&2
    exit 1
  fi
}

require_slice() {
  if [[ -z "$ROUND" || -z "$SLICE" ]]; then
    echo "Both --round and --slice are required." >&2
    exit 1
  fi
}

validate_mode() {
  if [[ "$MODE" != "advisory" && "$MODE" != "isolated" ]]; then
    echo "--mode must be advisory or isolated" >&2
    exit 1
  fi
}

validate_status() {
  case "$STATUS" in
    complete|complete_with_concerns|needs_context|blocked) ;;
    *)
      echo "--status must be complete, complete_with_concerns, needs_context, or blocked" >&2
      exit 1
      ;;
  esac
}

slice_dir() {
  printf '%s/round-%s/slice-%s' "$STATE_BASE" "$ROUND" "$SLICE"
}

state_file() {
  printf '%s/state.env' "$(slice_dir)"
}

packet_path() {
  printf '%s/packet.md' "$(slice_dir)"
}

report_md_path() {
  printf '%s/report.md' "$(slice_dir)"
}

report_json_path() {
  printf '%s/report.json' "$(slice_dir)"
}

worker_env_path() {
  printf '%s/worker.env' "$(slice_dir)"
}

default_start_sha() {
  if git -C "$REPO_ROOT" rev-parse --short HEAD >/dev/null 2>&1; then
    git -C "$REPO_ROOT" rev-parse --short HEAD
  else
    echo "unknown"
  fi
}

escape_json() {
  local text="$1"
  text="${text//\\/\\\\}"
  text="${text//\"/\\\"}"
  text="${text//$'\n'/\\n}"
  text="${text//$'\r'/\\r}"
  text="${text//$'\t'/\\t}"
  printf '%s' "$text"
}

parse_test_entry() {
  local entry="$1"
  TEST_COMMAND="${entry%%::*}"
  local rest="${entry#*::}"

  if [[ "$rest" == "$entry" ]]; then
    TEST_RESULT="not-run"
    TEST_NOTES=""
    return 0
  fi

  TEST_RESULT="${rest%%::*}"
  TEST_NOTES="${rest#*::}"
  if [[ "$TEST_NOTES" == "$rest" ]]; then
    TEST_NOTES=""
  fi
}

render_packet_template() {
  local out="$1"
  ROUND_VALUE="$ROUND" \
  SLICE_VALUE="$SLICE" \
  TRIGGER_VALUE="$TRIGGER" \
  MODE_VALUE="$MODE" \
  START_SHA_VALUE="$START_SHA" \
  perl -0pe '
    s/\{N\}/$ENV{ROUND_VALUE}/g;
    s/\{M\}/$ENV{SLICE_VALUE}/g;
    s/\{plan slice \/ verifier finding \/ fix slice\}/$ENV{TRIGGER_VALUE}/g;
    s/\{advisory \/ isolated\}/$ENV{MODE_VALUE}/g;
    s/\{git sha before delegation\}/$ENV{START_SHA_VALUE}/g;
  ' "$TEMPLATE_PACKET" >"$out"
}

scaffold_if_missing() {
  local source="$1" target="$2"
  if [[ -f "$target" && "$FORCE" != true ]]; then
    return 0
  fi
  cp "$source" "$target"
}

write_state() {
  local phase="$1"
  local worker_status="$2"
  local updated_at
  updated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cat >"$(state_file)" <<EOF
ROUND=$ROUND
SLICE=$SLICE
MODE=$MODE
TRIGGER=$TRIGGER
PHASE=$phase
WORKER_STATUS=$worker_status
WORKER_LABEL=$WORKER_LABEL
UPDATED_AT=$updated_at
EOF
}

append_json_array() {
  local phase="$1"
  shift
  local value
  local first=true
  for value in "$@"; do
    if $first; then
      first=false
      if [[ "$phase" == "indented" ]]; then
        printf '\n'
      fi
    else
      printf ',\n'
    fi
    printf '    "%s"' "$(escape_json "$value")"
  done
}

require_slice_dir() {
  local dir
  dir="$(slice_dir)"
  if [[ ! -d "$dir" ]]; then
    echo "Slice directory not initialized: $dir" >&2
    exit 1
  fi
}

handle_init_slice() {
  require_slice
  validate_mode
  START_SHA="${START_SHA:-$(default_start_sha)}"

  local dir
  dir="$(slice_dir)"
  mkdir -p "$dir"

  if [[ -f "$(packet_path)" && "$FORCE" != true ]]; then
    echo "Slice packet already exists: $(packet_path)" >&2
    echo "Use --force to overwrite the scaffolding files." >&2
    exit 1
  fi

  render_packet_template "$(packet_path)"
  scaffold_if_missing "$TEMPLATE_REPORT_MD" "$(report_md_path)"
  scaffold_if_missing "$TEMPLATE_REPORT_JSON" "$(report_json_path)"
  write_state "initialized" "pending"

  cat <<EOF
Initialized slice scratch:
  packet: $(packet_path)
  report.md: $(report_md_path)
  report.json: $(report_json_path)
EOF
}

handle_run_worker() {
  require_slice
  validate_mode
  require_slice_dir

  local dispatched_at
  dispatched_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cat >"$(worker_env_path)" <<EOF
ROUND=$ROUND
SLICE=$SLICE
MODE=$MODE
WORKER_LABEL=${WORKER_LABEL:-internal-worker}
DISPATCHED_AT=$dispatched_at
PACKET=$(packet_path)
REPORT_MD=$(report_md_path)
REPORT_JSON=$(report_json_path)
EOF
  write_state "running" "in_progress"

  cat <<EOF
Registered worker handoff:
  slice: round-$ROUND / slice-$SLICE
  worker: ${WORKER_LABEL:-internal-worker}
  packet: $(packet_path)
EOF
}

handle_collect_report() {
  require_slice
  validate_mode
  validate_status
  require_slice_dir

  if [[ -z "$SUMMARY" ]]; then
    echo "--summary is required for collect-report" >&2
    exit 1
  fi

  local report_md report_json patch_line patch_json test command result notes concern question file
  report_md="$(report_md_path)"
  report_json="$(report_json_path)"

  if [[ -z "$PATCH_PATH" ]]; then
    patch_line="N/A"
    patch_json="null"
  else
    patch_line="$PATCH_PATH"
    patch_json="\"$(escape_json "$PATCH_PATH")\""
  fi

  {
    cat <<EOF
# Worker Report: Round $ROUND Slice $SLICE

## Metadata

| Key | Value |
|-----|-------|
| Round | $ROUND |
| Slice | $SLICE |
| Status | $STATUS |
| Delegation Mode | $MODE |

## Summary

$SUMMARY

## Files Touched

EOF
    if [[ ${#FILES[@]} -eq 0 ]]; then
      echo "- \`None.\`"
    else
      for file in "${FILES[@]}"; do
        echo "- \`$file\`"
      done
    fi

    cat <<'EOF'

## Commands Run

EOF
    if [[ ${#TEST_ENTRIES[@]} -eq 0 ]]; then
      echo "- None. -> not run"
    else
      for test in "${TEST_ENTRIES[@]}"; do
        parse_test_entry "$test"
        printf -- '- %s -> %s' "$TEST_COMMAND" "${TEST_RESULT:-not-run}"
        if [[ -n "${TEST_NOTES:-}" ]]; then
          printf " (%s)" "$TEST_NOTES"
        fi
        printf "\n"
      done
    fi

    cat <<'EOF'

## Concerns

EOF
    if [[ ${#CONCERNS[@]} -eq 0 ]]; then
      echo "- None."
    else
      for concern in "${CONCERNS[@]}"; do
        echo "- $concern"
      done
    fi

    cat <<'EOF'

## Open Questions

EOF
    if [[ ${#QUESTIONS[@]} -eq 0 ]]; then
      echo "- None."
    else
      for question in "${QUESTIONS[@]}"; do
        echo "- $question"
      done
    fi

    cat <<EOF

## Patch

- Path: \`$patch_line\`
- Notes: Review the touched files, command results, and any concerns before integrating.
EOF
  } >"$report_md"

  {
    printf '{\n'
    printf '  "round": %s,\n' "$ROUND"
    printf '  "slice": %s,\n' "$SLICE"
    printf '  "status": "%s",\n' "$(escape_json "$STATUS")"
    printf '  "delegation_mode": "%s",\n' "$(escape_json "$MODE")"
    printf '  "summary": "%s",\n' "$(escape_json "$SUMMARY")"

    printf '  "files_touched": ['
    if [[ ${#FILES[@]} -gt 0 ]]; then
      append_json_array indented "${FILES[@]}"
      printf '\n  ],\n'
    else
      printf '],\n'
    fi

    printf '  "tests_run": ['
    if [[ ${#TEST_ENTRIES[@]} -gt 0 ]]; then
      printf '\n'
      local first_test=true
      for test in "${TEST_ENTRIES[@]}"; do
        parse_test_entry "$test"
        if $first_test; then
          first_test=false
        else
          printf ',\n'
        fi
        printf '    {\n'
        printf '      "command": "%s",\n' "$(escape_json "$TEST_COMMAND")"
        printf '      "result": "%s",\n' "$(escape_json "${TEST_RESULT:-not-run}")"
        printf '      "notes": "%s"\n' "$(escape_json "${TEST_NOTES:-}")"
        printf '    }'
      done
      printf '\n  ],\n'
    else
      printf '],\n'
    fi

    printf '  "concerns": ['
    if [[ ${#CONCERNS[@]} -gt 0 ]]; then
      append_json_array indented "${CONCERNS[@]}"
      printf '\n  ],\n'
    else
      printf '],\n'
    fi

    printf '  "open_questions": ['
    if [[ ${#QUESTIONS[@]} -gt 0 ]]; then
      append_json_array indented "${QUESTIONS[@]}"
      printf '\n  ],\n'
    else
      printf '],\n'
    fi

    printf '  "patch_path": %s\n' "$patch_json"
    printf '}\n'
  } >"$report_json"

  write_state "reported" "$STATUS"

  cat <<EOF
Collected worker report:
  report.md: $report_md
  report.json: $report_json
  status: $STATUS
EOF
}

handle_show_status() {
  if [[ -n "$ROUND" && -n "$SLICE" ]]; then
    require_slice_dir
    local dir
    dir="$(slice_dir)"
    echo "Slice scratch: $dir"
    if [[ -f "$(state_file)" ]]; then
      cat "$(state_file)"
    else
      echo "No state.env present."
    fi
    echo "packet=$(packet_path)"
    echo "report_md=$(report_md_path)"
    echo "report_json=$(report_json_path)"
    if [[ -f "$(worker_env_path)" ]]; then
      echo "worker_env=$(worker_env_path)"
    fi
    return 0
  fi

  if [[ ! -d "$STATE_BASE" ]]; then
    echo "No active Builder slices found."
    return 0
  fi

  local round_dir slice_state slice_name
  for round_dir in "$STATE_BASE"/round-*; do
    [[ -d "$round_dir" ]] || continue
    for slice_state in "$round_dir"/slice-*/state.env; do
      [[ -f "$slice_state" ]] || continue
      slice_name="$(dirname "$slice_state")"
      echo "== ${slice_name#$REPO_ROOT/} =="
      cat "$slice_state"
    done
  done
}

require_action

case "$ACTION" in
  init-slice) handle_init_slice ;;
  run-worker) handle_run_worker ;;
  collect-report) handle_collect_report ;;
  show-status) handle_show_status ;;
  *)
    usage >&2
    exit 1
    ;;
esac
