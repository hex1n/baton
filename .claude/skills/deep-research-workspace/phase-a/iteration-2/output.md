# Write-Lock Enforcement: End-to-End Trace and Deployment Readiness Assessment

## Answer

The write-lock enforcement is architecturally sound for team deployment. It implements defense-in-depth with four enforcement layers, covers all write tool types, fails closed on ambiguity, and fails open only on infrastructure errors (with visible warnings). There are two specific gaps worth noting: governance marker enforcement requires jq (silently skipped without it), and `BATON:COMPLETE` is not blocked from AI insertion by the hook layer. Neither is a deployment blocker, but both should be understood.

---

## End-to-End Enforcement Chain

### Layer 1: IDE Registration (settings.json)

The hook system is registered in `.claude/settings.json` (verified: read settings.json).

**PreToolUse hooks fire for:**
- `Edit|Write|MultiEdit|CreateFile|NotebookEdit` — all file-writing tools
- `Bash` — shell command execution (separate matcher, same dispatch path)

**Registration mechanism:** Each matcher entry calls `.baton/hooks/run-hook.cmd PreToolUse`, which is a polyglot cmd/bash wrapper. On Windows, it locates Git Bash in standard install locations (`C:\Program Files\Git\bin\bash.exe`, `%LOCALAPPDATA%\Programs\Git\bin\bash.exe`, then `PATH`). On Unix, it `exec`s dispatch.sh directly (verified: read run-hook.cmd:43-45).

**Critical design choice:** If no bash is found on Windows, `run-hook.cmd` exits 0 silently (line 40). This means **a Windows machine without Git Bash has no write-lock enforcement**. This is a fail-open design — the comment says "hooks are advisory, not blocking." For team deployment, this means Git Bash is a hard prerequisite on Windows.

### Layer 2: Dispatch (dispatch.sh)

`dispatch.sh` receives the event name, buffers stdin (the JSON payload from Claude Code), extracts `tool_name`, and routes to hooks via `manifest.conf` (verified: read dispatch.sh).

Key behaviors:
- **Manifest routing:** `PreToolUse:Write,Edit,MultiEdit,CreateFile,NotebookEdit:write-lock` routes file-write tools to write-lock.sh. `PreToolUse:Bash:bash-guard` routes Bash to bash-guard.sh. (verified: read manifest.conf:4-5)
- **Stdin buffering:** `BATON_STDIN` is exported so multiple hooks can read the same payload — stdin is consumed once. (dispatch.sh:19-20)
- **Tool name extraction:** Uses jq first, falls back to sed. (dispatch.sh:26-30)
- **Exit code semantics:** Exit 2 = block (first blocking exit wins). Exit 0 = allow. Other exits emit a warning but don't block. (dispatch.sh:54-61)
- **Subshell isolation:** Each hook runs in `( . "$_dir/$_script.sh" )`, isolating exit codes and variable state. (dispatch.sh:52)

### Layer 3: Write-Lock Decision (write-lock.sh)

This is the core enforcement engine. Decision flow:

```
BATON_BYPASS=1? ──yes──> ALLOW (with stderr warning)
    │no
    v
Can determine target path? ──no──> ALLOW (fail-open, stderr warning)
    │yes
    v
Target is *.md/*.mdx? ──yes──> Check governance markers ──found──> BLOCK
    │no                              │not found
    v                                v ALLOW
Find plan file (walk-up)
    │
    v
No plan found? ──yes──> BLOCK ("Complete research first")
    │no
    v
Multiple plans, no BATON_PLAN? ──yes──> BLOCK ("ambiguous")
    │no
    v
Plan has <!-- BATON:GO -->? ──no──> BLOCK ("Annotation cycle in progress")
    │yes
    v
Write-set defined in plan? ──no──> ALLOW (with additionalContext reminder)
    │yes
    v
Target in write-set? ──no──> BLOCK ("not in approved write set")
    │yes
    v
ALLOW (with additionalContext: "Self-check: confirm scope matches plan")
```

### Layer 4: Bash Guard (bash-guard.sh)

Parallel enforcement for shell commands. When the plan gate is closed (no `BATON:GO`), it blocks explicit file-write patterns:

| Pattern | Detection Method |
|---------|-----------------|
| Output redirection (`>`, `>>`) | Regex on quote-stripped command |
| Heredoc with redirect | Regex on quote-stripped command |
| `tee` | Command token check (path-aware) |
| `sed -i`, `perl -pi` | Substring match on stripped command |
| `python -c` with `open('w')` | Substring match on raw command (inside quotes) |
| `cp`, `mv`, `install`, `truncate`, `patch` | Command token check |

When gate is open: always allows. (verified: bash-guard.sh:24-30)

**Quote stripping** (bash-guard.sh:54-86) is notable: it character-walks the command, removing content inside single and double quotes before checking for write patterns. This prevents false positives from strings like `echo "don't use > for redirect"`, but the implementation is a state machine in bash — functional but ~86 lines of logic.

### Layer 5: Post-Write Tracking (post-write-tracker.sh)

Advisory layer (always exits 0). After a write succeeds:
- If the file isn't in the plan's write-set, emits a warning
- Tracks repeat violations per session in `/tmp/baton-writeset-violations-{session_id}`
- Escalates on repeat violations ("scope drift" warning)

This is **not enforcement** — it's detection-after-the-fact. It fires on `PostToolUse`, so the write has already happened.

---

## Edge Case Analysis

### 1. Governance Markers in Content

**What's checked:** When the target is a markdown file, write-lock.sh checks whether the write content contains `<!-- BATON:GO` or `<!-- BATON:OVERRIDE` (verified: write-lock.sh:65-75).

**How it's checked:** Extracts `.tool_input.new_string` (Edit) or `.tool_input.content` (Write) from stdin JSON using jq, then does a bash `case` pattern match.

**Gap: jq required.** The governance marker check is wrapped in `command -v jq >/dev/null 2>&1` (line 65). Without jq, the entire block is skipped — AI could write governance markers into markdown files. The awk fallback in lines 39-45 only covers path extraction, not content extraction.

**Gap: `BATON:COMPLETE` not enforced.** The constitution says "AI may place `BATON:COMPLETE` only after human confirms" (constitution.md, Governance markers section). However, write-lock.sh only blocks `BATON:GO` and `BATON:OVERRIDE` — not `BATON:COMPLETE`. This is a softer invariant (AI may add it conditionally), but the hook doesn't enforce the condition.

**Gap: `baton-tasks/` bypass.** Files under `baton-tasks/` skip the governance marker check entirely (line 62). This is intentional (research/plan documents may reference markers as examples), but means an AI writing to `baton-tasks/topic/plan.md` could embed a BATON:GO marker. However, `baton-tasks/` plans are themselves subject to plan discovery, so this only matters if the AI is writing to a plan file that would later be discovered as the active plan.

**Gap: Bash tool bypass.** The governance marker check only fires for Edit/Write tools targeting markdown. An AI could use `Bash` with `echo '<!-- BATON:GO -->' >> plan.md` to inject markers. Bash-guard blocks output redirection when the gate is closed, but this specific attack vector would require the gate to already be closed (which means no BATON:GO yet). If the gate is open, bash-guard allows everything, but the AI already has write permission in that state. **Net assessment: low risk** — the scenario where this matters (gate open, AI adds GO to a different plan) is contrived.

### 2. Bypass Mode (BATON_BYPASS=1)

Clean implementation (verified: write-lock.sh:17-20):
- Checked immediately, before any other logic
- Emits a visible warning to stderr: `"Write lock bypassed (BATON_BYPASS=1)"`
- Test coverage: Test 8 in test-write-lock.sh verifies both the allow behavior and the stderr warning

Bash-guard does NOT check BATON_BYPASS — it only checks the plan gate. This is consistent: bypass is scoped to the write-lock, not to all governance.

Post-write-tracker checks BATON_BYPASS and skips entirely (post-write-tracker.sh:14), which means bypass mode also suppresses write-set drift warnings.

### 3. jq-less Environments

**Path extraction:** Covered by awk fallback in both write-lock.sh (lines 39-45) and dispatch.sh (lines 28-30, sed fallback). Test 18 in test-write-lock.sh explicitly validates this by constructing a PATH without jq.

**Tool name extraction (dispatch.sh):** Uses sed fallback (line 29). This is critical — without tool name extraction, the manifest matcher can't route events. The sed pattern `s/.*"tool_name" *: *"\([^"]*\)".*/\1/p` handles standard JSON formatting.

**Content extraction for governance markers:** No fallback. Without jq, AI can write governance markers into markdown files unchecked (see Edge Case 1 above).

**Write-set extraction:** Uses awk exclusively (plan-parser.sh:411-428), no jq dependency. Robust.

**Summary table:**

| Function | jq | awk/sed fallback | Risk without jq |
|----------|-----|------------------|-----------------|
| Target path from stdin | Yes | Yes (awk) | None — tested |
| Tool name from stdin | Yes | Yes (sed) | None |
| Governance marker check | Yes | **None** | AI can write BATON:GO/OVERRIDE |
| Write-set extraction | N/A | awk only | None |
| Plan discovery | N/A | grep/ls only | None |
| BATON:GO detection | N/A | grep only | None |

### 4. Multi-Plan Disambiguation

When multiple `plan.md` / `plan-*.md` files exist:

1. **Layer 1:** If exactly one plan has `<!-- BATON:GO -->`, select it (plan-parser.sh:83-96)
2. **Layer 2:** If BATON_TARGET is inside `baton-tasks/<topic>/`, prefer that topic's plan (plan-parser.sh:99-125)
3. **Fallback:** If neither resolves, `MULTI_PLAN_COUNT > 1` triggers a fail-closed block in write-lock.sh:142-146

Test 22 verifies both the blocking behavior and the resolution via `BATON_PLAN`.

### 5. Files Outside Project Root

Files outside the detected project root are always allowed (write-lock.sh:129-131). Project root is determined by walking up from `JSON_CWD` looking for `.baton/`, `.git/`, `.claude/`, etc. markers (plan-parser.sh:234-237).

This means writes to `/tmp/`, other projects, or system files are never blocked. This is correct behavior — write-lock governs project source code, not system operations.

### 6. Path Normalization

`_canonicalize_path()` in write-lock.sh (lines 94-122) handles:
- Absolute paths (preserved)
- Relative paths (resolved against session directory)
- Uses `realpath -m` first (works for non-existent files), falls back to `readlink -f`, then manual parent-dir resolution

`parser_writeset_normalize()` in plan-parser.sh (lines 373-401) handles:
- Leading `./` stripping
- Windows drive letters (`C:/foo`)
- `cygpath` conversion on Windows
- Absolute-to-relative conversion using project root

Test coverage includes: relative paths, `./`-prefixed paths, absolute paths, and empty paths (test-plan-parser.sh, `parser_writeset_normalize` section).

---

## Test Coverage Assessment

| Area | Test File | Assertions | Coverage |
|------|-----------|------------|----------|
| Core write-lock flow | test-write-lock.sh | ~40 | Good: no-plan, plan-no-go, plan-with-go, re-lock, bypass, multi-plan, stdin JSON, walk-up, awk fallback, exit codes, phase guidance messages |
| Write-set primitives | test-plan-parser.sh | ~20 | Good: normalize, extract, contains, edge cases (empty, nonexistent, dedup, annotations) |
| Write-set enforcement in write-lock | test-write-lock.sh | 0 | **Gap: no test for write-set blocking in write-lock.sh itself** |
| Governance marker blocking | test-write-lock.sh | 0 | **Gap: no test verifies markdown governance marker block** |
| Bash-guard patterns | (not checked) | - | Not assessed in this investigation |

The write-set primitives are well-tested in isolation (parser functions), but the integration — write-lock.sh calling `parser_writeset_extract` and blocking on non-membership — has no dedicated test. The code path exists (write-lock.sh:150-161), but if it regressed, no test would catch it.

Similarly, the governance marker block (write-lock.sh:65-75) has no test coverage. This is the marker integrity enforcement.

---

## Deployment Readiness Assessment

### Strengths

1. **Defense in depth:** PreToolUse blocks (write-lock, bash-guard) + PostToolUse detection (post-write-tracker) + advisory quality gate. No single-layer failure defeats the system.

2. **Fail-closed on ambiguity:** Multiple plans without explicit selection = blocked. No plan = blocked. Plan without GO = blocked. These are the correct defaults.

3. **Fail-open only on infrastructure:** Missing common.sh, missing target path, unexpected errors — all fail-open with visible stderr warnings. This prevents the hook system from becoming a productivity blocker when the infrastructure is misconfigured.

4. **Cross-IDE support:** Claude Code (native hooks), Cursor (JSON response adapter), Codex (adapter). The enforcement logic is shared; adapters only translate the protocol.

5. **Write-set enforcement:** When plans include `Files:` fields in `## Todo`, writes are restricted to the declared set. This is the tightest enforcement mode.

6. **Session-persistent violation tracking:** post-write-tracker escalates on repeated out-of-set writes, creating pressure to address scope drift.

### Weaknesses / Risks

| Issue | Severity | Impact | Mitigation |
|-------|----------|--------|------------|
| Governance marker check requires jq | Medium | Without jq, AI can write BATON:GO/OVERRIDE into markdown | Install jq on all dev machines. Add awk fallback for content extraction. |
| No test for write-set blocking integration | Low-Medium | Regression risk on the most precise enforcement layer | Add integration test to test-write-lock.sh |
| No test for governance marker blocking | Low-Medium | Regression risk on marker integrity | Add test with stdin JSON containing BATON:GO in new_string |
| No bash on Windows = no enforcement | Medium | Machines without Git Bash have zero write-lock protection | Document Git Bash as hard prerequisite. Add setup-time check. |
| Cursor adapter: reduced enforcement | Low | Cursor lacks post-write-tracker, stop-guard, completion-check | Documented in adapter.sh:6-10. Team should prefer Claude Code for full enforcement. |
| `BATON:COMPLETE` not hook-enforced | Low | AI could add BATON:COMPLETE without human confirmation | Constitution says "only after human confirms" — this is a softer invariant. Review-layer enforcement is sufficient. |

### Blockers for Team Deployment

**None.** The system is deployment-ready with the following prerequisites:
1. Git Bash installed on all Windows machines
2. jq installed (strongly recommended; enforcement degrades without it)
3. Team understanding that Cursor has reduced enforcement compared to Claude Code

### Recommended Improvements (non-blocking)

1. **Add awk fallback for governance marker content extraction** — eliminates the jq dependency for the marker check (~15 lines of awk to extract `new_string`/`content` from JSON).
2. **Add integration tests for write-set blocking and governance marker blocking** — two gaps in test coverage that protect the most important enforcement paths.
3. **Add a startup check in phase-guide.sh** — warn at SessionStart if jq is not installed, so the team knows enforcement is degraded.

---

## 批注区

