#!/usr/bin/env bash
# Tests for validate-artifact.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="$SCRIPT_DIR/../spec/bootstrap/validate-artifact.sh"
PASS=0; FAIL=0; TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf $tmp' EXIT

assert_exit() {
  local label="$1" expected="$2"
  shift 2
  TOTAL=$((TOTAL + 1))
  local actual=0
  "$@" >/dev/null 2>&1 || actual=$?
  if [[ "$actual" -eq "$expected" ]]; then
    echo "  pass: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected exit $expected got $actual"
    FAIL=$((FAIL + 1))
  fi
}

# -- scoped-map: complete artifact passes --
cat > "$tmp/scoped-map.md" <<'EOF'
# Scoped Map: test-task
## 1. Scope
content
## 2. Entry Point
content
## 3. Call Chain
content
## 4. Existing Behavior
content
## 5. Existing Tests
content
## 6. Dependency / Risk Scan
content
## 7. Change Shape
content
## 9. Recommendation
content
EOF
assert_exit "scoped-map complete -> exit 0" 0 bash "$VALIDATE" "scoped-map" "$tmp/scoped-map.md"

# -- scoped-map: missing section fails --
cat > "$tmp/scoped-map-bad.md" <<'EOF'
# Scoped Map: test-task
## 1. Scope
content
## 2. Entry Point
content
EOF
assert_exit "scoped-map missing sections -> exit 1" 1 bash "$VALIDATE" "scoped-map" "$tmp/scoped-map-bad.md"

# -- requirements: complete passes --
cat > "$tmp/requirements.md" <<'EOF'
# Requirements: test-task
## 1. Problem
content
## 2. Scope
content
## 3. Functional Requirements
content
## 4. Non-Goals
content
## 5. Acceptance Criteria
content
## 6. Constraints
content
## 7. Validation Intent
content
EOF
assert_exit "requirements complete -> exit 0" 0 bash "$VALIDATE" "requirements" "$tmp/requirements.md"

# -- unknown artifact type -> exit 0 (skip, not error) --
assert_exit "unknown artifact type -> exit 0 (skip)" 0 bash "$VALIDATE" "unknown-type" "$tmp/requirements.md"

# -- file not found -> exit 1 --
assert_exit "missing file -> exit 1" 1 bash "$VALIDATE" "scoped-map" "$tmp/nonexistent.md"

echo ""
echo "Results: $PASS passed, $FAIL failed of $TOTAL total"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
