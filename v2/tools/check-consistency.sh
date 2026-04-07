#!/usr/bin/env bash
set -euo pipefail

# Check protocol-to-downstream consistency across Baton v2 files.
# Run after any protocol.md change to catch drift before it becomes a bug.
# Usage: bash v2/tools/check-consistency.sh [--repo-root <path>]

REPO_ROOT="."
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

PASS=0
FAIL=0
WARN=0

check() {
  local label="$1" result="$2" detail="${3:-}"
  if [[ "$result" == "pass" ]]; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  elif [[ "$result" == "warn" ]]; then
    echo "  ⚠️  $label — $detail"
    WARN=$((WARN + 1))
  else
    echo "  ❌ $label — $detail"
    FAIL=$((FAIL + 1))
  fi
}

echo "Baton v2 Consistency Check"
echo "========================="
echo ""

# --- 1. Execution modes ---
echo "1. Execution Modes"

# Protocol defines compact/standard/full
if grep -q "Compact.*Standard.*Full" "$REPO_ROOT/v2/protocol.md" 2>/dev/null; then
  check "protocol.md has compact/standard/full" "pass"
else
  check "protocol.md has compact/standard/full" "fail" "modes not found"
fi

# brief.template.md should match
if grep -q "compact.*standard.*full" "$REPO_ROOT/v2/templates/brief.template.md" 2>/dev/null; then
  check "brief.template.md execution mode" "pass"
else
  check "brief.template.md execution mode" "fail" "still has old mode names (strict/compact?)"
fi

# Dispatch should reference all three
if grep -q "compact.*standard.*full" "$REPO_ROOT/v2/skills/dispatch/SKILL.md" 2>/dev/null; then
  check "dispatch/SKILL.md mode references" "pass"
else
  check "dispatch/SKILL.md mode references" "fail" "missing mode references"
fi

echo ""

# --- 2. Verifier Modes (A/B/C/C+) ---
echo "2. Verifier Modes"

# brief.template.md should have C+
if grep -q "C+" "$REPO_ROOT/v2/templates/brief.template.md" 2>/dev/null; then
  check "brief.template.md has C+" "pass"
else
  check "brief.template.md has C+" "fail" "missing C+ mode"
fi

# project-profile.template.md should have C+
if grep -q "C+" "$REPO_ROOT/v2/templates/project-profile.template.md" 2>/dev/null; then
  check "project-profile.template.md has C+" "pass"
else
  check "project-profile.template.md has C+" "fail" "missing C+ mode"
fi

echo ""

# --- 3. Verifier module files exist ---
echo "3. Verifier Module Files"

if [[ -f "$REPO_ROOT/v2/skills/verifier/SKILL.md" ]]; then
  check "verifier/SKILL.md exists" "pass"
else
  check "verifier/SKILL.md exists" "fail" "core verifier file missing"
fi

if [[ -f "$REPO_ROOT/v2/skills/verifier/module-crossmodel.md" ]]; then
  check "verifier/module-crossmodel.md exists" "pass"
else
  check "verifier/module-crossmodel.md exists" "fail" "cross-model module missing"
fi

if [[ -f "$REPO_ROOT/v2/skills/verifier/module-adversarial.md" ]]; then
  check "verifier/module-adversarial.md exists" "pass"
else
  check "verifier/module-adversarial.md exists" "fail" "adversarial module missing"
fi

# Dispatch should reference module files
if grep -q "module-crossmodel" "$REPO_ROOT/v2/skills/dispatch/SKILL.md" 2>/dev/null; then
  check "dispatch references module-crossmodel.md" "pass"
else
  check "dispatch references module-crossmodel.md" "fail" "dispatch doesn't reference cross-model module"
fi

if grep -q "module-adversarial" "$REPO_ROOT/v2/skills/dispatch/SKILL.md" 2>/dev/null; then
  check "dispatch references module-adversarial.md" "pass"
else
  check "dispatch references module-adversarial.md" "fail" "dispatch doesn't reference adversarial module"
fi

echo ""

# --- 4. README projection layer rules ---
echo "4. README Projection Layer"

# README should NOT contain exact thresholds
for readme in "$REPO_ROOT/README.md" "$REPO_ROOT/README.zh-CN.md"; do
  [[ -f "$readme" ]] || continue
  name=$(basename "$readme")

  # Check for exact threshold numbers (excluding mermaid syntax and code blocks)
  if grep -v '^\s*```' "$readme" | grep -v 'flowchart\|subgraph\|style\|-->' | grep -qiE 'max 3|3x unresolved|3 次未解决|最多 3 次'; then
    check "$name: no exact thresholds" "fail" "contains hardcoded threshold values — should reference protocol.md"
  else
    check "$name: no exact thresholds" "pass"
  fi

  # Check for old mode names
  if grep -qE 'strict mode|Strict mode|strict/compact' "$readme" 2>/dev/null; then
    check "$name: no old mode names" "fail" "contains 'strict' — should use compact/standard/full"
  else
    check "$name: no old mode names" "pass"
  fi

  # Check verifier module files in structure tree
  if grep -q "module-crossmodel\|module-adversarial" "$readme" 2>/dev/null; then
    check "$name: structure tree has modules" "pass"
  else
    check "$name: structure tree has modules" "warn" "verifier modules not shown in structure tree"
  fi
done

echo ""

# --- 5. Language neutrality ---
echo "5. Language Neutrality"

# CLAUDE.md and protocol should not reference specific test frameworks
for f in "$REPO_ROOT/CLAUDE.md" "$REPO_ROOT/v2/CLAUDE.md"; do
  [[ -f "$f" ]] || continue
  name="${f#$REPO_ROOT/}"
  if grep -qi 'JUnit\|pytest\|jest\|mocha\|rspec' "$f" 2>/dev/null; then
    check "$name: language-agnostic" "fail" "contains language-specific test framework name"
  else
    check "$name: language-agnostic" "pass"
  fi
done

echo ""

# --- 6. Document Hierarchy section exists ---
echo "6. Governance"

if grep -q "Document Hierarchy" "$REPO_ROOT/v2/protocol.md" 2>/dev/null; then
  check "protocol.md has Document Hierarchy" "pass"
else
  check "protocol.md has Document Hierarchy" "fail" "missing governance section"
fi

if grep -q "Core Rules" "$REPO_ROOT/v2/protocol.md" 2>/dev/null; then
  check "protocol.md has Core/Module rule split" "pass"
else
  check "protocol.md has Core/Module rule split" "warn" "rules not split into core/module"
fi

echo ""

# --- Summary ---
echo "========================="
echo "Results: $PASS pass, $FAIL fail, $WARN warn"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "❌ Consistency check FAILED. Fix the issues above before committing."
  exit 1
elif [[ $WARN -gt 0 ]]; then
  echo ""
  echo "⚠️  Consistency check PASSED with warnings."
  exit 0
else
  echo ""
  echo "✅ All checks passed."
  exit 0
fi
