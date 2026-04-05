#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bootstrap_dir="$(cd "$script_dir/.." && pwd)"
spec_root="$(cd "$bootstrap_dir/.." && pwd)"
source "$bootstrap_dir/lib/task-status.sh"
source "$bootstrap_dir/lib/profile.sh"

repo_root="."
task_id=""
owner="scoped-explorer"
state="exploring"
notes="task row created by start-task bootstrap"
dry_run="false"

trim() {
  printf '%s' "$1" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

sanitize_cell() {
  printf '%s' "$1" | tr '|' '/'
}

human_template_path() {
  local template_name="$1"
  local override_root=""
  local override_candidate=""
  local candidate="$templates_dir/$template_name"

  if [[ -n "${resolved_repo_root:-}" ]]; then
    override_root="$resolved_repo_root/.harness/overrides/templates"
    override_candidate="$override_root/$template_name"

    if [[ -f "$override_candidate" ]]; then
      printf '%s' "$override_candidate"
      return 0
    fi
  fi

  if [[ ! -f "$candidate" ]]; then
    printf 'Template not found: %s\n' "$candidate" >&2
    exit 1
  fi

  printf '%s' "$candidate"
}

usage() {
  local owners_file="$spec_root/protocol/owners.txt"
  local states_file="$spec_root/protocol/states.txt"
  printf 'Usage:\n  start-task.sh --task-id ID [--repo-root PATH] [--owner ROLE] [--state STATE] [--notes TEXT] [--dry-run]\n\nOwners:\n'
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
    --dry-run)
      dry_run="true"
      shift
      ;;
    --version)
      printf 'harness-spec v%s\n' "$(cat "$spec_root/VERSION")"
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

owners_file="$spec_root/protocol/owners.txt"
if [[ ! -f "$owners_file" ]]; then
  printf 'owners.txt not found: %s\n' "$owners_file" >&2
  exit 1
fi
if ! grep -Fxq "$owner" "$owners_file"; then
  printf 'Unsupported owner: %s\n' "$owner" >&2
  exit 1
fi

states_file="$spec_root/protocol/states.txt"
if [[ ! -f "$states_file" ]]; then
  printf 'states.txt not found: %s\n' "$states_file" >&2
  exit 1
fi
if ! grep -Fxq "$state" "$states_file"; then
  printf 'Unsupported state: %s\n' "$state" >&2
  exit 1
fi

templates_dir="$spec_root/templates"
resolved_repo_root="$(cd "$repo_root" && pwd)"
harness_dir="$resolved_repo_root/.harness"
task_status_path="$harness_dir/task-status.md"
history_root="$harness_dir/history"
profile_local_path="$harness_dir/profile.local.yaml"

if [[ ! -d "$harness_dir" ]]; then
  printf 'Harness directory not found: %s. Run init-harness first.\n' "$harness_dir" >&2
  exit 1
fi
if [[ ! -f "$task_status_path" ]]; then
  printf 'Module status file not found: %s. Run init-harness first.\n' "$task_status_path" >&2
  exit 1
fi

task_status_schema_value="$(task_status_schema "$task_status_path")"
case "$task_status_schema_value" in
  current|legacy) ;;
  *)
    printf 'Unsupported task-status schema: %s\n' "$task_status_schema_value" >&2
    exit 1
    ;;
esac

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
done < <(task_status_rows_tsv "$task_status_path")

if [[ "$duplicate_task" == "true" ]]; then
  printf 'Task already exists in task-status.md: %s\n' "$task_id" >&2
  exit 1
fi

if [[ "${#open_rows[@]}" -gt 0 ]]; then
  printf 'Cannot start a new task while non-complete task rows exist: %s\n' "$(IFS=', '; printf '%s' "${open_rows[*]}")" >&2
  exit 1
fi

artifact_templates=(
  "exploration.template.md:exploration.md"
  "requirements.template.md:requirements.md"
  "architecture.template.md:architecture.md"
  "verification.template.md:verification.md"
  "evaluation.template.md:evaluation.md"
  "retrospective.template.md:retrospective.md"
  "decisions.template.md:decisions.md"
  "codebase-map.template.md:codebase-map.md"
)

archive_files=()
for entry in "${artifact_templates[@]}"; do
  template_name="${entry%%:*}"
  target_name="${entry##*:}"
  template_path="$(human_template_path "$template_name")"
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

# -- lesson-index extraction from outgoing retrospective --
lesson_index_path="$harness_dir/lesson-index.md"
retro_path="$harness_dir/retrospective.md"
max_lesson_tasks=10

if [[ "${#archive_files[@]}" -gt 0 && -f "$retro_path" ]]; then
  # Extract Repo-Specific Lessons and Harness Lessons sections
  extracted=""
  for section_pattern in 'Repo.Specific Lessons' 'Harness Lessons'; do
    block="$(sed -n "/^###.*${section_pattern}/,/^###/{ /^###.*${section_pattern}/d; /^###/d; p; }" "$retro_path" 2>/dev/null || true)"
    if [[ -n "$block" ]]; then
      extracted="${extracted}${block}"$'\n'
    fi
  done

  if [[ -n "$(printf '%s' "$extracted" | tr -d '[:space:]')" ]]; then
    entry_header="## ${last_scope} ($(date '+%Y-%m-%d'))"
    new_entry="${entry_header}"$'\n'"${extracted}"

    if [[ "$dry_run" == "true" ]]; then
      printf 'plan  %s (append lesson)\n' "$lesson_index_path"
    else
      # Ensure lesson-index.md exists with the template header
      if [[ ! -f "$lesson_index_path" ]]; then
        cp "$(human_template_path "lesson-index.template.md")" "$lesson_index_path"
      fi

      # Read existing header (lines before first ## entry)
      header="$(sed -n '1,/^## /{/^## /!p;}' "$lesson_index_path")"
      # Read existing entries
      existing_entries="$(sed -n '/^## /,$p' "$lesson_index_path")"

      # Rebuild: header + new entry (newest first) + existing entries, pruned to max tasks
      {
        printf '%s\n\n' "$header"
        printf '%s\n' "$new_entry"
        if [[ -n "$existing_entries" ]]; then
          printf '%s\n' "$existing_entries"
        fi
      } > "$lesson_index_path.tmp"

      # LRU prune: keep only the most recent $max_lesson_tasks entry blocks
      awk -v max="$max_lesson_tasks" '
        /^## / { count++ }
        count <= max { print }
      ' "$lesson_index_path.tmp" > "$lesson_index_path"
      rm -f "$lesson_index_path.tmp"

      printf 'write %s\n' "$lesson_index_path"
    fi
  fi
fi

for entry in "${artifact_templates[@]}"; do
  template_name="${entry%%:*}"
  target_name="${entry##*:}"
  template_path="$(human_template_path "$template_name")"
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
  printf 'plan  %s\n' "$task_status_path"
else
  {
    printf '# Task Status\n\n'
    printf '| Scope | Owner | State | Eval Round | Updated At | Notes |\n'
    printf '|------|------|------|-----------|-----------|------|\n'
    if [[ "${#rows[@]}" -gt 0 ]]; then
      for row in "${rows[@]}"; do
        printf '%s\n' "$row"
      done
    fi
    printf '%s\n' "$new_row"
    printf '\n## State Notes\n\n'
    printf -- '- Risk level:\n'
    printf -- '- Current artifacts: active task initialized for %s\n' "$safe_task_id"
    printf -- '- Current blockers: none\n'
    printf -- '- Current residual risks: none recorded yet\n'
    printf -- '- Current next decision: run Scoped Explorer\n'
  } > "$task_status_path"
  printf 'write %s\n' "$task_status_path"
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
printf '1. Fill .harness/exploration.md\n'
printf '2. Update .harness/task-status.md on each state transition\n'
printf '3. Archive completed task artifacts before the next task start\n'
