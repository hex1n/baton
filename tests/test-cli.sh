#!/bin/bash
# test-cli.sh — Tests for bin/baton CLI
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATON_CLI="$SCRIPT_DIR/../bin/baton"
SETUP="$SCRIPT_DIR/../setup.sh"
PASS=0
FAIL=0
TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf $tmp' EXIT

# Use a temporary BATON_HOME to avoid polluting real config
export HOME="$tmp/home"
mkdir -p "$HOME"
export BATON_HOME="$tmp/baton_home"
mkdir -p "$BATON_HOME"
unset CODEX_THREAD_ID CODEX_SANDBOX CODEX_SANDBOX_NETWORK_DISABLED BATON_IDE 2>/dev/null || true
# Copy required files into fake BATON_HOME
cp -r "$SCRIPT_DIR/../.baton" "$BATON_HOME/.baton"
cp "$SETUP" "$BATON_HOME/setup.sh"
mkdir -p "$BATON_HOME/bin"
cp "$BATON_CLI" "$BATON_HOME/bin/baton"

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
echo "=== Test 2: baton list — empty registry ==="
TOTAL=$((TOTAL + 1))
if bash "$BATON_CLI" list 2>&1 | grep -q 'No projects'; then
    echo "  pass: list shows 'No projects' when empty"
    PASS=$((PASS + 1))
else
    echo "  FAIL: list should show 'No projects'"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 3: baton init — registers project ==="
d="$tmp/proj1" && mkdir -p "$d/.claude"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
READONLY_HOME="$tmp/readonly-home"
mkdir -p "$READONLY_HOME"
chmod 555 "$READONLY_HOME"
set +e
OUTPUT="$(HOME="$READONLY_HOME" CODEX_THREAD_ID="test-codex-thread" CODEX_SANDBOX="seatbelt" BATON_SKIP=pre-commit bash "$BATON_CLI" init "$d" 2>&1)"
STATUS=$?
set -e
chmod 755 "$READONLY_HOME"
if [ "$STATUS" -eq 0 ]; then
    echo "  pass: init succeeded"
    PASS=$((PASS + 1))
else
    echo "  FAIL: init failed"
    echo "  OUTPUT: $OUTPUT"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "Could not update ~/.codex/config.toml automatically\|skipped project trust entry"; then
    echo "  pass: init degrades gracefully when ~/.codex/config.toml is not writable"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected graceful warning when ~/.codex/config.toml is not writable"
    echo "  OUTPUT: $OUTPUT"
    FAIL=$((FAIL + 1))
fi
# Check registry
TOTAL=$((TOTAL + 1))
_abs="$(cd "$d" && pwd)"
if grep -qF "$_abs" "$BATON_HOME/projects.list" 2>/dev/null; then
    echo "  pass: project registered in projects.list"
    PASS=$((PASS + 1))
else
    echo "  FAIL: project not in registry"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 4: baton list — shows registered project ==="
TOTAL=$((TOTAL + 1))
OUTPUT="$(timeout 10 bash "$BATON_CLI" list 2>&1 || true)"
if echo "$OUTPUT" | grep -q 'Registered projects'; then
    echo "  pass: list shows registered project"
    PASS=$((PASS + 1))
elif echo "$OUTPUT" | grep -qF "$_abs"; then
    echo "  pass: list shows project path"
    PASS=$((PASS + 1))
else
    echo "  FAIL: list should show registered project, got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 5: baton doctor — checks installation ==="
TOTAL=$((TOTAL + 1))
OUTPUT="$(bash "$BATON_CLI" doctor "$d" 2>&1)"
if echo "$OUTPUT" | grep -q 'Checking baton installation'; then
    echo "  pass: doctor runs"
    PASS=$((PASS + 1))
else
    echo "  FAIL: doctor output unexpected"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q 'write-lock.sh'; then
    echo "  pass: doctor checks scripts"
    PASS=$((PASS + 1))
else
    echo "  FAIL: doctor should check scripts"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q 'failure-tracker.sh'; then
    echo "  pass: doctor checks failure-tracker.sh"
    PASS=$((PASS + 1))
else
    echo "  FAIL: doctor should check failure-tracker.sh"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q 'plan-parser.sh'; then
    echo "  pass: doctor checks plan-parser.sh"
    PASS=$((PASS + 1))
else
    echo "  FAIL: doctor should check plan-parser.sh"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 5b: baton doctor — checks skills ==="
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q 'Skills:'; then
    echo "  pass: doctor has Skills section"
    PASS=$((PASS + 1))
else
    echo "  FAIL: doctor should have Skills section"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q 'skills present'; then
    echo "  pass: doctor checks skill presence"
    PASS=$((PASS + 1))
else
    echo "  FAIL: doctor should check skill presence"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "=== Test 5c: baton doctor — detects missing skills ==="
d_doc="$tmp/doc_skills" && mkdir -p "$d_doc/.baton/hooks" "$d_doc/.claude/skills/baton-plan"
# Only 1 of 6 skills → should flag missing
echo "---" > "$d_doc/.claude/skills/baton-plan/SKILL.md"
echo '@.baton/workflow.md' > "$d_doc/CLAUDE.md"
touch "$d_doc/.baton/workflow.md"
TOTAL=$((TOTAL + 1))
OUTPUT_DOC="$(bash "$BATON_CLI" doctor "$d_doc" 2>&1)"
if echo "$OUTPUT_DOC" | grep -q 'missing'; then
    echo "  pass: doctor detects missing skills"
    PASS=$((PASS + 1))
else
    echo "  FAIL: doctor should detect missing skills"
    echo "  OUTPUT: $OUTPUT_DOC"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "=== Test 5d: baton doctor — checks adapters ==="
d_adap="$tmp/doc_adapt" && mkdir -p "$d_adap/.baton/hooks" "$d_adap/.cursor"
touch "$d_adap/.baton/workflow.md"
echo '@.baton/workflow.md' > "$d_adap/CLAUDE.md"
# .cursor dir exists but no adapter → should flag
TOTAL=$((TOTAL + 1))
OUTPUT_ADAP="$(bash "$BATON_CLI" doctor "$d_adap" 2>&1)"
if echo "$OUTPUT_ADAP" | grep -q 'adapter-cursor.sh missing'; then
    echo "  pass: doctor detects missing cursor adapter"
    PASS=$((PASS + 1))
else
    echo "  FAIL: doctor should detect missing cursor adapter"
    echo "  OUTPUT: $OUTPUT_ADAP"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 6: baton status — shows phase ==="
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
echo "=== Test 7: baton status — RESEARCH phase (no plan) ==="
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
echo "=== Test 8: baton status — IMPLEMENT phase (plan with GO) ==="
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
echo "=== Test 9: baton status — FINISH phase (all todos done, no retro) ==="
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
echo "=== Test 9b: baton status — FINISH phase (retro present, ready to complete) ==="
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
echo "=== Test 9c: baton status — ## Todo with trailing spaces still counts ==="
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
echo "=== Test 10: baton uninstall — removes and deregisters ==="
TOTAL=$((TOTAL + 1))
if BATON_SKIP=pre-commit bash "$BATON_CLI" uninstall "$d" > /dev/null 2>&1; then
    echo "  pass: uninstall succeeded"
    PASS=$((PASS + 1))
else
    echo "  FAIL: uninstall failed"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if ! grep -qF "$_abs" "$BATON_HOME/projects.list" 2>/dev/null; then
    echo "  pass: project removed from registry"
    PASS=$((PASS + 1))
else
    echo "  FAIL: project still in registry after uninstall"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 11: baton update --all — no projects ==="
# Clear registry
> "$BATON_HOME/projects.list"
TOTAL=$((TOTAL + 1))
OUTPUT="$(bash "$BATON_CLI" update --all 2>&1)"
if echo "$OUTPUT" | grep -q 'No projects'; then
    echo "  pass: update --all shows no projects"
    PASS=$((PASS + 1))
else
    echo "  FAIL: update --all should show no projects"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 12: plan-*.md subdirectory walk-up ==="
d="$tmp/t12" && mkdir -p "$d/src/deep"
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
echo "=== Test 13: BATON_PLAN subdirectory walk-up ==="
d="$tmp/t13" && mkdir -p "$d/src/deep"
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
echo "=== Test 14: doctor rules injection ==="
d="$tmp/t14" && mkdir -p "$d/.baton/hooks" "$d/.claude"
echo '@.baton/workflow-full.md' > "$d/CLAUDE.md"
touch "$d/.baton/workflow.md"
OUTPUT="$(bash "$BATON_CLI" doctor "$d" 2>&1)"
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "⚠"; then
    echo "  pass: doctor flags old workflow-full.md import in CLAUDE.md"
    PASS=$((PASS + 1))
else
    echo "  FAIL: doctor should flag workflow-full.md import"
    echo "  OUTPUT: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# Correct import — narrow to Rules injection section only
echo '@.baton/workflow.md' > "$d/CLAUDE.md"
OUTPUT="$(bash "$BATON_CLI" doctor "$d" 2>&1)"
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "✓ CLAUDE.md"; then
    echo "  pass: CLAUDE.md Rules injection check passes"
    PASS=$((PASS + 1))
else
    echo "  FAIL: CLAUDE.md Rules injection should pass with correct import"
    echo "  OUTPUT: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# AGENTS.md old import
echo '@.baton/workflow-full.md' > "$d/AGENTS.md"
OUTPUT="$(bash "$BATON_CLI" doctor "$d" 2>&1)"
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "⚠"; then
    echo "  pass: doctor flags old import in AGENTS.md"
    PASS=$((PASS + 1))
else
    echo "  FAIL: doctor should flag workflow-full.md in AGENTS.md"
    FAIL=$((FAIL + 1))
fi

# AGENTS.md correct import — narrow to Rules injection section only
echo '@.baton/workflow.md' > "$d/AGENTS.md"
OUTPUT="$(bash "$BATON_CLI" doctor "$d" 2>&1)"
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep "Rules injection" | grep -qv "⚠"; then
    echo "  pass: AGENTS.md Rules injection check passes"
    PASS=$((PASS + 1))
else
    echo "  FAIL: AGENTS.md Rules injection should pass with correct import"
    echo "  OUTPUT: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 15: doctor detects mixed old+new imports ==="
d="$tmp/t15" && mkdir -p "$d/.baton/hooks" "$d/.claude"
touch "$d/.baton/workflow.md"
# CLAUDE.md with both old and new
printf '@.baton/workflow.md\n@.baton/workflow-full.md\n' > "$d/CLAUDE.md"
OUTPUT="$(bash "$BATON_CLI" doctor "$d" 2>&1)"
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "residual"; then
    echo "  pass: doctor flags residual workflow-full.md in mixed CLAUDE.md"
    PASS=$((PASS + 1))
else
    echo "  FAIL: doctor should flag residual workflow-full.md in mixed CLAUDE.md"
    echo "  OUTPUT: $OUTPUT"
    FAIL=$((FAIL + 1))
fi
# AGENTS.md with both old and new
printf '@.baton/workflow.md\n@.baton/workflow-full.md\n' > "$d/AGENTS.md"
OUTPUT="$(bash "$BATON_CLI" doctor "$d" 2>&1)"
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "residual"; then
    echo "  pass: doctor flags residual workflow-full.md in mixed AGENTS.md"
    PASS=$((PASS + 1))
else
    echo "  FAIL: doctor should flag residual workflow-full.md in mixed AGENTS.md"
    echo "  OUTPUT: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 16: Multi-plan detection in status ==="
d="$tmp/t16" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [ ] Step 1
EOF
echo "# Other" > "$d/plan-feature.md"
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
echo "=== Test 17: Research fallback — single topic-named research ==="
d="$tmp/t17" && mkdir -p "$d"
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
echo "=== Test 18: Research fallback — multiple research files ==="
d="$tmp/t18" && mkdir -p "$d"
echo "# Research A" > "$d/research-auth.md"
echo "# Research B" > "$d/research-api.md"
OUTPUT="$(bash "$BATON_CLI" status "$d" 2>&1)"
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "Multiple research files"; then
    echo "  pass: multi-research warning"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected multi-research warning"
    echo "  OUTPUT: $OUTPUT"
    FAIL=$((FAIL + 1))
fi
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
echo "=== Test 19: PLAN phase — no plan, research only ==="
d="$tmp/t19" && mkdir -p "$d"
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
echo "=== Test 20: Section-aware todo counting ==="
d="$tmp/t20" && mkdir -p "$d"
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
