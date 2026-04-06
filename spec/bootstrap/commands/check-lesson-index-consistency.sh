#!/usr/bin/env bash
# check-lesson-index-consistency.sh — static consistency check for the
# lesson-index write/read path.
#
# Background: commit 884e4ce wired start-task.sh to extract lesson
# sections from retrospective.md into a lesson index, but silently failed
# for months because three independent files had drifted:
#   1. start-task.sh sed regex expected level-3 headings (`^###`)
#   2. retrospective.template.md used level-2 numbered headings
#   3. baton-retrospective/SKILL.md output template used a different form
# No single file edit triggered a test; the whole extractor returned an
# empty string every run and no one noticed.
#
# This script exists so that any future edit to any of the three files
# fails CI / pre-commit until they are re-aligned. Intended usage:
#   bash spec/bootstrap/commands/check-lesson-index-consistency.sh
# Exit 0 = consistent; exit 1 = drift detected (with diagnostics).
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../.." && pwd)"

start_task="$repo_root/spec/bootstrap/commands/start-task.sh"
retro_template="$repo_root/spec/templates/retrospective.template.md"
retro_skill="$repo_root/skills/baton-retrospective/SKILL.md"
role_contracts="$repo_root/spec/protocol/role-contracts.md"
artifact_schema="$repo_root/spec/protocol/artifact-schema.md"
explorer_skill="$repo_root/skills/baton-explorer/SKILL.md"
explorer_template="$repo_root/spec/templates/exploration.template.md"

fail=0
report() {
  printf 'ERROR: %s\n' "$1" >&2
  fail=1
}

# ---- Check 1: start-task.sh regex shape ------------------------------------
# The extractor must match level-2 headings with optional numeric prefix,
# NOT level-3 headings (which was the original bug).
if [[ ! -f "$start_task" ]]; then
  report "start-task.sh missing at $start_task"
else
  if grep -Eq "sed[[:space:]]+-n[[:space:]]+\"/\^###" "$start_task"; then
    report "start-task.sh still contains a '^###' sed pattern — regex expects level-3 headings, but retrospective templates use level-2. See comment in start-task.sh near 'lesson-index extraction'."
  fi
  if ! grep -Fq "Repo.Specific Lessons" "$start_task"; then
    report "start-task.sh lost the 'Repo.Specific Lessons' section pattern — extractor will never match."
  fi
  if ! grep -Fq "Harness Lessons" "$start_task"; then
    report "start-task.sh lost the 'Harness Lessons' section pattern — extractor will never match."
  fi
  if ! grep -Eq 'lesson_index_path=.*knowledge/lessons\.md' "$start_task"; then
    report "start-task.sh lesson_index_path no longer points at <repo_root>/knowledge/lessons.md — Gate 2 D-1 decision (2026-04-05) requires knowledge/ at repo root."
  fi
fi

# ---- Check 2: retrospective.template.md headings ---------------------------
if [[ ! -f "$retro_template" ]]; then
  report "retrospective.template.md missing at $retro_template"
else
  if ! grep -Eq '^## ([0-9]+\. )?Repo-Specific Lessons' "$retro_template"; then
    report "retrospective.template.md missing '## Repo-Specific Lessons' (with optional 'N. ' prefix) heading — extractor regex won't match this file."
  fi
  if ! grep -Eq '^## ([0-9]+\. )?Harness Lessons' "$retro_template"; then
    report "retrospective.template.md missing '## Harness Lessons' (with optional 'N. ' prefix) heading — extractor regex won't match this file."
  fi
fi

# ---- Check 3: baton-retrospective/SKILL.md output template -----------------
if [[ ! -f "$retro_skill" ]]; then
  report "baton-retrospective/SKILL.md missing at $retro_skill"
else
  if ! grep -Eq '^## ([0-9]+\. )?Repo-Specific Lessons' "$retro_skill"; then
    report "baton-retrospective/SKILL.md output template missing '## Repo-Specific Lessons' heading — generated retrospectives won't be extracted."
  fi
  if ! grep -Eq '^## ([0-9]+\. )?Harness Lessons' "$retro_skill"; then
    report "baton-retrospective/SKILL.md output template missing '## Harness Lessons' heading — generated retrospectives won't contribute harness lessons."
  fi
fi

# ---- Check 4: protocol docs reference the current path ---------------------
if [[ -f "$role_contracts" ]]; then
  if grep -Fq '.harness/lesson-index.md' "$role_contracts"; then
    report "role-contracts.md still references the legacy path '.harness/lesson-index.md' — update to 'knowledge/lessons.md'."
  fi
  if ! grep -Fq 'knowledge/lessons.md' "$role_contracts"; then
    report "role-contracts.md does not mention 'knowledge/lessons.md' — path decision not wired into protocol docs."
  fi
fi
if [[ -f "$artifact_schema" ]]; then
  if grep -Eq '^### .harness/lesson-index\.md' "$artifact_schema" 2>/dev/null \
      || grep -Fq '### `lesson-index.md`' "$artifact_schema"; then
    report "artifact-schema.md still describes the legacy '.harness/lesson-index.md' as an in-harness artifact — should be under 'External Artifacts' as 'knowledge/lessons.md'."
  fi
  if ! grep -Fq 'knowledge/lessons.md' "$artifact_schema"; then
    report "artifact-schema.md does not register 'knowledge/lessons.md' under External Artifacts."
  fi
fi

# ---- Check 5: explorer SKILL + template agree on Historical Lessons --------
if [[ -f "$explorer_skill" ]]; then
  if grep -Fq '.harness/lesson-index.md' "$explorer_skill"; then
    report "baton-explorer/SKILL.md still references '.harness/lesson-index.md' — should read 'knowledge/lessons.md'."
  fi
  if ! grep -Fq 'knowledge/lessons.md' "$explorer_skill"; then
    report "baton-explorer/SKILL.md does not reference 'knowledge/lessons.md'."
  fi
  if ! grep -qE '(must|MUST|always)' "$explorer_skill"; then
    :  # informational only; this grep is too broad to gate on
  fi
fi
if [[ -f "$explorer_template" ]]; then
  if ! grep -Eq '^## 12\. Historical Lessons' "$explorer_template"; then
    report "exploration.template.md missing '## 12. Historical Lessons' section — required by Gate 2 D-1."
  fi
fi

# ---- Check 6: verification-explorer / evaluator must not read lessons ------
# Load-bearing isolation rule from role-contracts.md Context Isolation Note.
# Guard against accidental "consistency" edits that add a read step.
for skill in \
    "$repo_root/skills/baton-verification-explorer/SKILL.md" \
    "$repo_root/skills/baton-evaluator/SKILL.md"; do
  [[ -f "$skill" ]] || continue
  if grep -Eq '(read|consult).*knowledge/lessons\.md' "$skill" \
      || grep -Eq '(read|consult).*lesson-index\.md' "$skill"; then
    report "$skill appears to read the lesson index — this violates the Context Isolation Note in role-contracts.md. Verification Explorer and Evaluator MUST NOT read lessons."
  fi
done

# ---- Check 7: skill output template ↔ retrospective.template.md alignment --
# Guards against the drift class found by skill-retrospective-review:
# the retrospective skill's Output Template block and the actual template
# file had different section sets AND different orderings. Extract level-2
# headings from both (normalizing the numeric prefix on §4/§5) and require
# exact equality in content and order.
if [[ -f "$retro_skill" && -f "$retro_template" ]]; then
  # Extract level-2 headings inside the skill's ```markdown ... ``` block
  # and strip any "N. " numeric prefix.
  skill_headings="$(awk '
    /^```markdown$/ { in_block = 1; next }
    in_block && /^```$/ { in_block = 0 }
    in_block && /^## / {
      sub(/^## [0-9]+\. /, "## ", $0)
      print
    }
  ' "$retro_skill")"

  template_headings="$(awk '
    /^## / {
      sub(/^## [0-9]+\. /, "## ", $0)
      print
    }
  ' "$retro_template")"

  if [[ "$skill_headings" != "$template_headings" ]]; then
    report "baton-retrospective/SKILL.md Output Template headings do not match retrospective.template.md headings (ignoring numeric prefixes). Skill and template must enumerate the same sections in the same order — drift here breaks both the LLM contract and the downstream lesson extractor."
    printf '\nExpected (from retrospective.template.md):\n%s\n' "$template_headings" >&2
    printf '\nActual (from baton-retrospective/SKILL.md output template block):\n%s\n' "$skill_headings" >&2
  fi
fi

if [[ "$fail" -ne 0 ]]; then
  printf '\ncheck-lesson-index-consistency: FAIL — see errors above.\n' >&2
  exit 1
fi

printf 'check-lesson-index-consistency: OK\n'
exit 0
