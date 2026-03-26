#!/usr/bin/env bash
set -euo pipefail

repo_root="."
task_id=""
owner="scoped-explorer"
state="exploring"
notes="task row created by start-task bootstrap"
dry_run="false"

trim() {
  printf '%s' "$1" | sed 's/^[[:space:]\r]*//;s/[[:space:]\r]*$//'
}

sanitize_cell() {
  printf '%s' "$1" | tr '|' '/'
}

usage() {
  cat <<'EOF'
Usage:
  start-task.sh --task-id ID [--repo-root PATH] [--owner ROLE] [--state STATE] [--notes TEXT] [--dry-run]

Owners:
  repo-explorer
  scoped-explorer
  specifier
  architect
  verification-explorer
  generator
  reviewer
  evaluator
  human

States:
  exploring
  specifying
  architecting
  awaiting_human_arch
  verification_check
  generating
  reviewing
  blocked
  ready_for_human_close
  complete
EOF
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
    --dry-run)
      dry_run="true"
      shift
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

case "$owner" in
  repo-explorer|scoped-explorer|specifier|architect|verification-explorer|generator|reviewer|evaluator|human) ;;
  *)
    printf 'Unsupported owner: %s\n' "$owner" >&2
    exit 1
    ;;
esac

case "$state" in
  exploring|specifying|architecting|awaiting_human_arch|verification_check|generating|reviewing|blocked|ready_for_human_close|complete) ;;
  *)
    printf 'Unsupported state: %s\n' "$state" >&2
    exit 1
    ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
spec_root="$(cd "$script_dir/.." && pwd)"
templates_dir="$spec_root/templates"
resolved_repo_root="$(cd "$repo_root" && pwd)"
harness_dir="$resolved_repo_root/.harness"
module_status_path="$harness_dir/module-status.md"
history_root="$harness_dir/history"

if [[ ! -d "$harness_dir" ]]; then
  printf 'Harness directory not found: %s. Run init-harness first.\n' "$harness_dir" >&2
  exit 1
fi
if [[ ! -f "$module_status_path" ]]; then
  printf 'Module status file not found: %s. Run init-harness first.\n' "$module_status_path" >&2
  exit 1
fi

rows=()
last_scope="bootstrap"
duplicate_task="false"
open_rows=()
in_table="false"

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  line="$(trim "$raw_line")"

  if [[ "$line" == '## State Notes' ]]; then
    break
  fi

  if [[ "$line" == '| Scope | Owner | State | Updated At | Notes |' ]]; then
    in_table="true"
    continue
  fi

  if [[ "$in_table" != "true" ]]; then
    continue
  fi

  if [[ "$line" == '|------|------|------|-----------|------|' || -z "$line" ]]; then
    continue
  fi

  if [[ "$line" != \|* ]]; then
    continue
  fi

  trimmed_line="${line#|}"
  trimmed_line="${trimmed_line%|}"
  IFS='|' read -r scope_column owner_column state_column updated_column notes_column <<< "$trimmed_line"

  scope="$(trim "$scope_column")"
  row_state="$(trim "$state_column")"

  if [[ "$scope" == '<task-id>' ]]; then
    continue
  fi

  rows+=("$line")
  last_scope="$scope"

  if [[ "$scope" == "$task_id" ]]; then
    duplicate_task="true"
  fi

  if [[ "$row_state" != 'complete' ]]; then
    open_rows+=("$scope:$row_state")
  fi
done < "$module_status_path"

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
  "retrospective.template.md:retrospective.md"
)

archive_files=()
for entry in "${artifact_templates[@]}"; do
  template_name="${entry%%:*}"
  target_name="${entry##*:}"
  template_path="$templates_dir/$template_name"
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
  target_path="$harness_dir/$target_name"

  if [[ "$dry_run" == "true" ]]; then
    printf 'plan  %s\n' "$target_path"
  else
    cp "$templates_dir/$template_name" "$target_path"
    printf 'write %s\n' "$target_path"
  fi
done

safe_task_id="$(sanitize_cell "$task_id")"
safe_owner="$(sanitize_cell "$owner")"
safe_state="$(sanitize_cell "$state")"
safe_notes="$(sanitize_cell "$notes")"
new_row="| $safe_task_id | $safe_owner | $safe_state | $timestamp | $safe_notes |"

if [[ "$dry_run" == "true" ]]; then
  printf 'plan  %s\n' "$module_status_path"
else
  {
    printf '# Module Status\n\n'
    printf '| Scope | Owner | State | Updated At | Notes |\n'
    printf '|------|------|------|-----------|------|\n'
    for row in "${rows[@]}"; do
      printf '%s\n' "$row"
    done
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
if [[ "$dry_run" == "true" ]]; then
  printf 'Mode:     dry-run\n'
fi
printf '\nNext steps:\n'
printf '1. Fill .harness/scoped-map.md\n'
printf '2. Update .harness/module-status.md on each state transition\n'
printf '3. Archive completed task artifacts before the next task start\n'
