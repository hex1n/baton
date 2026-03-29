#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/module-status.sh"

repo_root="."
task_id=""
owner="scoped-explorer"
state="exploring"
notes="task row created by start-task bootstrap"
language=""
dry_run="false"

trim() {
  printf '%s' "$1" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

sanitize_cell() {
  printf '%s' "$1" | tr '|' '/'
}

normalize_language() {
  local value="${1:-}"
  value="${value%%#*}"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | sed "s/^[[:space:]\"']*//;s/[[:space:]\"']*$//")"
  printf '%s' "$value"
}

resolve_locale_language() {
  local locale_value="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
  local normalized
  normalized="$(printf '%s' "$locale_value" | tr '[:upper:]' '[:lower:]')"

  if [[ "$normalized" == zh* ]]; then
    printf '%s' 'zh'
    return
  fi

  printf '%s' 'en'
}

read_profile_language() {
  local profile_path="$1"
  local raw=''

  if [[ ! -f "$profile_path" ]]; then
    printf '%s' ''
    return
  fi

  raw="$(awk -F: '/^[[:space:]]*artifact_language:[[:space:]]*/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}' "$profile_path")"
  raw="$(printf '%s' "$raw" | sed "s/[[:space:]]*#.*$//;s/^[[:space:]\"']*//;s/[[:space:]\"']*$//" | tr '[:upper:]' '[:lower:]')"
  printf '%s' "$raw"
}

resolve_artifact_language() {
  local policy
  policy="$(normalize_language "$1")"

  if [[ -z "$policy" || "$policy" == 'auto' ]]; then
    resolve_locale_language
    return
  fi

  printf '%s' "$policy"
}

human_template_path() {
  local template_name="$1"
  local resolved_language="$2"
  local override_root=""
  local override_candidate=""
  local candidate="$templates_dir/$template_name"

  if [[ -n "${resolved_repo_root:-}" ]]; then
    override_root="$resolved_repo_root/.harness/overrides/templates"
    if [[ "$resolved_language" == 'zh' ]]; then
      override_candidate="$override_root/zh/$template_name"
    else
      override_candidate="$override_root/$template_name"
    fi

    if [[ -f "$override_candidate" ]]; then
      printf '%s' "$override_candidate"
      return 0
    fi
  fi

  if [[ "$resolved_language" == 'zh' ]]; then
    candidate="$templates_dir/zh/$template_name"
  fi

  if [[ ! -f "$candidate" ]]; then
    printf 'Template not found: %s\n' "$candidate" >&2
    exit 1
  fi

  printf '%s' "$candidate"
}

usage() {
  local owners_file="$script_dir/../protocol/owners.txt"
  local states_file="$script_dir/../protocol/states.txt"
  printf 'Usage:\n  start-task.sh --task-id ID [--repo-root PATH] [--owner ROLE] [--state STATE] [--notes TEXT] [--language auto|en|zh] [--dry-run]\n\nOwners:\n'
  if [[ -f "$owners_file" ]]; then
    while IFS= read -r token; do
      printf '  %s\n' "$token"
    done < "$owners_file"
  else
    printf '  (owners.txt not found at %s)\n' "$owners_file"
  fi
  printf '\nStates:\n'
  if [[ -f "$states_file" ]]; then
    while IFS= read -r token; do
      printf '  %s\n' "$token"
    done < "$states_file"
  else
    printf '  (states.txt not found at %s)\n' "$states_file"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      repo_root="$2"
      shift 2
      ;;
    --task-id)
      task_id="$2"
      shift 2
      ;;
    --owner)
      owner="$2"
      shift 2
      ;;
    --state)
      state="$2"
      shift 2
      ;;
    --notes)
      notes="$2"
      shift 2
      ;;
    --language)
      language="$2"
      shift 2
      ;;
    --dry-run)
      dry_run="true"
      shift
      ;;
    --version)
      printf 'harness-spec v%s\n' "$(cat "$script_dir/../VERSION")"
      exit 0
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$task_id" ]]; then
  printf 'Missing required argument: --task-id\n' >&2
  usage >&2
  exit 1
fi

language="$(normalize_language "$language")"
if [[ -n "$language" ]]; then
  case "$language" in
    auto|en|zh) ;;
    *)
      printf 'Unsupported language: %s\n' "$language" >&2
      exit 1
      ;;
  esac
fi

owners_file="$script_dir/../protocol/owners.txt"
if [[ ! -f "$owners_file" ]]; then
  printf 'owners.txt not found: %s\n' "$owners_file" >&2
  exit 1
fi
if ! grep -Fxq "$owner" "$owners_file"; then
  printf 'Unsupported owner: %s\n' "$owner" >&2
  exit 1
fi

states_file="$script_dir/../protocol/states.txt"
if [[ ! -f "$states_file" ]]; then
  printf 'states.txt not found: %s\n' "$states_file" >&2
  exit 1
fi
if ! grep -Fxq "$state" "$states_file"; then
  printf 'Unsupported state: %s\n' "$state" >&2
  exit 1
fi

spec_root="$(cd "$script_dir/.." && pwd)"
templates_dir="$spec_root/templates"
resolved_repo_root="$(cd "$repo_root" && pwd)"
harness_dir="$resolved_repo_root/.harness"
module_status_path="$harness_dir/module-status.md"
history_root="$harness_dir/history"
profile_local_path="$harness_dir/profile.local.yaml"

if [[ ! -d "$harness_dir" ]]; then
  printf 'Harness directory not found: %s. Run init-harness first.\n' "$harness_dir" >&2
  exit 1
fi
if [[ ! -f "$module_status_path" ]]; then
  printf 'Module status file not found: %s. Run init-harness first.\n' "$module_status_path" >&2
  exit 1
fi

module_status_schema_value="$(module_status_schema "$module_status_path")"
case "$module_status_schema_value" in
  current|legacy) ;;
  *)
    printf 'Unsupported module-status schema: %s\n' "$module_status_schema_value" >&2
    exit 1
    ;;
esac

profile_language="$(read_profile_language "$profile_local_path")"
if [[ -n "$profile_language" ]]; then
  case "$profile_language" in
    auto|en|zh) ;;
    *)
      printf 'Unsupported artifact language in profile.local.yaml: %s\n' "$profile_language" >&2
      exit 1
      ;;
  esac
fi

language_policy="$language"
if [[ -z "$language_policy" ]]; then
  language_policy="$profile_language"
fi
if [[ -z "$language_policy" ]]; then
  language_policy='zh'
fi

resolved_artifact_language="$(resolve_artifact_language "$language_policy")"

rows=()
last_scope="bootstrap"
duplicate_task="false"
open_rows=()

while IFS=$'\t' read -r scope owner_column row_state eval_round updated_column notes_column; do
  [[ -n "$scope" ]] || continue

  rows+=("| $(sanitize_cell "$scope") | $(sanitize_cell "$owner_column") | $(sanitize_cell "$row_state") | $(sanitize_cell "$eval_round") | $(sanitize_cell "$updated_column") | $(sanitize_cell "$notes_column") |")
  last_scope="$scope"

  if [[ "$scope" == "$task_id" ]]; then
    duplicate_task="true"
  fi

  if [[ "$row_state" != 'complete' ]]; then
    open_rows+=("$scope:$row_state")
  fi
done < <(module_status_rows_tsv "$module_status_path")

if [[ "$duplicate_task" == "true" ]]; then
  printf 'Task already exists in module-status.md: %s\n' "$task_id" >&2
  exit 1
fi

if [[ "${#open_rows[@]}" -gt 0 ]]; then
  printf 'Cannot start a new task while non-complete task rows exist: %s\n' "$(IFS=', '; printf '%s' "${open_rows[*]}")" >&2
  exit 1
fi

artifact_templates=(
  "scoped-map.template.md:scoped-map.md"
  "requirements.template.md:requirements.md"
  "architecture.template.md:architecture.md"
  "verification-path.template.md:verification-path.md"
  "evaluation.template.md:evaluation.md"
  "retrospective.template.md:retrospective.md"
)

archive_files=()
for entry in "${artifact_templates[@]}"; do
  template_name="${entry%%:*}"
  target_name="${entry##*:}"
  template_path="$(human_template_path "$template_name" "$resolved_artifact_language")"
  target_path="$harness_dir/$target_name"

  if [[ -f "$target_path" ]] && ! cmp -s "$template_path" "$target_path"; then
    archive_files+=("$target_name")
  fi
done

timestamp="$(date '+%Y-%m-%dT%H:%M:%S%z')"
history_stamp="$(date '+%Y%m%dT%H%M%S')"
archive_label="$(sanitize_cell "$last_scope" | tr ' ' '-')"
archive_dir="$history_root/$history_stamp-$archive_label"

if [[ "${#archive_files[@]}" -gt 0 ]]; then
  if [[ "$dry_run" == "true" ]]; then
    printf 'plan  %s\n' "$archive_dir"
    for file_name in "${archive_files[@]}"; do
      printf 'plan  %s\n' "$archive_dir/$file_name"
    done
  else
    mkdir -p "$archive_dir"
    for file_name in "${archive_files[@]}"; do
      cp "$harness_dir/$file_name" "$archive_dir/$file_name"
      printf 'write %s\n' "$archive_dir/$file_name"
    done
  fi
fi

for entry in "${artifact_templates[@]}"; do
  template_name="${entry%%:*}"
  target_name="${entry##*:}"
  template_path="$(human_template_path "$template_name" "$resolved_artifact_language")"
  target_path="$harness_dir/$target_name"

  if [[ "$dry_run" == "true" ]]; then
    printf 'plan  %s\n' "$target_path"
  else
    cp "$template_path" "$target_path"
    printf 'write %s\n' "$target_path"
  fi
done

safe_task_id="$(sanitize_cell "$task_id")"
safe_owner="$(sanitize_cell "$owner")"
safe_state="$(sanitize_cell "$state")"
safe_notes="$(sanitize_cell "$notes")"
new_row="| $safe_task_id | $safe_owner | $safe_state | 0 | $timestamp | $safe_notes |"

if [[ "$dry_run" == "true" ]]; then
  printf 'plan  %s\n' "$module_status_path"
else
  {
    printf '# Module Status\n\n'
    printf '| Scope | Owner | State | Eval Round | Updated At | Notes |\n'
    printf '|------|------|------|-----------|-----------|------|\n'
    if [[ "${#rows[@]}" -gt 0 ]]; then
      for row in "${rows[@]}"; do
        printf '%s\n' "$row"
      done
    fi
    printf '%s\n' "$new_row"
    printf '\n## State Notes\n\n'
    printf -- '- Current artifacts: active task initialized for %s\n' "$safe_task_id"
    printf -- '- Current blockers: none\n'
    printf -- '- Current residual risks: none recorded yet\n'
    printf -- '- Current next decision: run Scoped Explorer\n'
  } > "$module_status_path"
  printf 'write %s\n' "$module_status_path"
fi

printf '\nHarness task initialization complete.\n'
printf 'Repo:     %s\n' "$resolved_repo_root"
printf 'TaskId:   %s\n' "$safe_task_id"
printf 'Owner:    %s\n' "$safe_owner"
printf 'State:    %s\n' "$safe_state"
printf 'Language Policy:   %s\n' "$language_policy"
printf 'Artifact Language: %s\n' "$resolved_artifact_language"
if [[ "$dry_run" == "true" ]]; then
  printf 'Mode:     dry-run\n'
fi
printf '\nNext steps:\n'
printf '1. Fill .harness/scoped-map.md\n'
printf '2. Update .harness/module-status.md on each state transition\n'
printf '3. Archive completed task artifacts before the next task start\n'
