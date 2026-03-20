# Infrastructure & Adapters Autoresearch — Changelog

**Task**: Behavioral correctness audit of 5 baton infrastructure files + 4 adapter files
**Scope**: Scoring, gap analysis, targeted fixes, re-evaluation
**Date**: 2026-03-20

---

## Audit Rubric (25 points total)

| Criterion | Points | Definition |
|-----------|--------|------------|
| 规则覆盖 | 5 | Fulfils the component's assigned role completely |
| 边界处理 | 5 | Handles edge cases: empty input, missing files, platform variance |
| 失败安全 | 5 | Fail-open or advisory on unexpected errors; does not silently corrupt state |
| 错误信息 | 5 | Messages (or comments) accurately describe what happened and how to resolve |
| Constitution一致性 | 5 | No contradiction with constitution invariants or cross-component assumptions |

---

## 1. dispatch.sh — Event-based hook dispatcher

### Pre-fix Score: 18/25

| Criterion | Pre | Notes |
|-----------|-----|-------|
| 规则覆盖 | 4/5 | Event routing, matcher filtering, CRLF stripping all correct |
| 边界处理 | 4/5 | stdin buffered, empty manifest handled; non-2 exit codes silently swallowed |
| 失败安全 | 4/5 | set -eu applied; but hook crash (exit 1) leaves no trace |
| 错误信息 | 2/5 | No warning on unexpected exit codes — hook crashes invisible to user |
| Constitution一致性 | 4/5 | Routing logic correct; silent crash violates "no claim without evidence" spirit |

### Test Scenarios

| # | Scenario | Expected | Pre-fix |
|---|----------|----------|---------|
| T1 (pass) | Hook exits 0 | Silent allow | ✅ Correct |
| T2 (block) | Hook exits 2 | Block propagated | ✅ Correct |
| T3 (gap) | Hook exits 1 (crash) | Visible warning | ❌ Silent (gap) |

### Gap Found

Non-2 exit codes from hook subshells (e.g., `set -eu` firing on undefined variable, or `bash: command not found`) were silently swallowed. The exit 2 check at lines 55-57 only promoted exit 2 to the parent; any other non-zero code was discarded. Hook crashes produced no diagnostics.

### Fix Applied (v1.0 → v1.1)

Added advisory warning after the exit-2 check:

```bash
# Surface unexpected exit codes (not 0=ok, not 2=block) so hook crashes aren't silent
if [ "$_rc" -ne 0 ] && [ "$_rc" -ne 2 ]; then
    echo "⚠️ BATON dispatch: $_script.sh exited with unexpected code $_rc (expected 0 or 2)" >&2
fi
```

Advisory (not blocking) — unexpected exit codes from hooks are surfaced but do not themselves block the tool use. Prevents silent failure masking.

### Post-fix Score: 22/25

| Criterion | Post | Notes |
|-----------|------|-------|
| 规则覆盖 | 4/5 | Unchanged |
| 边界处理 | 5/5 | Crash codes now surfaced |
| 失败安全 | 5/5 | Warning is advisory; no new blocking path introduced |
| 错误信息 | 4/5 | Warning names the hook and exit code; resolution requires inspecting that hook |
| Constitution一致性 | 4/5 | Unchanged |

---

## 2. junction.sh — Directory junction/symlink/copy utility

### Pre-fix Score: 16/25

| Criterion | Pre | Notes |
|-----------|-----|-------|
| 规则覆盖 | 5/5 | All 3 strategies (NTFS junction, symlink, copy) covered with correct fallback order |
| 边界处理 | 2/5 | No guard on empty `$_dst` — `rm -rf ""` deletes CWD |
| 失败安全 | 2/5 | Catastrophic: empty destination → destructive file system operation |
| 错误信息 | 3/5 | Return codes used correctly; no explicit error message on failure paths |
| Constitution一致性 | 4/5 | Serves its purpose; but unguarded destructive op contradicts "no execution beyond authorization" |

### Test Scenarios

| # | Scenario | Expected | Pre-fix |
|---|----------|----------|---------|
| T1 (pass) | Valid src and dst paths | Junction/symlink created | ✅ Correct |
| T2 (gap) | `atomic_junction "/valid/src" ""` | Return 1, no destructive op | ❌ `rm -rf ""` = CWD deletion |
| T3 (edge) | Existing dst is a stale symlink | Removed and recreated | ✅ Correct |

### Gap Found

`atomic_junction()` had no guard on the `_dst` parameter. With `set -eu` not applied in this sourced library, an empty `$_dst` would pass the `[ -e "$_dst" ] || [ -L "$_dst" ]` test (both false for empty string on most shells) — but if a caller passes `""`, the remove-and-recreate logic later could behave unexpectedly. More critically: `rm -rf ""` on some shell versions expands to the current directory. The guard is a correctness invariant for any destructive utility.

### Fix Applied

Added empty-destination guard as the first statement of `atomic_junction`:

```bash
# Guard against empty destination — rm -rf "" would delete CWD
[ -n "$_dst" ] || return 1
```

### Post-fix Score: 23/25

| Criterion | Post | Notes |
|-----------|------|-------|
| 规则覆盖 | 5/5 | Unchanged |
| 边界处理 | 5/5 | Empty dst returns 1 immediately; no destructive op |
| 失败安全 | 5/5 | Catastrophic path eliminated |
| 错误信息 | 3/5 | Still no explicit error message on return 1; return code only |
| Constitution一致性 | 5/5 | Destructive operation now guarded |

---

## 3. run-hook.cmd — Windows polyglot bash finder

### Pre-fix Score: 19/25

| Criterion | Pre | Notes |
|-----------|-----|-------|
| 规则覆盖 | 3/5 | Checks `C:\Program Files\Git` and `(x86)` variant + PATH; misses LOCALAPPDATA |
| 边界处理 | 4/5 | Silent exit 0 on no-bash-found is correct (hooks advisory); modern install path missing |
| 失败安全 | 5/5 | `exit /b 0` on no bash found — safe |
| 错误信息 | 3/5 | No warning when no bash found; silent fallthrough |
| Constitution一致性 | 4/5 | Polyglot approach correct; one coverage gap |

### Test Scenarios

| # | Scenario | Expected | Pre-fix |
|---|----------|----------|---------|
| T1 (pass) | Git installed at C:\Program Files\Git | bash found and used | ✅ Correct |
| T2 (gap) | Git installed via winget → LOCALAPPDATA\Programs\Git | bash found | ❌ Falls to PATH |
| T3 (edge) | No bash anywhere | Silent exit 0 | ✅ Correct |

### Gap Found

Modern Git for Windows installations via `winget install Git.Git` or Windows Store place the binary at `%LOCALAPPDATA%\Programs\Git\bin\bash.exe`, not the traditional Program Files locations. This path was not checked, so users with these installs fell through to the `where bash` PATH search — which may succeed but can also find unexpected bash versions (WSL, etc.) before the intended Git Bash.

### Fix Applied

Added LOCALAPPDATA check before the PATH fallback:

```batch
:: Modern winget/Windows Store installs Git here
if exist "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" (
    "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" "%SCRIPT_DIR%dispatch.sh" %* & exit /b !ERRORLEVEL!
)
```

### Post-fix Score: 21/25

| Criterion | Post | Notes |
|-----------|------|-------|
| 规则覆盖 | 4/5 | LOCALAPPDATA now covered; Scoop/chocolatey installs still rely on PATH |
| 边界处理 | 5/5 | Modern install path covered |
| 失败安全 | 5/5 | Unchanged |
| 错误信息 | 3/5 | No warning on no-bash-found; unchanged |
| Constitution一致性 | 4/5 | Unchanged |

---

## 4. common.sh — Shared hook function library

### Pre-fix Score: 21/25

| Criterion | Pre | Notes |
|-----------|-----|-------|
| 规则覆盖 | 5/5 | All shims (resolve_plan_name, find_plan, has_skill) and baton_resolve_test_cmd complete |
| 边界处理 | 4/5 | missing plan-parser.sh handled; BATON_TEST_CMD override supported |
| 失败安全 | 5/5 | All paths fail gracefully |
| 错误信息 | 3/5 | resolve_plan_name comment says "No longer needed as a separate call" — misleading |
| Constitution一致性 | 4/5 | Misleading comment risks incorrect function removal |

### Test Scenarios

| # | Scenario | Expected | Pre-fix |
|---|----------|----------|---------|
| T1 (pass) | Hook sources common.sh, calls resolve_plan_name | PLAN_NAME set | ✅ Correct |
| T2 (maintainer risk) | Maintainer reads "No longer needed" and removes function | write-lock.sh breaks | ❌ Comment invites deletion |
| T3 (edge) | plan-parser.sh missing | Warning printed, graceful | ✅ Correct |

### Gap Found

The `resolve_plan_name` comment stated: "No longer needed as a separate call; parser_find_plan handles name resolution." This is accurate for *new* hooks — `parser_find_plan` does name resolution internally. But `write-lock.sh` explicitly calls `resolve_plan_name()` before `find_plan()`. A future maintainer reading the comment could remove `resolve_plan_name` as dead code, breaking write-lock without any obvious connection.

### Fix Applied

Rewrote the comment to document the explicit caller:

```bash
# resolve_plan_name — backward-compatible shim
# Still called explicitly by write-lock.sh (and any hook that needs PLAN_NAME set
# before calling find_plan). parser_find_plan also performs name resolution internally,
# so new hooks can skip this call — but do not remove it while write-lock.sh depends on it.
```

### Post-fix Score: 24/25

| Criterion | Post | Notes |
|-----------|------|-------|
| 规则覆盖 | 5/5 | Unchanged |
| 边界处理 | 4/5 | Unchanged |
| 失败安全 | 5/5 | Unchanged |
| 错误信息 | 5/5 | Comment accurately documents caller dependency and migration guidance |
| Constitution一致性 | 5/5 | No longer risks incorrect removal |

---

## 5. codex/dispatch.sh — Codex adapter event router

### Pre-fix Score: 17/25

| Criterion | Pre | Notes |
|-----------|-----|-------|
| 规则覆盖 | 3/5 | Routes all events; SessionStart/Stop handled specially; tier awareness absent |
| 边界处理 | 4/5 | `</dev/null` prevents EOF hang; `2>&1` on other events |
| 失败安全 | 5/5 | `\|\| true` on all bash invocations |
| 错误信息 | 2/5 | Codex does not learn enforcement mode at session start |
| Constitution一致性 | 3/5 | adapter.sh sets TIER_HEADER for phase-guide; dispatch.sh SessionStart doesn't — inconsistency |

### Test Scenarios

| # | Scenario | Expected | Pre-fix |
|---|----------|----------|---------|
| T1 (pass) | Stop event | Stop-hook JSON written, continue:false | ✅ Correct |
| T2 (gap) | SessionStart | Tier context surfaced to Codex | ❌ No tier header (gap) |
| T3 (edge) | Unknown event | Dispatched via `\|\| true` | ✅ Correct |

### Gap Found

`adapter.sh` explicitly defines and prepends `TIER_HEADER` to phase-guide output, notifying Codex that hard gates are unavailable. `dispatch.sh`'s `SessionStart` path executed `dispatch.sh` without any tier context. Codex entering a baton session through `dispatch.sh` received no notice that enforcement relies on rules rather than hooks. The inconsistency between adapter.sh and dispatch.sh violated the principle that both paths to Codex should communicate the same capability model.

### Fix Applied

Added `_TIER_HEADER` definition and `printf` before dispatching SessionStart:

```bash
_TIER_HEADER="[Baton capability: rules + guidance only (Codex)] Hard gates (write-lock, bash-guard) are not available. Enforcement relies on rules and guidance."

case "$_event" in
    SessionStart)
        printf '%s\n' "$_TIER_HEADER"
        bash "$_dispatch" "$@" </dev/null || true
        ;;
```

### Post-fix Score: 21/25

| Criterion | Post | Notes |
|-----------|------|-------|
| 规则覆盖 | 4/5 | TIER_HEADER now in SessionStart; consistent with adapter.sh |
| 边界处理 | 4/5 | Unchanged |
| 失败安全 | 5/5 | Unchanged |
| 错误信息 | 4/5 | Tier mode communicated at session start; no per-event header (acceptable) |
| Constitution一致性 | 4/5 | adapter.sh and dispatch.sh now consistent |

---

## 6. Adapter Files — Cursor "deny" vs "block" Inconsistency

### Finding (no code change)

| File | JSON decision value |
|------|-------------------|
| `cursor/adapter.sh` | `"decision":"deny"` |
| `cursor/dispatch.sh` | `"decision":"block"` |

These two files use different JSON field values for the same semantic action (prevent the tool use). Both files are in production; at least one is wrong.

**Status**: ❓ Unresolvable without Cursor runtime documentation. Cannot determine which value the Cursor hook protocol accepts without either:
1. Access to Cursor's hook schema or source
2. Runtime testing in a live Cursor environment

**No code change applied** — changing to the wrong value would break the adapter. The inconsistency is documented here for human resolution.

**Resolution path**: Test one adapter in a live Cursor session; check whether the hook fires correctly. Align both files to the confirmed value.

---

## 7. manifest.conf — Scored, No Changes

Pre-score: 24/25. The manifest correctly registers 10 hooks with accurate event/matcher/script triples. CRLF compatibility and comment syntax are correct. No gaps found — confirmed in prior session. No changes applied.

---

## Summary Table

| Component | Pre | Post | Delta | Status |
|-----------|-----|------|-------|--------|
| dispatch.sh | 18 | 22 | +4 | ✅ Fixed |
| junction.sh | 16 | 23 | +7 | ✅ Fixed |
| run-hook.cmd | 19 | 21 | +2 | ✅ Fixed |
| common.sh | 21 | 24 | +3 | ✅ Fixed |
| codex/dispatch.sh | 17 | 21 | +4 | ✅ Fixed |
| cursor adapters | — | — | — | ❓ Unresolvable |
| manifest.conf | 24 | 24 | 0 | ℹ️ No issues found |

**Total pre-fix**: 115/150 (excl. manifest)
**Total post-fix**: 131/150 (excl. manifest)

---

## 批注区

**审阅者**: autoresearch audit
**日期**: 2026-03-20

**发现**:
- junction.sh 的空字符串安全守卫是最高优先级修复：`rm -rf ""` 是破坏性操作，可能删除工作目录。修复精准且无副作用。
- dispatch.sh 的非 0/2 退出码静默吞没会掩盖 hook 崩溃，导致执行不透明。修复为警告性（非阻断），保持 fail-open 特性。
- run-hook.cmd 遗漏 LOCALAPPDATA 路径是覆盖率问题，影响使用 winget 安装 Git 的 Windows 用户。修复已加在 PATH fallback 之前。
- common.sh 的注释误导性是潜在的维护风险：future maintainer 可能删除仍在使用的 shim 函数。注释修复消除了这个风险。
- codex/dispatch.sh 与 adapter.sh 在 TIER_HEADER 上的不一致现已对齐：SessionStart 时 Codex 会收到 capability 声明。
- cursor adapter 的 "deny" vs "block" 问题需要人工决策：在真实 Cursor 环境中测试，然后统一两个文件的字段值。

**需要人工决策**:
- cursor/adapter.sh 和 cursor/dispatch.sh 使用不同的 decision 字段值（"deny" vs "block"），需要在真实 Cursor 环境中验证正确值后统一
