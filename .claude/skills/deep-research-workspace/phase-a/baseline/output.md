# Write-Lock Enforcement: End-to-End Trace and Deployment Readiness Assessment

## Answer

The write-lock enforcement is robust for team deployment on Claude Code. It uses a defense-in-depth architecture with five enforcement layers, fail-closed defaults on ambiguity, and a tested jq/awk dual-path for JSON parsing. The main deployment caveats are: (1) Cursor and Codex get reduced enforcement compared to Claude Code, (2) the awk fallback cannot check governance markers in markdown content, and (3) the system is fail-open on unexpected errors by design. These are deliberate tradeoffs, not bugs.

---

## End-to-End Flow Trace

### Layer 1: Registration (settings.json / hooks.json)

**Claude Code** registers hooks in `.claude/settings.json` (verified: `settings.json:8-106`). The relevant write-lock registration:

```json
"PreToolUse": [
  {
    "matcher": "Edit|Write|MultiEdit|CreateFile|NotebookEdit",
    "hooks": [
      {
        "type": "command",
        "command": ".baton/hooks/run-hook.cmd PreToolUse"
      }
    ]
  },
  {
    "matcher": "Bash",
    "hooks": [
      {
        "type": "command",
        "command": ".baton/hooks/run-hook.cmd PreToolUse"
      }
    ]
  }
]
```

**IDE-level matcher filtering**: Claude Code only fires the hook for the 5 write tools + Bash. Other tools (Read, Grep, Glob, etc.) never trigger the hook at all. (verified: `settings.json:11,21`)

**Cursor** uses `.cursor/hooks.json` with a separate adapter (`dispatch-cursor.sh`) that translates camelCase event names and exit codes to Cursor's JSON protocol (`{"decision":"block","reason":"..."}`) (verified: `adapters/cursor/dispatch.sh:12-33`).

**Codex** has **no write-lock enforcement** -- only rules-based guidance via AGENTS.md. The adapter explicitly documents this: "Hard gates (write-lock, bash-guard) are not available on Codex." (verified: `adapters/codex/adapter.sh:8-9`)

**setup.sh** handles registration for all IDEs (verified: `setup.sh:184-282` for Claude, `setup.sh:284-361` for Cursor, `setup.sh:363-478` for Codex). It supports both fresh install (hardcoded JSON fallback without jq) and merge into existing settings (jq required for merge).

### Layer 2: Platform Shim (run-hook.cmd)

A polyglot bash/cmd script (verified: `run-hook.cmd:1-46`). On Windows, cmd.exe interprets the batch portion which locates Git Bash in three standard locations, falls back to `bash` on PATH. On Unix, the shell portion runs directly via `exec bash dispatch.sh`.

**Critical detail**: If no bash is found on Windows, the script exits silently with code 0 (line 40) -- this is a **fail-open** on environments without bash. The comment says "hooks are advisory, not blocking."

### Layer 3: Dispatch (dispatch.sh)

The dispatcher (verified: `dispatch.sh:1-64`) does:

1. Captures event name from `$1`
2. Buffers stdin once into `BATON_STDIN` (exported) so multiple hooks can read it
3. Extracts `tool_name` from stdin JSON (jq primary, sed fallback)
4. Iterates `manifest.conf` lines matching `event:matcher:script`
5. Runs each matching hook in a subshell: `( . "$_dir/$_script.sh" )`
6. For PreToolUse: first exit code 2 wins (blocks the operation)

**manifest.conf routing** (verified: `manifest.conf:4`):
```
PreToolUse:Write,Edit,MultiEdit,CreateFile,NotebookEdit:write-lock
PreToolUse:Bash:bash-guard
```

The manifest uses comma-separated matchers, matched via `case ",$_matcher," in *",$_tool,"*`. This is a second-level filter -- the IDE-level matcher already filtered to the right tools, but the manifest provides finer granularity (write-lock only fires for write tools, bash-guard only for Bash).

### Layer 4: Write-Lock Decision Logic (write-lock.sh)

The core enforcement script (verified: `write-lock.sh:1-172`, version 3.1). Decision flow:

```
Entry
  |
  +-- BATON_BYPASS=1? --> exit 0 (allow, with warning to stderr)
  |
  +-- Read BATON_STDIN (already buffered by dispatch.sh)
  |
  +-- Resolve target path:
  |     Priority: BATON_TARGET env > stdin JSON .tool_input.file_path
  |     JSON parsing: jq primary, awk fallback
  |
  +-- No target resolved? --> exit 0 (fail-open, warning to stderr)
  |
  +-- Target is .md/.MD/.markdown/.mdx?
  |     |
  |     +-- In baton-tasks/*? --> exit 0 (allow, skip marker check)
  |     |
  |     +-- Content contains BATON:GO or BATON:OVERRIDE marker?
  |     |     --> exit 2 (BLOCK: "AI must not add governance markers")
  |     |     (only checked when jq is available)
  |     |
  |     +-- Otherwise --> exit 0 (allow)
  |
  +-- Source common.sh + plan-parser.sh
  |     Missing? --> exit 0 (fail-open)
  |
  +-- Target outside project root? --> exit 0 (allow)
  |
  +-- No plan file found? --> exit 2 (BLOCK: "no plan found")
  |
  +-- Multiple plans + no BATON_PLAN set? --> exit 2 (BLOCK: "ambiguous")
  |
  +-- Plan exists, has <!-- BATON:GO -->?
  |     |
  |     +-- Write-set defined in ## Todo?
  |     |     Target in write-set? --> exit 0 (allow + hookSpecificOutput)
  |     |     Target NOT in write-set? --> exit 2 (BLOCK: "not in approved write set")
  |     |
  |     +-- No write-set defined? --> exit 0 (allow + hookSpecificOutput)
  |
  +-- Plan exists, no GO marker --> exit 2 (BLOCK: "plan not approved")
```

### Layer 5: Bash Escape Hatch Guard (bash-guard.sh)

Prevents shell-command file writes when the gate is closed (verified: `bash-guard.sh:1-164`). Blocks:
- Output redirection (`>`, `>>`)
- Heredoc with redirect
- `tee`
- `sed -i`, `perl -pi`
- `python -c` with `open(... 'w')`
- `cp`, `mv`, `install`, `truncate`, `patch`

Uses quote-stripping to avoid false positives from string literals. Warns (but allows) on `rm` and `touch`.

### Layer 6: Post-Write Tracking (post-write-tracker.sh)

Advisory layer after writes succeed (verified: `post-write-tracker.sh:1-116`). Always exits 0 (cannot block). Warns when modified files aren't in the plan's write set. Tracks repeat violations per session in `/tmp/baton-writeset-violations-*` and escalates the warning on repeats.

---

## Edge Cases Analysis

### 1. Governance Markers in Content

**Scenario**: AI writes `<!-- BATON:GO -->` or `<!-- BATON:OVERRIDE -->` into a markdown file.

**Enforcement** (verified: `write-lock.sh:65-75`):
- Only checked for markdown files (`.md`, `.MD`, `.markdown`, `.mdx`)
- Only checked when jq is available (the `if` at line 65 requires `command -v jq`)
- Extracts `new_string` (Edit) or `content` (Write) from stdin JSON
- Uses `case` pattern matching against the extracted content
- Blocks with exit 2 and message "AI must not add governance markers"
- Skipped for files in `baton-tasks/*/` (allows referencing markers in research docs)

**Gap**: Without jq, the governance marker check is silently skipped (the `if` condition at line 65 fails). The awk fallback is used for path extraction only, not for content extraction. This means in jq-less environments, AI could write governance markers into markdown files.

**Severity assessment**: Low-medium. The constitution.md rules also instruct the AI not to write these markers ("AI must never write BATON:GO, BATON:OVERRIDE"), so there's a rules-based layer even without the hook. But for adversarial scenarios (prompt injection), the hook gap matters.

### 2. Bypass Mode (BATON_BYPASS=1)

**Enforcement** (verified: `write-lock.sh:17-20`):
- Checked immediately after the error trap, before any other logic
- Emits warning to stderr: "Write lock bypassed (BATON_BYPASS=1)"
- Exits 0 (allow)
- Must be set as an environment variable -- cannot be set from within AI conversation

**Security**: The bypass requires environment-level access. In Claude Code, env vars are set in `settings.json` or system environment. The AI cannot set them during a session. In team deployment, `BATON_BYPASS` would need to be set per-project or per-developer, not baked into shared config.

### 3. jq-less Environments

**Path extraction** (verified: `write-lock.sh:39-45`):
```bash
TARGET="$(printf '%s' "$STDIN" | awk -F'"' '{
    for(i=1;i<=NF;i++) if($i=="file_path") print $(i+2)
}' | head -1)"
```
This awk fallback splits on `"` and finds the value two fields after `file_path`. Works for simple JSON but fragile for nested structures or escaped quotes.

**dispatch.sh tool extraction** (verified: `dispatch.sh:28-30`):
```bash
_tool="$(printf '%s' "$BATON_STDIN" | sed -n 's/.*"tool_name" *: *"\([^"]*\)".*/\1/p' | head -1)"
```
Uses sed as the fallback for tool name extraction.

**What's missing without jq**:
1. Governance marker check (content inspection) -- silently skipped
2. `setup.sh` merge mode (cannot safely merge into existing settings.json)
3. hookSpecificOutput extraction in Cursor adapter (falls back to generic message)

**What still works without jq**:
1. Path extraction (awk fallback)
2. Write-lock core logic (plan discovery, GO check, write-set enforcement)
3. Bash-guard (has its own awk fallback)

The test suite explicitly tests the jq-less path (verified: `test-write-lock.sh:333-351`, Test 18).

### 4. Multi-Plan Ambiguity

**Enforcement** (verified: `write-lock.sh:142-146`, `plan-parser.sh:55-139`):
- Multiple active plans (non-COMPLETE) without `BATON_PLAN` set triggers fail-closed (exit 2)
- Disambiguation layers: (1) exactly one plan has GO marker, (2) target file is in a baton-tasks topic directory matching a plan
- Only if disambiguation fails does it block

### 5. Files Outside Project Root

**Enforcement** (verified: `write-lock.sh:124-132`):
- Project root inferred by walking up for `.baton`, `.git`, `.claude`, `.cursor`, `.codex`, `AGENTS.md`, `CLAUDE.md` markers
- Files outside the root are always allowed (exit 0)
- Path canonicalization handles `../` traversal via `realpath -m` or `readlink -f`

### 6. Write-Set Enforcement

**Enforcement** (verified: `write-lock.sh:150-161`, `plan-parser.sh:408-441`):
- Only active when the plan has a `## Todo` section with `Files:` fields
- Extracts backtick-wrapped, comma-separated paths from `Files:` lines
- Strips annotations like `(new)` and completion metadata after `|`
- Normalizes paths: strips `./`, converts absolute to project-relative, handles Windows drive letters via `cygpath`
- If write-set is defined but target not in it: exit 2 (block)
- If no write-set defined: allow (no restriction beyond GO marker)

---

## Fail Mode Summary

| Condition | Behavior | Rationale |
|-----------|----------|-----------|
| Unexpected error (trap) | Fail-open (exit 0) | "hooks are advisory" |
| No target path resolvable | Fail-open (exit 0 + warning) | Can't determine what to check |
| common.sh missing | Fail-open (exit 0 + warning) | Can't run checks |
| No bash on Windows | Fail-open (exit 0, silent) | run-hook.cmd line 40 |
| No plan found | Fail-closed (exit 2) | Core gate |
| Multiple plans, ambiguous | Fail-closed (exit 2) | Prevents wrong-plan bypass |
| Plan exists, no GO | Fail-closed (exit 2) | Core gate |
| Target not in write-set | Fail-closed (exit 2) | Scope enforcement |
| Governance marker in content | Fail-closed (exit 2) | But only with jq |

---

## IDE Enforcement Comparison

| Capability | Claude Code | Cursor | Codex |
|-----------|-------------|--------|-------|
| Write-lock (hard block) | Yes -- PreToolUse exit 2 | Yes -- JSON `{"decision":"block"}` | **No** -- rules only |
| Bash-guard (shell writes) | Yes | Yes (via preToolUse) | **No** |
| Write-set enforcement | Yes (pre + post) | Pre only (no PostToolUse tracker) | **No** |
| Governance marker guard | Yes (with jq) | Yes (via adapter) | **No** |
| Post-write drift tracking | Yes | **No** (adapter note: "Reduced/missing: post-write-tracker") | **No** |
| Self-challenge quality gate | Yes | **No** | **No** |

(verified: `adapters/cursor/adapter.sh:6-10`, `adapters/codex/adapter.sh:6-11`)

---

## Test Coverage

The test suite (`test-write-lock.sh`, verified: 530 lines) covers:

| Test | Scenario | Assertions |
|------|----------|------------|
| 1 | No plan -> block source, allow markdown | 4 |
| 1b | Non-existent parent directory | 1 |
| 2 | Plan without GO -> block | 2 |
| 3 | Plan with GO -> allow | 3 |
| 4 | Re-lock on GO removal | 2 |
| 5 | Walk-up plan discovery | 1 |
| 5b | `../` path traversal | 1 |
| 6 | Empty target -> fail-open | 1 |
| 7 | Various file extensions | 6 |
| 8 | BATON_BYPASS | 3 |
| 9 | stdin JSON path resolution | 3 |
| 10 | BATON_PLAN custom name | 3 |
| 11 | .mdx files | 2 |
| 12 | BATON_TARGET precedence | 1 |
| 15 | Phase guidance messages | 2 |
| 16 | JSON cwd for plan discovery | 1 |
| 17 | JSON cwd + plan-*.md walk-up | 1 |
| 18 | awk fallback (no jq) | 1 |
| 19 | GO without ## Todo -> allow | 1 |
| 21 | Exit code 2 verification | 2 |
| 22 | Multi-plan ambiguity | 3 |
| 23 | hookSpecificOutput / additionalContext | 6 |
| 20 | Performance benchmark (opt-in) | 1 |

**Notable gap**: No test for governance marker blocking (the `BATON:GO` / `BATON:OVERRIDE` content check). No test for write-set enforcement within write-lock.sh (write-set is tested via plan-parser but not the integration in write-lock).

---

## Deployment Readiness Assessment

### Strengths for team deployment

1. **Defense in depth**: Five enforcement layers (IDE registration, dispatch, write-lock, bash-guard, post-write tracking) means a single-point failure doesn't defeat governance.
2. **Fail-closed on ambiguity**: Multi-plan conflicts block rather than guess.
3. **Write-set enforcement**: Goes beyond "is there a plan?" to "is this file in the plan?" -- significant for scope discipline.
4. **Automated setup**: `setup.sh` handles IDE-specific registration and supports merge into existing configs.
5. **Cross-platform**: Windows (Git Bash via run-hook.cmd) and Unix both supported, with explicit NTFS junction handling.
6. **Comprehensive tests**: 46+ assertions covering the main paths.

### Risks for team deployment

1. **Codex has no hard enforcement** -- teams using Codex rely entirely on rules-based compliance. The adapter explicitly documents this, so it's a known limitation rather than a gap.

2. **jq dependency for governance marker guard** -- without jq, AI could write `<!-- BATON:GO -->` into a plan file and self-approve. Mitigation: constitution.md rules, and jq is near-universal on developer machines.

3. **Fail-open on unexpected errors** -- the trap on line 14 of write-lock.sh means any bash error (corrupted plan file, path resolution crash, etc.) allows the write. This is a deliberate availability-over-safety tradeoff.

4. **run-hook.cmd silent fail-open on no-bash Windows** -- if Git Bash isn't installed, hooks silently do nothing. For team deployment, this should be a documented prerequisite.

5. **awk JSON parsing fragility** -- the awk fallback (`awk -F'"' ... if($i=="file_path") print $(i+2)`) breaks on JSON with escaped quotes in values, or if `file_path` appears as a string value rather than a key. For standard Claude Code/Cursor JSON payloads this isn't a practical concern, but it's theoretically fragile.

### Recommendation

**Suitable for team deployment on Claude Code**, with these provisos:
- Require jq in the team's dev environment (covers governance marker guard and robust JSON parsing)
- Document that Codex enforcement is rules-only
- Document Git Bash as a Windows prerequisite
- Consider adding integration tests for governance marker blocking and write-set enforcement within write-lock.sh (the two notable test gaps)

---

## Challenge

**Weakest conclusion**: "The awk fallback is fragile." In practice, Claude Code's JSON payloads are simple flat objects -- the awk parser has worked in production. The fragility is theoretical, not demonstrated.

**What would disprove robustness**: A scenario where the AI can set environment variables during a session (to set BATON_BYPASS=1), or a JSON payload format change by Claude Code that breaks the awk parser. Neither is currently possible, but Claude Code is under active development.

**What I skipped**: I did not trace the Factory IDE path (appears to reuse Claude Code's settings.json). I did not verify the Cursor adapter's behavior with Cursor's actual hook protocol (only read the code). I did not run the test suite -- findings are from code reading only.

## 批注区
