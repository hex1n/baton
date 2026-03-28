#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
spec_root="$(cd "$script_dir/.." && pwd)"
repo_root="$(cd "$spec_root/.." && pwd)"

owners_file="$spec_root/protocol/owners.txt"
states_file="$spec_root/protocol/states.txt"
state_machine_file="$spec_root/protocol/state-machine.md"
skills_dir="$repo_root/skills"
claude_skills_dir="$repo_root/.claude/skills"
agents_dir="$repo_root/.agents"
template_file="$spec_root/templates/module-status.template.md"
start_task_sh="$script_dir/start-task.sh"
start_task_ps1="$script_dir/start-task.ps1"
readme_check_sh="$script_dir/check-root-readme-bilingual.sh"
governance_check_sh="$script_dir/sync-governance-entrypoints.sh"

errors=0

# ---------------------------------------------------------------------------
# Invariant 1: owner tokens used in skills/ must all be present in owners.txt
# ---------------------------------------------------------------------------
inv1_errors=0
if [[ ! -f "$owners_file" ]]; then
  printf 'ERROR: owners.txt not found: %s\n' "$owners_file"
  inv1_errors=$((inv1_errors + 1))
else
  while IFS= read -r token; do
    if ! grep -Fxq "$token" "$owners_file"; then
      printf 'ERROR: invariant-1: token "%s" found in skills/ but not in owners.txt\n' "$token"
      inv1_errors=$((inv1_errors + 1))
    fi
  done < <(grep -rh 'owner `' "$skills_dir"/harness-*.md 2>/dev/null \
    | grep -oE 'owner `[^`]+`' | grep -oE '`[^`]+`' | tr -d '`' | sort -u)
  if [[ $inv1_errors -eq 0 ]]; then
    printf 'OK: invariant-1: all owner tokens in skills/ are present in owners.txt\n'
  fi
fi
errors=$((errors + inv1_errors))

# ---------------------------------------------------------------------------
# Invariant 2: states.txt matches state-machine.md and bootstrap scripts consume it
# ---------------------------------------------------------------------------
inv2_errors=0
if [[ ! -f "$states_file" ]]; then
  printf 'ERROR: states.txt not found: %s\n' "$states_file"
  inv2_errors=$((inv2_errors + 1))
elif [[ ! -f "$state_machine_file" ]]; then
  printf 'ERROR: state-machine.md not found: %s\n' "$state_machine_file"
  inv2_errors=$((inv2_errors + 1))
else
  file_states="$(grep -v '^[[:space:]]*$' "$states_file" | sort)"
  doc_states="$(sed -n '/## Canonical States/,/## State Semantics/p' "$state_machine_file" \
    | grep '^- `' | sed -E 's/^- `([^`]+)`/\1/' | sort)"

  if [[ "$file_states" != "$doc_states" ]]; then
    printf 'ERROR: invariant-2: states.txt does not match canonical states in state-machine.md\n'
    printf '  states.txt:\n%s\n' "$file_states"
    printf '  state-machine.md:\n%s\n' "$doc_states"
    inv2_errors=$((inv2_errors + 1))
  fi

  if ! grep -Fq 'states.txt' "$start_task_sh"; then
    printf 'ERROR: invariant-2: start-task.sh does not read states.txt\n'
    inv2_errors=$((inv2_errors + 1))
  fi

  if ! grep -Fq 'states.txt' "$start_task_ps1"; then
    printf 'ERROR: invariant-2: start-task.ps1 does not read states.txt\n'
    inv2_errors=$((inv2_errors + 1))
  fi

  if [[ $inv2_errors -eq 0 ]]; then
    printf 'OK: invariant-2: canonical states match and bootstrap scripts read states.txt\n'
  fi
fi
errors=$((errors + inv2_errors))

# ---------------------------------------------------------------------------
# Invariant 3: start-task.sh header output matches module-status.template.md header
# ---------------------------------------------------------------------------
inv3_errors=0
template_header="$(sed -n '3p' "$template_file")"
script_header="$(grep -o "'| Scope.*|'" "$start_task_sh" | tr -d "'")"
if [[ -z "$template_header" ]]; then
  printf 'ERROR: invariant-3: could not read header from template file\n'
  inv3_errors=$((inv3_errors + 1))
elif [[ -z "$script_header" ]]; then
  printf 'ERROR: invariant-3: could not extract header from start-task.sh printf\n'
  inv3_errors=$((inv3_errors + 1))
elif [[ "$template_header" != "$script_header" ]]; then
  printf 'ERROR: invariant-3: header mismatch\n'
  printf '  template : %s\n' "$template_header"
  printf '  script   : %s\n' "$script_header"
  inv3_errors=$((inv3_errors + 1))
else
  printf 'OK: invariant-3: template header matches start-task.sh header\n'
fi
errors=$((errors + inv3_errors))

# ---------------------------------------------------------------------------
# Invariant 4: skills/ files match .claude/skills/ and .agents/ copies
# ---------------------------------------------------------------------------
inv4_errors=0
for src in "$skills_dir"/harness-*.md; do
  filename="$(basename "$src")"
  claude_copy="$claude_skills_dir/$filename"
  agents_copy="$agents_dir/$filename"

  if [[ ! -f "$claude_copy" ]]; then
    printf 'ERROR: invariant-4: %s missing from .claude/skills/\n' "$filename"
    inv4_errors=$((inv4_errors + 1))
  elif ! cmp -s "$src" "$claude_copy"; then
    printf 'ERROR: invariant-4: %s diverged from .claude/skills/%s\n' "$filename" "$filename"
    inv4_errors=$((inv4_errors + 1))
  fi

  if [[ ! -f "$agents_copy" ]]; then
    printf 'ERROR: invariant-4: %s missing from .agents/\n' "$filename"
    inv4_errors=$((inv4_errors + 1))
  elif ! cmp -s "$src" "$agents_copy"; then
    printf 'ERROR: invariant-4: %s diverged from .agents/%s\n' "$filename" "$filename"
    inv4_errors=$((inv4_errors + 1))
  fi
done
errors=$((errors + inv4_errors))
if [[ $inv4_errors -eq 0 ]]; then
  printf 'OK: invariant-4: skills/ files match .claude/skills/ and .agents/\n'
fi

# ---------------------------------------------------------------------------
# Invariant 5: root README bilingual pair remains structurally aligned
# ---------------------------------------------------------------------------
inv5_errors=0
if [[ ! -f "$readme_check_sh" ]]; then
  printf 'ERROR: invariant-5: README bilingual check script not found: %s\n' "$readme_check_sh"
  inv5_errors=$((inv5_errors + 1))
elif ! bash "$readme_check_sh" --repo-root "$repo_root"; then
  printf 'ERROR: invariant-5: root README bilingual checks failed\n'
  inv5_errors=$((inv5_errors + 1))
else
  printf 'OK: invariant-5: root README bilingual checks passed\n'
fi
errors=$((errors + inv5_errors))

# ---------------------------------------------------------------------------
# Invariant 6: root governance entrypoints remain synced across hosts
# ---------------------------------------------------------------------------
inv6_errors=0
if [[ ! -f "$governance_check_sh" ]]; then
  printf 'ERROR: invariant-6: governance sync script not found: %s\n' "$governance_check_sh"
  inv6_errors=$((inv6_errors + 1))
elif ! bash "$governance_check_sh" --repo-root "$repo_root" --mode check; then
  printf 'ERROR: invariant-6: root governance entrypoints are out of sync\n'
  inv6_errors=$((inv6_errors + 1))
else
  printf 'OK: invariant-6: root governance entrypoints are synced\n'
fi
errors=$((errors + inv6_errors))

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [[ $errors -eq 0 ]]; then
  printf 'all invariants OK\n'
  exit 0
else
  printf '%d error(s) found\n' "$errors"
  exit 1
fi
