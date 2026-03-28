#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
default_source_root="$(cd "$script_dir/../.." && pwd)"

mode="install"
repo_root="."
source_root="$default_source_root"
dry_run="false"
force="false"

usage() {
  cat <<'EOF'
Usage:
  install-harness.sh --repo-root PATH [--source-root PATH] [--dry-run] [--force]
  install-harness.sh --mode update --repo-root PATH [--source-root PATH] [--dry-run] [--force]
EOF
}

mkdir_if_needed() {
  local path="$1"
  if [[ "$dry_run" == "true" ]]; then
    printf 'plan  mkdir -p %s\n' "$path"
    return
  fi
  mkdir -p "$path"
}

remove_if_exists() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    return
  fi
  if [[ "$dry_run" == "true" ]]; then
    printf 'plan  rm -rf %s\n' "$path"
    return
  fi
  rm -rf "$path"
}

copy_file() {
  local source="$1"
  local target="$2"
  if [[ "$dry_run" == "true" ]]; then
    printf 'plan  %s\n' "$target"
    return
  fi
  cp "$source" "$target"
  printf 'write %s\n' "$target"
}

copy_dir() {
  local source="$1"
  local target="$2"
  if [[ "$dry_run" == "true" ]]; then
    printf 'plan  %s\n' "$target"
    return
  fi
  cp -R "$source" "$target"
  printf 'write %s\n' "$target"
}

append_unique() {
  local value="$1"
  local existing
  for existing in "${skill_names[@]:-}"; do
    if [[ "$existing" == "$value" ]]; then
      return
    fi
  done
  skill_names+=("$value")
}

resolve_effective_skill_source() {
  local name="$1"
  if [[ -f "$override_skills_dir/$name" ]]; then
    printf '%s' "$override_skills_dir/$name"
    return
  fi
  if [[ -f "$vendor_skills_root/$name" ]]; then
    printf '%s' "$vendor_skills_root/$name"
    return
  fi
  printf 'effective skill source not found for %s\n' "$name" >&2
  exit 1
}

link_one() {
  local source="$1"
  local target="$2"

  if [[ "$dry_run" == "true" ]]; then
    printf 'symlink'
    return 0
  fi

  rm -f "$target"

  if ln -s "$source" "$target" 2>/dev/null; then
    printf 'symlink'
    return 0
  fi

  if ln "$source" "$target" 2>/dev/null; then
    printf 'hardlink'
    return 0
  fi

  cp "$source" "$target"
  printf 'copy'
}

materialize_runtime_dir() {
  local target_dir="$1"
  local dir_mode="symlink"
  local existing
  local name
  local source
  local target
  local mode_used

  mkdir_if_needed "$target_dir"

  for existing in "$target_dir"/harness-*.md; do
    [[ -e "$existing" ]] || continue
    if [[ "$dry_run" == "true" ]]; then
      printf 'plan  rm -f %s\n' "$existing"
    else
      rm -f "$existing"
    fi
  done

  for name in "${skill_names[@]}"; do
    source="$(resolve_effective_skill_source "$name")"
    target="$target_dir/$name"
    mode_used="$(link_one "$source" "$target")"
    if [[ "$mode_used" == "copy" ]]; then
      dir_mode="copy"
    elif [[ "$mode_used" == "hardlink" && "$dir_mode" == "symlink" ]]; then
      dir_mode="hardlink"
    fi
    printf '%s  %s\n' "$mode_used" "$target"
  done

  printf '%s' "$dir_mode"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      mode="$2"
      shift 2
      ;;
    --repo-root)
      repo_root="$2"
      shift 2
      ;;
    --source-root)
      source_root="$2"
      shift 2
      ;;
    --dry-run)
      dry_run="true"
      shift
      ;;
    --force)
      force="true"
      shift
      ;;
    --version)
      printf 'harness-spec v%s\n' "$(cat "$default_source_root/spec/VERSION")"
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

case "$mode" in
  install|update) ;;
  *)
    printf 'Unsupported mode: %s\n' "$mode" >&2
    exit 1
    ;;
esac

resolved_repo_root="$(cd "$repo_root" && pwd)"
resolved_source_root="$(cd "$source_root" && pwd)"

if [[ ! -f "$resolved_source_root/spec/VERSION" ]]; then
  printf 'spec/VERSION not found under source root: %s\n' "$resolved_source_root" >&2
  exit 1
fi

vendor_root="$resolved_repo_root/.vendor/baton-harness"
vendor_spec_root="$vendor_root/spec"
vendor_skills_root="$vendor_root/skills"
harness_dir="$resolved_repo_root/.harness"
lockfile_path="$harness_dir/harness.lock.yaml"
override_root="$harness_dir/overrides"
override_skills_dir="$override_root/skills"
override_templates_dir="$override_root/templates"
override_templates_zh_dir="$override_templates_dir/zh"

if [[ "$mode" == "install" && -f "$lockfile_path" && "$force" != "true" ]]; then
  printf 'Lockfile already exists at %s. Run update-harness or pass --force.\n' "$lockfile_path" >&2
  exit 1
fi

if [[ "$mode" == "update" && ! -f "$lockfile_path" ]]; then
  printf 'Lockfile not found at %s. Run install-harness first.\n' "$lockfile_path" >&2
  exit 1
fi

version="$(cat "$resolved_source_root/spec/VERSION")"
upstream_commit="$(git -C "$resolved_source_root" rev-parse HEAD 2>/dev/null || printf '%s' 'unknown')"
timestamp="$(date '+%Y-%m-%dT%H:%M:%S%z')"

mkdir_if_needed "$resolved_repo_root/.vendor"
mkdir_if_needed "$harness_dir"
mkdir_if_needed "$override_root"
mkdir_if_needed "$override_skills_dir"
mkdir_if_needed "$override_templates_dir"
mkdir_if_needed "$override_templates_zh_dir"

remove_if_exists "$vendor_spec_root"
remove_if_exists "$vendor_skills_root"
remove_if_exists "$vendor_root/README.md"

mkdir_if_needed "$vendor_root"
copy_dir "$resolved_source_root/spec" "$vendor_spec_root"
mkdir_if_needed "$vendor_skills_root"
copy_file "$resolved_source_root/README.md" "$vendor_root/README.md"

vendor_skill_files=()
while IFS= read -r source_skill; do
  vendor_skill_files+=("$source_skill")
done < <(find "$resolved_source_root/skills" -maxdepth 1 -type f -name 'harness-*.md' | sort)

if [[ "${#vendor_skill_files[@]}" -eq 0 ]]; then
  printf 'No harness skill files found under %s/skills\n' "$resolved_source_root" >&2
  exit 1
fi

for source_skill in "${vendor_skill_files[@]}"; do
  copy_file "$source_skill" "$vendor_skills_root/$(basename "$source_skill")"
done

skill_names=()
for source_skill in "${vendor_skill_files[@]}"; do
  append_unique "$(basename "$source_skill")"
done

while IFS= read -r override_skill; do
  append_unique "$(basename "$override_skill")"
done < <(find "$override_skills_dir" -maxdepth 1 -type f -name '*.md' | sort)

runtime_mode="symlink"
for runtime_target in "$resolved_repo_root/.claude/skills" "$resolved_repo_root/.agents"; do
  dir_mode="$(materialize_runtime_dir "$runtime_target")"
  if [[ "$dir_mode" == "copy" ]]; then
    runtime_mode="copy"
  elif [[ "$dir_mode" == "hardlink" && "$runtime_mode" == "symlink" ]]; then
    runtime_mode="hardlink"
  fi
done

if [[ "$dry_run" == "true" ]]; then
  printf 'plan  %s\n' "$lockfile_path"
else
  cat > "$lockfile_path" <<EOF
schema: harness-lock/v1
upstream:
  name: baton
  version: $version
  commit: $upstream_commit
install:
  mode: $mode
  installed_at: $timestamp
layout:
  vendor_root: .vendor/baton-harness
  spec_root: .vendor/baton-harness/spec
  skills_root: .vendor/baton-harness/skills
  runtime_skill_targets:
    - .claude/skills
    - .agents
  runtime_skill_mode: $runtime_mode
  override_roots:
    skills: .harness/overrides/skills
    templates: .harness/overrides/templates
EOF
  printf 'write %s\n' "$lockfile_path"
fi

# Install platform hooks for artifact validation and state transition enforcement
if [[ "$dry_run" != "true" ]]; then
  hook_installer="$resolved_source_root/spec/bootstrap/install-hooks.sh"
  if [[ -f "$hook_installer" ]]; then
    bootstrap_dir="$vendor_spec_root/bootstrap"
    bash "$hook_installer" \
      --repo-root "$resolved_repo_root" \
      --bootstrap-dir "$bootstrap_dir" \
      || printf 'Warning: install-hooks.sh failed — hooks not installed\n'
  fi
fi

printf '\nHarness %s complete.\n' "$mode"
printf 'Target Repo:   %s\n' "$resolved_repo_root"
printf 'Source Root:   %s\n' "$resolved_source_root"
printf 'Version:       %s\n' "$version"
printf 'Commit:        %s\n' "$upstream_commit"
printf 'Runtime Mode:  %s\n' "$runtime_mode"
if [[ "$dry_run" == "true" ]]; then
  printf 'Mode:          dry-run\n'
fi
printf '\nNext steps:\n'
printf '1. Review %s\n' "$lockfile_path"
printf '2. If this was install, run %s/.vendor/baton-harness/spec/bootstrap/init-harness.sh --repo-root %s\n' "$resolved_repo_root" "$resolved_repo_root"
printf '3. Put local overrides under %s\n' "$override_root"
