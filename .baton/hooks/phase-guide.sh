#!/usr/bin/env bash
# phase-guide.sh — Detect current phase, output phase-specific guidance
# Version: 7.0
# Hook: SessionStart
# Skills-first: prompts skill invocation when baton skills are available
# Fallback: hardcoded summaries per phase
# States: RESEARCH → PLAN → ANNOTATION → AWAITING_TODO → IMPLEMENT → FINISH

# --- Fail-open on unexpected errors ---
trap 'echo "⚠️ BATON phase-guide: unexpected error, skipping guidance" >&2; exit 0' HUP INT TERM

# --- Source shared functions ---
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"

# --- Governance context injection (runs on every exit) ---
# Reads using-baton SKILL.md and outputs as additionalContext JSON to stdout,
# mirroring how superpowers injects using-superpowers at SessionStart.
_escape_for_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}
_output_governance_context() {
    local _gb_path="$SCRIPT_DIR/../skills/using-baton/SKILL.md"
    [ ! -f "$_gb_path" ] && return 0
    local _content
    _content="$(cat "$_gb_path" 2>/dev/null)" || return 0
    local _escaped
    _escaped="$(_escape_for_json "$_content")"
    local _ctx="<EXTREMELY_IMPORTANT>\nYou are in a baton-governed project.\n\n**Below is the full content of 'using-baton' — baton's orchestration and governance layer. It applies to ALL skills:**\n\n${_escaped}\n</EXTREMELY_IMPORTANT>"
    if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
        cat <<EOFJ
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "${_ctx}"
  }
}
EOFJ
    else
        cat <<EOFJ
{
  "additional_context": "${_ctx}"
}
EOFJ
    fi
}
trap '_output_governance_context' EXIT
if [ -f "$SCRIPT_DIR/_common.sh" ]; then
    . "$SCRIPT_DIR/_common.sh"
else
    echo "⚠️ BATON phase-guide: _common.sh not found, skipping guidance" >&2
    exit 0
fi
MINDSET_LINE="⚠️ Mindset: verify before claiming · disagree with evidence · stop when uncertain"

# --- Auto-create missing skill junctions ---
if [ -d "$SCRIPT_DIR/../skills" ]; then
    _skill_src="$(cd "$SCRIPT_DIR/../skills" 2>/dev/null && pwd)" 2>/dev/null || true
    if [ -n "${_skill_src:-}" ]; then
        . "$SCRIPT_DIR/junction.sh" 2>/dev/null || true
        for _skill_dir in "$_skill_src"/baton-*; do
            [ ! -d "$_skill_dir" ] && continue
            _name="$(basename "$_skill_dir")"
            _proj="${BATON_PROJECT_DIR:-$(pwd)}"
            for _ide_skills in "$_proj/.claude/skills" "$_proj/.cursor/skills" "$_proj/.agents/skills"; do
                [ -d "$_ide_skills" ] || continue
                _target="$_ide_skills/$_name"
                [ -d "$_target" ] && continue
                atomic_junction "$_skill_dir" "$_target" 2>/dev/null || true
            done
        done
    fi
fi

# --- Scan all installed skills (not just baton-*) ---
# Returns space-separated list of skill names found across all IDE skill dirs
# Uses parser_project_root for walk-up when BATON_PROJECT_DIR is not set
_scan_all_skills() {
    local _d="${BATON_PROJECT_DIR:-$(parser_project_root)}" _seen="" _name
    for _ide in .baton .claude .cursor .agents; do
        for _skill_dir in "$_d/$_ide/skills"/*/; do
            [ -f "$_skill_dir/SKILL.md" ] || continue
            _name="$(basename "$_skill_dir")"
            case " $_seen " in *" $_name "*) continue ;; esac
            _seen="$_seen $_name"
        done
    done
    echo "$_seen"
}

# Filter skills by keyword in name (e.g., "research" "plan" "implement" "debug" "review")
_skills_matching() {
    local _keyword="$1" _all="$2" _matched="" _s
    for _s in $_all; do
        case "$_s" in *"$_keyword"*) _matched="${_matched:+$_matched }/$_s" ;; esac
    done
    [ -n "$_matched" ] && echo " $_matched"
}

_ALL_SKILLS="$(_scan_all_skills)"

resolve_plan_name
find_plan
parser_find_research
_RF_COUNT="${RESEARCH_FALLBACK_COUNT:-0}"

# --- State detection (priority high → low) ---

# State 1: FINISH — all todos done
if [ -n "$PLAN" ] && grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null; then
    parser_todo_counts
    if [ "$TODO_TOTAL" -gt 0 ] && [ "$TODO_TOTAL" -eq "$TODO_DONE" ]; then
        echo "$MINDSET_LINE" >&2
        cat >&2 <<EOF
📍 FINISH phase — all tasks complete. Complete the completion workflow (baton-implement Step 5):
   1. Append ## Retrospective to $PLAN_NAME (≥3 lines: what went wrong, surprises, research improvements)
   2. Run the full test suite to verify nothing is broken
   3. Mark complete: add <!-- BATON:COMPLETE --> on its own line in $PLAN_NAME
   4. Decide branch disposition (merge, keep, or discard)
EOF
        exit 0
    fi
fi

# State 2: AWAITING_TODO — plan + GO but no ## Todo
if [ -n "$PLAN" ] && grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null; then
    parser_todo_range
    if [ "${TODO_START:-0}" -eq 0 ] 2>/dev/null || [ "${TODO_TOTAL:-0}" -eq 0 ] 2>/dev/null; then
        cat >&2 << 'EOF'
⚠️ Mindset: verify before claiming · disagree with evidence · stop when uncertain
📍 BATON:GO is set but no actionable ## Todo items found.
Ask the human to say "generate Todo list" before starting implementation.
Implementation begins only after Todo list is generated.
EOF
        exit 0
    fi
fi

# State 3: IMPLEMENT — plan + GO (+ Todo exists)
if [ -n "$PLAN" ] && grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null; then
    echo "$MINDSET_LINE" >&2
    # Detect available implementation/debug skills dynamically
    _impl_skills="$(_skills_matching "implement" "$_ALL_SKILLS")$(_skills_matching "execut" "$_ALL_SKILLS")$(_skills_matching "tdd" "$_ALL_SKILLS")$(_skills_matching "test-driven" "$_ALL_SKILLS")"
    _debug_skills="$(_skills_matching "debug" "$_ALL_SKILLS")"

    if [ -n "$_impl_skills" ]; then
        echo "📍 IMPLEMENT phase — available:$_impl_skills" >&2
    else
        echo "📍 IMPLEMENT phase — <!-- BATON:GO --> is set" >&2
        echo "" >&2
        cat >&2 <<'EOF'
For each Todo item: re-read plan intent → implement → self-check → verify → mark [x].
Only modify files listed in the plan. Discover omission → STOP, update plan.
Same approach fails 3x → STOP and report.
EOF
    fi
    echo "" >&2
    echo "🔍 Self-check: (1) re-read modified code, not from memory · (2) run tests before marking done · (3) check consumers of changed files" >&2
    if [ -n "$_debug_skills" ]; then
        echo "🐛 If stuck, available:$_debug_skills" >&2
    fi
    exit 0
fi

# State 4: ANNOTATION — plan exists, no GO
if [ -n "$PLAN" ]; then
    echo "$MINDSET_LINE" >&2
    echo "📍 ANNOTATION cycle — $PLAN_NAME awaiting approval" >&2
    _plan_skills="$(_skills_matching "plan" "$_ALL_SKILLS")"
    if [ -n "$_plan_skills" ]; then
        echo "   Review annotations. Available:$_plan_skills" >&2
    else
        echo "" >&2
        cat >&2 <<EOF
Read the document for feedback. Free-text is the default; [PAUSE] means stop and investigate first.
For each piece: infer intent, verify with file:line before responding, then answer with evidence.
Record in ## Annotation Log. Human adds <!-- BATON:GO --> when satisfied.
EOF
    fi
    # Check for unprocessed annotations in 批注区
    _anno_content="$(awk '/^## 批注区/{f=1; next} f{print}' "$PLAN" \
        | grep -cvE '^[[:space:]]*$|^<!--.*-->$' 2>/dev/null)" || _anno_content=0
    if [ "$_anno_content" -gt 0 ] 2>/dev/null; then
        echo "📝 Unprocessed content detected in ## 批注区 — review and respond before proceeding." >&2
    fi
    # Complexity upgrade hint: count unique file references from Todo `Files:`
    # lines and plan-spec `**File**:` / `**Files**:` lines.
    _file_count="$(
        {
            parser_writeset_extract "$PLAN" 2>/dev/null
            awk '
            function emit_list(raw, parts, n, i, item) {
                gsub(/`/, "", raw)
                n = split(raw, parts, ",")
                for (i = 1; i <= n; i++) {
                    item = parts[i]
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", item)
                    if (item != "" && item != "none" && item != "n/a") print item
                }
            }
            /^\*\*File\*\*:[[:space:]]*/ {
                line = $0
                sub(/^\*\*File\*\*:[[:space:]]*/, "", line)
                emit_list(line)
                next
            }
            /^\*\*Files\*\*:[[:space:]]*/ {
                line = $0
                sub(/^\*\*Files\*\*:[[:space:]]*/, "", line)
                emit_list(line)
            }
            ' "$PLAN" 2>/dev/null
        } | sort -u | wc -l | tr -d ' '
    )" || _file_count=0
    if [ "$_file_count" -gt 3 ] 2>/dev/null && ! grep -qi '^## Surface Scan' "$PLAN" 2>/dev/null; then
        echo "📊 Plan touches >3 files but has no ## Surface Scan — consider upgrading complexity." >&2
    fi
    exit 0
fi

# State 5: PLAN — research exists, no plan
if [ -n "$RESEARCH" ]; then
    echo "$MINDSET_LINE" >&2
    _plan_skills="$(_skills_matching "plan" "$_ALL_SKILLS")"
    if [ -n "$_plan_skills" ]; then
        echo "📍 PLAN phase — available:$_plan_skills" >&2
        echo "   Create in baton-tasks/<topic>/plan.md (same directory as research)." >&2
    else
        echo "📍 PLAN phase — create in baton-tasks/<topic>/plan.md (same directory as research)." >&2
        echo "" >&2
        cat >&2 <<EOF
Derive approaches from research findings. Don't jump to solutions.
Extract constraints → derive 2-3 approaches → recommend with reasoning.
Plan must end with ## 批注区. Todo list generated only after human says so.
EOF
    fi
    # Final Conclusions gate
    _fc_count="$(grep -c '^## Final Conclusions' "$RESEARCH" 2>/dev/null)" || _fc_count=0
    if [ "$_fc_count" -eq 0 ] 2>/dev/null; then
        echo "⚠️ Research file exists but no ## Final Conclusions — research may be incomplete." >&2
    elif [ "$_fc_count" -gt 1 ] 2>/dev/null; then
        echo "⚠️ Research has multiple ## Final Conclusions sections — may not be converged to single source of truth." >&2
    fi
    exit 0
fi

# State 5b: Research multi-match fallback — no plan, no paired research, multiple research-*.md
if [ "$_RF_COUNT" -gt 1 ] 2>/dev/null; then
    echo "$MINDSET_LINE" >&2
    echo "⚠️ Multiple research files found (research-*.md). Name your plan to match the primary research file, or consolidate." >&2
    _plan_skills="$(_skills_matching "plan" "$_ALL_SKILLS")"
    if [ -n "$_plan_skills" ]; then
        echo "📍 PLAN phase — available:$_plan_skills" >&2
    else
        echo "📍 PLAN phase — derive approaches from research findings." >&2
    fi
    exit 0
fi

# State 6: RESEARCH — nothing exists
echo "$MINDSET_LINE" >&2
_research_skills="$(_skills_matching "research" "$_ALL_SKILLS")$(_skills_matching "brainstorm" "$_ALL_SKILLS")"
if [ -n "$_research_skills" ]; then
    echo "📍 RESEARCH phase — available:$_research_skills" >&2
    echo "   Create in baton-tasks/<topic>/research.md." >&2
else
    echo "📍 RESEARCH phase — create in baton-tasks/<topic>/research.md." >&2
    echo "" >&2
    cat >&2 <<EOF
Investigate code: start from entry points, trace call chains with file:line evidence.
Read implementations, not just interfaces. Stop at framework internals (annotate why).
Use subagents for 3+ call paths. Spike with Bash. End with ## 批注区.
Simple changes may skip research and go straight to $PLAN_NAME.
EOF
fi

exit 0
