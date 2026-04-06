#!/usr/bin/env bash
# backfill-lessons.sh — one-shot seed for knowledge/lessons.md
#
# Walks .harness/history/<ts>-<slug>/retrospective.md in the current repo,
# extracts the "Repo-Specific Lessons" and "Harness Lessons" sections
# (matches both English and the legacy Chinese headings), and writes a
# draft to <repo-root>/knowledge/lessons.md.draft for human review.
#
# After review, the user promotes the draft manually:
#   mv knowledge/lessons.md.draft knowledge/lessons.md
#
# This is a BOOTSTRAP tool. After the initial seed, new lessons arrive
# automatically via start-task.sh extraction at task-start time.
#
# Gate 2 decision D-6 (2026-04-05): semi-automatic — script extracts
# everything, human filters for signal. See .harness/decisions.md.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../.." && pwd)"

history_dir="$repo_root/.harness/history"
draft_path="$repo_root/knowledge/lessons.md.draft"

if [[ ! -d "$history_dir" ]]; then
  printf 'ERROR: no .harness/history directory at %s — nothing to backfill\n' "$history_dir" >&2
  exit 1
fi

mkdir -p "$(dirname "$draft_path")"

# Section patterns to match (English + legacy Chinese).
# Each entry matches "## [N. ]<pattern>" at level-2.
# Order matters for output grouping.
section_patterns=(
  'Repo.Specific Lessons'
  'Harness Lessons'
  '仓库特定经验'
  'Harness[[:space:]]*协议经验'
  'Harness[[:space:]]*经验'
)

extract_section() {
  local file="$1" pattern="$2"
  sed -n "/^## \([0-9][0-9]*\. \)\{0,1\}${pattern}/,/^## /{ /^## \([0-9][0-9]*\. \)\{0,1\}${pattern}/d; /^## /d; p; }" "$file" 2>/dev/null \
    | sed -e '/^$/N;/^\n$/D'  # collapse duplicate blank lines
}

# Non-empty check: strip whitespace and markdown placeholders
has_real_content() {
  local block="$1"
  local stripped
  stripped="$(printf '%s' "$block" \
    | sed -e 's/^[[:space:]]*-[[:space:]]*$//' \
          -e 's/<[^>]*>//g' \
    | tr -d '[:space:]-')"
  [[ -n "$stripped" ]]
}

# Collect retros in chronological order (directory names start with
# YYYYMMDDTHHMMSS so a lexical sort is chronological).
retros=()
while IFS= read -r path; do
  [[ -f "$path" ]] || continue
  retros+=("$path")
done < <(find "$history_dir" -type f -name retrospective.md | sort)

if [[ "${#retros[@]}" -eq 0 ]]; then
  printf 'no retrospectives found under %s\n' "$history_dir" >&2
  exit 1
fi

# Build the draft.
{
  printf '# Lessons (DRAFT — needs human review)\n\n'
  printf '> Auto-extracted from `.harness/history/*/retrospective.md` on %s.\n' "$(date '+%Y-%m-%d')"
  printf '> **Do not promote as-is.** Review every bullet against the non-obvious\n'
  printf '> bar from `skills/baton-retrospective/SKILL.md`:\n'
  printf '>\n'
  printf '> - past task actually got burned on this, AND\n'
  printf '> - likely to re-bite a future similar task, AND\n'
  printf '> - not generic process advice.\n'
  printf '>\n'
  printf '> Delete bullets that are boilerplate ("remember to test", "communicate\n'
  printf '> early"), project-specific trivia with no transfer value, or one-shot\n'
  printf '> artifacts of this particular run. After filtering, move to\n'
  printf '> `knowledge/lessons.md` with:\n'
  printf '>\n'
  printf '>     mv knowledge/lessons.md.draft knowledge/lessons.md\n'
  printf '>\n'

  total=0
  kept=0
  for retro in "${retros[@]}"; do
    total=$((total + 1))
    # task id = parent dir name
    task_id="$(basename "$(dirname "$retro")")"
    # source path relative to repo root for provenance
    rel_path="${retro#$repo_root/}"

    task_block=""
    for pattern in "${section_patterns[@]}"; do
      block="$(extract_section "$retro" "$pattern" || true)"
      if has_real_content "$block"; then
        # Label the block with its original heading (normalize to English
        # for index grouping — human reviewer can re-organize).
        case "$pattern" in
          'Repo.Specific Lessons'|'仓库特定经验')
            header='Repo-Specific'
            ;;
          *'Harness'*)
            header='Harness'
            ;;
          *)
            header="$pattern"
            ;;
        esac
        task_block="${task_block}  *${header}:*"$'\n'"${block}"$'\n'
      fi
    done

    if [[ -n "$task_block" ]]; then
      kept=$((kept + 1))
      printf '\n## %s\n\n' "$task_id"
      printf '**Source:** `%s`\n\n' "$rel_path"
      printf '%s' "$task_block"
    fi
  done

  printf '\n---\n\n'
  printf '_Extracted from %d retrospective(s); %d contained lesson content._\n' "$total" "$kept"
} > "$draft_path"

printf 'wrote %s\n' "$draft_path"
printf 'next: review the draft, delete low-signal bullets, then:\n'
printf '  mv %s %s\n' "$draft_path" "${draft_path%.draft}"
