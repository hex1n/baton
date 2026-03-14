#!/bin/bash
# test-plan-parser.sh — Tests for plan-parser.sh 1A discovery + 1B section + 1C write-set primitives
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSER="$SCRIPT_DIR/../.baton/hooks/plan-parser.sh"
PASS=0
FAIL=0
TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf $tmp' EXIT

# Source parser directly for unit testing
source_parser() {
    unset _BATON_PARSER_LOADED
    unset PLAN PLAN_NAME MULTI_PLAN_COUNT
    unset RESEARCH RESEARCH_NAME RESEARCH_FALLBACK_COUNT
    unset TODO_START TODO_END TODO_TOTAL TODO_DONE TODO_REMAINING
    unset RETRO_START RETRO_END RETRO_LINE_COUNT
    unset BATON_PLAN JSON_CWD
    . "$PARSER"
}

assert_eq() {
    local actual="$1" expected="$2" desc="$3"
    TOTAL=$((TOTAL + 1))
    if [ "$actual" = "$expected" ]; then
        echo "  pass: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected '$expected', got '$actual')"
        FAIL=$((FAIL + 1))
    fi
}

assert_rc() {
    local rc="$1" expected="$2" desc="$3"
    TOTAL=$((TOTAL + 1))
    if [ "$rc" -eq "$expected" ]; then
        echo "  pass: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected exit $expected, got $rc)"
        FAIL=$((FAIL + 1))
    fi
}

# ============================================================
echo "=== parser_find_plan ==="

# --- plan in cwd ---
echo "--- plan in cwd ---"
source_parser
d="$tmp/find-cwd"
mkdir -p "$d"
echo "# test plan" > "$d/plan.md"
JSON_CWD="$d" parser_find_plan
assert_eq "$PLAN" "$d/plan.md" "finds plan.md in cwd"
assert_eq "$PLAN_NAME" "plan.md" "PLAN_NAME is plan.md"
assert_eq "$MULTI_PLAN_COUNT" "1" "single plan count is 1"

# --- named plan in cwd ---
echo "--- named plan in cwd ---"
source_parser
d="$tmp/find-named"
mkdir -p "$d"
echo "# test" > "$d/plan-feature.md"
JSON_CWD="$d" parser_find_plan
assert_eq "$PLAN" "$d/plan-feature.md" "finds plan-feature.md in cwd"
assert_eq "$PLAN_NAME" "plan-feature.md" "PLAN_NAME is plan-feature.md"

# --- plan in parent (walk-up) ---
echo "--- plan in parent (walk-up) ---"
source_parser
d="$tmp/find-parent"
mkdir -p "$d/sub/deep"
echo "# parent plan" > "$d/plan.md"
JSON_CWD="$d/sub/deep" parser_find_plan
assert_eq "$PLAN" "$d/plan.md" "walks up to find plan.md in ancestor"
assert_eq "$PLAN_NAME" "plan.md" "PLAN_NAME from walk-up"

# --- no plan anywhere ---
echo "--- no plan ---"
source_parser
d="$tmp/find-none"
mkdir -p "$d"
JSON_CWD="$d" parser_find_plan
assert_eq "$PLAN" "" "PLAN is empty when no plan found"
assert_eq "$PLAN_NAME" "plan.md" "PLAN_NAME defaults to plan.md"
assert_eq "$MULTI_PLAN_COUNT" "0" "count is 0 when no plan"

# --- BATON_PLAN explicit selection ---
echo "--- BATON_PLAN explicit ---"
source_parser
d="$tmp/find-explicit"
mkdir -p "$d"
echo "# plan a" > "$d/plan.md"
echo "# plan b" > "$d/plan-custom.md"
BATON_PLAN="plan-custom.md" JSON_CWD="$d" parser_find_plan
assert_eq "$PLAN" "$d/plan-custom.md" "BATON_PLAN selects specific plan"
assert_eq "$PLAN_NAME" "plan-custom.md" "PLAN_NAME matches BATON_PLAN"
assert_eq "$MULTI_PLAN_COUNT" "0" "explicit selection reports 0 ambiguity"

# --- BATON_PLAN walk-up ---
echo "--- BATON_PLAN walk-up ---"
source_parser
d="$tmp/find-explicit-walkup"
mkdir -p "$d/child"
echo "# explicit" > "$d/plan-specific.md"
BATON_PLAN="plan-specific.md" JSON_CWD="$d/child" parser_find_plan
assert_eq "$PLAN" "$d/plan-specific.md" "BATON_PLAN walks up to find named plan"

# --- BATON_PLAN not found ---
echo "--- BATON_PLAN not found ---"
source_parser
d="$tmp/find-explicit-missing"
mkdir -p "$d"
BATON_PLAN="plan-nonexistent.md" JSON_CWD="$d" parser_find_plan
assert_eq "$PLAN" "" "PLAN empty when BATON_PLAN target not found"

# --- multi-plan detection ---
echo "--- multi-plan detection ---"
source_parser
d="$tmp/find-multi"
mkdir -p "$d"
echo "# a" > "$d/plan.md"
echo "# b" > "$d/plan-other.md"
JSON_CWD="$d" parser_find_plan 2>"$tmp/_stderr"
_stderr="$(cat "$tmp/_stderr")"
assert_eq "$MULTI_PLAN_COUNT" "2" "detects 2 plan files"
TOTAL=$((TOTAL + 1))
if echo "$_stderr" | grep -q "Multiple plan files"; then
    echo "  pass: multi-plan warning on stderr"
    PASS=$((PASS + 1))
else
    echo "  FAIL: multi-plan warning on stderr (got: $_stderr)"
    FAIL=$((FAIL + 1))
fi

# --- mtime ordering (most recent wins) ---
echo "--- mtime ordering ---"
source_parser
d="$tmp/find-mtime"
mkdir -p "$d"
echo "# old" > "$d/plan-old.md"
sleep 1
echo "# new" > "$d/plan-new.md"
JSON_CWD="$d" parser_find_plan 2>/dev/null
assert_eq "$PLAN_NAME" "plan-new.md" "most recently modified plan selected"

# ============================================================
echo ""
echo "=== parser_find_research ==="

# --- paired research ---
echo "--- paired research ---"
source_parser
d="$tmp/research-paired"
mkdir -p "$d"
echo "# plan" > "$d/plan-feature.md"
echo "# research" > "$d/research-feature.md"
JSON_CWD="$d" parser_find_plan 2>/dev/null
parser_find_research
assert_eq "$RESEARCH" "$d/research-feature.md" "finds paired research"
assert_eq "$RESEARCH_NAME" "research-feature.md" "RESEARCH_NAME derived from plan"

# --- paired research for plan.md ---
echo "--- paired research for plan.md ---"
source_parser
d="$tmp/research-default"
mkdir -p "$d"
echo "# plan" > "$d/plan.md"
echo "# research" > "$d/research.md"
JSON_CWD="$d" parser_find_plan 2>/dev/null
parser_find_research
assert_eq "$RESEARCH" "$d/research.md" "finds research.md paired with plan.md"

# --- no paired research ---
echo "--- no paired research ---"
source_parser
d="$tmp/research-missing"
mkdir -p "$d"
echo "# plan" > "$d/plan-feature.md"
JSON_CWD="$d" parser_find_plan 2>/dev/null
parser_find_research
assert_eq "$RESEARCH" "" "RESEARCH empty when no paired file"

# --- glob fallback: single research, no plan ---
echo "--- glob fallback: single research ---"
source_parser
d="$tmp/research-glob-single"
mkdir -p "$d"
echo "# research" > "$d/research-auth.md"
JSON_CWD="$d"
parser_find_plan 2>/dev/null
parser_find_research
assert_eq "$RESEARCH" "$d/research-auth.md" "glob fallback finds single research"
assert_eq "$RESEARCH_NAME" "research-auth.md" "fallback sets RESEARCH_NAME"
assert_eq "$PLAN_NAME" "plan-auth.md" "fallback derives PLAN_NAME from research"
assert_eq "$RESEARCH_FALLBACK_COUNT" "1" "fallback count is 1"

# --- glob fallback: multiple research, no plan ---
echo "--- glob fallback: multiple research ---"
source_parser
d="$tmp/research-glob-multi"
mkdir -p "$d"
echo "# r1" > "$d/research-one.md"
echo "# r2" > "$d/research-two.md"
JSON_CWD="$d"
parser_find_plan 2>/dev/null
parser_find_research
assert_eq "$RESEARCH" "" "no auto-pick with multiple research files"
TOTAL=$((TOTAL + 1))
if [ "$RESEARCH_FALLBACK_COUNT" -gt 1 ] 2>/dev/null; then
    echo "  pass: fallback count > 1 for multiple research files"
    PASS=$((PASS + 1))
else
    echo "  FAIL: fallback count should be > 1 (got: $RESEARCH_FALLBACK_COUNT)"
    FAIL=$((FAIL + 1))
fi

# --- no glob fallback when plan exists ---
echo "--- no glob fallback when plan exists ---"
source_parser
d="$tmp/research-no-fallback"
mkdir -p "$d"
echo "# plan" > "$d/plan-x.md"
echo "# stale" > "$d/research-unrelated.md"
JSON_CWD="$d" parser_find_plan 2>/dev/null
parser_find_research
assert_eq "$RESEARCH" "" "glob fallback disabled when plan exists"
assert_eq "$RESEARCH_FALLBACK_COUNT" "0" "fallback count 0 when plan exists"

# ============================================================
echo ""
echo "=== parser_has_go ==="

# --- GO present ---
echo "--- GO present ---"
source_parser
d="$tmp/go-present"
mkdir -p "$d"
printf '# Plan\n<!-- BATON:GO -->\n## Todo\n' > "$d/plan.md"
JSON_CWD="$d" parser_find_plan 2>/dev/null
parser_has_go; rc=$?
assert_rc "$rc" 0 "detects BATON:GO when present"

# --- GO absent ---
echo "--- GO absent ---"
source_parser
d="$tmp/go-absent"
mkdir -p "$d"
printf '# Plan\n## Todo\n' > "$d/plan.md"
JSON_CWD="$d" parser_find_plan 2>/dev/null
parser_has_go && rc=0 || rc=$?
assert_rc "$rc" 1 "returns 1 when GO absent"

# --- GO with explicit path arg ---
echo "--- GO with explicit path ---"
source_parser
d="$tmp/go-explicit"
mkdir -p "$d"
printf '# Plan\n<!-- BATON:GO -->\n' > "$d/other.md"
parser_has_go "$d/other.md"; rc=$?
assert_rc "$rc" 0 "accepts explicit plan path"

# --- GO on nonexistent file ---
echo "--- GO on nonexistent file ---"
source_parser
parser_has_go "/nonexistent/plan.md" && rc=0 || rc=$?
assert_rc "$rc" 1 "returns 1 for nonexistent file"

# --- GO when no plan ---
echo "--- GO when no PLAN set ---"
source_parser
PLAN=""
parser_has_go && rc=0 || rc=$?
assert_rc "$rc" 1 "returns 1 when PLAN is empty"

# ============================================================
echo ""
echo "=== parser_has_skill ==="

# --- skill in .baton/skills ---
echo "--- skill in .baton/skills ---"
source_parser
d="$tmp/skill-baton"
mkdir -p "$d/.baton/skills/baton-implement"
echo "# skill" > "$d/.baton/skills/baton-implement/SKILL.md"
JSON_CWD="$d" parser_has_skill "baton-implement"; rc=$?
assert_rc "$rc" 0 "finds skill in .baton/skills"

# --- skill in .claude/skills ---
echo "--- skill in .claude/skills ---"
source_parser
d="$tmp/skill-claude"
mkdir -p "$d/.claude/skills/baton-plan"
echo "# skill" > "$d/.claude/skills/baton-plan/SKILL.md"
JSON_CWD="$d" parser_has_skill "baton-plan"; rc=$?
assert_rc "$rc" 0 "finds skill in .claude/skills"

# --- skill in .cursor/skills ---
echo "--- skill in .cursor/skills ---"
source_parser
d="$tmp/skill-cursor"
mkdir -p "$d/.cursor/skills/baton-research"
echo "# skill" > "$d/.cursor/skills/baton-research/SKILL.md"
JSON_CWD="$d" parser_has_skill "baton-research"; rc=$?
assert_rc "$rc" 0 "finds skill in .cursor/skills"

# --- skill in .agents/skills ---
echo "--- skill in .agents/skills ---"
source_parser
d="$tmp/skill-agents"
mkdir -p "$d/.agents/skills/baton-finish"
echo "# skill" > "$d/.agents/skills/baton-finish/SKILL.md"
JSON_CWD="$d" parser_has_skill "baton-finish"; rc=$?
assert_rc "$rc" 0 "finds skill in .agents/skills"

# --- skill not found ---
echo "--- skill not found ---"
source_parser
d="$tmp/skill-none"
mkdir -p "$d"
JSON_CWD="$d" parser_has_skill "nonexistent" && rc=0 || rc=$?
assert_rc "$rc" 1 "returns 1 for nonexistent skill"

# --- skill walk-up ---
echo "--- skill walk-up ---"
source_parser
d="$tmp/skill-walkup"
mkdir -p "$d/.baton/skills/baton-debug"
echo "# skill" > "$d/.baton/skills/baton-debug/SKILL.md"
mkdir -p "$d/sub/deep"
JSON_CWD="$d/sub/deep" parser_has_skill "baton-debug"; rc=$?
assert_rc "$rc" 0 "walks up to find skill in ancestor"

# --- .baton/skills takes priority (checked first) ---
echo "--- .baton priority ---"
source_parser
d="$tmp/skill-priority"
mkdir -p "$d/.baton/skills/baton-plan"
mkdir -p "$d/.claude/skills/baton-plan"
echo "# baton version" > "$d/.baton/skills/baton-plan/SKILL.md"
echo "# claude version" > "$d/.claude/skills/baton-plan/SKILL.md"
JSON_CWD="$d" parser_has_skill "baton-plan"; rc=$?
assert_rc "$rc" 0 ".baton/skills checked (both present, .baton first)"

# ============================================================
echo ""
echo "=== double-source guard ==="
source_parser
d="$tmp/double-source"
mkdir -p "$d"
echo "# plan" > "$d/plan.md"
JSON_CWD="$d" parser_find_plan 2>/dev/null
assert_eq "$PLAN" "$d/plan.md" "first source works"
# Source again without unsetting guard
. "$PARSER"
# parser functions should still work (guard returns early but functions remain)
JSON_CWD="$d" parser_find_plan 2>/dev/null
assert_eq "$PLAN" "$d/plan.md" "parser works after double source"

# ============================================================
echo ""
echo "=== _common.sh integration ==="

# Verify that sourcing _common.sh makes parser functions available
echo "--- _common.sh sources parser ---"
COMMON="$SCRIPT_DIR/../.baton/hooks/_common.sh"
(
    unset _BATON_PARSER_LOADED
    SCRIPT_DIR_INNER="$(cd "$(dirname "$COMMON")" && pwd)"
    . "$COMMON"
    d="$tmp/common-integration"
    mkdir -p "$d"
    echo "# plan" > "$d/plan.md"
    printf '<!-- BATON:GO -->\n' >> "$d/plan.md"
    mkdir -p "$d/.baton/skills/baton-test"
    echo "# skill" > "$d/.baton/skills/baton-test/SKILL.md"

    # Legacy wrappers
    JSON_CWD="$d" resolve_plan_name
    JSON_CWD="$d" find_plan 2>/dev/null

    # Parser functions directly
    JSON_CWD="$d" parser_has_go && go_rc=0 || go_rc=1
    JSON_CWD="$d" parser_has_skill "baton-test" && skill_rc=0 || skill_rc=1
    JSON_CWD="$d" has_skill "baton-test" && legacy_rc=0 || legacy_rc=1

    echo "PLAN=$PLAN"
    echo "GO_RC=$go_rc"
    echo "SKILL_RC=$skill_rc"
    echo "LEGACY_SKILL_RC=$legacy_rc"
) > "$tmp/common-output.txt" 2>/dev/null

_co="$(cat "$tmp/common-output.txt")"
TOTAL=$((TOTAL + 1))
if echo "$_co" | grep -q "PLAN=$tmp/common-integration/plan.md"; then
    echo "  pass: _common.sh legacy find_plan works"
    PASS=$((PASS + 1))
else
    echo "  FAIL: _common.sh legacy find_plan (got: $_co)"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$_co" | grep -q "GO_RC=0"; then
    echo "  pass: parser_has_go accessible through _common.sh"
    PASS=$((PASS + 1))
else
    echo "  FAIL: parser_has_go through _common.sh (got: $_co)"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$_co" | grep -q "SKILL_RC=0"; then
    echo "  pass: parser_has_skill finds .baton/skills through _common.sh"
    PASS=$((PASS + 1))
else
    echo "  FAIL: parser_has_skill through _common.sh (got: $_co)"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$_co" | grep -q "LEGACY_SKILL_RC=0"; then
    echo "  pass: legacy has_skill delegates to parser (finds .baton/skills)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: legacy has_skill delegation (got: $_co)"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== parser_todo_range ==="

# --- section with items ---
echo "--- section with items ---"
source_parser
d="$tmp/todo-range-items"
mkdir -p "$d"
cat > "$d/plan.md" <<'PLAN'
# Plan
<!-- BATON:GO -->
## Todo
- [ ] item 1
- [x] item 2
## Retrospective
stuff
PLAN
PLAN="$d/plan.md"
parser_todo_range
assert_eq "$TODO_START" "3" "TODO_START at ## Todo header"
assert_eq "$TODO_END" "5" "TODO_END at last todo line"

# --- section at end of file ---
echo "--- section at end of file ---"
source_parser
d="$tmp/todo-range-eof"
mkdir -p "$d"
cat > "$d/plan.md" <<'PLAN'
# Plan
## Todo
- [ ] item 1
- [ ] item 2
PLAN
PLAN="$d/plan.md"
parser_todo_range
assert_eq "$TODO_START" "2" "TODO_START when section at EOF"
assert_eq "$TODO_END" "4" "TODO_END is last line of file"

# --- empty section ---
echo "--- empty section ---"
source_parser
d="$tmp/todo-range-empty"
mkdir -p "$d"
printf '## Todo\n## Retrospective\n' > "$d/plan.md"
PLAN="$d/plan.md"
parser_todo_range
assert_eq "$TODO_START" "1" "TODO_START for empty section"
assert_eq "$TODO_END" "1" "TODO_END equals START for empty section"

# --- no section ---
echo "--- no section ---"
source_parser
d="$tmp/todo-range-none"
mkdir -p "$d"
echo "# Plan with no todo" > "$d/plan.md"
PLAN="$d/plan.md"
parser_todo_range
assert_eq "$TODO_START" "0" "TODO_START 0 when no section"
assert_eq "$TODO_END" "0" "TODO_END 0 when no section"

# --- nonexistent file ---
echo "--- nonexistent file ---"
source_parser
parser_todo_range "/nonexistent/plan.md"
assert_eq "$TODO_START" "0" "TODO_START 0 for nonexistent file"

# ============================================================
echo ""
echo "=== parser_todo_counts ==="

# --- mixed done/undone ---
echo "--- mixed done/undone ---"
source_parser
d="$tmp/todo-counts-mixed"
mkdir -p "$d"
cat > "$d/plan.md" <<'PLAN'
# Plan
## Todo
- [ ] undone 1
- [x] ✅ done 1
- [ ] undone 2
- [x] ✅ done 2
- [x] ✅ done 3
## Retrospective
PLAN
PLAN="$d/plan.md"
parser_todo_counts
assert_eq "$TODO_TOTAL" "5" "total is 5"
assert_eq "$TODO_DONE" "3" "done is 3"
assert_eq "$TODO_REMAINING" "2" "remaining is 2"

# --- critical: checklist outside ## Todo NOT counted ---
echo "--- checklists outside ## Todo ---"
source_parser
d="$tmp/todo-counts-scoped"
mkdir -p "$d"
cat > "$d/plan.md" <<'PLAN'
# Plan

## Checklist (not todo)
- [ ] unrelated checklist item 1
- [x] unrelated checklist item 2

## Todo
- [ ] real todo 1
- [x] ✅ real todo 2

## Other Section
- [ ] also not a todo
- [x] also not a todo
PLAN
PLAN="$d/plan.md"
parser_todo_counts
assert_eq "$TODO_TOTAL" "2" "only counts items inside ## Todo"
assert_eq "$TODO_DONE" "1" "only counts done inside ## Todo"
assert_eq "$TODO_REMAINING" "1" "remaining scoped to ## Todo"

# --- no section ---
echo "--- no ## Todo section ---"
source_parser
d="$tmp/todo-counts-none"
mkdir -p "$d"
echo "# Plan without todo section" > "$d/plan.md"
PLAN="$d/plan.md"
parser_todo_counts
assert_eq "$TODO_TOTAL" "0" "total 0 when no section"
assert_eq "$TODO_DONE" "0" "done 0 when no section"
assert_eq "$TODO_REMAINING" "0" "remaining 0 when no section"

# --- all done ---
echo "--- all done ---"
source_parser
d="$tmp/todo-counts-alldone"
mkdir -p "$d"
cat > "$d/plan.md" <<'PLAN'
## Todo
- [x] ✅ done 1
- [x] ✅ done 2
PLAN
PLAN="$d/plan.md"
parser_todo_counts
assert_eq "$TODO_TOTAL" "2" "total is 2"
assert_eq "$TODO_DONE" "2" "done is 2"
assert_eq "$TODO_REMAINING" "0" "remaining is 0 when all done"

# --- empty section ---
echo "--- empty ## Todo section ---"
source_parser
d="$tmp/todo-counts-empty"
mkdir -p "$d"
printf '## Todo\n## Next\n' > "$d/plan.md"
PLAN="$d/plan.md"
parser_todo_counts
assert_eq "$TODO_TOTAL" "0" "total 0 for empty section"

# --- nonexistent file ---
echo "--- nonexistent file ---"
source_parser
parser_todo_counts "/nonexistent/plan.md"
assert_eq "$TODO_TOTAL" "0" "total 0 for nonexistent file"
assert_eq "$TODO_REMAINING" "0" "remaining 0 for nonexistent file"

# ============================================================
echo ""
echo "=== parser_retro_range ==="

# --- section present ---
echo "--- section present ---"
source_parser
d="$tmp/retro-range-present"
mkdir -p "$d"
cat > "$d/plan.md" <<'PLAN'
# Plan
## Todo
- [x] done
## Retrospective
Line 1
Line 2
Line 3
PLAN
PLAN="$d/plan.md"
parser_retro_range
assert_eq "$RETRO_START" "4" "RETRO_START at header"
assert_eq "$RETRO_END" "7" "RETRO_END at last line"

# --- no section ---
echo "--- no section ---"
source_parser
d="$tmp/retro-range-none"
mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
PLAN="$d/plan.md"
parser_retro_range
assert_eq "$RETRO_START" "0" "RETRO_START 0 when absent"
assert_eq "$RETRO_END" "0" "RETRO_END 0 when absent"

# --- section followed by another ## ---
echo "--- section in middle ---"
source_parser
d="$tmp/retro-range-middle"
mkdir -p "$d"
cat > "$d/plan.md" <<'PLAN'
## Retrospective
Content here
## 批注区
PLAN
PLAN="$d/plan.md"
parser_retro_range
assert_eq "$RETRO_START" "1" "RETRO_START at line 1"
assert_eq "$RETRO_END" "2" "RETRO_END before next ## section"

# ============================================================
echo ""
echo "=== parser_retro_valid ==="

# --- valid (≥3 lines) ---
echo "--- valid retrospective ---"
source_parser
d="$tmp/retro-valid-ok"
mkdir -p "$d"
cat > "$d/plan.md" <<'PLAN'
## Retrospective
What the plan got wrong: nothing major
What surprised me: the scope
What to research next time: more edge cases
PLAN
PLAN="$d/plan.md"
parser_retro_valid; rc=$?
assert_rc "$rc" 0 "returns 0 for ≥3 non-empty lines"
assert_eq "$RETRO_LINE_COUNT" "3" "RETRO_LINE_COUNT is 3"

# --- invalid (<3 lines) ---
echo "--- insufficient lines ---"
source_parser
d="$tmp/retro-valid-short"
mkdir -p "$d"
cat > "$d/plan.md" <<'PLAN'
## Retrospective
Only two lines
of content
PLAN
PLAN="$d/plan.md"
parser_retro_valid && rc=0 || rc=$?
assert_rc "$rc" 1 "returns 1 for <3 non-empty lines (got 2)"

# --- no section ---
echo "--- no retrospective section ---"
source_parser
d="$tmp/retro-valid-missing"
mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
PLAN="$d/plan.md"
parser_retro_valid && rc=0 || rc=$?
assert_rc "$rc" 1 "returns 1 when no section"
assert_eq "$RETRO_LINE_COUNT" "0" "line count 0 when no section"

# --- whitespace-only lines don't count ---
echo "--- whitespace-only lines ---"
source_parser
d="$tmp/retro-valid-whitespace"
mkdir -p "$d"
cat > "$d/plan.md" <<PLAN
## Retrospective
Real line 1

Real line 2

PLAN
PLAN="$d/plan.md"
parser_retro_valid && rc=0 || rc=$?
assert_rc "$rc" 1 "whitespace-only lines not counted (only 2 real)"
assert_eq "$RETRO_LINE_COUNT" "2" "RETRO_LINE_COUNT is 2 (whitespace excluded)"

# --- valid with whitespace interspersed ---
echo "--- valid with whitespace interspersed ---"
source_parser
d="$tmp/retro-valid-mixed"
mkdir -p "$d"
cat > "$d/plan.md" <<PLAN
## Retrospective
Plan was mostly right

Scope surprised me

Research more next time
PLAN
PLAN="$d/plan.md"
parser_retro_valid; rc=$?
assert_rc "$rc" 0 "valid despite interspersed blank lines"
assert_eq "$RETRO_LINE_COUNT" "3" "counts 3 non-empty lines"

# --- nonexistent file ---
echo "--- nonexistent file ---"
source_parser
parser_retro_valid "/nonexistent/plan.md" && rc=0 || rc=$?
assert_rc "$rc" 1 "returns 1 for nonexistent file"

# ============================================================
echo ""
echo "=== parser_writeset_normalize ==="

# --- plain relative path ---
echo "--- plain relative path ---"
source_parser
result="$(parser_writeset_normalize "src/main.sh")"
assert_eq "$result" "src/main.sh" "relative path unchanged"

# --- leading ./ stripped ---
echo "--- leading ./ stripped ---"
source_parser
result="$(parser_writeset_normalize "./src/main.sh")"
assert_eq "$result" "src/main.sh" "leading ./ stripped"

# --- absolute path to relative ---
echo "--- absolute path ---"
source_parser
GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -n "$GIT_ROOT" ]; then
    result="$(parser_writeset_normalize "$GIT_ROOT/.baton/hooks/plan-parser.sh")"
    assert_eq "$result" ".baton/hooks/plan-parser.sh" "absolute path converted to relative"
else
    echo "  skip: not in a git repo"
fi

# --- absolute path to relative via plan root ---
echo "--- absolute path via plan root ---"
source_parser
d="$tmp/ws-normalize-plan-root"
mkdir -p "$d/src" "$d/.baton"
echo "# plan" > "$d/plan.md"
JSON_CWD="$d"
PLAN="$d/plan.md"
result="$(parser_writeset_normalize "$d/src/main.sh")"
assert_eq "$result" "src/main.sh" "absolute path converted relative to plan root"

# --- empty path ---
echo "--- empty path ---"
source_parser
result="$(parser_writeset_normalize "")"
assert_eq "$result" "" "empty path produces no output"

# ============================================================
echo ""
echo "=== parser_writeset_extract ==="

# --- single file, no backticks ---
echo "--- single file ---"
source_parser
d="$tmp/ws-extract-single"
mkdir -p "$d"
cat > "$d/plan.md" <<'PLAN'
## Todo
- [ ] do something
  Files: src/main.sh
  Verification: test
PLAN
result="$(PLAN="$d/plan.md" parser_writeset_extract)"
assert_eq "$result" "src/main.sh" "single file extracted"

# --- multiple files with backticks ---
echo "--- multiple files with backticks ---"
source_parser
d="$tmp/ws-extract-multi"
mkdir -p "$d"
cat > "$d/plan.md" <<'PLAN'
## Todo
- [ ] do something
  Files: `src/main.sh`, `src/util.sh`, `tests/test.sh`
  Verification: test
PLAN
result="$(PLAN="$d/plan.md" parser_writeset_extract)"
expected="$(printf 'src/main.sh\nsrc/util.sh\ntests/test.sh')"
assert_eq "$result" "$expected" "three backtick-wrapped files extracted"

# --- (new) annotations stripped ---
echo "--- annotations stripped ---"
source_parser
d="$tmp/ws-extract-annotations"
mkdir -p "$d"
cat > "$d/plan.md" <<'PLAN'
## Todo
- [ ] create files
  Files: `src/new-file.sh` (new), `src/existing.sh`
  Verification: test
PLAN
result="$(PLAN="$d/plan.md" parser_writeset_extract)"
expected="$(printf 'src/existing.sh\nsrc/new-file.sh')"
assert_eq "$result" "$expected" "(new) annotation stripped, sorted"

# --- completion metadata after | stripped ---
echo "--- completion metadata stripped ---"
source_parser
d="$tmp/ws-extract-pipe"
mkdir -p "$d"
cat > "$d/plan.md" <<'PLAN'
## Todo
- [x] done item
  Files: `src/a.sh`, `src/b.sh`
  Verification: test
  Files: `src/a.sh`, `src/b.sh` | Verified: bash test.sh → pass | Deviations: none
PLAN
result="$(PLAN="$d/plan.md" parser_writeset_extract)"
expected="$(printf 'src/a.sh\nsrc/b.sh')"
assert_eq "$result" "$expected" "pipe-delimited metadata stripped, deduplicated"

# --- multiple todo items ---
echo "--- multiple todo items ---"
source_parser
d="$tmp/ws-extract-multi-todo"
mkdir -p "$d"
cat > "$d/plan.md" <<'PLAN'
## Todo
- [ ] first item
  Files: `src/alpha.sh`
- [ ] second item
  Files: `src/beta.sh`, `tests/test-beta.sh`
## Other Section
PLAN
result="$(PLAN="$d/plan.md" parser_writeset_extract)"
expected="$(printf 'src/alpha.sh\nsrc/beta.sh\ntests/test-beta.sh')"
assert_eq "$result" "$expected" "files from multiple todo items"

# --- duplicates across items deduplicated ---
echo "--- dedup across items ---"
source_parser
d="$tmp/ws-extract-dedup"
mkdir -p "$d"
cat > "$d/plan.md" <<'PLAN'
## Todo
- [ ] first
  Files: `shared.sh`, `only-first.sh`
- [ ] second
  Files: `shared.sh`, `only-second.sh`
PLAN
result="$(PLAN="$d/plan.md" parser_writeset_extract)"
expected="$(printf 'only-first.sh\nonly-second.sh\nshared.sh')"
assert_eq "$result" "$expected" "shared file deduplicated"

# --- no ## Todo section ---
echo "--- no Todo section ---"
source_parser
d="$tmp/ws-extract-no-todo"
mkdir -p "$d"
echo "# Plan with no todo" > "$d/plan.md"
result="$(PLAN="$d/plan.md" parser_writeset_extract)"
assert_eq "$result" "" "no output when no ## Todo"

# --- Todo section with no Files: lines ---
echo "--- no Files: lines ---"
source_parser
d="$tmp/ws-extract-no-files"
mkdir -p "$d"
cat > "$d/plan.md" <<'PLAN'
## Todo
- [ ] item without files field
  Change: something
  Verification: manual
PLAN
result="$(PLAN="$d/plan.md" parser_writeset_extract)"
assert_eq "$result" "" "no output when no Files: lines"

# --- leading ./ in plan paths stripped ---
echo "--- leading ./ in plan paths ---"
source_parser
d="$tmp/ws-extract-dotslash"
mkdir -p "$d"
cat > "$d/plan.md" <<'PLAN'
## Todo
- [ ] item
  Files: `./src/main.sh`, `src/other.sh`
PLAN
result="$(PLAN="$d/plan.md" parser_writeset_extract)"
expected="$(printf 'src/main.sh\nsrc/other.sh')"
assert_eq "$result" "$expected" "leading ./ stripped from plan paths"

# --- nonexistent file ---
echo "--- nonexistent file ---"
source_parser
result="$(parser_writeset_extract "/nonexistent/plan.md")"
assert_eq "$result" "" "no output for nonexistent file"

# --- Files: outside ## Todo not extracted ---
echo "--- Files: outside Todo not extracted ---"
source_parser
d="$tmp/ws-extract-outside"
mkdir -p "$d"
cat > "$d/plan.md" <<'PLAN'
## Design
  Files: `should/not/appear.sh`
## Todo
- [ ] only item
  Files: `real/file.sh`
## Notes
  Files: `also/not/extracted.sh`
PLAN
result="$(PLAN="$d/plan.md" parser_writeset_extract)"
assert_eq "$result" "real/file.sh" "only Files: inside ## Todo extracted"

# ============================================================
echo ""
echo "=== parser_writeset_contains ==="

# --- file in write set ---
echo "--- file in write set ---"
source_parser
d="$tmp/ws-contains-yes"
mkdir -p "$d"
cat > "$d/plan.md" <<'PLAN'
## Todo
- [ ] item
  Files: `src/main.sh`, `src/util.sh`
PLAN
parser_writeset_contains "src/main.sh" "$d/plan.md"; rc=$?
assert_rc "$rc" 0 "returns 0 for file in write set"

# --- file not in write set ---
echo "--- file not in write set ---"
source_parser
parser_writeset_contains "src/other.sh" "$d/plan.md" && rc=0 || rc=$?
assert_rc "$rc" 1 "returns 1 for file not in write set"

# --- same basename, different directory ---
echo "--- basename match but wrong dir ---"
source_parser
parser_writeset_contains "lib/main.sh" "$d/plan.md" && rc=0 || rc=$?
assert_rc "$rc" 1 "returns 1 for same basename in different directory"

# --- input with leading ./ matches ---
echo "--- input with ./ matches ---"
source_parser
parser_writeset_contains "./src/main.sh" "$d/plan.md"; rc=$?
assert_rc "$rc" 0 "returns 0 after stripping ./ from input"

# --- empty path ---
echo "--- empty path ---"
source_parser
parser_writeset_contains "" "$d/plan.md" && rc=0 || rc=$?
assert_rc "$rc" 1 "returns 1 for empty path"

# --- absolute path matches ---
echo "--- absolute path matches ---"
source_parser
GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -n "$GIT_ROOT" ]; then
    d2="$tmp/ws-contains-abs"
    mkdir -p "$d2"
    cat > "$d2/plan.md" <<'PLAN'
## Todo
- [ ] item
  Files: `.baton/hooks/plan-parser.sh`
PLAN
    parser_writeset_contains "$GIT_ROOT/.baton/hooks/plan-parser.sh" "$d2/plan.md"; rc=$?
    assert_rc "$rc" 0 "absolute path resolved to relative and matched"
else
    echo "  skip: not in a git repo"
    TOTAL=$((TOTAL + 1))
    PASS=$((PASS + 1))
fi

# --- nonexistent plan file ---
echo "--- nonexistent plan ---"
source_parser
parser_writeset_contains "src/main.sh" "/nonexistent/plan.md" && rc=0 || rc=$?
assert_rc "$rc" 1 "returns 1 when plan file doesn't exist"

# ============================================================
echo ""
echo "=== COMPLETE filter ==="

# --- COMPLETE-marked plan is skipped ---
echo "--- COMPLETE plan skipped ---"
source_parser
d="$tmp/complete-filter"
mkdir -p "$d"
printf '# Old plan\n<!-- BATON:COMPLETE -->\n' > "$d/plan-old.md"
echo "# Active plan" > "$d/plan-new.md"
JSON_CWD="$d" parser_find_plan
assert_eq "$PLAN_NAME" "plan-new.md" "COMPLETE-marked plan skipped, active plan found"
assert_eq "$MULTI_PLAN_COUNT" "1" "only active plan counted"

# --- all plans COMPLETE → no plan found ---
echo "--- all COMPLETE → no plan ---"
source_parser
d="$tmp/complete-all"
mkdir -p "$d"
printf '# Done\n<!-- BATON:COMPLETE -->\n' > "$d/plan-done.md"
JSON_CWD="$d" parser_find_plan
assert_eq "$PLAN" "" "all COMPLETE → PLAN empty"

# --- COMPLETE in body text (not on own line) is not filtered ---
echo "--- COMPLETE in body text not filtered ---"
source_parser
d="$tmp/complete-body"
mkdir -p "$d"
printf '# Plan\nDescribes <!-- BATON:COMPLETE --> marker usage\n' > "$d/plan-describe.md"
JSON_CWD="$d" parser_find_plan
assert_eq "$PLAN_NAME" "plan-describe.md" "COMPLETE in body text does not filter plan"

# ============================================================
echo ""
echo "=== baton-tasks discovery ==="

# --- plan in baton-tasks/<topic>/ ---
echo "--- baton-tasks plan discovery ---"
source_parser
d="$tmp/baton-tasks-disc"
mkdir -p "$d/.baton" "$d/baton-tasks/my-feature"
echo "# Plan" > "$d/baton-tasks/my-feature/plan.md"
JSON_CWD="$d" parser_find_plan
assert_eq "$PLAN" "$d/baton-tasks/my-feature/plan.md" "finds plan in baton-tasks/<topic>/"
assert_eq "$PLAN_NAME" "baton-tasks/my-feature/plan.md" "PLAN_NAME includes baton-tasks path"

# --- root plan takes priority over baton-tasks by mtime ---
echo "--- root plan priority ---"
source_parser
d="$tmp/baton-tasks-priority"
mkdir -p "$d/.baton" "$d/baton-tasks/feat"
echo "# Task plan" > "$d/baton-tasks/feat/plan.md"
sleep 1
echo "# Root plan" > "$d/plan-root.md"  # created after → newer mtime
JSON_CWD="$d" parser_find_plan
# Both found — most recent by mtime wins (root was created later)
assert_eq "$PLAN" "$d/plan-root.md" "root plan wins by mtime"

# --- research in same directory as baton-tasks plan ---
echo "--- same-dir research pairing ---"
source_parser
d="$tmp/baton-tasks-research"
mkdir -p "$d/.baton" "$d/baton-tasks/auth"
echo "# Plan" > "$d/baton-tasks/auth/plan.md"
echo "# Research" > "$d/baton-tasks/auth/research.md"
JSON_CWD="$d" parser_find_plan
parser_find_research
assert_eq "$RESEARCH" "$d/baton-tasks/auth/research.md" "research found in same baton-tasks dir"
assert_eq "$RESEARCH_NAME" "research.md" "RESEARCH_NAME is just research.md"

# --- project_root returns project root, not task subdir ---
echo "--- project_root not task subdir ---"
source_parser
d="$tmp/baton-tasks-root"
mkdir -p "$d/.baton" "$d/baton-tasks/feat"
echo "# Plan" > "$d/baton-tasks/feat/plan.md"
JSON_CWD="$d"
parser_find_plan
_root="$(parser_project_root)"
assert_eq "$_root" "$d" "project_root returns project root, not baton-tasks subdir"

# --- COMPLETE plan in baton-tasks is skipped ---
echo "--- COMPLETE baton-tasks plan skipped ---"
source_parser
d="$tmp/baton-tasks-complete"
mkdir -p "$d/.baton" "$d/baton-tasks/done" "$d/baton-tasks/active"
printf '# Done\n<!-- BATON:COMPLETE -->\n' > "$d/baton-tasks/done/plan.md"
echo "# Active" > "$d/baton-tasks/active/plan.md"
JSON_CWD="$d" parser_find_plan
assert_eq "$PLAN" "$d/baton-tasks/active/plan.md" "COMPLETE baton-tasks plan skipped"

# --- research glob fallback includes baton-tasks ---
echo "--- research glob fallback with baton-tasks ---"
source_parser
d="$tmp/baton-tasks-research-fallback"
mkdir -p "$d/.baton" "$d/baton-tasks/topic"
echo "# Research" > "$d/baton-tasks/topic/research.md"
JSON_CWD="$d"
parser_find_plan  # no plan found
parser_find_research
assert_eq "$RESEARCH" "$d/baton-tasks/topic/research.md" "research glob fallback finds baton-tasks research"

# ============================================================
echo ""
echo "=== Results ==="
echo "$PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
