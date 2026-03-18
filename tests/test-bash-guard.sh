#!/bin/bash
# test-bash-guard.sh — Tests for bash-guard.sh v3 (selective blocking)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD="$SCRIPT_DIR/../.baton/hooks/bash-guard.sh"
PASS=0
FAIL=0
TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf $tmp' EXIT

# Helper: run bash-guard with a command string via stdin JSON
run_guard() {
    local dir="$1" cmd="$2"
    local json="{\"tool_input\":{\"command\":$(printf '%s' "$cmd" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')}}"
    (cd "$dir" && printf '%s' "$json" | bash "$GUARD" 2>/dev/null)
}

# Helper: run bash-guard and capture stderr
run_guard_stderr() {
    local dir="$1" cmd="$2"
    local json="{\"tool_input\":{\"command\":$(printf '%s' "$cmd" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')}}"
    (cd "$dir" && printf '%s' "$json" | bash "$GUARD" 2>&1 1>/dev/null) || true
}

# Helper: run bash-guard and capture exit code
run_guard_exit() {
    local dir="$1" cmd="$2"
    local json="{\"tool_input\":{\"command\":$(printf '%s' "$cmd" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')}}"
    local rc=0
    (cd "$dir" && printf '%s' "$json" | bash "$GUARD" 2>/dev/null) || rc=$?
    echo "$rc"
}

assert_blocked() {
    local dir="$1" cmd="$2"
    TOTAL=$((TOTAL + 1))
    if run_guard "$dir" "$cmd"; then
        echo "  FAIL: expected BLOCKED for '$cmd' but was ALLOWED"
        FAIL=$((FAIL + 1))
    else
        echo "  pass: blocked '$cmd'"
        PASS=$((PASS + 1))
    fi
}

assert_allowed() {
    local dir="$1" cmd="$2"
    TOTAL=$((TOTAL + 1))
    if run_guard "$dir" "$cmd"; then
        echo "  pass: allowed '$cmd'"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: expected ALLOWED for '$cmd' but was BLOCKED"
        FAIL=$((FAIL + 1))
    fi
}

assert_exit_code() {
    local dir="$1" cmd="$2" expected="$3"
    TOTAL=$((TOTAL + 1))
    local actual
    actual="$(run_guard_exit "$dir" "$cmd")"
    if [ "$actual" -eq "$expected" ]; then
        echo "  pass: exit $actual for '$cmd'"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: expected exit $expected for '$cmd', got $actual"
        FAIL=$((FAIL + 1))
    fi
}

# ============================================================
echo "=== Test 1: Gate open (BATON:GO) → all commands allowed ==="
d="$tmp/t1" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
# Plan
<!-- BATON:GO -->
## Todo
- [ ] Step 1
EOF
assert_allowed "$d" "echo hello > file.txt"
assert_allowed "$d" "echo hello >> file.txt"
assert_allowed "$d" "sed -i 's/a/b/' file.txt"
assert_allowed "$d" "cp src.txt dst.txt"
assert_allowed "$d" "mv old.txt new.txt"
assert_allowed "$d" "cat file | tee output.txt"
assert_allowed "$d" "ls -la"

# ============================================================
echo ""
echo "=== Test 2: No plan → block write patterns ==="
d="$tmp/t2" && mkdir -p "$d"
assert_blocked "$d" "echo hello > file.txt"
assert_blocked "$d" "sed -i 's/a/b/' file.txt"
assert_blocked "$d" "cp src.txt dst.txt"

# ============================================================
echo ""
echo "=== Test 3: Plan without GO → block write patterns ==="
d="$tmp/t3" && mkdir -p "$d"
echo "# Plan without GO" > "$d/plan.md"
assert_blocked "$d" "echo hello > file.txt"
assert_blocked "$d" "sed -i 's/a/b/' file.txt"
assert_blocked "$d" "cp src.txt dst.txt"

# ============================================================
echo ""
echo "=== Test 4: Output redirection patterns → blocked ==="
d="$tmp/t4" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
assert_blocked "$d" "echo hello > file.txt"
assert_blocked "$d" "echo hello >> file.txt"
assert_blocked "$d" "echo hello>file.txt"
assert_blocked "$d" "echo hello>>file.txt"
assert_blocked "$d" "cmd 1> file"
assert_blocked "$d" "cmd 1>> file"
assert_blocked "$d" "cmd 1>file"
assert_blocked "$d" "cmd 1>>file"
assert_blocked "$d" "cmd 2> file"
assert_blocked "$d" "cmd 2>> file"
assert_blocked "$d" "cmd 2>file"
assert_blocked "$d" "cmd 2>>file"

# ============================================================
echo ""
echo "=== Test 5: Pipe to tee → blocked ==="
d="$tmp/t5" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
assert_blocked "$d" "cat file | tee output.txt"
assert_blocked "$d" "cat file |tee output.txt"
assert_blocked "$d" "cat file | tee -a output.txt"

# ============================================================
echo ""
echo "=== Test 6: In-place editors → blocked ==="
d="$tmp/t6" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
assert_blocked "$d" "sed -i 's/a/b/' file.txt"
assert_blocked "$d" "sed -i.bak 's/a/b/' file.txt"
assert_blocked "$d" "perl -pi -e 's/a/b/' file.txt"
assert_blocked "$d" "python -c \"open('f','w').write('x')\""
assert_blocked "$d" "python3 -c \"open('f','a').write('x')\""

# ============================================================
echo ""
echo "=== Test 7: File mutation commands → blocked ==="
d="$tmp/t7" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
assert_blocked "$d" "cp src.txt dst.txt"
assert_blocked "$d" "mv old.txt new.txt"
assert_blocked "$d" "install -m 644 src dst"
assert_blocked "$d" "truncate -s 0 file.txt"

# ============================================================
echo ""
echo "=== Test 8: Heredoc with redirect → blocked ==="
d="$tmp/t8" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
assert_blocked "$d" "cat <<EOF > file.txt"
assert_blocked "$d" "cat <<'EOF' > file.txt"
assert_blocked "$d" "python <<'PY' > file.txt"
assert_blocked "$d" "cat<<EOF>file.txt"
assert_blocked "$d" "python<<'PY'>file.txt"

# ============================================================
echo ""
echo "=== Test 9: Warn-only: touch → exit 0 with warning ==="
d="$tmp/t9" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
assert_allowed "$d" "touch file.txt"
TOTAL=$((TOTAL + 1))
STDERR="$(run_guard_stderr "$d" "touch file.txt")"
if echo "$STDERR" | grep -q "touch"; then
    echo "  pass: touch emits warning to stderr"
    PASS=$((PASS + 1))
else
    echo "  FAIL: touch should emit warning to stderr"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 10: Read-only commands → always allowed ==="
d="$tmp/t10" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
assert_allowed "$d" "ls -la"
assert_allowed "$d" "cat file.txt"
assert_allowed "$d" "grep pattern file"
assert_allowed "$d" "git status"
assert_allowed "$d" "echo hello"
assert_allowed "$d" "find . -name '*.txt'"
assert_allowed "$d" "head -10 file.txt"
assert_allowed "$d" "tail -5 file.txt"
assert_allowed "$d" "wc -l file.txt"

# ============================================================
echo ""
echo "=== Test 11: python -c without write patterns → allowed ==="
d="$tmp/t11" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
assert_allowed "$d" "python -c \"print('hello')\""
assert_allowed "$d" "python3 -c \"import sys; print(sys.version)\""

# ============================================================
echo ""
echo "=== Test 12: Gate open → write commands allowed ==="
d="$tmp/t12" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
# Plan
<!-- BATON:GO -->
## Todo
- [ ] Implement
EOF
assert_allowed "$d" "echo data > output.txt"
assert_allowed "$d" "sed -i 's/old/new/' config.yaml"
assert_allowed "$d" "cp a.txt b.txt"
assert_allowed "$d" "mv a.txt b.txt"
assert_allowed "$d" "cat <<EOF > script.sh"
assert_allowed "$d" "truncate -s 0 log.txt"
assert_allowed "$d" "perl -pi -e 's/x/y/' file"
assert_allowed "$d" "install -m 755 bin/app /usr/local/bin/"

# ============================================================
echo ""
echo "=== Test 13: Multi-plan ambiguity without BATON_PLAN → blocked ==="
d="$tmp/t13" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [ ] Step 1
EOF
echo "# Other plan" > "$d/plan-feature.md"
# Multi-plan without BATON_PLAN → gate-closed
assert_blocked "$d" "echo hello > file.txt"
assert_blocked "$d" "cp src dst"

# ============================================================
echo ""
echo "=== Test 14: Multi-plan + BATON_PLAN → allowed (if GO present) ==="
d="$tmp/t14" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [ ] Step 1
EOF
echo "# Other plan" > "$d/plan-feature.md"
TOTAL=$((TOTAL + 1))
json="{\"tool_input\":{\"command\":\"echo hello > file.txt\"}}"
if (cd "$d" && export BATON_PLAN=plan.md && printf '%s' "$json" | bash "$GUARD" 2>/dev/null); then
    echo "  pass: multi-plan + BATON_PLAN=plan.md → allowed"
    PASS=$((PASS + 1))
else
    echo "  FAIL: multi-plan + BATON_PLAN should resolve ambiguity"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 15: Exit code verification: blocked = exit 2 ==="
d="$tmp/t15" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
assert_exit_code "$d" "echo hello > file.txt" 2
assert_exit_code "$d" "sed -i 's/a/b/' f" 2
assert_exit_code "$d" "cp a b" 2
assert_exit_code "$d" "mv a b" 2
assert_exit_code "$d" "cat <<EOF > f" 2

# ============================================================
echo ""
echo "=== Test 16: Exit code verification: allowed = exit 0 ==="
d="$tmp/t16" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
assert_exit_code "$d" "ls -la" 0
assert_exit_code "$d" "cat file.txt" 0
assert_exit_code "$d" "grep pattern file" 0
assert_exit_code "$d" "touch file.txt" 0

# ============================================================
echo ""
echo "=== Test 17: Error message mentions 'plan gate' ==="
d="$tmp/t17" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
TOTAL=$((TOTAL + 1))
STDERR="$(run_guard_stderr "$d" "echo hello > file.txt")"
if echo "$STDERR" | grep -q "plan gate"; then
    echo "  pass: blocking message mentions 'plan gate'"
    PASS=$((PASS + 1))
else
    echo "  FAIL: blocking message should mention 'plan gate'"
    echo "    got: $STDERR"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 18: Empty stdin → exit 0 (no command to parse) ==="
d="$tmp/t18" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
TOTAL=$((TOTAL + 1))
if (cd "$d" && bash "$GUARD" < /dev/null 2>/dev/null); then
    echo "  pass: empty stdin → exit 0"
    PASS=$((PASS + 1))
else
    echo "  FAIL: empty stdin should exit 0"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 19: No plan at all → block write patterns ==="
d="$tmp/t19" && mkdir -p "$d"
# No plan.md exists
assert_blocked "$d" "echo data > output.txt"
assert_allowed "$d" "ls -la"

# ============================================================
echo ""
echo "=== Test 20: Fail-open when common.sh missing ==="
d="$tmp/t20" && mkdir -p "$d"
TOTAL=$((TOTAL + 1))
# Create a copy of bash-guard.sh in isolation (no lib/common.sh sibling)
cp "$GUARD" "$d/bash-guard-isolated.sh"
json='{"tool_input":{"command":"echo hello > file.txt"}}'
if (cd "$d" && printf '%s' "$json" | bash "$d/bash-guard-isolated.sh" 2>/dev/null); then
    echo "  pass: missing common.sh → fail-open (exit 0)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: missing common.sh should fail-open"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 21: Standalone tee → blocked (fix #1) ==="
d="$tmp/t21" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
assert_blocked "$d" "tee output.txt <<< hello"
assert_blocked "$d" "tee -a file.txt < input.txt"
assert_blocked "$d" "tee file.txt"

# ============================================================
echo ""
echo "=== Test 22: Quoted command names → not blocked (fix #4) ==="
d="$tmp/t22" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
assert_allowed "$d" "echo 'cp src dst'"
assert_allowed "$d" "echo 'mv old new'"
assert_allowed "$d" "echo 'install -m 644 src dst'"
assert_allowed "$d" "echo 'truncate -s 0 file'"
assert_allowed "$d" "echo 'tee output.txt'"
assert_allowed "$d" "printf '%s\n' 'cp a b'"

# ============================================================
echo ""
echo "=== Test 23: Path-qualified commands → blocked ==="
d="$tmp/t23" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
assert_blocked "$d" "/bin/cp a b"
assert_blocked "$d" "/usr/bin/tee out.txt <<< hi"
assert_blocked "$d" "/usr/bin/mv old new"
assert_blocked "$d" "/usr/local/bin/install -m 644 src dst"
assert_blocked "$d" "/usr/bin/truncate -s 0 file"

# ============================================================
echo ""
echo "================================"
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
    echo "FAILED"
    exit 1
else
    echo "ALL PASSED"
    exit 0
fi
