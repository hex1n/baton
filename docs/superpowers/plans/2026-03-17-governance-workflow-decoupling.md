# Governance-Workflow Decoupling Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Baton's governance layer artifact-agnostic so any workflow system (Superpowers, baton skills, hand-written) works under Baton's enforcement.

**Architecture:** Generalize plan-parser to find plans in broader locations. Make phase-guide report phase + available skills without prescribing which to use. Keep governance hooks unchanged.

**Spec:** `docs/superpowers/specs/2026-03-17-install-architecture-redesign.md` (for v4 context)

---

## Task 1: Generalize plan-parser.sh plan discovery

**Files:**
- Modify: `.baton/hooks/plan-parser.sh:55-58`
- Test: `tests/test-plan-parser.sh` (add cases)

Currently the parser searches:
```
plan.md, plan-*.md, baton-tasks/*/plan.md, baton-tasks/*/plan-*.md
```

Expand to also search:
```
docs/**/plan*.md, docs/**/*-plan*.md
docs/**/*-design*.md (treated as research, not plan)
```

- [ ] **Step 1: Add test cases for broader plan discovery**

Add to `tests/test-plan-parser.sh`:

```bash
# --- Plans in docs/ subdirectories ---
echo "=== docs/ plan discovery ==="
mkdir -p "$tmp/docs/superpowers/plans"
echo '# Plan' > "$tmp/docs/superpowers/plans/2026-03-17-feature-plan.md"
JSON_CWD="$tmp" parser_find_plan
assert_eq "$PLAN_NAME" "docs/superpowers/plans/2026-03-17-feature-plan.md" \
    "finds plan in docs/ subdirectory"

# --- Root plan takes priority over docs/ plan ---
echo "=== root plan priority ==="
echo '# Root Plan' > "$tmp/plan.md"
JSON_CWD="$tmp" parser_find_plan
assert_eq "$PLAN_NAME" "plan.md" \
    "root plan.md takes priority over docs/ plan"
rm -f "$tmp/plan.md"

# --- BATON:GO works in docs/ plans ---
echo "=== BATON:GO in docs/ plan ==="
printf '# Plan\n<!-- BATON:GO -->\n## Todo\n- [ ] Step 1\n' > \
    "$tmp/docs/superpowers/plans/2026-03-17-feature-plan.md"
JSON_CWD="$tmp" parser_find_plan
assert_eq "$PLAN_NAME" "docs/superpowers/plans/2026-03-17-feature-plan.md" \
    "finds BATON:GO plan in docs/"
parser_has_go
assert_eq "$?" "0" "parser_has_go works for docs/ plan"

# --- BATON:COMPLETE plans are filtered ---
echo "=== COMPLETE filtering in docs/ ==="
printf '# Plan\n<!-- BATON:COMPLETE -->\n' > \
    "$tmp/docs/superpowers/plans/2026-03-17-feature-plan.md"
JSON_CWD="$tmp" parser_find_plan
assert_eq "$PLAN" "" "COMPLETE plan in docs/ is filtered out"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/test-plan-parser.sh`
Expected: New tests FAIL (parser doesn't search docs/)

- [ ] **Step 3: Modify parser_find_plan to search docs/**

In `.baton/hooks/plan-parser.sh`, expand the `ls` candidates line (line 58):

```bash
# Current:
_candidates="$(cd "$_d" 2>/dev/null && ls -t plan.md plan-*.md baton-tasks/*/plan.md baton-tasks/*/plan-*.md 2>/dev/null)" || true

# New: also search docs/ subdirectories
_candidates="$(cd "$_d" 2>/dev/null && {
    ls -t plan.md plan-*.md 2>/dev/null
    ls -t baton-tasks/*/plan.md baton-tasks/*/plan-*.md 2>/dev/null
    find docs/ -maxdepth 4 -name 'plan*.md' -o -name '*-plan*.md' 2>/dev/null | sort -t/ -k1,1
} | head -20)" || true
```

Priority: root plans first (by mtime), then baton-tasks, then docs/ (alphabetical).
`head -20` prevents performance issues if docs/ has many files.

- [ ] **Step 4: Run tests**

Run: `bash tests/test-plan-parser.sh`
Expected: All PASS including new cases

- [ ] **Step 5: Commit**

```bash
git add .baton/hooks/plan-parser.sh tests/test-plan-parser.sh
git commit -m "feat: generalize plan-parser to discover plans in docs/ subdirectories"
```

---

## Task 2: Generalize research detection

**Files:**
- Modify: `.baton/hooks/plan-parser.sh` (`parser_find_research` function)
- Test: `tests/test-plan-parser.sh`

Currently research searches:
```
research.md, research-*.md (matched by plan name)
```

Expand to also recognize:
```
docs/**/*-design*.md, docs/**/*-spec*.md
```

- [ ] **Step 1: Add test cases for spec/design detection**

```bash
echo "=== docs/ spec as research ==="
mkdir -p "$tmp/docs/superpowers/specs"
echo '# Design Spec' > "$tmp/docs/superpowers/specs/2026-03-17-feature-design.md"
PLAN="" PLAN_NAME=""
JSON_CWD="$tmp" parser_find_research
assert_neq "$RESEARCH" "" "finds spec in docs/ as research"
```

- [ ] **Step 2: Modify parser_find_research**

After the existing research file search, add a fallback to docs/ specs:

```bash
# Fallback: look for design/spec docs if no research.md found
if [ -z "$RESEARCH" ]; then
    local _spec
    _spec="$(cd "$_d" 2>/dev/null && find docs/ -maxdepth 4 \
        \( -name '*-design*.md' -o -name '*-spec*.md' \) \
        -newer . 2>/dev/null | sort -r | head -1)" || true
    if [ -n "$_spec" ] && [ -f "$_d/$_spec" ]; then
        RESEARCH="$_d/$_spec"
        RESEARCH_NAME="$_spec"
    fi
fi
```

- [ ] **Step 3: Run tests, commit**

```bash
bash tests/test-plan-parser.sh
git add .baton/hooks/plan-parser.sh tests/test-plan-parser.sh
git commit -m "feat: parser recognizes docs/ specs and designs as research artifacts"
```

---

## Task 3: Make phase-guide skill-agnostic

**Files:**
- Modify: `.baton/hooks/phase-guide.sh`

Currently phase-guide prescribes specific skills:
```
"📍 RESEARCH phase — invoke /baton-research to begin investigation"
"📍 PLAN phase — invoke /baton-plan to create change proposal"
"📍 IMPLEMENT phase — invoke /baton-implement for execution discipline"
```

Change to report phase + list all available skills for that phase:

- [ ] **Step 1: Add skill detection for Superpowers skills**

After the existing `has_skill` checks, also detect Superpowers skills:

```bash
# Detect available skills per phase
_research_skills=""
has_skill baton-research && _research_skills="$_research_skills /baton-research"
has_skill superpowers:brainstorming && _research_skills="$_research_skills /superpowers:brainstorming"

_plan_skills=""
has_skill baton-plan && _plan_skills="$_plan_skills /baton-plan"
has_skill superpowers:writing-plans && _plan_skills="$_plan_skills /superpowers:writing-plans"

_impl_skills=""
has_skill baton-implement && _impl_skills="$_impl_skills /baton-implement"
has_skill superpowers:executing-plans && _impl_skills="$_impl_skills /superpowers:executing-plans"
has_skill superpowers:test-driven-development && _impl_skills="$_impl_skills /superpowers:test-driven-development"

_review_skills=""
has_skill baton-review && _review_skills="$_review_skills /baton-review"
```

- [ ] **Step 2: Update phase output messages**

Replace prescriptive messages with informational ones:

```bash
# RESEARCH phase
echo "📍 RESEARCH phase" >&2
echo "   Available:$_research_skills" >&2

# PLAN phase
echo "📍 PLAN phase" >&2
echo "   Available:$_plan_skills" >&2

# IMPLEMENT phase
echo "📍 IMPLEMENT phase" >&2
echo "   Available:$_impl_skills" >&2
if [ -n "$_review_skills" ]; then
    echo "   Review:$_review_skills" >&2
fi
```

- [ ] **Step 3: Run phase-guide tests**

Run: `bash tests/test-phase-guide.sh`
Expected: Some tests need updating (they assert exact message text).
Update assertions to match new format.

- [ ] **Step 4: Commit**

```bash
git add .baton/hooks/phase-guide.sh tests/test-phase-guide.sh
git commit -m "feat: phase-guide reports available skills without prescribing workflow"
```

---

## Task 4: Add BATON:GO template to Superpowers plan format

**Files:**
- Modify: Superpowers `writing-plans` skill (if accessible)
- Alternative: Add a `.claude/skills/baton-plan-bridge/SKILL.md` that enhances writing-plans output

This task makes Superpowers plans compatible with Baton's authorization gate.

- [ ] **Step 1: Check if Superpowers skills are editable**

The Superpowers plugin is at `.claude/plugins/cache/claude-plugins-official/superpowers/`.
Check if skills can be overridden locally.

- [ ] **Step 2: Option A — local skill override**

If Superpowers skills can be overridden, add to the writing-plans plan header template:

```markdown
> **Baton governance:** This plan requires `<!-- BATON:GO -->` before execution.
> Add the marker after reviewing and approving the plan.
```

- [ ] **Step 3: Option B — bridge skill**

If Superpowers can't be modified, create a bridge skill:

```markdown
# .baton/skills/baton-governance-bridge/SKILL.md
---
name: baton-governance-bridge
description: Ensures Superpowers workflow artifacts are compatible with Baton governance
---

When writing implementation plans (via superpowers:writing-plans or similar):

1. Include a "## Baton Governance" section with:
   - `<!-- BATON:GO -->` placeholder (human adds when approving)
   - Write-set listing (files the plan is authorized to modify)

2. Before executing any plan, verify:
   - The plan file contains `<!-- BATON:GO -->`
   - If not, ask the human to add it before proceeding
```

- [ ] **Step 4: Commit**

```bash
git add .baton/skills/baton-governance-bridge/
git commit -m "feat: bridge skill ensures Superpowers plans comply with Baton governance"
```

---

## Task 5: Route Superpowers review to baton-review

**Files:**
- Create: `.claude/skills/review-routing/SKILL.md` (or modify Superpowers config)

baton-review produces significantly higher quality reviews (first-principles framework,
evidence fidelity, anti-defensive-bias). Superpowers' spec/plan review loops should
dispatch baton-review instead of their own reviewer.

- [ ] **Step 1: Create review routing skill**

```markdown
# .baton/skills/review-routing/SKILL.md
---
name: review-routing
description: Routes all spec and plan reviews to baton-review for first-principles analysis
---

When reviewing specs, plans, or implementation artifacts:

- Use /baton-review instead of dispatching spec-document-reviewer or plan-document-reviewer
- baton-review provides:
  - First-principles framework (4 questions)
  - Evidence-backed challenges with fidelity levels
  - Severity classification (high/medium/low)
  - Anti-defensive-bias mechanisms
  - Frame-level + artifact-level findings

When the superpowers skills say "dispatch spec-document-reviewer subagent" or
"dispatch plan-document-reviewer subagent", use baton-review instead via:
  Agent tool with subagent_type="superpowers:code-reviewer" and include in the prompt:
  "Use baton-review's first-principles framework for this review."
```

- [ ] **Step 2: Commit**

```bash
git add .baton/skills/review-routing/
git commit -m "feat: route all reviews to baton-review for first-principles analysis"
```

---

## Summary

| Task | What | Impact |
|------|------|--------|
| 1 | Parser finds plans in docs/ | Baton governance covers Superpowers plans |
| 2 | Parser recognizes specs as research | Phase detection works with Superpowers artifacts |
| 3 | Phase-guide lists skills, doesn't prescribe | Users choose best tool per phase |
| 4 | BATON:GO bridge for Superpowers plans | Write-lock works with any workflow |
| 5 | Reviews route to baton-review | Best reviewer always used |

**After these 5 tasks:**
- Baton governance works with any workflow system
- Users can freely mix baton-research + superpowers:brainstorming + superpowers:writing-plans + baton-review
- No coupling between governance and workflow
- One `plan-parser.sh` change is the keystone
