# Security Analysis: Baton Enforcement Model

**Depth: Deep** -- adversarial security analysis with design tension evaluation.

**Scope**: All bypass vectors against write-lock.sh and bash-guard.sh, including
fail-open paths, parser gaps, uncovered tools, environment manipulation, and
architectural boundaries. Distinguishes intentional fail-open (by design) from
genuine gaps. Defines the actual threat model.

---

## Architecture Overview

```
IDE (Claude Code / Cursor / Codex)
 │
 ├── .claude/settings.json ─── Hook registration (matchers + run-hook.cmd)
 │
 └── run-hook.cmd ─── Polyglot (cmd.exe / bash) wrapper
      │
      └── dispatch.sh ─── Event router, reads manifest.conf
           │
           ├── write-lock.sh ─── PreToolUse: Edit|Write|MultiEdit|CreateFile|NotebookEdit
           │    └── lib/common.sh → plan-parser.sh (plan discovery, GO check, write-set)
           │
           ├── bash-guard.sh ─── PreToolUse: Bash
           │    └── lib/common.sh → plan-parser.sh
           │
           ├── post-write-tracker.sh ─── PostToolUse (advisory, exit 0 always)
           ├── quality-gate.sh ─── PostToolUse (advisory)
           ├── completion-check.sh ─── TaskCompleted (blocking)
           └── ... (phase-guide, stop-guard, etc.)
```

**Enforcement boundary**: Only PreToolUse hooks can block (exit 2 = deny tool
invocation). PostToolUse hooks are advisory only (exit 0 always). The defense
model is layered: hooks enforce structure, review enforces quality (per
constitution.md).

---

## Bypass Vectors

### 1. Fail-Open Paths in write-lock.sh (By Design)

These are intentional fail-open behaviors, documented in the code:

**1a. Unexpected error trap** (line 14)
```bash
trap 'echo "...fail-open..." >&2; exit 0' HUP INT TERM
```
- Any signal (HUP/INT/TERM) during execution exits 0 (allow).
- **Severity**: Low. This is defensive design -- a crash should not permanently block the user. The warning is visible on stderr.
- **By design**: Yes. Documented. Tested.

**1b. Empty target path** (lines 49-55)
```bash
if [ -z "$TARGET" ]; then
    echo "...fail-open..." >&2; exit 0
fi
```
- If neither `BATON_TARGET` env var nor stdin JSON `file_path` can be parsed, the write is allowed.
- **Trigger condition**: Malformed or missing JSON from the IDE.
- **Severity**: Low. The AI agent does not control the IDE's JSON format. This protects against IDE bugs or new tool formats, not adversarial agents.
- **By design**: Yes. Explicitly documented and tested (Test 6).

**1c. Missing common.sh** (lines 82-87)
```bash
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    . "$SCRIPT_DIR/lib/common.sh"
else
    echo "...fail-open..." >&2; exit 0
fi
```
- If the shared library is missing (broken installation, junction failure), all writes are allowed.
- **Severity**: Low. Junction failure is a platform issue, not an agent-exploitable vector.
- **By design**: Yes.

**1d. Files outside project root** (lines 129-132)
```bash
case "$TARGET_REAL" in
    "$PROJECT_DIR"|"$PROJECT_DIR"/*) ;;  # inside project, continue
    *) exit 0 ;;                          # outside project, allow
esac
```
- Any write to a path outside the detected project root is unconditionally allowed.
- **Severity**: Medium. The agent could write to `/tmp/malicious.sh` or another project directory without restriction. However, this is intentional -- baton only governs the project it's installed in.
- **By design**: Yes. Baton's scope is the project, not the entire filesystem.

### 2. Fail-Open Paths in bash-guard.sh (By Design)

**2a. Unexpected error trap** (line 11) -- same as write-lock. By design.

**2b. Missing common.sh** (lines 15-19) -- same pattern. By design.

**2c. Empty command** (line 51)
```bash
[ -z "${CMD:-}" ] && exit 0
```
- If command cannot be parsed from stdin JSON, all bash operations are allowed.
- **By design**: Yes. Same rationale as write-lock's empty target.

### 3. BATON_BYPASS Environment Variable (By Design)

```bash
# write-lock.sh:17-19
if [ "${BATON_BYPASS:-}" = "1" ]; then
    echo "...bypassed..." >&2; exit 0
fi
```
- Setting `BATON_BYPASS=1` disables write-lock entirely.
- **Present in**: write-lock.sh, post-write-tracker.sh, completion-check.sh, subagent-context.sh, pre-compact.sh.
- **Notably absent from**: bash-guard.sh. The bash guard has no BATON_BYPASS check. (verified: read bash-guard.sh, no BATON_BYPASS reference)
- **Severity**: Medium. This is an intentional emergency escape hatch. The warning on stderr is visible. However, an AI agent could theoretically set `BATON_BYPASS=1` in its environment before invoking a Bash tool, then use that bash session to modify files. This depends on whether the IDE propagates agent-set env vars to hook subprocesses.
- **By design**: Yes (emergency bypass). But the inconsistency with bash-guard not honoring it is worth noting as a design decision, not a gap.

### 4. Quote Stripping Gaps in bash-guard.sh (Genuine Gap)

bash-guard.sh uses `strip_quoted_segments()` (lines 54-86) to remove quoted content before scanning for write patterns. This is well-implemented with state tracking for single/double quotes and escape handling. However:

**4a. Backtick command substitution**
```bash
`cp src dst`
```
- Backticks are not handled by `strip_quoted_segments()`. Content inside backticks is NOT stripped, so commands within backticks WILL be caught.
- **Result**: This is actually correct behavior -- backtick contents execute, so they should be scanned. Not a gap.

**4b. $() command substitution in quotes**
```bash
echo "$(cp src dst)"
```
- The `cp src dst` is inside double quotes, so `strip_quoted_segments` strips it. The `_SCAN_CMD` won't contain `cp`, so it won't be blocked.
- **Severity**: Medium. An agent that knows the bypass could construct `echo "$(cp src dst)"` to execute a copy while bypassing detection.
- **By design**: Partially. The quote-stripping is designed to prevent false positives on commands like `echo 'cp src dst'` (Test 22 verifies this). The tradeoff is that it also hides genuine writes inside quoted command substitutions.

**4c. Here-string (<<<) without a write command**
```bash
bash <<< 'cp src dst'
```
- The here-string content `cp src dst` is in quotes, so it's stripped. But `bash` as a command isn't on the block list.
- **Severity**: Medium. An agent could invoke a sub-shell via `bash -c 'cp src dst'` -- the `-c` argument content is in quotes and gets stripped.
- **Mitigation**: `bash -c` with write patterns inside the -c argument is a real bypass vector.

**4d. eval with quoted arguments**
```bash
eval 'cp src dst'
```
- `eval` is not on the block list. The `cp src dst` is in single quotes, so it's stripped from `_SCAN_CMD`. `eval` alone doesn't match any block pattern.
- **Severity**: Medium. `eval` is a general-purpose command execution bypass.

**4e. xargs, find -exec, sh -c**
```bash
echo src | xargs -I{} cp {} dst
find . -name '*.bak' -exec rm {} \;
sh -c 'cp a b'
```
- None of `xargs`, `find -exec`, `sh`, or `bash -c` are on the block list.
- **Severity**: Medium. These are indirect write vectors.

### 5. Uncovered Write Mechanisms in bash-guard.sh (Genuine Gap)

The bash-guard block list covers: output redirection (>/>>/heredoc), tee, sed -i, perl -pi, python -c with open(w/a), cp, mv, install, truncate, patch.

**Not covered**:

| Command | Write capability | Severity |
|---------|-----------------|----------|
| `dd` | `dd of=file.txt` -- direct file write | Medium |
| `curl -o` / `wget -O` | Download to file | Medium |
| `git checkout -- file` | Restore file from git | Low |
| `git apply` | Apply a patch | Medium |
| `rsync` | File sync/copy | Medium |
| `ln` / `ln -s` | Create symlinks (indirect FS mutation) | Low |
| `chmod` / `chown` | Metadata mutation | Low |
| `mkdir` | Directory creation | Low (no data) |
| `tar -x` / `unzip` | Extract archives to disk | Medium |
| `npm install` / `pip install` | Package manager writes | Low (outside project usually) |
| `node -e` / `ruby -e` | Scripting language one-liners with file writes | Medium |
| `awk '{print ...}' > file` | awk with redirect (redirect is caught, but awk itself isn't) | Caught by redirect |
| `powershell -c` | Windows PowerShell file operations | Medium (Windows-specific) |

**Severity context**: Most of these are low-probability vectors for an AI agent during normal operation. The AI is more likely to use standard tools (Edit, Write, Bash with cp/mv) than to construct `dd of=file.txt` chains. But an adversarial analysis must note them.

### 6. Tool Coverage Gaps (Genuine Gap)

**6a. MCP tools that write files**

Write-lock hooks into `PreToolUse` for: `Write`, `Edit`, `MultiEdit`, `CreateFile`, `NotebookEdit`.

MCP server tools that might write files (e.g., a filesystem MCP server, or the spawner MCP tools visible in this session) are NOT covered by the matcher. The matcher `Edit|Write|MultiEdit|CreateFile|NotebookEdit` is specific to Claude Code's built-in tools.

- **Severity**: High (if MCP file-write tools are available). An MCP tool could bypass write-lock entirely because its tool name wouldn't match the PreToolUse matcher.
- **Mitigation**: Claude Code's hook system fires PreToolUse for MCP tools too, but only if the matcher includes the MCP tool name. The current matchers are exhaustive for built-in tools but don't cover arbitrary MCP tools.
- **Note**: The manifest.conf uses the same matcher set (`Write,Edit,MultiEdit,CreateFile,NotebookEdit`). Adding a catch-all matcher (`""` in dispatch.sh terms) would make write-lock fire for every tool, which would be noisy and slow.

**6b. NotebookEdit coverage**

`NotebookEdit` is in the manifest.conf matcher but is not separately tested in the test suite. The hook would fire, and write-lock would apply the same logic (check plan GO marker), so this is functionally covered.

### 7. Governance Marker Injection (Partial Coverage)

Write-lock.sh (lines 65-76) blocks AI from writing `<!-- BATON:GO -->` or `<!-- BATON:OVERRIDE -->` into markdown files:

```bash
case "$_new_content" in
    *'<!-- BATON:GO'*|*'<!-- BATON:OVERRIDE'*)
        echo "Blocked: AI must not add governance markers..." >&2
        exit 2
        ;;
esac
```

**Gaps**:

**7a. Only checked when jq is available** (line 65: `command -v jq`)
- If jq is not installed, the governance marker check is entirely skipped. The awk fallback does NOT implement this check.
- **Severity**: Medium. On systems without jq, an AI agent could write `<!-- BATON:GO -->` into a plan file and then immediately write source code.
- **By design**: No. This appears to be an implementation gap -- the awk fallback was written for path parsing but not extended to content inspection.

**7b. Only checks `.tool_input.new_string` and `.tool_input.content`**
- The Edit tool sends `old_string` + `new_string`. The Write tool sends `content`. MultiEdit sends an array of edits. The current check covers Edit's `new_string` and Write's `content`.
- MultiEdit is not checked (its structure is different -- an array of `{old_string, new_string}` pairs).
- **Severity**: Low-Medium. If an AI uses MultiEdit to inject BATON:GO, the check wouldn't fire. However, MultiEdit is rarely used for markdown files.

**7c. Only checks exact marker format**
- `*'<!-- BATON:GO'*` matches the marker with any trailing content (including `-->` or `-->`).
- It would NOT match Unicode homoglyph attacks like `<!-- BAT0N:GO -->` (zero instead of O), but those wouldn't be functional markers either, so this is not a real bypass.

**7d. baton-tasks/ documents are exempted** (lines 61-63)
```bash
case "$TARGET" in
    baton-tasks/*|*/baton-tasks/*) exit 0 ;;
esac
```
- Files in `baton-tasks/` skip the governance marker check entirely. This is by design (these documents may reference governance markers as examples). But it means an AI could write `<!-- BATON:GO -->` into a `baton-tasks/*/plan.md` file.
- **Severity**: Low. The plan discovery system (`parser_find_plan`) searches `baton-tasks/*/plan.md` paths, so a GO marker there IS functional. But this is a narrow edge case requiring: (a) a baton-tasks plan to exist, and (b) the agent to target that specific plan path.
- **By design**: The exemption is by design, but the interaction with plan discovery creating a functional bypass may be unintended.

### 8. Path Traversal / Canonicalization (Mostly Covered)

Write-lock.sh uses `_canonicalize_path()` (lines 94-122) which attempts `realpath -m` or `readlink -f`, with fallbacks. The project root check (line 129) compares the canonicalized target against the project directory.

**8a. Symlink traversal**
- If `realpath` and `readlink` are available, symlinks are resolved. A symlink from inside the project pointing outside would be resolved to the external path and allowed (outside-project check, by design).
- A symlink from outside the project pointing inside would be resolved to the internal path and checked. Correct behavior.
- **Severity**: Low. Covered by canonicalization.

**8b. Case sensitivity on Windows**
- NTFS is case-insensitive but `case` pattern matching in bash is case-sensitive. `PROJECT_DIR="/c/users/hexin/..."` and `TARGET_REAL="/c/Users/hexin/..."` would not match the prefix check.
- **Mitigation**: `realpath -m` on Git Bash / MSYS2 normalizes case. On native Windows paths through cygpath, case is preserved. This is a theoretical edge case.
- **Severity**: Low.

### 9. Race Conditions (Genuine Gap, Low Severity)

**9a. TOCTOU on plan file**
- Write-lock reads the plan file to check for `<!-- BATON:GO -->`, then allows the write. Between the check and the actual file write, the plan could be modified (marker removed). However, this would require a concurrent process modifying the plan, which is unlikely in normal AI agent operation.
- **Severity**: Very Low. The AI agent is single-threaded in its tool invocations; the IDE serializes PreToolUse checks.

**9b. TOCTOU on write-set**
- The write-set is extracted from the plan at check time. If the plan is modified between check and write, the write-set could be stale. Same low probability.
- **Severity**: Very Low.

### 10. Environment Variable Manipulation (Genuine Gap)

**10a. Agent sets BATON_BYPASS=1 via Bash tool**
- An AI agent could run `export BATON_BYPASS=1` in a Bash invocation, but this would not persist -- each hook runs in a subprocess with the environment inherited from the IDE, not from previous Bash tool invocations.
- **Severity**: Very Low. Environment doesn't propagate between tool calls.

**10b. Agent modifies BATON_PLAN to point to a permissive plan**
- If the agent could set `BATON_PLAN=malicious-plan.md` in its env, and `malicious-plan.md` contains `<!-- BATON:GO -->`, write-lock would use that plan.
- Same as above: environment doesn't propagate between tool calls in Claude Code.
- **Severity**: Very Low.

**10c. Agent creates a plan file with BATON:GO**
- The agent could use the Edit/Write tool to create a new `plan.md` containing `<!-- BATON:GO -->`.
- **BLOCKED**: The governance marker injection check (7a above) catches this -- writing `<!-- BATON:GO -->` into any markdown file outside baton-tasks/ is blocked.
- **But**: If jq is not installed, this check is skipped (gap 7a).
- **Severity**: Medium (when jq is absent), Very Low (when jq is present).

### 11. Adapter-Level Bypasses (By Design)

**11a. Codex has no hard gates**
```bash
# codex/dispatch.sh line 12
_TIER_HEADER="[Baton capability: rules + guidance only (Codex)] Hard gates (write-lock, bash-guard) are not available."
```
- Codex adapter explicitly states that write-lock and bash-guard are unavailable. All events exit 0 (line 34: `exit 0`).
- **Severity**: N/A (by design). Codex relies on its own sandbox and human approval controls.
- **By design**: Yes. Explicitly documented in adapter comments.

**11b. Cursor adapter uses legacy adapter.sh**
- The Cursor adapter has both `adapter.sh` (legacy, only runs write-lock) and `dispatch.sh` (newer, routes all events). The `.cursor/hooks.json` registration determines which is used. If the old adapter.sh is registered, bash-guard doesn't fire for Cursor.
- **Severity**: Medium (if misconfigured). The newer dispatch.sh covers all events.
- **By design**: Transitional. Both files exist for backward compatibility.

### 12. run-hook.cmd Fail-Silent on Windows (By Design)

```batch
REM No bash found - exit silently (hooks are advisory, not blocking)
exit /b 0
```
- If no bash executable is found on Windows, the hook exits 0 (allow all writes).
- **Severity**: Low. This is a platform availability issue, not an agent-exploitable vector.
- **By design**: Yes. Documented in the comment.

---

## Bypass Vector Comparison Table

| # | Vector | Type | Severity | By Design? | Mitigated? |
|---|--------|------|----------|------------|------------|
| 1a | Unexpected error trap (write-lock) | Fail-open | Low | Yes | Visible warning |
| 1b | Empty target path | Fail-open | Low | Yes | Visible warning |
| 1c | Missing common.sh | Fail-open | Low | Yes | Visible warning |
| 1d | Files outside project root | Scope boundary | Medium | Yes | By design (project scope) |
| 2a-c | bash-guard fail-open paths | Fail-open | Low | Yes | Same as write-lock |
| 3 | BATON_BYPASS=1 | Emergency bypass | Medium | Yes | Visible warning |
| 4b | `echo "$(cp src dst)"` | Quote stripping | Medium | Partially | False-positive tradeoff |
| 4c | `bash -c 'cp src dst'` | Indirect execution | Medium | No | **Not mitigated** |
| 4d | `eval 'cp src dst'` | Indirect execution | Medium | No | **Not mitigated** |
| 4e | `sh -c`, `xargs`, `find -exec` | Indirect execution | Medium | No | **Not mitigated** |
| 5 | Uncovered commands (dd, curl -o, node -e, etc.) | Block list gap | Medium | Partially | Denylist approach is inherently incomplete |
| 6a | MCP tools that write files | Matcher gap | High | No | **Not mitigated** (if MCP file-write tools exist) |
| 7a | Governance check skipped without jq | Implementation gap | Medium | No | **Not mitigated** |
| 7b | MultiEdit governance check | Implementation gap | Low-Medium | No | Partially (rare for markdown) |
| 7d | baton-tasks/ marker exemption | Design interaction | Low | Partially | Narrow edge case |
| 8b | Case sensitivity on Windows | Platform edge case | Low | Partially | realpath usually normalizes |
| 9 | TOCTOU race conditions | Race condition | Very Low | N/A | IDE serializes tool calls |
| 10 | Env var manipulation by agent | Env isolation | Very Low | N/A | IDE isolates tool env |
| 11a | Codex has no hard gates | Tier design | N/A | Yes | Codex sandbox replaces |
| 12 | No bash on Windows | Platform | Low | Yes | Fail-silent with comment |

---

## Threat Model Analysis

### What Baton IS Defending Against

1. **Premature writes by a cooperative but eager AI agent.** The primary threat model is an AI agent that wants to be helpful and writes source code before the human has approved a plan. The agent is cooperative -- it will respect hook-emitted blocking messages and phase guidance. Write-lock prevents the "eager coder" pattern where the agent jumps to implementation before planning/research is complete.

2. **Scope drift during approved implementation.** Once BATON:GO is set, the write-set enforcement prevents the agent from modifying files outside the approved scope. This catches accidental overreach, not intentional circumvention.

3. **Governance marker self-approval.** The marker injection check prevents the agent from adding `<!-- BATON:GO -->` to its own plan, which would be self-approval -- a violation of the constitution's separation of authority ("AI must never write BATON:GO").

4. **Destructive bash commands without plan approval.** bash-guard catches common write patterns (redirection, cp, mv, sed -i) in shell commands when the plan gate is closed.

### What Baton is NOT Defending Against

1. **A deliberately adversarial AI agent.** Baton's enforcement model assumes a cooperative agent that respects blocking messages. A truly adversarial agent that intentionally constructs bypass commands (`eval 'cp a b'`, `bash -c 'rm -rf /'`, MCP tool abuse) is outside the threat model. As the constitution states: "Hooks enforce structure. Review enforces quality. Neither is sufficient alone." (verified: read constitution.md, Defense Model section)

2. **Attacks through the IDE itself.** The hook system is provided by the IDE (Claude Code, Cursor). If the IDE has a bug that doesn't fire hooks, or if hooks can be disabled in settings, baton has no recourse. Baton trusts the IDE's hook infrastructure.

3. **Writes outside the project root.** By design, baton only governs the project directory. An agent that writes to `/tmp`, `~/.config`, or another project is outside scope.

4. **Post-write reversal.** PostToolUse hooks (post-write-tracker, quality-gate) are advisory only -- they warn but cannot undo writes. If write-lock fails to catch a write, the damage is done.

5. **Human-side attacks.** If the human adds `<!-- BATON:GO -->` to a plan without reading it, baton cannot distinguish informed approval from rubber-stamping. The defense model relies on the human actually performing review.

6. **Network-level exfiltration.** Baton does not monitor or block network operations. An agent could `curl` data to an external server without restriction.

### Design Tensions

**Fail-open vs. Fail-closed**: Baton explicitly chooses fail-open on errors (trap handler, missing target, missing common.sh). The rationale is that a governance tool must not permanently brick the user's workflow. This is the correct choice for a tool that runs as a hook in a developer's IDE -- availability matters more than perfect enforcement. The visible warnings on stderr ensure the human knows enforcement degraded.

**Denylist vs. Allowlist for bash-guard**: bash-guard uses a denylist approach (block known write patterns). An allowlist approach (only allow known-safe patterns) would be more secure but would break legitimate read-only commands that happen to not be on the allowlist. The denylist is intentionally incomplete -- it catches the most common write patterns (>, cp, mv, sed -i, tee, truncate, patch) while allowing the vast majority of legitimate commands. This is a pragmatic tradeoff.

**Quote stripping tradeoff**: The `strip_quoted_segments()` function exists to prevent false positives (blocking `echo 'cp a b'` which is a read-only echo of a string). But it also creates true negatives (allowing `bash -c 'cp a b'` which is a real write). The design chose to minimize false positives at the cost of some bypass vectors, which is consistent with the cooperative-agent threat model.

---

## Contradictions and Tensions

**Tension 1: BATON_BYPASS inconsistency.** write-lock.sh honors `BATON_BYPASS=1` but bash-guard.sh does not. If the intent is an emergency bypass that disables all enforcement, bash-guard should also honor it. If the intent is that bash-guard is harder to bypass, the asymmetry should be documented.

**Tension 2: Governance marker check requires jq.** The header of write-lock.sh documents the awk fallback for path parsing, but the governance marker check (lines 65-76) only runs when jq is available. On systems without jq, the most critical security check (preventing AI self-approval) is silently skipped. The awk fallback should extend to content inspection.

**Tension 3: MCP tool gap contradicts comprehensive matcher list.** The manifest.conf carefully lists all five write tools (`Write,Edit,MultiEdit,CreateFile,NotebookEdit`), suggesting comprehensive coverage is a goal. But MCP file-write tools are completely uncovered. If the project intends to support MCP-heavy workflows, this is a real gap.

---

## Challenge

**Weakest conclusion**: The MCP tool bypass (6a) rated as High severity. This could be overstated if Claude Code does not expose any file-writing MCP tools in practice, or if MCP tools are rare in baton's actual usage context. The severity depends on whether any installed MCP servers provide file-write capabilities.

**What would disprove it**: If Claude Code's PreToolUse hook fires with the original tool name even for MCP tools, and MCP file-write tool names follow a predictable pattern that could be added to the matcher, the gap is addressable. If no MCP file-write tools exist in practice, the gap is theoretical.

**What I skipped**: I did not test the actual behavior of Claude Code hooks with MCP tools (no runtime access). I also did not verify whether Claude Code's hook system itself has bypass mechanisms (e.g., a `--no-hooks` flag).

**Strongest bias risk**: I may be underweighting the bash-guard indirect execution bypasses (4c-4e) by noting the "cooperative agent" threat model. If the threat model should include "confused agent" (agent that uses sub-shells or eval without adversarial intent), these bypasses become more important.

---

## Open Questions

1. **Does Claude Code fire PreToolUse for MCP tool invocations?** If yes, what tool_name does it use? (e.g., `mcp__server__tool` format) This determines whether gap 6a is real.
2. **Can an AI agent influence environment variables seen by subsequent hook invocations?** If yes, BATON_BYPASS manipulation (10a) becomes a real vector.
3. **Should bash-guard honor BATON_BYPASS?** The current inconsistency appears unintentional.
4. **Should the governance marker check have an awk fallback?** The jq dependency for the most critical security check is a real gap on jq-free systems.
5. **How common are `bash -c` / `eval` patterns in AI agent behavior?** If agents frequently use sub-shell invocation, the quote-stripping bypass (4c-4d) is higher priority than rated.
