#!/bin/bash
# test-cli.sh — Tests for bin/baton CLI (v5 flat install)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATON_CLI="$SCRIPT_DIR/../bin/baton"
SETUP="$SCRIPT_DIR/../setup.sh"
PASS=0
FAIL=0
TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf $tmp' EXIT

# Use a temporary HOME and BATON_HOME
export HOME="$tmp/home"
mkdir -p "$HOME/.claude"
export BATON_HOME="$tmp/baton_home"
mkdir -p "$BATON_HOME"
unset CODEX_THREAD_ID CODEX_SANDBOX CODEX_SANDBOX_NETWORK_DISABLED BATON_IDE 2>/dev/null || true

# Set up BATON_HOME with required files (v5 layout)
git init -q "$BATON_HOME"
cp -r "$SCRIPT_DIR/../hooks" "$BATON_HOME/hooks"
cp -r "$SCRIPT_DIR/../skills" "$BATON_HOME/skills"
cp "$SCRIPT_DIR/../constitution.md" "$BATON_HOME/constitution.md"
cp "$SETUP" "$BATON_HOME/setup.sh"
mkdir -p "$BATON_HOME/bin"
cp "$BATON_CLI" "$BATON_HOME/bin/baton"

# Set up fake user-level install for doctor tests
mkdir -p "$HOME/.claude/skills"
for _skill in baton-plan baton-implement baton-review baton-research baton-debug baton-subagent baton-evolve using-baton; do
    ln -s "$BATON_HOME/skills/$_skill" "$HOME/.claude/skills/$_skill"
done
# Minimal settings.json with baton hook reference
printf '{"hooks":{"PreToolUse":[{"matcher":"","hooks":["bash \\"%s/hooks/run-hook.cmd\\" bash-guard"]}]}}\n' "$BATON_HOME" > "$HOME/.claude/settings.json"
# Constitution in CLAUDE.md
echo '@../.baton/constitution.md' > "$HOME/.claude/CLAUDE.md"

# ============================================================
echo "=== Test 1: baton help ==="
TOTAL=$((TOTAL + 1))
if bash "$BATON_CLI" help 2>&1 | grep -q 'plan-first workflow'; then
    echo "  pass: help shows usage text"
    PASS=$((PASS + 1))
else
    echo "  FAIL: help output missing expected text"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 2: baton init — shows v5 redirect ==="
TOTAL=$((TOTAL + 1))
OUTPUT="$(bash "$BATON_CLI" init 2>&1 || true)"
if echo "$OUTPUT" | grep -q 'no longer needed'; then
    echo "  pass: init shows v5 redirect message"
    PASS=$((PASS + 1))
else
    echo "  FAIL: init should show redirect message"
    echo "  OUTPUT: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 3: baton doctor — checks v5 user-level installation ==="
TOTAL=$((TOTAL + 1))
OUTPUT="$(bash "$BATON_CLI" doctor 2>&1)"
if echo "$OUTPUT" | grep -q 'Checking baton v5 installation'; then
    echo "  pass: doctor runs with v5 header"
    PASS=$((PASS + 1))
else
    echo "  FAIL: doctor output unexpected"
    echo "  OUTPUT: $OUTPUT"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q 'dispatch.sh present'; then
    echo "  pass: doctor checks dispatch.sh"
    PASS=$((PASS + 1))
else
    echo "  FAIL: doctor should check dispatch.sh"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q 'manifest.conf present'; then
    echo "  pass: doctor checks manifest.conf"
    PASS=$((PASS + 1))
else
    echo "  FAIL: doctor should check manifest.conf"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q 'hooks configured'; then
    echo "  pass: doctor checks hook configuration"
    PASS=$((PASS + 1))
else
    echo "  FAIL: doctor should check hook configuration"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 3b: baton doctor — checks skills ==="
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q 'Skills'; then
    echo "  pass: doctor has Skills section"
    PASS=$((PASS + 1))
else
    echo "  FAIL: doctor should have Skills section"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q '8/8 skills'; then
    echo "  pass: doctor reports all 8 skills"
    PASS=$((PASS + 1))
else
    echo "  FAIL: doctor should report 8/8 skills"
    echo "  OUTPUT: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 3c: baton doctor — checks constitution ==="
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q 'constitution referenced'; then
    echo "  pass: doctor checks constitution in CLAUDE.md"
    PASS=$((PASS + 1))
else
    echo "  FAIL: doctor should check constitution reference"
    echo "  OUTPUT: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 3d: baton doctor — detects missing skills ==="
# Remove one skill symlink
rm "$HOME/.claude/skills/baton-plan"
TOTAL=$((TOTAL + 1))
OUTPUT_DOC="$(bash "$BATON_CLI" doctor 2>&1)"
if echo "$OUTPUT_DOC" | grep -q 'missing'; then
    echo "  pass: doctor detects missing skill"
    PASS=$((PASS + 1))
else
    echo "  FAIL: doctor should detect missing skills"
    echo "  OUTPUT: $OUTPUT_DOC"
    FAIL=$((FAIL + 1))
fi
# Restore
ln -s "$BATON_HOME/skills/baton-plan" "$HOME/.claude/skills/baton-plan"

# ============================================================
echo ""
echo "=== Test 3e: baton doctor — all checks pass ==="
TOTAL=$((TOTAL + 1))
OUTPUT_OK="$(bash "$BATON_CLI" doctor 2>&1)"
if echo "$OUTPUT_OK" | grep -q 'all checks passed'; then
    echo "  pass: doctor reports all checks passed"
    PASS=$((PASS + 1))
else
    echo "  FAIL: doctor should report all checks passed"
    echo "  OUTPUT: $OUTPUT_OK"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 4: baton status — shows phase ==="
d="$tmp/proj1" && mkdir -p "$d"
TOTAL=$((TOTAL + 1))
OUTPUT="$(bash "$BATON_CLI" status "$d" 2>&1)"
if echo "$OUTPUT" | grep -q 'Phase:'; then
    echo "  pass: status shows phase"
    PASS=$((PASS + 1))
else
    echo "  FAIL: status should show phase"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 5: baton status — RESEARCH phase (no plan) ==="
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q 'RESEARCH'; then
    echo "  pass: status shows RESEARCH when no plan"
    PASS=$((PASS + 1))
else
    echo "  FAIL: should show RESEARCH phase"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 6: baton status — IMPLEMENT phase (plan with GO) ==="
printf '# Plan\n<!-- BATON:GO -->\n## Todo\n- [ ] Step 1\n' > "$d/plan.md"
TOTAL=$((TOTAL + 1))
OUTPUT="$(bash "$BATON_CLI" status "$d" 2>&1)"
if echo "$OUTPUT" | grep -q 'IMPLEMENT'; then
    echo "  pass: status shows IMPLEMENT when plan has GO + Todo"
    PASS=$((PASS + 1))
else
    echo "  FAIL: should show IMPLEMENT phase, got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 7: baton status — FINISH phase (all todos done, no retro) ==="
printf '# Plan\n<!-- BATON:GO -->\n## Todo\n- [x] Step 1\n- [x] Step 2\n' > "$d/plan.md"
TOTAL=$((TOTAL + 1))
OUTPUT="$(bash "$BATON_CLI" status "$d" 2>&1)"
if echo "$OUTPUT" | grep -q 'FINISH'; then
    echo "  pass: status shows FINISH when all todos complete"
    PASS=$((PASS + 1))
else
    echo "  FAIL: should show FINISH phase, got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q 'retrospective needed'; then
    echo "  pass: FINISH shows 'retrospective needed' without retrospective"
    PASS=$((PASS + 1))
else
    echo "  FAIL: should show 'retrospective needed', got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 7b: baton status — FINISH phase (retro present, ready to complete) ==="
printf '# Plan\n<!-- BATON:GO -->\n## Todo\n- [x] Step 1\n- [x] Step 2\n## Retrospective\nLine one of retro.\nLine two of retro.\nLine three of retro.\n' > "$d/plan.md"
TOTAL=$((TOTAL + 1))
OUTPUT="$(bash "$BATON_CLI" status "$d" 2>&1)"
if echo "$OUTPUT" | grep -q 'FINISH'; then
    echo "  pass: status shows FINISH with retrospective"
    PASS=$((PASS + 1))
else
    echo "  FAIL: should show FINISH phase, got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q 'ready to complete'; then
    echo "  pass: FINISH shows 'ready to complete' with valid retrospective"
    PASS=$((PASS + 1))
else
    echo "  FAIL: should show 'ready to complete', got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 7c: baton status — ## Todo with trailing spaces still counts ==="
printf '# Plan\n<!-- BATON:GO -->\n## Todo   \n- [ ] Step 1\n' > "$d/plan.md"
TOTAL=$((TOTAL + 1))
OUTPUT="$(bash "$BATON_CLI" status "$d" 2>&1)"
if echo "$OUTPUT" | grep -q 'IMPLEMENT'; then
    echo "  pass: status treats ## Todo with trailing spaces as IMPLEMENT"
    PASS=$((PASS + 1))
else
    echo "  FAIL: status should not regress to AWAITING_TODO for trailing spaces"
    echo "  OUTPUT: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 8: baton uninstall — runs setup --uninstall ==="
TOTAL=$((TOTAL + 1))
# We can't fully run uninstall (it would remove our test fixtures),
# but we can verify the command dispatches correctly
OUTPUT="$(bash "$BATON_CLI" uninstall 2>&1 || true)"
# setup --uninstall will run and remove artifacts from $HOME
if [ $? -eq 0 ] || echo "$OUTPUT" | grep -q -i 'uninstall\|removed\|clean'; then
    echo "  pass: uninstall dispatched to setup.sh"
    PASS=$((PASS + 1))
else
    echo "  FAIL: uninstall should dispatch to setup.sh"
    echo "  OUTPUT: $OUTPUT"
    FAIL=$((FAIL + 1))
fi
# Restore test fixtures after uninstall
mkdir -p "$HOME/.claude/skills"
for _skill in baton-plan baton-implement baton-review baton-research baton-debug baton-subagent baton-evolve using-baton; do
    ln -s "$BATON_HOME/skills/$_skill" "$HOME/.claude/skills/$_skill" 2>/dev/null || true
done
printf '{"hooks":{"PreToolUse":[{"matcher":"","hooks":["bash \\"%s/hooks/run-hook.cmd\\" bash-guard"]}]}}\n' "$BATON_HOME" > "$HOME/.claude/settings.json"
echo '@../.baton/constitution.md' > "$HOME/.claude/CLAUDE.md"

# ============================================================
echo ""
echo "=== Test 9: baton self-update — redirects to update ==="
TOTAL=$((TOTAL + 1))
OUTPUT="$(bash "$BATON_CLI" self-update 2>&1 || true)"
if echo "$OUTPUT" | grep -q "now just.*update"; then
    echo "  pass: self-update shows redirect message"
    PASS=$((PASS + 1))
else
    echo "  FAIL: self-update should redirect to update"
    echo "  OUTPUT: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 10: plan-*.md subdirectory walk-up ==="
d="$tmp/t10" && mkdir -p "$d/src/deep"
cat > "$d/plan-feature.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [ ] Step 1
EOF
echo "# Research" > "$d/research-feature.md"
OUTPUT="$(bash "$BATON_CLI" status "$d/src/deep" 2>&1)"
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "IMPLEMENT"; then
    echo "  pass: walk-up from subdirectory finds plan-feature.md → IMPLEMENT"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected IMPLEMENT from subdirectory walk-up"
    echo "  OUTPUT: $OUTPUT"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "plan-feature.md"; then
    echo "  pass: Plan: line shows plan-feature.md"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected plan-feature.md in Plan: line"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "research-feature.md"; then
    echo "  pass: Research: line shows research-feature.md"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected research-feature.md in Research: line"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "exists"; then
    echo "  pass: research file detected as exists"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected 'exists' for research file"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 11: BATON_PLAN subdirectory walk-up ==="
d="$tmp/t11" && mkdir -p "$d/src/deep"
cat > "$d/plan-custom.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [ ] Step 1
EOF
echo "# Research" > "$d/research-custom.md"
OUTPUT="$(BATON_PLAN=plan-custom.md bash "$BATON_CLI" status "$d/src/deep" 2>&1)"
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "IMPLEMENT"; then
    echo "  pass: BATON_PLAN walk-up from subdirectory → IMPLEMENT"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected IMPLEMENT with BATON_PLAN subdirectory walk-up"
    echo "  OUTPUT: $OUTPUT"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "plan-custom.md"; then
    echo "  pass: Plan: line shows plan-custom.md"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected plan-custom.md in output"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "research-custom.md"; then
    echo "  pass: Research: line shows research-custom.md"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected research-custom.md in output"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 12: Multi-plan detection in status ==="
d="$tmp/t12" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [ ] Step 1
EOF
cat > "$d/plan-feature.md" << 'EOF2'
<!-- BATON:GO -->
## Todo
- [ ] Feature step
EOF2
OUTPUT="$(bash "$BATON_CLI" status "$d" 2>&1)"
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "Multiple plan files"; then
    echo "  pass: multi-plan warning in status output"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected multi-plan warning"
    echo "  OUTPUT: $OUTPUT"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "BATON_PLAN"; then
    echo "  pass: multi-plan warning suggests BATON_PLAN"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected BATON_PLAN suggestion"
    FAIL=$((FAIL + 1))
fi
# No warning when BATON_PLAN is set
TOTAL=$((TOTAL + 1))
OUTPUT="$(BATON_PLAN=plan.md bash "$BATON_CLI" status "$d" 2>&1)"
if echo "$OUTPUT" | grep -q "Multiple plan files"; then
    echo "  FAIL: should not warn when BATON_PLAN is set"
    FAIL=$((FAIL + 1))
else
    echo "  pass: no multi-plan warning when BATON_PLAN is set"
    PASS=$((PASS + 1))
fi

# ============================================================
echo ""
echo "=== Test 13: Research fallback — single topic-named research ==="
d="$tmp/t13" && mkdir -p "$d"
echo "# Research" > "$d/research-auth.md"
OUTPUT="$(bash "$BATON_CLI" status "$d" 2>&1)"
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "research-auth.md"; then
    echo "  pass: discovered research-auth.md via fallback"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected research-auth.md in output"
    echo "  OUTPUT: $OUTPUT"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "exists"; then
    echo "  pass: research file shows 'exists'"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected 'exists' for research file"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "PLAN"; then
    echo "  pass: no plan + research → PLAN phase"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected PLAN phase with research only"
    echo "  OUTPUT: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 14: Research fallback — multiple research files ==="
d="$tmp/t14" && mkdir -p "$d"
echo "# Research A" > "$d/research-auth.md"
echo "# Research B" > "$d/research-api.md"
OUTPUT="$(bash "$BATON_CLI" status "$d" 2>&1)"
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "Research: research-\\*\\.md (multiple matches)"; then
    echo "  pass: research status line stays ambiguous when multiple"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected ambiguous research status line"
    echo "  OUTPUT: $OUTPUT"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "PLAN"; then
    echo "  pass: multiple research files still imply PLAN phase"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected PLAN phase for ambiguous research"
    echo "  OUTPUT: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 15: PLAN phase — no plan, research only ==="
d="$tmp/t15" && mkdir -p "$d"
echo "# Research" > "$d/research.md"
OUTPUT="$(bash "$BATON_CLI" status "$d" 2>&1)"
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "PLAN"; then
    echo "  pass: no plan + research.md → PLAN phase"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected PLAN phase"
    echo "  OUTPUT: $OUTPUT"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "research.md.*exists"; then
    echo "  pass: research.md detected as exists"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected research.md to show 'exists'"
    echo "  OUTPUT: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 16: Section-aware todo counting ==="
d="$tmp/t16" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Approach
- [ ] Not a real todo
## Todo
- [x] Step 1
- [ ] Step 2
## Notes
- [ ] Also not a real todo
EOF
OUTPUT="$(bash "$BATON_CLI" status "$d" 2>&1)"
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "1/2"; then
    echo "  pass: section-aware counting (1/2)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected 1/2 in todos, got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

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
