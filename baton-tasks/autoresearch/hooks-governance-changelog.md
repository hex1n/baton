# Hooks Governance Audit — Changelog

**Task**: Behavioral correctness audit of 5 baton governance hooks
**Scope**: Scoring, gap analysis, test scenarios, targeted fixes, re-evaluation
**Date**: 2026-03-20

---

## Audit Rubric (25 points total)

| Criterion | Points | Definition |
|-----------|--------|------------|
| 规则覆盖 | 5 | Enforces the intended constitution rule(s) completely |
| 边界处理 | 5 | Handles edge cases: missing files, empty input, ambiguous state |
| 失败安全 | 5 | Fail-open on unexpected errors; does not block valid work |
| 错误信息 | 5 | Messages state what was blocked, why, and how to unblock |
| Constitution一致性 | 5 | No contradiction with constitution invariants or cross-hook assumptions |

---

## 1. write-lock.sh

### Pre-fix Score: 16/25

| Criterion | Pre | Notes |
|-----------|-----|-------|
| 规则覆盖 | 2/5 | BATON:GO → unconditional allow; write set never consulted |
| 边界处理 | 4/5 | Good: awk fallback, fail-open on missing jq, multi-plan guard |
| 失败安全 | 5/5 | Trap + fail-open on all error paths |
| 错误信息 | 3/5 | Block messages informative, but allowed path gave no confirmation |
| Constitution一致性 | 2/5 | Constitution: "approved scope is a hard boundary"; write set was decorative |

### Test Scenarios

| # | Scenario | Expected | Pre-fix |
|---|----------|----------|---------|
| T1 (pass) | Edit file that is in write set, BATON:GO present | Allow | ✅ Allow |
| T2 (block) | Edit file NOT in write set, BATON:GO present | Block | ❌ Allow (gap) |
| T3 (edge) | Plan has BATON:GO but no Files: entries (empty write set) | Allow (backward compat) | ✅ Allow |

### Gap Found

BATON:GO presence → `exit 0` without checking write set. The write-set parsing primitives (`parser_writeset_extract`, `parser_writeset_normalize`) existed in plan-parser.sh v1.3 but were never called.

### Fix Applied (v2.1 → v3.1)

After `parser_has_go`, extract write set. If non-empty, normalize TARGET and check membership. Block with approved-file listing if not found. Backward compatible: empty write set = no restriction.

```bash
if parser_has_go; then
    _writeset="$(parser_writeset_extract "$PLAN" 2>/dev/null)"
    if [ -n "$_writeset" ]; then
        _target_norm="$(parser_writeset_normalize "$TARGET" "$PROJECT_DIR")"
        if ! printf '%s\n' "$_writeset" | grep -qxF "$_target_norm"; then
            echo "🔒 Blocked: $(basename "$TARGET") is not in the approved write set." >&2
            echo "   Approved files in $PLAN_NAME:" >&2
            printf '%s\n' "$_writeset" | head -10 | sed 's/^/   · /' >&2
            echo "📍 Add this file to the plan write set, or record BATON:OVERRIDE with reason before proceeding." >&2
            exit 2
        fi
    fi
    cat <<'HOOKJSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"Baton: write-set approved. Self-check: confirm scope matches plan before writing."}}
HOOKJSON
    exit 0
fi
```

### Live Validation

- Immediately blocked an edit to `quality-gate.sh` (not in write set): ✅ correct
- Allowed edits to authorized files in write set: ✅ correct

### Post-fix Score: 24/25

| Criterion | Post | Notes |
|-----------|------|-------|
| 规则覆盖 | 5/5 | Write set enforced; governance marker injection guard also present |
| 边界处理 | 4/5 | Empty write set handled; awk fallback remains |
| 失败安全 | 5/5 | No regressions |
| 错误信息 | 5/5 | Block message lists approved files and directs to resolution |
| Constitution一致性 | 5/5 | "Approved scope is a hard boundary" now enforced |

---

## 2. quality-gate.sh

### Pre-fix Score: 14/25

| Criterion | Pre | Notes |
|-----------|-----|-------|
| 规则覆盖 | 3/5 | Self-challenge checked; `## 批注区` (required by constitution) never checked |
| 边界处理 | 4/5 | File-not-found guard, type filter |
| 失败安全 | 5/5 | Advisory only, always exit 0 |
| 错误信息 | 2/5 | Missing 批注区 check → no reminder; self-challenge message lacks resolution path |
| Constitution一致性 | 0/5 | Constitution: "every research or plan document ends with `## 批注区`"; hook ignores it |

### Test Scenarios

| # | Scenario | Expected | Pre-fix |
|---|----------|----------|---------|
| T1 (pass) | plan.md with `## Self-Challenge` (3+ lines) + `## 批注区` | Silent | ❌ Silent even without 批注区 |
| T2 (block) | plan.md with `## Self-Challenge` but no `## 批注区` | Advisory warning | ❌ Silent (gap) |
| T3 (edge) | plan.md with `## Self-Challenge` < 3 content lines | Advisory for shallow SC | ✅ Warns |

### Gap Found

Hook checks `## Self-Challenge` depth but never verifies `## 批注区` presence. Constitution requires this section in every research/plan document. No hook enforces it.

### Fix Designed (v1.0 → v1.1) — BLOCKED

Add after self-challenge depth check:

```bash
# Check for 批注区 (required by constitution)
if ! grep -q '^## 批注区' "$TARGET" 2>/dev/null; then
    echo "⚠️ $FILE_TYPE is missing ## 批注区 — constitution requires this terminal section." >&2
    echo "   Add ## 批注区 at the end of the document." >&2
fi
```

**Status**: BLOCKED — `quality-gate.sh` is not in the write set of the active plan (`baton-tasks/first-principles-analysis/plan.md`). Fix cannot be applied without:

1. Adding `quality-gate.sh` to the write set in that plan
2. Recording a `BATON:OVERRIDE` marker in the plan with reason
3. Creating a new plan scoped to this hooks-governance audit

**Post-fix Score (projected)**: 22/25

---

## 3. completion-check.sh

### Pre-fix Score: 18/25

| Criterion | Pre | Notes |
|-----------|-----|-------|
| 规则覆盖 | 3/5 | Checked todos + retrospective; missed ❓ evidence markers |
| 边界处理 | 4/5 | Multi-plan guard, missing plan = exit 0 |
| 失败安全 | 5/5 | Trap + fail-open |
| 错误信息 | 4/5 | Good block messages; retrospective guidance specific |
| Constitution一致性 | 2/5 | Constitution completion requires "blockers and contradictions closed"; no ❓ check |

### Test Scenarios

| # | Scenario | Expected | Pre-fix |
|---|----------|----------|---------|
| T1 (pass) | All todos done, retrospective ≥3 lines, no ❓ markers | Allow | ✅ Allow |
| T2 (block) | All todos done, ❓ markers present | Advisory warning | ❌ Silent (gap) |
| T3 (edge) | Retrospective exists with only 2 content lines | Block | ✅ Block |

### Gap Found

No check for unresolved `❓` evidence markers. Constitution completion condition 3: "Blockers and contradictions closed." Unresolved evidence gaps violate this.

### Fix Applied (v1.1 → v1.2)

Added advisory check before test-suite check:

```bash
# --- Check for unresolved ❓ markers (advisory) ---
_unresolved="$(grep -c '❓' "$PLAN" 2>/dev/null || echo 0)"
if [ "${_unresolved:-0}" -gt 0 ] 2>/dev/null; then
    echo "⚠️ $PLAN_NAME has ${_unresolved} unresolved ❓ marker(s) — constitution requires blockers and contradictions closed before completion." >&2
fi
```

Advisory (not blocking) because legitimate completion sometimes carries documented unknowns that the human has accepted. Human judgment still applies.

### Post-fix Score: 23/25

| Criterion | Post | Notes |
|-----------|------|-------|
| 规则覆盖 | 4/5 | ❓ check added; advisory not blocking (1 pt deducted for partial enforcement) |
| 边界处理 | 4/5 | No change |
| 失败安全 | 5/5 | No change |
| 错误信息 | 5/5 | ❓ message references constitution explicitly |
| Constitution一致性 | 5/5 | Completion condition 3 now surfaced |

---

## 4. failure-tracker.sh

### Pre-fix Score: 17/25

| Criterion | Pre | Notes |
|-----------|-----|-------|
| 规则覆盖 | 4/5 | Session-total proxy is correct given hook constraints; counts failures |
| 边界处理 | 4/5 | SESSION_ID sanitization, PPID fallback |
| 失败安全 | 5/5 | Advisory only, exit 0 always |
| 错误信息 | 2/5 | Count=3 message contradicted itself ("default ≥2; phase skill may override to 3") — hook fires AT 3, not 2 |
| Constitution一致性 | 2/5 | Messages implied hook tracks per-hypothesis; it tracks session totals only |

### Test Scenarios

| # | Scenario | Expected | Pre-fix |
|---|----------|----------|---------|
| T1 (pass) | 2 failures, different tools | No alert | ✅ Silent |
| T2 (alert) | 3rd failure in session | Alert about hypothesis check | ✅ Alert, but message confused |
| T3 (edge) | No jq, SESSION_ID has special chars | Sanitized path, fallback works | ✅ Handled |

### Gap Found

Count=3 message: "check if failures share a root cause (default ≥2; active phase skill may override to 3)." This is self-contradictory — the hook fires at count=3, so it cannot enforce the ≥2 threshold. The note "phase skill may override to 3" misrepresents the architecture; phase skills don't configure the hook threshold. The hook is a session-total proxy, not a per-hypothesis counter.

### Fix Applied (v1.0 → v1.1)

Updated header comment to document the proxy nature. Rewrote both alert messages:

**Count=3 (before)**:
> "3 tool failures this session — check if failures share a root cause (default ≥2; active phase skill may override to 3). If yes, invoke /baton-debug."

**Count=3 (after)**:
> "3 tool failures this session — check if any two share the same root-cause hypothesis. Constitution: ≥2 failures under the same hypothesis → stop and surface. If yes, invoke /baton-debug."

**Count=5 (before)**:
> "5 tool failures this session — constitution failure boundary likely applies. Stop and surface the pattern to the human."

**Count=5 (after)**:
> "5 tool failures this session — failure boundary very likely applies. Stop, identify the hypothesis driving repeated attempts, and surface to the human."

### Known Architectural Limitation

Per-hypothesis counting is impossible at the hook layer. The constitution's failure boundary ("same hypothesis failing ≥2 times") requires hypothesis identity, which only the AI layer has. This hook is an advisory session-total proxy. Per-hypothesis enforcement remains an AI-layer responsibility. Documented in header comment.

### Post-fix Score: 22/25

| Criterion | Post | Notes |
|-----------|------|-------|
| 规则覆盖 | 4/5 | Proxy nature documented; advisory threshold reasonable |
| 边界处理 | 4/5 | No change |
| 失败安全 | 5/5 | No change |
| 错误信息 | 4/5 | Messages now accurate; hypothesis concept surfaced |
| Constitution一致性 | 5/5 | No longer contradicts constitution; proxy limitation documented |

---

## 5. stop-guard.sh

### Pre-fix Score: 14/25

| Criterion | Pre | Notes |
|-----------|-----|-------|
| 规则覆盖 | 2/5 | Enforces finish-workflow reminder; does not implement failure boundary detection |
| 边界处理 | 4/5 | Fail-open, plan-not-found handled |
| 失败安全 | 5/5 | Advisory only |
| 错误信息 | 2/5 | Finish reminder useful; no guidance for mid-session stop |
| Constitution一致性 | 1/5 | Failure boundary enforcement missing; stop-without-retrospective only partial |

### Test Scenarios

| # | Scenario | Expected | Pre-fix |
|---|----------|----------|---------|
| T1 (pass) | Session ends, plan complete with retrospective | Silent | ✅ Silent |
| T2 (advisory) | Session ends mid-task (todos incomplete) | Reminder to surface state | ✅ Reminder (if implemented) |
| T3 (edge) | Session ends after repeated failures (same hypothesis) | Alert about failure boundary | ❌ No detection |

### Gap Found

Hook does not detect repeated-failure patterns. Constitutional failure boundary requires surfacing when the same hypothesis fails ≥2 times. Session-ID reconstruction at Stop event is unreliable — the hook fires in a different process context than when tool failures occurred.

### Fix Decision: Architectural Limitation — No Fix Applied

The failure-boundary gap cannot be fixed at the Stop hook layer:
1. Stop hook has no access to failure counts from the session
2. SESSION_ID reconstruction at Stop is not reliable
3. The failure-tracker.sh advisory messages at count=3/5 are the appropriate hook-layer proxy

**Correct enforcement location**: AI reasoning layer — the AI must track hypothesis identity and apply the ≥2 threshold during the session.

### Post-fix Score: 14/25 (unchanged)

The score reflects the architectural constraint, not a quality defect in the hook's implementation given its constraints.

---

## Summary Table

| Hook | Pre | Post | Delta | Status |
|------|-----|------|-------|--------|
| write-lock.sh | 16 | 24 | +8 | ✅ Fixed |
| quality-gate.sh | 14 | — | — | 🔒 Blocked (not in write set) |
| completion-check.sh | 18 | 23 | +5 | ✅ Fixed |
| failure-tracker.sh | 17 | 22 | +5 | ✅ Fixed |
| stop-guard.sh | 14 | 14 | 0 | ℹ️ Architectural limit |

**Total pre-fix**: 79/125
**Total post-fix**: 83/125 (quality-gate projected 22 if fix applied: 105/125)

---

## Open Items

### quality-gate.sh — 批注区 check (BLOCKED)

To apply the fix, the human must do one of:
1. Add `.baton/hooks/quality-gate.sh` to the write set in `baton-tasks/first-principles-analysis/plan.md`
2. Record a `BATON:OVERRIDE` marker (without HTML comment syntax in this document to avoid injection guard) in the plan with reason
3. Create a new baton plan scoped to this hooks-governance audit

### stop-guard.sh — failure boundary

No hook-layer fix is possible. If stronger enforcement is needed, the constitution or phase skills must explicitly require the AI to maintain a per-hypothesis failure log in the plan document and check it before each attempt.

---

## 批注区

**审阅者**: autoresearch audit
**日期**: 2026-03-20

**发现**:
- write-lock.sh 写集合执行缺口是最严重的问题：BATON:GO 存在时完全绕过了写集合检查。新版本已修复并通过实时测试验证。
- quality-gate.sh 缺少 批注区 检查是 constitution 一致性问题，但因写集合授权受阻无法应用修复。
- completion-check.sh 的 ❓ 标记检查缺口直接违反了完成条件 3（"blockers and contradictions closed"）。
- failure-tracker.sh 的消息矛盾属于文档准确性问题，已通过重写消息修复。
- stop-guard.sh 失败边界缺口是架构限制，不是 bug。

**需要人工决策**:
- quality-gate.sh 修复需要扩展写集合或覆盖标记
- 如需更强的失败边界执行，需在 constitution 层面要求 AI 在 plan 文档中维护逐假设失败日志
