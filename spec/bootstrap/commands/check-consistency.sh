#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bootstrap_dir="$(cd "$script_dir/.." && pwd)"
spec_root="$(cd "$bootstrap_dir/.." && pwd)"
repo_root="$(cd "$spec_root/.." && pwd)"

owners_file="$spec_root/protocol/owners.txt"
states_file="$spec_root/protocol/states.txt"
state_machine_file="$spec_root/protocol/state-machine.md"
skills_dir="$repo_root/skills"
claude_skills_dir="$repo_root/.claude/skills"
agents_dir="$repo_root/.agents"
template_file="$spec_root/templates/module-status.template.md"
verification_template="$spec_root/templates/verification-path.template.md"
evaluation_template="$spec_root/templates/evaluation.template.md"
zh_verification_template="$spec_root/templates/zh/verification-path.template.md"
zh_evaluation_template="$spec_root/templates/zh/evaluation.template.md"
generator_feedback_template="$spec_root/templates/generator-feedback.template.md"
zh_generator_feedback_template="$spec_root/templates/zh/generator-feedback.template.md"
legacy_generator_feedback_template="$repo_root/spec/extensions/java-backend-strict/templates/generator-feedback.template.md"
profile_template="$spec_root/templates/profile.local.template.yaml"
start_task_sh="$script_dir/start-task.sh"
validate_artifact_sh="$script_dir/validate-artifact.sh"
validate_isolation_sh="$script_dir/validate-isolation.sh"
harness_context_sh="$script_dir/harness-context.sh"
provenance_sh="$bootstrap_dir/lib/provenance.sh"
readme_check_sh="$bootstrap_dir/check-root-readme-bilingual.sh"
governance_check_sh="$bootstrap_dir/sync-governance-entrypoints.sh"
module_status_script="$bootstrap_dir/module-status.sh"
install_hooks_sh="$bootstrap_dir/install-hooks.sh"
prepare_review_sh="$bootstrap_dir/prepare-review.sh"
verifier_skill="$repo_root/skills/baton-verifier/SKILL.md"
evaluator_skill="$repo_root/skills/baton-evaluator/SKILL.md"
live_module_status="$repo_root/.harness/module-status.md"
live_codex_hooks="$repo_root/.codex/hooks.json"
live_claude_settings="$repo_root/.claude/settings.json"

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
  done < <(grep -rh 'owner `' "$skills_dir"/baton-*/SKILL.md 2>/dev/null \
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
script_header="$(
  grep -F "printf '| Scope |" "$start_task_sh" | head -n 1 | sed -E "s/.*printf '(.+)\\\\n'.*/\1/" || true
)"
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
# Invariant 4: skills/ directories match .claude/skills/ and .agents/ copies
# Skills are stored as skills/<name>/SKILL.md and linked as directories.
# ---------------------------------------------------------------------------
inv4_errors=0
for src in "$skills_dir"/*/SKILL.md; do
  [[ -f "$src" ]] || continue
  dirname="$(basename "$(dirname "$src")")"

  # Check .claude/skills/<name>/SKILL.md (or directory symlink resolving to it)
  claude_copy="$claude_skills_dir/$dirname/SKILL.md"
  if [[ ! -f "$claude_copy" ]]; then
    printf 'ERROR: invariant-4: %s/SKILL.md missing from .claude/skills/\n' "$dirname"
    inv4_errors=$((inv4_errors + 1))
  elif ! cmp -s "$src" "$claude_copy"; then
    printf 'ERROR: invariant-4: %s/SKILL.md diverged from .claude/skills/%s/SKILL.md\n' "$dirname" "$dirname"
    inv4_errors=$((inv4_errors + 1))
  fi

  # Check .agents/<name>/SKILL.md
  agents_copy="$agents_dir/$dirname/SKILL.md"
  if [[ ! -f "$agents_copy" ]]; then
    printf 'ERROR: invariant-4: %s/SKILL.md missing from .agents/\n' "$dirname"
    inv4_errors=$((inv4_errors + 1))
  elif ! cmp -s "$src" "$agents_copy"; then
    printf 'ERROR: invariant-4: %s/SKILL.md diverged from .agents/%s/SKILL.md\n' "$dirname" "$dirname"
    inv4_errors=$((inv4_errors + 1))
  fi
done
errors=$((errors + inv4_errors))
if [[ $inv4_errors -eq 0 ]]; then
  printf 'OK: invariant-4: skills/ directories match .claude/skills/ and .agents/\n'
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
# Invariant 7: .claude/agents/ contains all context:fork skills from skills/
# ---------------------------------------------------------------------------
claude_agents_dir="$repo_root/.claude/agents"
inv7_errors=0
for src in "$skills_dir"/*/SKILL.md; do
  [[ -f "$src" ]] || continue
  grep -q '^context: fork' "$src" 2>/dev/null || continue
  dirname="$(basename "$(dirname "$src")")"
  agents_copy="$claude_agents_dir/$dirname/SKILL.md"

  if [[ ! -f "$agents_copy" ]]; then
    printf 'ERROR: invariant-7: %s/SKILL.md missing from .claude/agents/\n' "$dirname"
    inv7_errors=$((inv7_errors + 1))
  elif ! cmp -s "$src" "$agents_copy"; then
    printf 'ERROR: invariant-7: %s/SKILL.md diverged from .claude/agents/%s/SKILL.md\n' "$dirname" "$dirname"
    inv7_errors=$((inv7_errors + 1))
  fi
done
errors=$((errors + inv7_errors))
if [[ $inv7_errors -eq 0 ]]; then
  printf 'OK: invariant-7: .claude/agents/ contains all context:fork skills from skills/\n'
fi

# ---------------------------------------------------------------------------
# Invariant 8: committed runtime symlinks are repo-relative, never absolute
# ---------------------------------------------------------------------------
inv8_errors=0
# Check both flat .md symlinks (legacy) and directory symlinks (current)
for link in "$claude_skills_dir"/*.md "$agents_dir"/*.md "$claude_agents_dir"/*.md; do
  [[ -L "$link" ]] || continue
  target="$(readlink "$link")"
  case "$target" in
    /*)
      printf 'ERROR: invariant-8: %s uses absolute symlink target %s\n' "$link" "$target"
      inv8_errors=$((inv8_errors + 1))
      ;;
  esac
done
for link_dir in "$claude_skills_dir"/* "$agents_dir"/* "$claude_agents_dir"/*; do
  [[ -L "$link_dir" && -d "$link_dir" ]] || continue
  target="$(readlink "$link_dir")"
  case "$target" in
    /*)
      printf 'ERROR: invariant-8: %s uses absolute symlink target %s\n' "$link_dir" "$target"
      inv8_errors=$((inv8_errors + 1))
      ;;
  esac
done
errors=$((errors + inv8_errors))
if [[ $inv8_errors -eq 0 ]]; then
  printf 'OK: invariant-8: runtime symlinks use repo-relative targets\n'
fi

# ---------------------------------------------------------------------------
# Invariant 9: live module-status.md uses current schema and has one active row
# ---------------------------------------------------------------------------
inv9_errors=0
if [[ -f "$live_module_status" ]]; then
  if [[ ! -f "$module_status_script" ]]; then
    printf 'ERROR: invariant-9: module-status parser missing: %s\n' "$module_status_script"
    inv9_errors=$((inv9_errors + 1))
  else
    live_schema="$(bash "$module_status_script" schema "$live_module_status")"
    current_scope="$(bash "$module_status_script" current-field "$live_module_status" scope)"
    current_state="$(bash "$module_status_script" current-field "$live_module_status" state)"
    row_count="$(bash "$module_status_script" row-count "$live_module_status")"
    open_count="$(bash "$module_status_script" non-complete-count "$live_module_status")"

    if [[ "$live_schema" != 'current' ]]; then
      printf 'ERROR: invariant-9: live module-status.md must use current schema, found %s\n' "$live_schema"
      inv9_errors=$((inv9_errors + 1))
    fi

    if [[ -z "$current_scope" || -z "$current_state" ]]; then
      printf 'ERROR: invariant-9: current task row is not readable from %s\n' "$live_module_status"
      inv9_errors=$((inv9_errors + 1))
    fi

    if [[ "$row_count" -lt 1 ]]; then
      printf 'ERROR: invariant-9: live module-status.md contains no task rows\n'
      inv9_errors=$((inv9_errors + 1))
    fi

    if [[ "$open_count" -gt 1 ]]; then
      printf 'ERROR: invariant-9: live module-status.md has %s non-complete rows; expected at most 1\n' "$open_count"
      inv9_errors=$((inv9_errors + 1))
    fi

    if [[ $inv9_errors -eq 0 ]]; then
      printf 'OK: invariant-9: live module-status.md uses current schema and a single active task\n'
    fi
  fi
else
  printf 'OK: invariant-9: live module-status.md absent; skipping live control-plane checks\n'
fi
errors=$((errors + inv9_errors))

# ---------------------------------------------------------------------------
# Invariant 10: isolation templates exist and start-task resets evaluation.md
# ---------------------------------------------------------------------------
inv10_errors=0
for template in "$verification_template" "$evaluation_template" "$zh_verification_template" "$zh_evaluation_template"; do
  if [[ ! -f "$template" ]]; then
    printf 'ERROR: invariant-10: required template missing: %s\n' "$template"
    inv10_errors=$((inv10_errors + 1))
  fi
done

if [[ -f "$verification_template" ]] && ! grep -Fq '## 4. Execution Provenance' "$verification_template"; then
  printf 'ERROR: invariant-10: verification-path template missing Execution Provenance section\n'
  inv10_errors=$((inv10_errors + 1))
fi

if [[ -f "$evaluation_template" ]] && ! grep -Fq '## 2. Execution Provenance' "$evaluation_template"; then
  printf 'ERROR: invariant-10: evaluation template missing Execution Provenance section\n'
  inv10_errors=$((inv10_errors + 1))
fi

if ! grep -Fq 'evaluation.template.md:evaluation.md' "$start_task_sh"; then
  printf 'ERROR: invariant-10: start-task.sh does not reset evaluation.md\n'
  inv10_errors=$((inv10_errors + 1))
fi

if [[ $inv10_errors -eq 0 ]]; then
  printf 'OK: invariant-10: isolation templates exist and start-task resets evaluation.md\n'
fi
errors=$((errors + inv10_errors))

# ---------------------------------------------------------------------------
# Invariant 11: provenance contract stays coupled across schema, readers, and tests
# ---------------------------------------------------------------------------
inv11_errors=0

for file in "$provenance_sh" "$validate_isolation_sh" "$harness_context_sh"; do
  if [[ ! -f "$file" ]]; then
    printf 'ERROR: invariant-11: required provenance component missing: %s\n' "$file"
    inv11_errors=$((inv11_errors + 1))
  fi
done

for consumer in "$validate_isolation_sh" "$harness_context_sh"; do
  if [[ -f "$consumer" ]] && ! grep -Fq 'lib/provenance.sh' "$consumer"; then
    printf 'ERROR: invariant-11: %s does not source provenance.sh\n' "$consumer"
    inv11_errors=$((inv11_errors + 1))
  fi
done

for template in "$verification_template" "$evaluation_template" "$zh_verification_template" "$zh_evaluation_template"; do
  [[ -f "$template" ]] || continue
  for needle in 'Execution Provenance' '- Role:' '- Isolation mode:' '- Execution context:' '- Agent ID:' '- Evidence:' '- Fallback policy:' '- Fallback reason:'; do
    if ! grep -Fq -- "$needle" "$template"; then
      printf 'ERROR: invariant-11: %s missing provenance field %s\n' "$template" "$needle"
      inv11_errors=$((inv11_errors + 1))
    fi
  done
done

if [[ -f "$validate_artifact_sh" ]]; then
  for artifact in 'verification-path)' 'evaluation)'; do
    if ! grep -Fq "$artifact" "$validate_artifact_sh"; then
      printf 'ERROR: invariant-11: validate-artifact.sh missing case %s\n' "$artifact"
      inv11_errors=$((inv11_errors + 1))
    fi
  done
fi

if [[ -f "$validate_isolation_sh" ]]; then
  for needle in '"Role"' '"Isolation mode"' '"Execution context"' '"Agent ID"' '"Fallback reason"' 'isolated_subagent'; do
    if ! grep -Fq "$needle" "$validate_isolation_sh"; then
      printf 'ERROR: invariant-11: validate-isolation.sh missing provenance read for %s\n' "$needle"
      inv11_errors=$((inv11_errors + 1))
    fi
  done
fi

for test_file in \
  "$repo_root/tests/test-validate-artifact.sh" \
  "$repo_root/tests/test-validate-isolation.sh" \
  "$repo_root/tests/test-harness-context.sh" \
  "$repo_root/tests/test-start-task.sh"
do
  if [[ ! -f "$test_file" ]]; then
    printf 'ERROR: invariant-11: required test missing: %s\n' "$test_file"
    inv11_errors=$((inv11_errors + 1))
  fi
done

if [[ -f "$repo_root/tests/test-validate-isolation.sh" ]]; then
  for needle in 'Role: verification_explorer' 'Role: evaluator' 'Isolation mode:' 'Agent ID:'; do
    if ! grep -Fq "$needle" "$repo_root/tests/test-validate-isolation.sh"; then
      printf 'ERROR: invariant-11: test-validate-isolation.sh missing coverage marker %s\n' "$needle"
      inv11_errors=$((inv11_errors + 1))
    fi
  done
fi

if [[ -f "$repo_root/tests/test-harness-context.sh" ]] && ! grep -Fq 'verifier:' "$repo_root/tests/test-harness-context.sh"; then
  printf 'ERROR: invariant-11: test-harness-context.sh missing human-close provenance summary coverage\n'
  inv11_errors=$((inv11_errors + 1))
fi

for skill_file in "$verifier_skill" "$evaluator_skill"; do
  if [[ ! -f "$skill_file" ]]; then
    printf 'ERROR: invariant-11: missing isolated review skill %s\n' "$skill_file"
    inv11_errors=$((inv11_errors + 1))
    continue
  fi

  for needle in 'spawn_agent({ fork_context: false })' 'Agent ID:'; do
    if ! grep -Fq "$needle" "$skill_file"; then
      printf 'ERROR: invariant-11: %s missing isolated review guidance %s\n' "$skill_file" "$needle"
      inv11_errors=$((inv11_errors + 1))
    fi
  done
done

if [[ $inv11_errors -eq 0 ]]; then
  printf 'OK: invariant-11: provenance contract is coupled across templates, readers, and tests\n'
fi
errors=$((errors + inv11_errors))

# ---------------------------------------------------------------------------
# Invariant 12: each hook runtime script has a matching test file
# ---------------------------------------------------------------------------
inv12_errors=0
for hook_script in "$bootstrap_dir/hooks"/*; do
  [[ -f "$hook_script" ]] || continue
  case "$(basename "$hook_script")" in
    run-hook.cmd) continue ;;
    *.cmd) continue ;;
  esac
  hook_name="$(basename "$hook_script")"
  test_file="$repo_root/tests/test-hook-$hook_name.sh"
  if [[ ! -f "$test_file" ]]; then
    printf 'ERROR: invariant-12: missing hook test for %s at %s\n' "$hook_script" "$test_file"
    inv12_errors=$((inv12_errors + 1))
  fi
done

if [[ ! -f "$repo_root/tests/test-hook-parse-input.sh" ]]; then
  printf 'ERROR: invariant-12: missing hook test for parse-input.sh\n'
  inv12_errors=$((inv12_errors + 1))
fi

if [[ $inv12_errors -eq 0 ]]; then
  printf 'OK: invariant-12: hook runtime scripts have matching tests\n'
fi
errors=$((errors + inv12_errors))

# ---------------------------------------------------------------------------
# Invariant 13: install-hooks.sh references only real hook scripts
# ---------------------------------------------------------------------------
inv13_errors=0
for hook_ref in $(grep -oE 'hooks/[A-Za-z0-9._/-]+' "$script_dir/install-hooks.sh" | sort -u); do
  if [[ ! -f "$spec_root/bootstrap/$hook_ref" ]]; then
    printf 'ERROR: invariant-13: install-hooks.sh references missing script %s\n' "$hook_ref"
    inv13_errors=$((inv13_errors + 1))
  fi
done

if [[ ! -f "$profile_template" ]]; then
  printf 'ERROR: invariant-13: profile template missing: %s\n' "$profile_template"
  inv13_errors=$((inv13_errors + 1))
elif ! grep -Fq 'max_eval_rounds: 3' "$profile_template"; then
  printf 'ERROR: invariant-13: profile.local.template.yaml missing max_eval_rounds: 3\n'
  inv13_errors=$((inv13_errors + 1))
fi

if [[ $inv13_errors -eq 0 ]]; then
  printf 'OK: invariant-13: install-hooks.sh references real hook scripts and profile template exposes max_eval_rounds\n'
fi
errors=$((errors + inv13_errors))

# ---------------------------------------------------------------------------
# Invariant 14: generator-feedback contract is synchronized across schema, validator, templates, and skills
# ---------------------------------------------------------------------------
inv14_errors=0
if ! grep -Fq '### `generator-feedback.md`' "$spec_root/protocol/artifact-schema.md"; then
  printf 'ERROR: invariant-14: artifact-schema.md missing generator-feedback.md entry\n'
  inv14_errors=$((inv14_errors + 1))
fi

if ! grep -Fq 'generator-feedback)' "$validate_artifact_sh"; then
  printf 'ERROR: invariant-14: validate-artifact.sh missing generator-feedback case\n'
  inv14_errors=$((inv14_errors + 1))
fi

for template in "$generator_feedback_template" "$zh_generator_feedback_template"; do
  if [[ ! -f "$template" ]]; then
    printf 'ERROR: invariant-14: generator-feedback template missing: %s\n' "$template"
    inv14_errors=$((inv14_errors + 1))
  fi
done

if [[ -f "$generator_feedback_template" ]]; then
  for needle in '## Original Assumption' '## Actual Finding' '## Impact' '## Recommended Next Owner'; do
    if ! grep -Fq "$needle" "$generator_feedback_template"; then
      printf 'ERROR: invariant-14: %s missing heading %s\n' "$generator_feedback_template" "$needle"
      inv14_errors=$((inv14_errors + 1))
    fi
  done
fi

if [[ -f "$zh_generator_feedback_template" ]]; then
  for needle in '## 原始假设' '## 实际发现' '## 影响' '## 建议下一步负责方'; do
    if ! grep -Fq "$needle" "$zh_generator_feedback_template"; then
      printf 'ERROR: invariant-14: %s missing heading %s\n' "$zh_generator_feedback_template" "$needle"
      inv14_errors=$((inv14_errors + 1))
    fi
  done
fi

if [[ -e "$legacy_generator_feedback_template" ]]; then
  printf 'ERROR: invariant-14: legacy generator-feedback template still exists: %s\n' "$legacy_generator_feedback_template"
  inv14_errors=$((inv14_errors + 1))
fi

if [[ -f "$repo_root/skills/baton-generator/SKILL.md" ]]; then
  for needle in '.harness/generator-feedback.md' '[design_blocker]'; do
    if ! grep -Fq "$needle" "$repo_root/skills/baton-generator/SKILL.md"; then
      printf 'ERROR: invariant-14: baton-generator guidance missing %s\n' "$needle"
      inv14_errors=$((inv14_errors + 1))
    fi
  done
else
  printf 'ERROR: invariant-14: missing %s\n' "$repo_root/skills/baton-generator/SKILL.md"
  inv14_errors=$((inv14_errors + 1))
fi

if [[ -f "$repo_root/skills/baton-explorer/SKILL.md" ]]; then
  for needle in 'Overlay Recommendation' 'overlay: core' 'overlay: strict'; do
    if ! grep -Fq "$needle" "$repo_root/skills/baton-explorer/SKILL.md"; then
      printf 'ERROR: invariant-14: baton-explorer guidance missing %s\n' "$needle"
      inv14_errors=$((inv14_errors + 1))
    fi
  done
else
  printf 'ERROR: invariant-14: missing %s\n' "$repo_root/skills/baton-explorer/SKILL.md"
  inv14_errors=$((inv14_errors + 1))
fi

if [[ $inv14_errors -eq 0 ]]; then
  printf 'OK: invariant-14: generator-feedback contract stays synchronized across schema, validator, templates, and skills\n'
fi
errors=$((errors + inv14_errors))

# ---------------------------------------------------------------------------
# Invariant 15: bootstrap keeps one bash core and no PowerShell business entrypoints
# ---------------------------------------------------------------------------
inv15_errors=0
for ps1_script in "$bootstrap_dir"/*.ps1; do
  [[ -e "$ps1_script" ]] || continue
  printf 'ERROR: invariant-15: bootstrap PowerShell business entrypoint still present: %s\n' "$ps1_script"
  inv15_errors=$((inv15_errors + 1))
done

doc_refs="$(
  grep -nH -E 'install-harness\.ps1|init-harness\.ps1|start-task\.ps1|update-harness\.ps1|link-skills\.ps1|sync-governance-entrypoints\.ps1|sync-skills\.ps1|pwsh[[:space:]].*spec/bootstrap/' \
    "$spec_root/README.md" "$bootstrap_dir"/*.md || true
)"
if [[ -n "$doc_refs" ]]; then
  printf 'ERROR: invariant-15: bootstrap docs still reference removed PowerShell entrypoints\n%s\n' "$doc_refs"
  inv15_errors=$((inv15_errors + 1))
fi

if [[ $inv15_errors -eq 0 ]]; then
  printf 'OK: invariant-15: bootstrap keeps one bash core and docs no longer advertise PowerShell business entrypoints\n'
fi
errors=$((errors + inv15_errors))

# ---------------------------------------------------------------------------
# Invariant 16: live local hook configs match the current install-hooks manifest
# ---------------------------------------------------------------------------
inv16_errors=0

extract_live_hook_command() {
  local file="$1" jq_expr="$2"
  jq -r "$jq_expr" "$file"
}

if [[ ! -f "$install_hooks_sh" ]]; then
  printf 'ERROR: invariant-16: install-hooks script missing: %s\n' "$install_hooks_sh"
  inv16_errors=$((inv16_errors + 1))
elif [[ ! -f "$prepare_review_sh" ]]; then
  printf 'ERROR: invariant-16: prepare-review entrypoint missing: %s\n' "$prepare_review_sh"
  inv16_errors=$((inv16_errors + 1))
else
  hook_manifest="$(bash "$install_hooks_sh" --repo-root "$repo_root" --bootstrap-dir "$bootstrap_dir" --print-manifest)"

  if [[ ! -f "$live_claude_settings" ]]; then
    printf 'ERROR: invariant-16: missing live Claude hook config: %s\n' "$live_claude_settings"
    inv16_errors=$((inv16_errors + 1))
  else
    expected_cc_post="$(printf '%s' "$hook_manifest" | jq -r '.claude.post')"
    expected_cc_pre="$(printf '%s' "$hook_manifest" | jq -r '.claude.pre')"
    expected_cc_stop="$(printf '%s' "$hook_manifest" | jq -r '.claude.stop')"
    expected_cc_subagent="$(printf '%s' "$hook_manifest" | jq -r '.claude.subagent_stop')"
    expected_cc_session="$(printf '%s' "$hook_manifest" | jq -r '.claude.session_start')"

    actual_cc_post="$(extract_live_hook_command "$live_claude_settings" '[.hooks.PostToolUse[]?.hooks[]?.command | select(test("baton-validate-artifact"))][0] // empty')"
    actual_cc_pre="$(extract_live_hook_command "$live_claude_settings" '[.hooks.PreToolUse[]?.hooks[]?.command | select(test("baton-validate-transition"))][0] // empty')"
    actual_cc_stop="$(extract_live_hook_command "$live_claude_settings" '[.hooks.Stop[]?.hooks[]?.command | select(test("baton-validate-state"))][0] // empty')"
    actual_cc_subagent="$(extract_live_hook_command "$live_claude_settings" '[.hooks.SubagentStop[]?.hooks[]?.command | select(test("baton-subagent-stop"))][0] // empty')"
    actual_cc_session="$(extract_live_hook_command "$live_claude_settings" '[.hooks.SessionStart[]?.hooks[]?.command | select(test("baton-harness-context"))][0] // empty')"

    for pair in \
      "Claude PostToolUse:$expected_cc_post:$actual_cc_post" \
      "Claude PreToolUse:$expected_cc_pre:$actual_cc_pre" \
      "Claude Stop:$expected_cc_stop:$actual_cc_stop" \
      "Claude SubagentStop:$expected_cc_subagent:$actual_cc_subagent" \
      "Claude SessionStart:$expected_cc_session:$actual_cc_session"
    do
      label="${pair%%:*}"
      rest="${pair#*:}"
      expected="${rest%%:*}"
      actual="${rest#*:}"
      if [[ "$expected" != "$actual" ]]; then
        printf 'ERROR: invariant-16: %s drifted from install-hooks manifest\n' "$label"
        inv16_errors=$((inv16_errors + 1))
      fi
    done
  fi

  if [[ ! -f "$live_codex_hooks" ]]; then
    printf 'ERROR: invariant-16: missing live Codex hook config: %s\n' "$live_codex_hooks"
    inv16_errors=$((inv16_errors + 1))
  else
    expected_cx_post="$(printf '%s' "$hook_manifest" | jq -r '.codex.post')"
    expected_cx_pre="$(printf '%s' "$hook_manifest" | jq -r '.codex.pre')"
    expected_cx_stop="$(printf '%s' "$hook_manifest" | jq -r '.codex.stop')"
    expected_cx_session="$(printf '%s' "$hook_manifest" | jq -r '.codex.session_start')"

    actual_cx_post="$(extract_live_hook_command "$live_codex_hooks" '[.hooks.PostToolUse[]?.hooks[]?.command | select(test("baton-validate-artifact"))][0] // empty')"
    actual_cx_pre="$(extract_live_hook_command "$live_codex_hooks" '[.hooks.PreToolUse[]?.hooks[]?.command | select(test("baton-validate-transition"))][0] // empty')"
    actual_cx_stop="$(extract_live_hook_command "$live_codex_hooks" '[.hooks.Stop[]?.hooks[]?.command | select(test("baton-validate-state"))][0] // empty')"
    actual_cx_session="$(extract_live_hook_command "$live_codex_hooks" '[.hooks.SessionStart[]?.hooks[]?.command | select(test("baton-harness-context"))][0] // empty')"

    for pair in \
      "Codex PostToolUse:$expected_cx_post:$actual_cx_post" \
      "Codex PreToolUse:$expected_cx_pre:$actual_cx_pre" \
      "Codex Stop:$expected_cx_stop:$actual_cx_stop" \
      "Codex SessionStart:$expected_cx_session:$actual_cx_session"
    do
      label="${pair%%:*}"
      rest="${pair#*:}"
      expected="${rest%%:*}"
      actual="${rest#*:}"
      if [[ "$expected" != "$actual" ]]; then
        printf 'ERROR: invariant-16: %s drifted from install-hooks manifest\n' "$label"
        inv16_errors=$((inv16_errors + 1))
      fi
    done
  fi
fi

if [[ $inv16_errors -eq 0 ]]; then
  printf 'OK: invariant-16: live local hook configs match the current install-hooks manifest\n'
fi
errors=$((errors + inv16_errors))

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
