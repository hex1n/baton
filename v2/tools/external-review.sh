#!/usr/bin/env bash
set -euo pipefail

# Provider-neutral adapter for Baton's Mode C+ external review lifecycle.
# Reads project-profile.md § External Reviewer and exposes:
#   start / status / result / cancel
#
# Command templates come from the profile section and may use placeholders:
#   {job_id} {input} {base} {focus} {state_dir} {repo_root}
#
# If a provider needs more complex shell logic, point the command rows at a
# local helper script rather than embedding pipelines into the markdown table.

REPO_ROOT="."
ACTION="${1:-}"
if [[ $# -gt 0 ]]; then
  shift
fi

JOB_ID=""
KIND=""
INPUT_PATH=""
BASE_REF=""
FOCUS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    --job-id) JOB_ID="$2"; shift 2 ;;
    --kind) KIND="$2"; shift 2 ;;
    --input) INPUT_PATH="$2"; shift 2 ;;
    --base) BASE_REF="$2"; shift 2 ;;
    --focus) FOCUS="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

PROFILE="${REPO_ROOT}/project-profile.md"
STATE_BASE="${REPO_ROOT}/.context/baton/active/external-review"

usage() {
  cat <<'EOF'
Usage:
  bash v2/tools/external-review.sh start  --kind review|challenge --input <path> [--base <git-ref>] [--focus <text>] [--repo-root <path>]
  bash v2/tools/external-review.sh status --job-id <id> [--repo-root <path>]
  bash v2/tools/external-review.sh result --job-id <id> [--repo-root <path>]
  bash v2/tools/external-review.sh cancel --job-id <id> [--repo-root <path>]
EOF
}

if [[ -z "$ACTION" ]]; then
  usage >&2
  exit 1
fi

if [[ ! -f "$PROFILE" ]]; then
  echo "project-profile.md not found: $PROFILE" >&2
  exit 1
fi

normalize_value() {
  local value="$1"
  value="${value//$'\r'/}"
  value="${value#\`}"
  value="${value%\`}"
  printf '%s' "$value"
}

profile_value() {
  local key="$1"
  awk -F'|' -v wanted="$key" '
    /^## External Reviewer/ { in_section=1; next }
    /^## / && in_section { exit }
    in_section && $0 ~ /^\|/ {
      key=$2
      value=$3
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      if (key == wanted) {
        print value
        exit
      }
    }
  ' "$PROFILE"
}

PROFILE_PROVIDER="$(normalize_value "$(profile_value "Provider")")"
PROFILE_AVAILABILITY="$(normalize_value "$(profile_value "Availability")")"
PROFILE_START_REVIEW="$(normalize_value "$(profile_value "Start review command")")"
PROFILE_START_CHALLENGE="$(normalize_value "$(profile_value "Start challenge command")")"
PROFILE_STATUS="$(normalize_value "$(profile_value "Status command")")"
PROFILE_RESULT="$(normalize_value "$(profile_value "Result command")")"
PROFILE_CANCEL="$(normalize_value "$(profile_value "Cancel command")")"

ensure_available() {
  if [[ -z "$PROFILE_PROVIDER" || "$PROFILE_PROVIDER" == "none" || "$PROFILE_PROVIDER" == "N/A" ]]; then
    echo "External reviewer is not configured in project-profile.md § External Reviewer." >&2
    exit 1
  fi

  if [[ "$PROFILE_AVAILABILITY" != "✅" ]]; then
    echo "External reviewer provider '$PROFILE_PROVIDER' is marked unavailable." >&2
    exit 1
  fi
}

require_job_dir() {
  local job_dir="${STATE_BASE}/${JOB_ID}"
  if [[ -z "$JOB_ID" || ! -d "$job_dir" ]]; then
    echo "Unknown external-review job id: ${JOB_ID:-<empty>}" >&2
    exit 1
  fi
  printf '%s' "$job_dir"
}

write_meta() {
  local job_dir="$1"
  cat >"${job_dir}/meta.env" <<EOF
JOB_ID=$JOB_ID
ACTION_KIND=$KIND
PROVIDER=$PROFILE_PROVIDER
INPUT_PATH=$INPUT_PATH
BASE_REF=$BASE_REF
FOCUS=$FOCUS
REPO_ROOT=$REPO_ROOT
EOF
}

render_command() {
  local template="$1"
  local job_dir="$2"
  local rendered="$template"
  rendered="${rendered//\{job_id\}/$JOB_ID}"
  rendered="${rendered//\{input\}/$INPUT_PATH}"
  rendered="${rendered//\{base\}/$BASE_REF}"
  rendered="${rendered//\{focus\}/$FOCUS}"
  rendered="${rendered//\{state_dir\}/$job_dir}"
  rendered="${rendered//\{repo_root\}/$REPO_ROOT}"
  printf '%s' "$rendered"
}

run_template() {
  local template="$1"
  local job_dir="$2"
  local phase="$3"

  if [[ -z "$template" || "$template" == "N/A" ]]; then
    echo "No command configured for ${phase}." >&2
    return 1
  fi

  local command
  command="$(render_command "$template" "$job_dir")"
  printf '%s\n' "$command" >"${job_dir}/${phase}.command"

  if bash -lc "$command" >"${job_dir}/${phase}.stdout" 2>"${job_dir}/${phase}.stderr"; then
    echo "success" >"${job_dir}/${phase}.status"
    return 0
  else
    echo "failed" >"${job_dir}/${phase}.status"
    return 1
  fi
}

case "$ACTION" in
  start)
    ensure_available
    if [[ "$KIND" != "review" && "$KIND" != "challenge" ]]; then
      echo "start requires --kind review|challenge" >&2
      exit 1
    fi
    if [[ -z "$INPUT_PATH" ]]; then
      echo "start requires --input <path>" >&2
      exit 1
    fi

    mkdir -p "$STATE_BASE"
    JOB_ID="${KIND}-$(date +%Y%m%d%H%M%S)-$$"
    job_dir="${STATE_BASE}/${JOB_ID}"
    mkdir -p "$job_dir"
    write_meta "$job_dir"

    if [[ "$KIND" == "review" ]]; then
      command_template="$PROFILE_START_REVIEW"
    else
      command_template="$PROFILE_START_CHALLENGE"
    fi

    if run_template "$command_template" "$job_dir" "start"; then
      echo "started" >"${job_dir}/state"
      echo "$JOB_ID"
    else
      echo "failed" >"${job_dir}/state"
      echo "External review start failed for job ${JOB_ID}. See ${job_dir}/start.stderr" >&2
      exit 1
    fi
    ;;

  status)
    ensure_available
    job_dir="$(require_job_dir)"
    if [[ -n "$PROFILE_STATUS" && "$PROFILE_STATUS" != "N/A" ]]; then
      if run_template "$PROFILE_STATUS" "$job_dir" "status"; then
        echo "running" >"${job_dir}/state"
        cat "${job_dir}/status.stdout"
      else
        echo "status-error" >"${job_dir}/state"
        cat "${job_dir}/status.stderr" >&2
        exit 1
      fi
    else
      cat "${job_dir}/state" 2>/dev/null || echo "unknown"
    fi
    ;;

  result)
    ensure_available
    job_dir="$(require_job_dir)"
    if [[ -n "$PROFILE_RESULT" && "$PROFILE_RESULT" != "N/A" ]]; then
      if run_template "$PROFILE_RESULT" "$job_dir" "result"; then
        echo "complete" >"${job_dir}/state"
        cat "${job_dir}/result.stdout"
      else
        echo "result-error" >"${job_dir}/state"
        cat "${job_dir}/result.stderr" >&2
        exit 1
      fi
    else
      cat "${job_dir}/start.stdout" 2>/dev/null || true
    fi
    ;;

  cancel)
    ensure_available
    job_dir="$(require_job_dir)"
    if [[ -n "$PROFILE_CANCEL" && "$PROFILE_CANCEL" != "N/A" ]]; then
      if run_template "$PROFILE_CANCEL" "$job_dir" "cancel"; then
        echo "cancelled" >"${job_dir}/state"
        cat "${job_dir}/cancel.stdout"
      else
        echo "cancel-error" >"${job_dir}/state"
        cat "${job_dir}/cancel.stderr" >&2
        exit 1
      fi
    else
      echo "cancelled" >"${job_dir}/state"
      echo "Cancelled local Baton job ${JOB_ID} (provider has no cancel command configured)."
    fi
    ;;

  *)
    usage >&2
    exit 1
    ;;
esac
