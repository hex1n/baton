#!/usr/bin/env bash
set -euo pipefail

repo_root="."
profile="auto"
adapter="codex"
force="false"
dry_run="false"
detect_only="false"
task_id=""

copy_if_needed() {
  local source="$1"
  local target="$2"
  local overwrite="$3"

  if [[ -e "$target" && "$overwrite" != "true" ]]; then
    printf 'skip  %s\n' "$target"
    return
  fi

  if [[ "$dry_run" == "true" ]]; then
    printf 'plan  %s\n' "$target"
    return
  fi

  cp "$source" "$target"
  printf 'write %s\n' "$target"
}

default_build_command() {
  case "$1" in
    java-maven) printf '%s' 'mvn -pl <module> -am -DskipTests compile' ;;
    node-monorepo) printf '%s' 'pnpm --filter <package> build' ;;
    python-service) printf '%s' 'python -m compileall <package>' ;;
    *) printf '%s' '' ;;
  esac
}

default_test_command() {
  case "$1" in
    java-maven) printf '%s' 'mvn -pl <module> -am test' ;;
    node-monorepo) printf '%s' 'pnpm --filter <package> test' ;;
    python-service) printf '%s' 'pytest <path>' ;;
    *) printf '%s' '' ;;
  esac
}

default_optional_static_check() {
  case "$1" in
    java-maven) printf '%s' 'mvn -pl <module> -am -DskipTests compile' ;;
    node-monorepo) printf '%s' 'pnpm --filter <package> lint' ;;
    python-service) printf '%s' 'python -m compileall <package>' ;;
    *) printf '%s' '' ;;
  esac
}

default_high_risk_1() {
  case "$1" in
    java-maven) printf '%s' 'integration' ;;
    node-monorepo) printf '%s' 'shared-packages' ;;
    python-service) printf '%s' 'migrations' ;;
    *) printf '%s' 'high-risk-path' ;;
  esac
}

default_high_risk_2() {
  case "$1" in
    java-maven) printf '%s' 'bootstrap' ;;
    node-monorepo) printf '%s' 'infra' ;;
    python-service) printf '%s' 'settings' ;;
    *) printf '%s' 'environment-sensitive-path' ;;
  esac
}

resolve_profile() {
  local repo="$1"
  local requested="$2"

  if [[ "$requested" != "auto" ]]; then
    printf '%s' "$requested"
    return
  fi

  if [[ -f "$repo/pom.xml" ]]; then
    printf '%s' 'java-maven'
    return
  fi

  if [[ -f "$repo/pnpm-workspace.yaml" || -f "$repo/turbo.json" || -f "$repo/nx.json" || -f "$repo/package.json" ]]; then
    printf '%s' 'node-monorepo'
    return
  fi

  if [[ -f "$repo/pyproject.toml" || -f "$repo/requirements.txt" || -f "$repo/pytest.ini" ]]; then
    printf '%s' 'python-service'
    return
  fi

  printf '%s' ''
}

usage() {
  cat <<'EOF'
Usage:
  init-harness.sh [--repo-root PATH] [--profile PROFILE] [--adapter ADAPTER] [--task-id ID] [--dry-run] [--detect-only] [--force]

Profiles:
  auto
  java-maven
  node-monorepo
  python-service

Adapters:
  codex
  claude-code
  cursor
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      repo_root="$2"
      shift 2
      ;;
    --profile)
      profile="$2"
      shift 2
      ;;
    --adapter)
      adapter="$2"
      shift 2
      ;;
    --task-id)
      task_id="$2"
      shift 2
      ;;
    --dry-run)
      dry_run="true"
      shift
      ;;
    --detect-only)
      detect_only="true"
      shift
      ;;
    --force)
      force="true"
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

case "$profile" in
  auto|java-maven|node-monorepo|python-service) ;;
  *)
    printf 'Unsupported profile: %s\n' "$profile" >&2
    exit 1
    ;;
esac

case "$adapter" in
  codex|claude-code|cursor) ;;
  *)
    printf 'Unsupported adapter: %s\n' "$adapter" >&2
    exit 1
    ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
spec_root="$(cd "$script_dir/.." && pwd)"
templates_dir="$spec_root/templates"
profiles_dir="$spec_root/profiles"
adapters_dir="$spec_root/adapters"
resolved_repo_root="$(cd "$repo_root" && pwd)"
resolved_profile="$(resolve_profile "$resolved_repo_root" "$profile")"

if [[ -z "$resolved_profile" ]]; then
  printf 'Unable to auto-detect profile for repo: %s\n' "$resolved_repo_root" >&2
  exit 1
fi

repo_name="$(basename "$resolved_repo_root")"
harness_dir="$resolved_repo_root/.harness"
selected_profile_path="$profiles_dir/$resolved_profile.yaml"
selected_adapter_path="$adapters_dir/$adapter.md"

if [[ ! -f "$selected_profile_path" ]]; then
  printf 'Profile not found: %s\n' "$selected_profile_path" >&2
  exit 1
fi
if [[ ! -f "$selected_adapter_path" ]]; then
  printf 'Adapter not found: %s\n' "$selected_adapter_path" >&2
  exit 1
fi

build_command="$(default_build_command "$resolved_profile")"
test_command="$(default_test_command "$resolved_profile")"

if [[ "$detect_only" == "true" ]]; then
  printf 'Harness profile detection complete.\n'
  printf 'Repo:     %s\n' "$resolved_repo_root"
  printf 'Profile:  %s\n' "$resolved_profile"
  printf 'Adapter:  %s\n' "$adapter"
  printf 'Build:    %s\n' "$build_command"
  printf 'Test:     %s\n' "$test_command"
  printf 'Mode:     detect-only\n\n'
  printf 'No files were written.\n'
  exit 0
fi

if [[ "$dry_run" == "true" ]]; then
  printf 'plan  %s\n' "$harness_dir"
else
  mkdir -p "$harness_dir"
fi

module_status_existed="false"
if [[ -e "$harness_dir/module-status.md" ]]; then
  module_status_existed="true"
fi

copy_if_needed "$templates_dir/scoped-map.template.md" "$harness_dir/scoped-map.md" "$force"
copy_if_needed "$templates_dir/requirements.template.md" "$harness_dir/requirements.md" "$force"
copy_if_needed "$templates_dir/architecture.template.md" "$harness_dir/architecture.md" "$force"
copy_if_needed "$templates_dir/verification-path.template.md" "$harness_dir/verification-path.md" "$force"
copy_if_needed "$templates_dir/module-status.template.md" "$harness_dir/module-status.md" "$force"
copy_if_needed "$templates_dir/retrospective.template.md" "$harness_dir/retrospective.md" "$force"
copy_if_needed "$selected_profile_path" "$harness_dir/profile.base.yaml" "$force"
copy_if_needed "$selected_adapter_path" "$harness_dir/adapter-reference.md" "$force"

profile_local_target="$harness_dir/profile.local.yaml"
if [[ ! -e "$profile_local_target" || "$force" == "true" ]]; then
  optional_static_check="$(default_optional_static_check "$resolved_profile")"
  risk_1="$(default_high_risk_1 "$resolved_profile")"
  risk_2="$(default_high_risk_2 "$resolved_profile")"

  if [[ "$dry_run" == "true" ]]; then
    printf 'plan  %s\n' "$profile_local_target"
  else
    sed \
      -e "s|__REPO_NAME__|$repo_name|g" \
      -e "s|__BASE_PROFILE__|$resolved_profile|g" \
      -e "s|__ADAPTER__|$adapter|g" \
      -e "s|__BUILD_COMMAND__|$build_command|g" \
      -e "s|__TEST_COMMAND__|$test_command|g" \
      -e "s|__OPTIONAL_STATIC_CHECK__|$optional_static_check|g" \
      -e "s|__HIGH_RISK_PATH_1__|$risk_1|g" \
      -e "s|__HIGH_RISK_PATH_2__|$risk_2|g" \
      -e "s|__REPO_NOTE__|Review and refine commands before the first generator task.|g" \
      "$templates_dir/profile.local.template.yaml" > "$profile_local_target"
    printf 'write %s\n' "$profile_local_target"
  fi
else
  printf 'skip  %s\n' "$profile_local_target"
fi

if [[ -n "$task_id" && ( "$module_status_existed" == "false" || "$force" == "true" ) ]]; then
  timestamp="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  if [[ "$dry_run" == "true" ]]; then
    printf 'plan  %s (seed first task row)\n' "$harness_dir/module-status.md"
  else
    sed \
      -e "s|<task-id>|$task_id|g" \
      -e "s|<role>|repo-explorer|g" \
      -e "s|<state>|exploring|g" \
      -e "s|<timestamp>|$timestamp|g" \
      -e "s|<notes>|initial task row created by init-harness bootstrap|g" \
      "$templates_dir/module-status.template.md" > "$harness_dir/module-status.md"
    printf 'write %s (seed first task row)\n' "$harness_dir/module-status.md"
  fi
fi

printf '\nHarness bootstrap complete.\n'
printf 'Repo:     %s\n' "$resolved_repo_root"
printf 'Profile:  %s\n' "$resolved_profile"
printf 'Adapter:  %s\n' "$adapter"
if [[ -n "$task_id" ]]; then
  printf 'TaskId:   %s\n' "$task_id"
fi
if [[ "$dry_run" == "true" ]]; then
  printf 'Mode:     dry-run\n'
fi
printf '\nNext steps:\n'
printf '1. Review .harness/profile.local.yaml\n'
printf '2. Run Repo Explorer\n'
printf '3. Run Verification Path Check before Generator\n'
