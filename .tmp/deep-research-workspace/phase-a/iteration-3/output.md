# Write-Lock Enforcement: End-to-End Trace and Deployment Readiness Assessment

## Answer

The write-lock enforcement is robust enough for team deployment on Claude Code, with one significant gap and one known limitation. The enforcement chain is: IDE settings.json registers hooks -> `run-hook.cmd` bridges to bash -> `dispatch.sh` routes events via `manifest.conf` -> `write-lock.sh` (and `bash-guard.sh`) block unauthorized writes with exit code 2. The system is layered, fail-open by design, and tested with 40+ assertions across write-lock and bash-guard tests. The **significant gap** is that governance marker injection checking (preventing AI from writing `BATON:GO` into markdown) silently degrades to no-op without jq. The **known limitation** is that Cursor gets reduced enforcement (no post-write tracking), and Codex gets no hard gates at all.

---

## End-to-End Flow

### Layer 1: Registration (settings.json)

```
.claude/settings.json
```

The hook system registers via Claude Code's native hook protocol (verified: `settings.json:8-106`):

| Event | Matcher | Purpose |
|-------|---------|---------|
| `PreToolUse` | `Edit\|Write\|MultiEdit\|CreateFile\|NotebookEdit` | Write-lock gate |
| `PreToolUse` | `Bash` | Bash-guard gate |
| `PostToolUse` | `Edit\|Write\|MultiEdit\|CreateFile\|NotebookEdit` | Post-write tracking + quality gate |
| `SessionStart` | (all) | Phase guidance injection |
| `Stop` | (all) | Session-end reminders |

All events route to the same entry point: `.baton/hooks/run-hook.cmd <EventName>`.

Claude Code's hook protocol: `PreToolUse` hooks that exit 2 **block the tool call**. Exit 0 allows. This is the hard enforcement mechanism. (verified: Claude Code docs + `dispatch.sh:54-57`)

### Layer 2: Platform Bridge (run-hook.cmd)

```
.baton/hooks/run-hook.cmd
```

This is a **bash/cmd polyglot** (verified: `run-hook.cmd:1-45`):
- **Windows (cmd.exe)**: The `@echo off` block searches for bash in standard Git for Windows locations (`C:\Program Files\Git\bin\bash.exe`, etc.), then falls back to `where bash` on PATH.
- **Unix**: The shell interprets `:` as a no-op, skips the batch block entirely, and runs `exec bash "${SCRIPT_DIR}/dispatch.sh" "$@"`.

**Critical behavior**: If no bash is found on Windows, `run-hook.cmd` exits 0 silently (line 40: `exit /b 0`). This means on a Windows machine without Git Bash, **all hooks fail-open** -- no enforcement at all. This is intentional (hooks are advisory when the runtime isn't available) but must be understood for team deployment.

### Layer 3: Event Dispatch (dispatch.sh)

```
.baton/hooks/dispatch.sh
```

The dispatcher (verified: `dispatch.sh:1-64`):

1. Buffers stdin to `BATON_STDIN` (line 20) so multiple hooks can read the same JSON payload.
2. Extracts `tool_name` from stdin JSON using jq, with sed fallback (lines 25-31).
3. Reads `manifest.conf` line-by-line, matching `event:matcher:script` triples (lines 35-62).
4. Runs each matching hook in a **subshell** (`( . "$_dir/$_script.sh" )`) for isolation.
5. For PreToolUse: **first exit 2 wins** -- once any hook blocks, the final exit is 2 regardless of later hooks.
6. Non-0, non-2 exit codes emit a warning to stderr but don't block (line 60).

The matcher system: `case ",$_matcher," in *",$_tool,"*)` -- this is a comma-delimited substring match. For write-lock, the manifest line is `PreToolUse:Write,Edit,MultiEdit,CreateFile,NotebookEdit:write-lock` (verified: `manifest.conf:4`).

### Layer 4: Write-Lock Decision Logic (write-lock.sh)

```
.baton/hooks/write-lock.sh
```

The decision tree (verified: `write-lock.sh:1-172`):

```
                    START
                      |
              BATON_BYPASS=1? ----yes----> EXIT 0 (allow, warn to stderr)
                      |no
                      |
              Resolve TARGET from
              BATON_TARGET env or
              stdin JSON (.tool_input.file_path)
                      |
              TARGET empty? ----yes----> EXIT 0 (fail-open, warn to stderr)
                      |no
                      |
              TARGET is *.md/*.mdx? ----yes----> Governance marker check
                      |no                          |
                      |                    Content has BATON:GO    ----yes----> EXIT 2 (block)
                      |                    or BATON:OVERRIDE?                   |no
                      |                            |                    EXIT 0 (allow)
                      |
              Source lib/common.sh
              (loads plan-parser.sh)
                      |
              common.sh missing? ----yes----> EXIT 0 (fail-open, warn)
                      |no
                      |
              TARGET outside project root? ----yes----> EXIT 0 (allow)
                      |no
                      |
              resolve_plan_name() + find_plan()
                      |
              PLAN empty (no plan found)? ----yes----> EXIT 2 (block + research guidance)
                      |no
                      |
              Multiple plans + no BATON_PLAN? ----yes----> EXIT 2 (block + ambiguity msg)
                      |no
                      |
              Plan has <!-- BATON:GO -->? ----no----> EXIT 2 (block + annotation guidance)
                      |yes
                      |
              Write-set enforcement:
              Plan has Files: fields?
                      |yes                 |no
              TARGET in write-set? -------> EXIT 0 (allow + additionalContext JSON)
                      |no
              EXIT 2 (block + write-set listing)
```

### Layer 5: Bash Command Guard (bash-guard.sh)

```
.baton/hooks/bash-guard.sh
```

Complements write-lock by catching file writes through the Bash tool (verified: `bash-guard.sh:1-164`):

- **Gate open** (BATON:GO present): all bash commands allowed.
- **Gate closed**: blocks explicit write patterns via quote-stripping + pattern matching.
- Blocked patterns: output redirection (`>`, `>>`), `tee`, `sed -i`, `perl -pi`, `python -c` with file write, `cp`, `mv`, `install`, `truncate`, `patch`, heredoc-to-redirect.
- Warn-only: `rm`, `touch` (exit 0 but emit stderr warning).
- Path-qualified variants caught: `/bin/cp`, `/usr/bin/tee`, etc.
- Quote stripping prevents false positives: `echo 'cp a b'` is allowed.

### Layer 6: Post-Write Tracking (Advisory)

```
.baton/hooks/post-write-tracker.sh
```

PostToolUse hook -- **cannot block** (always exit 0). Provides advisory warnings when:
- Modified file is not in the plan's write-set (`Files:` fields in `## Todo`).
- Tracks repeat violations per session to escalate warnings.
- Falls back to basename grep against plan text when no `Files:` fields exist.

---

## Plan Discovery and GO Marker Mechanics

### Plan Discovery (parser_find_plan)

Verified: `plan-parser.sh:35-140`

1. Walk up from `JSON_CWD` (or shell cwd) looking for plan files.
2. Candidates: `plan.md`, `plan-*.md`, `baton-tasks/*/plan.md`, `baton-tasks/*/plan-*.md`.
3. Filters out `BATON:COMPLETE`-marked plans.
4. **Multi-plan disambiguation**:
   - Layer 1: If exactly one active plan has `BATON:GO`, select it.
   - Layer 2: If `BATON_TARGET` is inside `baton-tasks/<topic>/`, prefer that topic's plan.
   - Else: fail-closed (exit 2, "ambiguous").
5. `BATON_PLAN` env var overrides discovery entirely -- searches for that exact filename.

### GO Marker Check (parser_has_go)

```bash
grep -q '<!-- BATON:GO -->' "$_plan"
```

Simple substring grep. The marker must be exactly `<!-- BATON:GO -->` (HTML comment syntax). Verified: `plan-parser.sh:194-197`.

### Write-Set Enforcement (parser_writeset_extract + parser_writeset_normalize)

Verified: `plan-parser.sh:373-441`

Extracts file paths from `Files:` fields within `## Todo` section items. Handles:
- Backtick-wrapped paths: `` `src/main.sh` ``
- Comma-separated lists
- Annotations like `(new)` stripped
- Completion metadata after `|` stripped
- Leading `./` stripped
- Absolute paths converted to project-relative (Windows cygpath-aware)
- Deduplication via `sort -u`

---

## Edge Cases

### 1. Governance Marker Injection (CRITICAL GAP)

**Code**: `write-lock.sh:65`

```bash
if [ -n "$STDIN" ] && command -v jq >/dev/null 2>&1; then
```

The governance marker check (preventing AI from writing `<!-- BATON:GO -->` or `<!-- BATON:OVERRIDE -->` into markdown files) **requires jq**. There is no awk fallback for this check. Without jq:
- The `if` condition fails silently.
- The markdown file is allowed (exit 0 on line 76).
- AI could write `BATON:GO` into a plan file, then unlock its own writes.

**Severity**: High. This is a self-unlock vector in jq-less environments. The governance marker check is the only hook-level defense against AI placing `BATON:GO` -- the constitution.md prohibits it at the prompt level, but hook enforcement degrades.

**Mitigating factors**:
- The constitution.md explicitly states "AI must never write BATON:GO" (constitution.md, Permissions section) -- this is a prompt-level control that functions independently.
- Most deployment environments have jq available.
- The `baton-tasks/*` exemption (line 62) correctly allows research documents to reference markers as examples without triggering the block.

### 2. Bypass Mode (BATON_BYPASS=1)

**Code**: `write-lock.sh:17-19`

```bash
if [ "${BATON_BYPASS:-}" = "1" ]; then
    echo "Warning: Write lock bypassed (BATON_BYPASS=1)" >&2
    exit 0
fi
```

Clean implementation:
- Checked early (before any parsing).
- Emits a visible warning to stderr.
- Does not suppress the warning (always visible in AI output).
- Exits immediately -- no partial processing.
- Bash-guard does NOT check BATON_BYPASS (it relies on plan GO marker). This means bypass only affects the file-write hook, not the bash-command guard.

**Wait -- is that a gap?** Let me verify:

Bash-guard (`bash-guard.sh:23-31`): checks `parser_has_go()` directly against the plan. It does not check `BATON_BYPASS`. So `BATON_BYPASS=1` would bypass `write-lock.sh` (allowing Edit/Write tools) but NOT bypass `bash-guard.sh` (still blocking `echo > file.txt` via Bash tool if no GO marker).

This is **inconsistent but safe** -- bypass is already an emergency escape, and the inconsistency means bash commands are still gated even under bypass. For team deployment, this is actually conservative.

### 3. jq-less Environments (General)

**Target resolution** (`write-lock.sh:34-46`): Has awk fallback for `file_path` and `cwd` extraction. Tested in test-write-lock.sh Test 18.

**Tool name extraction** (`dispatch.sh:26-31`): Has sed fallback for `tool_name`. This ensures matcher filtering works without jq.

**Bash command extraction** (`bash-guard.sh:42-48`): Has awk fallback for `command` field.

**Governance marker check** (`write-lock.sh:65`): **NO fallback** -- jq only. This is the gap.

**Summary table**:

| Parse operation | jq | Fallback | Tested |
|---|---|---|---|
| `tool_name` (dispatch) | Yes | sed | Implicit |
| `file_path` (write-lock) | Yes | awk | Test 18 |
| `cwd` (write-lock) | Yes | awk | Test 18 |
| `command` (bash-guard) | Yes | awk | Implicit |
| `new_string`/`content` (governance marker check) | Yes | **NONE** | **NOT TESTED** |
| `new_string`/`content` (write-set extract) | N/A (reads file) | awk | Test suite |

### 4. Fail-Open Design

The system is **consistently fail-open** on unexpected errors:

- `write-lock.sh:14`: trap on HUP/INT/TERM -> exit 0 with warning.
- `write-lock.sh:49-55`: empty TARGET -> exit 0 with warning.
- `write-lock.sh:82-87`: missing common.sh -> exit 0 with warning.
- `bash-guard.sh:12`: trap on HUP/INT/TERM -> exit 0 with warning.
- `bash-guard.sh:17-19`: missing common.sh -> exit 0.
- `dispatch.sh:59-61`: non-0/non-2 exit codes -> warning, continue.

This is the correct design for a development tool -- a bug in the hook system should never brick a developer's workflow. But it means the enforcement can silently degrade. The stderr warnings are the signal.

### 5. Windows-Specific Behavior

- `run-hook.cmd:40`: No bash found -> exit 0 silently. **No enforcement at all** on Windows without Git Bash.
- `dispatch.sh:37`: CRLF stripping (`_evt="${_evt%$'\r'}"`) for Windows `core.autocrlf=true`.
- `plan-parser.sh:391-393`: `cygpath` normalization for absolute path comparison on Windows.
- `write-lock.sh:102`: `realpath -m` with `readlink -f` fallback for path canonicalization (both work on Windows Git Bash).

### 6. BATON:COMPLETE Filtering

Completed plans (containing `<!-- BATON:COMPLETE -->` on its own line) are excluded from plan discovery (`plan-parser.sh:65`). This means a completed plan cannot accidentally gate new work -- the lock would require a new plan or removal of the COMPLETE marker.

### 7. Files Outside Project Root

`write-lock.sh:129-131`: Files outside the Baton project root are always allowed. Project root is determined by walking up to find `.baton/`, `.git/`, `.claude/`, etc. markers. This correctly allows writing to temp files, external tools, etc.

### 8. additionalContext Injection

When a write is approved, write-lock emits hookSpecificOutput JSON on stdout (`write-lock.sh:162-164`):
```json
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"Baton: write-set approved. Self-check: confirm scope matches plan before writing."}}
```

This provides a post-unlock nudge even after the gate is open. The Cursor adapter translates this to Cursor's `{"decision":"allow","context":"..."}` format.

---

## IDE Coverage Matrix

| Capability | Claude Code | Cursor | Codex |
|---|---|---|---|
| Write-lock (hard gate) | Full | Via adapter | Not available |
| Bash-guard (hard gate) | Full | Not available | Not available |
| Post-write tracking (advisory) | Full | Not available | Not available |
| Phase guidance (SessionStart) | Full | Full | Via adapter |
| Stop-guard (session end) | Full | Not available | Via adapter |
| Governance marker block | Full (with jq) | Degraded | Not available |

(verified: `cursor/adapter.sh:6-10`, `codex/adapter.sh:6-11`)

For **team deployment**: if the team uses Claude Code, enforcement is full. Cursor gets write-lock via adapter but loses bash-guard and post-write tracking. Codex gets no hard gates -- enforcement is purely prompt-based.

---

## Test Coverage Assessment

| Test file | Assertions | Coverage |
|---|---|---|
| `test-write-lock.sh` | ~45 | Core lock/unlock, bypass, custom plans, stdin JSON, awk fallback, multi-plan, exit codes, additionalContext |
| `test-bash-guard.sh` | ~55 | All blocked patterns, gate open/closed, exit codes, quote stripping, path-qualified commands, multi-plan |
| `test-plan-parser.sh` | ~90+ (full file) | Plan discovery, write-set extract/normalize/contains, TODO parsing, retro validation |

**Gaps in test coverage**:
- No test for governance marker blocking (AI writing `BATON:GO` into markdown content).
- No test for governance marker check degradation without jq.
- No test for `BATON_BYPASS` interaction with bash-guard (verifying bypass does NOT affect bash-guard).
- No test for `run-hook.cmd` bash discovery on Windows (would require mocking `where bash`).

---

## Contradictions and Tensions

### Fail-open vs. Security

The system is consistently fail-open, which is correct for developer experience but creates a tension with the governance model. Any unexpected error in the hook chain silently allows the write. The stderr warnings are the only signal. In a team deployment, if stderr is not monitored or visible, enforcement degradation would be invisible.

### Bypass Inconsistency

`BATON_BYPASS=1` bypasses write-lock but not bash-guard. This is technically an inconsistency but is safe-by-default. A team deploying this should document that bypass only affects the Edit/Write/CreateFile tools, not Bash commands.

### Governance Marker Check jq Dependency

This is the one place where the jq fallback pattern breaks. Every other JSON parsing operation has an awk/sed fallback. The governance marker check does not. This is likely because extracting `new_string` content (which can be multiline, contain special characters, and be deeply nested) is harder to do reliably with awk than extracting a simple field like `file_path`.

---

## Deployment Readiness Assessment

### Blockers for Team Deployment

None that would prevent deployment. The system is functional and well-tested on Claude Code.

### High-Priority Improvements

1. **Add awk fallback for governance marker check** (`write-lock.sh:65`). Without this, jq-less environments have a self-unlock vector. Even a basic pattern match (`grep` for `BATON:GO` in the raw stdin) would be better than no check.

2. **Add `BATON_BYPASS` check to `bash-guard.sh`** for consistency. Currently bypass only affects write-lock, not bash-guard. This creates confusion when a team member sets bypass expecting all enforcement to be suspended.

### Medium-Priority Improvements

3. **Test governance marker blocking** -- this is an untested critical path.

4. **Document IDE-specific enforcement tiers** for the team -- Cursor and Codex have reduced enforcement. Team members on these IDEs need to understand what's covered and what's prompt-only.

5. **Consider fail-closed option** for high-security deployments (`BATON_FAIL_MODE=closed` env var). Some teams may prefer a bricked workflow over silent enforcement degradation.

### What the Assessment Assumes

- Team uses Claude Code as primary IDE (full enforcement).
- Git Bash is available on Windows machines.
- jq is installed (or will be added to team setup requirements).
- Team members understand the plan-based governance model and won't systematically bypass it.
- The prompt-level controls (constitution.md) provide defense-in-depth beyond the hook system alone.

---

## 批注区

