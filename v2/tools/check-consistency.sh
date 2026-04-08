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

# plan.template.md should match
if grep -q "compact.*standard.*full" "$REPO_ROOT/v2/templates/plan.template.md" 2>/dev/null; then
  check "plan.template.md execution mode" "pass"
else
  check "plan.template.md execution mode" "fail" "still has old mode names (strict/compact?)"
fi

if grep -q "^### Open Decisions$" "$REPO_ROOT/v2/templates/plan.template.md" 2>/dev/null; then
  check "plan.template.md open decisions" "pass"
else
  check "plan.template.md open decisions" "fail" "missing structured Open Decisions section"
fi

# Dispatcher entrypoint should reference all three
if grep -q "compact.*standard.*full" "$REPO_ROOT/v2/skills/dispatch/SKILL.md" 2>/dev/null; then
  check "dispatch/SKILL.md mode references" "pass"
else
  check "dispatch/SKILL.md mode references" "fail" "missing mode references"
fi

echo ""

# --- 2. Verifier Modes (A/B/C/C+) ---
echo "2. Verifier Modes"

# plan.template.md should have C+
if grep -q "C+" "$REPO_ROOT/v2/templates/plan.template.md" 2>/dev/null; then
  check "plan.template.md has C+" "pass"
else
  check "plan.template.md has C+" "fail" "missing C+ mode"
fi

# project-profile.template.md should have C+
if grep -q "C+" "$REPO_ROOT/v2/templates/project-profile.template.md" 2>/dev/null; then
  check "project-profile.template.md has C+" "pass"
else
  check "project-profile.template.md has C+" "fail" "missing C+ mode"
fi

if [[ -f "$REPO_ROOT/v2/templates/review.template.md" ]]; then
  check "review.template.md exists" "pass"
else
  check "review.template.md exists" "fail" "missing review template"
fi

if [[ -f "$REPO_ROOT/v2/templates/review-findings.template.json" ]]; then
  check "review-findings.template.json exists" "pass"
else
  check "review-findings.template.json exists" "fail" "missing review findings sidecar template"
fi

if grep -q "^## Routing Signals$" "$REPO_ROOT/v2/templates/review.template.md" 2>/dev/null; then
  check "review.template.md routing signals" "pass"
else
  check "review.template.md routing signals" "fail" "missing structured Routing Signals section"
fi

if grep -q "^### Findings Sidecar$" "$REPO_ROOT/v2/templates/review.template.md" 2>/dev/null; then
  check "review.template.md findings sidecar" "pass"
else
  check "review.template.md findings sidecar" "fail" "missing findings sidecar section"
fi

echo ""

# --- 3. Skill companion files exist ---
echo "3. Skill Companion Files"

if [[ -f "$REPO_ROOT/v2/skills/dispatch/SKILL.md" ]]; then
  check "dispatch/SKILL.md exists" "pass"
else
  check "dispatch/SKILL.md exists" "fail" "dispatch entrypoint missing"
fi

if [[ -f "$REPO_ROOT/v2/skills/dispatch/routing.md" ]]; then
  check "dispatch/routing.md exists" "pass"
else
  check "dispatch/routing.md exists" "fail" "dispatch routing file missing"
fi

if [[ -f "$REPO_ROOT/v2/skills/dispatch/checkpoints.md" ]]; then
  check "dispatch/checkpoints.md exists" "pass"
else
  check "dispatch/checkpoints.md exists" "fail" "dispatch checkpoints file missing"
fi

if grep -q "routing.md" "$REPO_ROOT/v2/skills/dispatch/SKILL.md" 2>/dev/null; then
  check "dispatch references routing.md" "pass"
else
  check "dispatch references routing.md" "fail" "dispatch entrypoint doesn't reference routing file"
fi

if grep -q "checkpoints.md" "$REPO_ROOT/v2/skills/dispatch/SKILL.md" 2>/dev/null; then
  check "dispatch references checkpoints.md" "pass"
else
  check "dispatch references checkpoints.md" "fail" "dispatch entrypoint doesn't reference checkpoints file"
fi

if [[ -f "$REPO_ROOT/v2/skills/planner/SKILL.md" ]]; then
  check "planner/SKILL.md exists" "pass"
else
  check "planner/SKILL.md exists" "fail" "planner entrypoint missing"
fi

if [[ -f "$REPO_ROOT/v2/skills/planner/profile.md" ]]; then
  check "planner/profile.md exists" "pass"
else
  check "planner/profile.md exists" "fail" "planner profile file missing"
fi

if [[ -f "$REPO_ROOT/v2/skills/planner/planning.md" ]]; then
  check "planner/planning.md exists" "pass"
else
  check "planner/planning.md exists" "fail" "planner planning file missing"
fi

if [[ -f "$REPO_ROOT/v2/skills/planner/revision.md" ]]; then
  check "planner/revision.md exists" "pass"
else
  check "planner/revision.md exists" "fail" "planner revision file missing"
fi

if grep -q "profile.md" "$REPO_ROOT/v2/skills/planner/SKILL.md" 2>/dev/null; then
  check "planner references profile.md" "pass"
else
  check "planner references profile.md" "fail" "planner entrypoint doesn't reference profile file"
fi

if grep -q "planning.md" "$REPO_ROOT/v2/skills/planner/SKILL.md" 2>/dev/null; then
  check "planner references planning.md" "pass"
else
  check "planner references planning.md" "fail" "planner entrypoint doesn't reference planning file"
fi

if grep -q "revision.md" "$REPO_ROOT/v2/skills/planner/SKILL.md" 2>/dev/null; then
  check "planner references revision.md" "pass"
else
  check "planner references revision.md" "fail" "planner entrypoint doesn't reference revision file"
fi

if [[ -f "$REPO_ROOT/v2/skills/verifier/SKILL.md" ]]; then
  check "verifier/SKILL.md exists" "pass"
else
  check "verifier/SKILL.md exists" "fail" "core verifier file missing"
fi

if [[ -f "$REPO_ROOT/v2/skills/verifier/preflight.md" ]]; then
  check "verifier/preflight.md exists" "pass"
else
  check "verifier/preflight.md exists" "fail" "pre-flight file missing"
fi

if [[ -f "$REPO_ROOT/v2/skills/verifier/verification.md" ]]; then
  check "verifier/verification.md exists" "pass"
else
  check "verifier/verification.md exists" "fail" "verification file missing"
fi

if [[ -f "$REPO_ROOT/v2/skills/verifier/cross-model.md" ]]; then
  check "verifier/cross-model.md exists" "pass"
else
  check "verifier/cross-model.md exists" "fail" "cross-model file missing"
fi

if [[ -f "$REPO_ROOT/v2/tools/external-review.sh" ]]; then
  check "tools/external-review.sh exists" "pass"
else
  check "tools/external-review.sh exists" "fail" "external review adapter missing"
fi

if [[ -f "$REPO_ROOT/v2/skills/verifier/adversarial.md" ]]; then
  check "verifier/adversarial.md exists" "pass"
else
  check "verifier/adversarial.md exists" "fail" "adversarial file missing"
fi

# Verifier entrypoint should reference module files
if grep -q "preflight.md" "$REPO_ROOT/v2/skills/verifier/SKILL.md" 2>/dev/null; then
  check "verifier references preflight.md" "pass"
else
  check "verifier references preflight.md" "fail" "verifier entrypoint doesn't reference pre-flight file"
fi

if grep -q "verification.md" "$REPO_ROOT/v2/skills/verifier/SKILL.md" 2>/dev/null; then
  check "verifier references verification.md" "pass"
else
  check "verifier references verification.md" "fail" "verifier entrypoint doesn't reference verification file"
fi

if grep -q "cross-model.md" "$REPO_ROOT/v2/skills/verifier/SKILL.md" 2>/dev/null; then
  check "verifier references cross-model.md" "pass"
else
  check "verifier references cross-model.md" "fail" "verifier entrypoint doesn't reference cross-model file"
fi

if grep -q "external-review.sh" "$REPO_ROOT/v2/skills/verifier/cross-model.md" 2>/dev/null; then
  check "cross-model.md references external-review.sh" "pass"
else
  check "cross-model.md references external-review.sh" "fail" "cross-model guide bypasses the adapter"
fi

if grep -q "adversarial.md" "$REPO_ROOT/v2/skills/verifier/SKILL.md" 2>/dev/null; then
  check "verifier references adversarial.md" "pass"
else
  check "verifier references adversarial.md" "fail" "verifier entrypoint doesn't reference adversarial file"
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

  # Check verifier companion files in structure tree
  if grep -Eq 'cross-model|adversarial' "$readme" 2>/dev/null; then
    check "$name: structure tree has companion files" "pass"
  else
    check "$name: structure tree has companion files" "warn" "verifier companion files not shown in structure tree"
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

if [[ -f "$REPO_ROOT/CONTRIBUTING.md" ]]; then
  check "CONTRIBUTING.md exists" "pass"
else
  check "CONTRIBUTING.md exists" "fail" "missing contribution guide"
fi

if [[ -f "$REPO_ROOT/.context/baton/README.md" ]]; then
  check ".context/baton/README.md exists" "pass"
else
  check ".context/baton/README.md exists" "fail" "missing scratch-state contract"
fi

if [[ -f "$REPO_ROOT/skills/using-baton/SKILL.md" ]]; then
  check "skills/using-baton/SKILL.md exists" "pass"
else
  check "skills/using-baton/SKILL.md exists" "fail" "missing thin bootstrap companion skill"
fi

if grep -q "Repository Layers" "$REPO_ROOT/v2/protocol.md" 2>/dev/null; then
  check "protocol.md has Repository Layers" "pass"
else
  check "protocol.md has Repository Layers" "fail" "missing core / companion / adapter boundary section"
fi

if grep -q "Change Governance" "$REPO_ROOT/v2/protocol.md" 2>/dev/null; then
  check "protocol.md has Change Governance" "pass"
else
  check "protocol.md has Change Governance" "fail" "missing behavior-change governance section"
fi

if grep -q "plan.md" "$REPO_ROOT/CLAUDE.md" 2>/dev/null && grep -q "review.md" "$REPO_ROOT/CLAUDE.md" 2>/dev/null; then
  check "CLAUDE.md projects plan/review" "pass"
else
  check "CLAUDE.md projects plan/review" "fail" "root CLAUDE projection is stale"
fi

if grep -qE 'brief.md|eval.md|brief.template.md' "$REPO_ROOT/CLAUDE.md" 2>/dev/null; then
  check "CLAUDE.md avoids legacy brief/eval names" "fail" "root CLAUDE still references legacy artifact names"
else
  check "CLAUDE.md avoids legacy brief/eval names" "pass"
fi

if grep -q "CONTRIBUTING.md" "$REPO_ROOT/v2/CLAUDE.md" 2>/dev/null; then
  check "v2/CLAUDE.md references CONTRIBUTING" "pass"
else
  check "v2/CLAUDE.md references CONTRIBUTING" "fail" "v2 quick reference missing change-policy link"
fi

if grep -q "using-baton" "$REPO_ROOT/README.md" 2>/dev/null && grep -q "using-baton" "$REPO_ROOT/README.zh-CN.md" 2>/dev/null; then
  check "README projects using-baton companion" "pass"
else
  check "README projects using-baton companion" "fail" "companion-skill table missing using-baton"
fi

echo ""

# --- 7. Skill complexity ---
echo "7. Skill Complexity"

dispatch_lines=$(wc -l < "$REPO_ROOT/v2/skills/dispatch/SKILL.md" 2>/dev/null || echo 0)
planner_lines=$(wc -l < "$REPO_ROOT/v2/skills/planner/SKILL.md" 2>/dev/null || echo 0)
verifier_lines=$(wc -l < "$REPO_ROOT/v2/skills/verifier/SKILL.md" 2>/dev/null || echo 0)

if [[ "$dispatch_lines" -gt 180 ]]; then
  check "dispatch/SKILL.md line count ($dispatch_lines)" "warn" "exceeds 180 lines — public entrypoint is getting heavy"
else
  check "dispatch/SKILL.md line count ($dispatch_lines)" "pass"
fi

if [[ "$planner_lines" -gt 180 ]]; then
  check "planner/SKILL.md line count ($planner_lines)" "warn" "exceeds 180 lines — public entrypoint is getting heavy"
else
  check "planner/SKILL.md line count ($planner_lines)" "pass"
fi

if [[ "$verifier_lines" -gt 180 ]]; then
  check "verifier/SKILL.md line count ($verifier_lines)" "warn" "exceeds 180 lines — public entrypoint is getting heavy"
else
  check "verifier/SKILL.md line count ($verifier_lines)" "pass"
fi

echo ""

# --- 8. Protocol host neutrality ---
echo "8. Protocol Host Neutrality"

if grep -qi 'codex-plugin-cc\|/codex:\|openai codex\|claude code' "$REPO_ROOT/v2/protocol.md" 2>/dev/null; then
  check "protocol.md: host-neutral" "fail" "contains tool-specific references — should use generic terms, defer to companion files"
else
  check "protocol.md: host-neutral" "pass"
fi

echo ""

# --- Contract tests ---
echo "9. Contract Tests"

if bash "$REPO_ROOT/v2/tests/run.sh" --repo-root "$REPO_ROOT" >/tmp/baton-contract-tests.log 2>&1; then
  check "v2/tests/run.sh" "pass"
else
  detail=$(sed -n '1,6p' /tmp/baton-contract-tests.log | tr '\n' ' ')
  check "v2/tests/run.sh" "fail" "${detail:-contract tests failed}"
fi

echo ""

# --- Summary ---
echo "10. Live State Validation"

if [[ -f "$REPO_ROOT/project-profile.md" || -f "$REPO_ROOT/.harness/plan.md" || -f "$REPO_ROOT/.harness/review.md" ]]; then
  if bash "$REPO_ROOT/v2/tools/validate-live-state.sh" --repo-root "$REPO_ROOT" >/tmp/baton-live-state.log 2>&1; then
    check "validate-live-state.sh" "pass"
  else
    detail=$(sed -n '1,3p' /tmp/baton-live-state.log | tr '\n' ' ')
    check "validate-live-state.sh" "fail" "${detail:-live state validation failed}"
  fi

  if bash "$REPO_ROOT/v2/tools/validate-round-sync.sh" --repo-root "$REPO_ROOT" >/tmp/baton-round-sync.log 2>&1; then
    check "validate-round-sync.sh" "pass"
  else
    detail=$(sed -n '1,3p' /tmp/baton-round-sync.log | tr '\n' ' ')
    check "validate-round-sync.sh" "fail" "${detail:-round sync validation failed}"
  fi
else
  check "live state validation" "warn" "no live state found"
fi

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
