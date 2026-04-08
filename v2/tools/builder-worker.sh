#!/usr/bin/env bash
set -euo pipefail

# Host-neutral helper for Baton's optional Builder delegation flow.
# It manages scratch artifacts for one delegated batch:
#   init-batch     -> scaffold packet/report files from templates
#   run-worker     -> record a worker handoff in scratch state
#   collect-report -> write concrete worker reports
#   show-status    -> inspect current batch delegation state

REPO_ROOT="."
ACTION="${1:-}"
if [[ $# -gt 0 ]]; then
  shift
fi

ROUND=""
BATCH=""
TRIGGER="plan batch"
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
    --batch) BATCH="$2"; shift 2 ;;
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

STATE_BASE="${REPO_ROOT}/.context/baton/active/batches"
TEMPLATE_PACKET="${REPO_ROOT}/v2/templates/batch-packet.template.md"
TEMPLATE_REPORT_MD="${REPO_ROOT}/v2/templates/worker-report.template.md"
TEMPLATE_REPORT_JSON="${REPO_ROOT}/v2/templates/worker-report.template.json"

usage() {
  cat <<'EOF'
Usage:
  bash v2/tools/builder-worker.sh init-batch \
    --round <N> --batch <M> [--trigger <text>] [--mode advisory|isolated] [--start-sha <sha>] [--repo-root <path>] [--force]

  bash v2/tools/builder-worker.sh run-worker \
    --round <N> --batch <M> [--worker-label <label>] [--mode advisory|isolated] [--repo-root <path>]

  bash v2/tools/builder-worker.sh collect-report \
    --round <N> --batch <M> --status complete|complete_with_concerns|needs_context|blocked \
    --summary <text> [--worker-label <label>] [--patch-path <path>] [--file <path>]... \
    [--concern <text>]... [--question <text>]... [--test-entry "<command>::<result>::<notes>"]... \
    [--repo-root <path>]

  bash v2/tools/builder-worker.sh show-status \
    [--round <N> [--batch <M>]] [--repo-root <path>]
EOF
}

require_action() {
  if [[ -z "$ACTION" ]]; then
    usage >&2
    exit 1
  fi
}

require_batch() {
  if [[ -z "$ROUND" || -z "$BATCH" ]]; then
    echo "Both --round and --batch are required." >&2
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

batch_dir() {
  printf '%s/round-%s/batch-%s' "$STATE_BASE" "$ROUND" "$BATCH"
}

state_file() {
  printf '%s/state.env' "$(batch_dir)"
}

packet_path() {
  printf '%s/packet.md' "$(batch_dir)"
}

report_md_path() {
  printf '%s/report.md' "$(batch_dir)"
}

report_json_path() {
  printf '%s/report.json' "$(batch_dir)"
}

worker_env_path() {
  printf '%s/worker.env' "$(batch_dir)"
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
  BATCH_VALUE="$BATCH" \
  TRIGGER_VALUE="$TRIGGER" \
  MODE_VALUE="$MODE" \
  START_SHA_VALUE="$START_SHA" \
  perl -0pe '
    s/\{N\}/$ENV{ROUND_VALUE}/g;
    s/\{M\}/$ENV{BATCH_VALUE}/g;
    s/\{plan batch \/ verifier finding \/ fix slice\}/$ENV{TRIGGER_VALUE}/g;
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
BATCH=$BATCH
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

require_batch_dir() {
  local dir
  dir="$(batch_dir)"
  if [[ ! -d "$dir" ]]; then
    echo "Batch directory not initialized: $dir" >&2
    exit 1
  fi
}

handle_init_batch() {
  require_batch
  validate_mode
  START_SHA="${START_SHA:-$(default_start_sha)}"

  local dir
  dir="$(batch_dir)"
  mkdir -p "$dir"

  if [[ -f "$(packet_path)" && "$FORCE" != true ]]; then
    echo "Batch packet already exists: $(packet_path)" >&2
    echo "Use --force to overwrite the scaffolding files." >&2
    exit 1
  fi

  render_packet_template "$(packet_path)"
  scaffold_if_missing "$TEMPLATE_REPORT_MD" "$(report_md_path)"
  scaffold_if_missing "$TEMPLATE_REPORT_JSON" "$(report_json_path)"
  write_state "initialized" "pending"

  cat <<EOF
Initialized batch scratch:
  packet: $(packet_path)
  report.md: $(report_md_path)
  report.json: $(report_json_path)
EOF
}

handle_run_worker() {
  require_batch
  validate_mode
  require_batch_dir

  local dispatched_at
  dispatched_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cat >"$(worker_env_path)" <<EOF
ROUND=$ROUND
BATCH=$BATCH
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
  batch: round-$ROUND / batch-$BATCH
  worker: ${WORKER_LABEL:-internal-worker}
  packet: $(packet_path)
EOF
}

handle_collect_report() {
  require_batch
  validate_mode
  validate_status
  require_batch_dir

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
# Worker Report: Round $ROUND Batch $BATCH

## Metadata

| Key | Value |
|-----|-------|
| Round | $ROUND |
| Batch | $BATCH |
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
    printf '  "batch": %s,\n' "$BATCH"
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
  if [[ -n "$ROUND" && -n "$BATCH" ]]; then
    require_batch_dir
    local dir
    dir="$(batch_dir)"
    echo "Batch scratch: $dir"
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
    echo "No active Builder batches found."
    return 0
  fi

  local round_dir batch_state batch_name
  for round_dir in "$STATE_BASE"/round-*; do
    [[ -d "$round_dir" ]] || continue
    for batch_state in "$round_dir"/batch-*/state.env; do
      [[ -f "$batch_state" ]] || continue
      batch_name="$(dirname "$batch_state")"
      echo "== ${batch_name#$REPO_ROOT/} =="
      cat "$batch_state"
    done
  done
}

require_action

case "$ACTION" in
  init-batch) handle_init_batch ;;
  run-worker) handle_run_worker ;;
  collect-report) handle_collect_report ;;
  show-status) handle_show_status ;;
  *)
    usage >&2
    exit 1
    ;;
esac
