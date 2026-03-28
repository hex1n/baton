#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
spec_root="$(cd "$script_dir/.." && pwd)"
default_repo_root="$(cd "$spec_root/.." && pwd)"

repo_root="$default_repo_root"

usage() {
  cat <<'EOF'
Usage: check-root-readme-bilingual.sh [--repo-root PATH]

Checks that the baton repo's root English and Chinese README files remain
present, cross-linked, and aligned on key sections / adoption terms.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      if [[ $# -lt 2 ]]; then
        printf 'ERROR: --repo-root requires a value\n' >&2
        exit 2
      fi
      repo_root="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'ERROR: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

repo_root="$(cd "$repo_root" && pwd)"
readme_en="$repo_root/README.md"
readme_zh="$repo_root/README.zh-CN.md"

errors=0

report_ok() {
  printf 'OK: %s\n' "$1"
}

report_error() {
  printf 'ERROR: %s\n' "$1"
  errors=$((errors + 1))
}

require_file() {
  local path="$1"
  local label="$2"

  if [[ -f "$path" ]]; then
    report_ok "$label exists"
  else
    report_error "$label missing at $path"
  fi
}

require_fixed() {
  local path="$1"
  local needle="$2"
  local label="$3"

  if grep -Fq "$needle" "$path"; then
    report_ok "$label"
  else
    report_error "$label missing \"$needle\" in $path"
  fi
}

require_heading() {
  local path="$1"
  local heading="$2"
  local label="$3"

  if grep -Fxq "$heading" "$path"; then
    report_ok "$label"
  else
    report_error "$label missing heading \"$heading\" in $path"
  fi
}

require_file "$readme_en" "English root README"
require_file "$readme_zh" "Chinese root README"

if [[ ! -f "$readme_en" || ! -f "$readme_zh" ]]; then
  printf '%d error(s) found\n' "$errors"
  exit 1
fi

require_fixed "$readme_en" "[简体中文](README.zh-CN.md)" "English README links to Chinese README"
require_fixed "$readme_zh" "[English](README.md)" "Chinese README links to English README"

en_headings=(
  "# Baton Harness"
  "## Structure"
  "## Protocol"
  "## Artifact Language"
  "## Quick Start"
  "### Adopt in a new repo"
  "### Install / Update In Target Repo"
  "### Link skills for development (baton repo only)"
  "### Manual Copy Fallback"
  "## Role Skills"
  "## Capability Skills"
)

zh_headings=(
  "# Baton Harness"
  "## 结构"
  "## 协议"
  "## 制品语言"
  "## 快速开始"
  "### 在新仓库里接入"
  "### 在目标仓库里安装 / 升级"
  "### baton 自己内部开发时的链接模式"
  "### 手工复制 fallback"
  "## 角色技能"
  "## 能力技能"
)

for i in "${!en_headings[@]}"; do
  require_heading "$readme_en" "${en_headings[$i]}" "English README contains ${en_headings[$i]}"
  require_heading "$readme_zh" "${zh_headings[$i]}" "Chinese README contains ${zh_headings[$i]}"
done

shared_tokens=(
  "install-harness.sh"
  "update-harness.sh"
  ".vendor/baton-harness/"
  ".harness/harness.lock.yaml"
  ".harness/overrides/"
  "link-skills.sh"
  "check-root-readme-bilingual.sh"
  "CLAUDE.md"
  "AGENTS.md"
  "sync-governance-entrypoints.sh"
)

for token in "${shared_tokens[@]}"; do
  require_fixed "$readme_en" "$token" "English README mentions $token"
  require_fixed "$readme_zh" "$token" "Chinese README mentions $token"
done

if [[ $errors -eq 0 ]]; then
  printf 'root README bilingual checks OK\n'
  exit 0
fi

printf '%d error(s) found\n' "$errors"
exit 1
