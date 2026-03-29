#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0; TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

assert_equals() {
  local label="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$actual" == "$expected" ]]; then
    echo "  pass: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected '$expected' got '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local label="$1" haystack="$2" needle="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "  FAIL: $label — '$haystack' contains '$needle'"
    FAIL=$((FAIL + 1))
  else
    echo "  pass: $label"
    PASS=$((PASS + 1))
  fi
}

# ---------------------------------------------------------------------------
# link-skills.sh creates repo-relative symlinks
# ---------------------------------------------------------------------------
link_repo="$tmp/link-repo"
mkdir -p "$link_repo/spec" "$link_repo/skills/deep-test"
cp -R "$SCRIPT_DIR/../spec/bootstrap" "$link_repo/spec/bootstrap"
printf 'name: flat\n' > "$link_repo/skills/example.md"
cat > "$link_repo/skills/forked.md" <<'EOF'
context: fork
EOF
cat > "$link_repo/skills/deep-test/SKILL.md" <<'EOF'
---
name: deep-test
---
EOF

bash "$link_repo/spec/bootstrap/link-skills.sh" >/dev/null

flat_target="$(readlink "$link_repo/.claude/skills/example.md")"
agents_target="$(readlink "$link_repo/.agents/example.md")"
subdir_target="$(readlink "$link_repo/.claude/skills/deep-test.md" 2>/dev/null || true)"
subdir_dir_target="$(readlink "$link_repo/.claude/skills/deep-test")"
fork_target="$(readlink "$link_repo/.claude/agents/forked.md")"

assert_equals "link-skills .claude/skills is relative" "../../skills/example.md" "$flat_target"
assert_equals "link-skills .agents is relative" "../skills/example.md" "$agents_target"
assert_equals "link-skills removes stale flat skill link" "" "$subdir_target"
assert_equals "link-skills subdir skill keeps directory link" "../../skills/deep-test" "$subdir_dir_target"
assert_equals "link-skills .claude/agents is relative" "../../skills/forked.md" "$fork_target"
assert_not_contains "link-skills target omits absolute repo path" "$flat_target" "$link_repo"

# ---------------------------------------------------------------------------
# install-harness.sh creates repo-relative symlinks in target repos
# ---------------------------------------------------------------------------
source_repo="$tmp/source-repo"
target_repo="$tmp/target-repo"
mkdir -p "$source_repo/spec" "$source_repo/skills"
cp -R "$SCRIPT_DIR/../spec/bootstrap" "$source_repo/spec/bootstrap"
printf '1.2.3\n' > "$source_repo/spec/VERSION"
printf '# source\n' > "$source_repo/README.md"
printf 'name: harness-alpha\n' > "$source_repo/skills/harness-alpha.md"
mkdir -p "$target_repo"

bash "$source_repo/spec/bootstrap/install-harness.sh" \
  --repo-root "$target_repo" \
  --source-root "$source_repo" >/dev/null

installed_claude_target="$(readlink "$target_repo/.claude/skills/harness-alpha.md")"
installed_agents_target="$(readlink "$target_repo/.agents/harness-alpha.md")"

assert_equals "install-harness .claude/skills is relative" "../../.vendor/baton-harness/skills/harness-alpha.md" "$installed_claude_target"
assert_equals "install-harness .agents is relative" "../.vendor/baton-harness/skills/harness-alpha.md" "$installed_agents_target"
assert_not_contains "install-harness target omits source absolute path" "$installed_claude_target" "$source_repo"
assert_not_contains "install-harness target omits target absolute path" "$installed_claude_target" "$target_repo"

echo ""
echo "Results: $PASS passed, $FAIL failed of $TOTAL total"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
