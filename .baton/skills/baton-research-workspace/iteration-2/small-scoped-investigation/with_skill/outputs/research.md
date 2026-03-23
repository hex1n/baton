# bash-guard.sh Blocking Logic

## Question

How does bash-guard.sh decide what to block, and what are the current blocking rules? The goal is to understand the logic well enough to diagnose a false positive.

**Sizing**: Small -- single file (`bash-guard.sh`) with one supporting dependency (`common.sh` / `plan-parser.sh`). One question, one verification step (read the code).

## Findings

### Gate Check (lines 23-31 of bash-guard.sh)

Before any command inspection, bash-guard checks whether the "gate is open":

1. Sources `lib/common.sh`, which sources `lib/plan-parser.sh`. Calls `resolve_plan_name` then `find_plan` to locate the active plan file. `find_plan` walks up the directory tree looking for `plan.md` or `plan-*.md` files. It sets `$PLAN` (path), `$PLAN_NAME` (filename), and `$MULTI_PLAN_COUNT`. **`find_plan` also searches `baton-tasks/*/plan.md` and `baton-tasks/*/plan-*.md`.** -- `read plan-parser.sh:56-58`

2. If `$PLAN` is found AND `parser_has_go` returns true (i.e., the plan contains `<!-- BATON:GO -->`), the hook exits 0 immediately -- all commands allowed. `read bash-guard.sh:28-29`

3. **Multi-plan exception**: If multiple active plans are found AND `$BATON_PLAN` env is not set, the gate is treated as closed regardless of whether any plan has BATON:GO. This prevents ambiguous authorization. `read bash-guard.sh:26-27`

4. If `common.sh` is missing entirely, the hook fails open (exit 0). `read bash-guard.sh:15-18`

### Command Extraction (lines 33-51)

The hook reads the command from stdin JSON at `tool_input.command`. It uses `jq` if available, otherwise an `awk` fallback. If no command is found, it exits 0 (allow). `read bash-guard.sh:42-48`

### Quote Stripping (lines 54-86)

Before pattern matching, `strip_quoted_segments()` removes all content inside single and double quotes from the command string, producing `$_SCAN_CMD`. This is critical for false positive prevention: command names mentioned *inside* quotes (like `echo 'cp src dst'`) are stripped away and won't trigger blocking. `read bash-guard.sh:54-92`

### Command Token Detection (lines 96-98)

`_is_cmd_token()` checks if a token appears as a command (at start of line, or after `;`, `&`, `|`, `(`). It also matches path-qualified variants like `/bin/cp`. The regex: `(^|[;&|(]\s*)(/[^ ]*/)?$1(\s|$)`. This runs against `$_SCAN_CMD` (quote-stripped). `read bash-guard.sh:96-98`

### Blocking Rules (Phase-1 Block List, lines 100-152)

When the gate is closed, these patterns cause exit 2 (block):

| Rule | Detection Method | What It Catches |
|------|-----------------|-----------------|
| **Heredoc with redirect** | Regex on `$_SCAN_CMD`: `<<[-]?[[:space:]]*[^>]*>[[:space:]]*[^&[:space:]]` | `cat <<EOF > file.txt`, `python <<'PY' > file.txt` |
| **Output redirection** | `has_output_redirection()` regex: `(^\|[^<])([012]?>>?\|>>?)[[:space:]]*[^&[:space:]]` | `echo x > file`, `cmd 2>> file`, `cmd 1>file` |
| **tee** | `_is_cmd_token 'tee'` | `tee output.txt`, `cat f \| tee out`, `/usr/bin/tee out` |
| **sed -i** | Substring match on `$_SCAN_CMD` | `sed -i 's/a/b/' file` |
| **perl -pi** | Substring match on `$_SCAN_CMD` | `perl -pi -e 's/x/y/' file` |
| **python -c with file write** | `python -c` or `python3 -c` on `$_SCAN_CMD`, then checks raw `$CMD` for `open(` with `'w'` or `'a'` modes | `python -c "open('f','w').write('x')"` |
| **cp** | `_is_cmd_token 'cp'` | `cp src dst`, `/bin/cp a b` |
| **mv** | `_is_cmd_token 'mv'` | `mv old new`, `/usr/bin/mv a b` |
| **install** | `_is_cmd_token 'install'` | `install -m 644 src dst` |
| **truncate** | `_is_cmd_token 'truncate'` | `truncate -s 0 file` |
| **patch** | `_is_cmd_token 'patch'` | `patch -p1 < diff.patch` |

All evidence: `read bash-guard.sh:100-152`.

### Warn-Only Patterns (lines 154-162)

These emit a stderr warning but still exit 0 (allow):

- **rm**: detected via `_is_cmd_token 'rm'`
- **touch**: detected via substring match `*"touch "*` on `$_SCAN_CMD`

Evidence: `read bash-guard.sh:154-162`.

### NOT Blocked (commands that pass through)

Any command not matching the above patterns is allowed. This includes all read-only commands: `ls`, `cat`, `grep`, `git`, `echo` (without redirect), `find`, `head`, `tail`, `wc`, `python -c` (without file write patterns), `mkdir`, `chmod`, etc.

Evidence: `read test-bash-guard.sh:186-198` -- Test 10 explicitly verifies these pass.

## False Positive Surfaces

Based on the blocking logic, the most likely sources of false positives:

1. **Output redirection regex over-matching**: The `has_output_redirection` regex `(^|[^<])([012]?>>?|>>?)[[:space:]]*[^&[:space:]]` could match `>` characters that aren't file redirections (e.g., comparison operators in awk scripts, angle brackets in non-shell contexts). The `[^<]` negative lookbehind only excludes `<<` (heredoc), not other `>` contexts.

2. **`_is_cmd_token` matching substrings in complex commands**: The regex `(^|[;&|(]\s*)(/[^ ]*/)?$1(\s|$)` matches a command name at word boundaries after shell operators. But it could match unintended positions -- e.g., `install` appearing as a subcommand argument (`npm install` would match because `_is_cmd_token` only checks position after `;&|(` or start-of-line -- but `npm install` has `install` after a space, not after a shell operator, so it would NOT match). **However**, `npm install` in a pipe like `echo x | install ...` WOULD match. Also, commands after `&&` are not covered by the regex (it checks `;&|(` but not `&` in `&&`).

3. **Quote stripping limitations**: The character-by-character parser handles `'...'` and `"..."` but does not handle:
   - `$'...'` (ANSI-C quoting)
   - `$"..."` (locale translation)
   - Backtick `` `...` `` command substitution
   - `$(...)` command substitution
   Content inside these constructs is NOT stripped, so command names inside them could trigger false positives.

4. **Heredoc regex**: The heredoc pattern `<<[-]?[[:space:]]*[^>]*>[[:space:]]*[^&[:space:]]` could match strings that happen to contain `<<` followed by `>` but aren't actually heredoc-to-file redirects.

5. **`sed -i` / `perl -pi` substring matching**: These use simple `*"sed -i"*` / `*"perl -pi"*` case patterns on the quote-stripped command. A command like `echo checking sed -ident` (unlikely but possible) would be a false positive. Since quote stripping removes quoted content, `echo "sed -i"` would correctly NOT match.

6. **Multi-plan ambiguity**: If multiple plan files exist (e.g., leftover `plan-*.md` files), the gate may be treated as closed even when one plan has BATON:GO. This is by design but could surprise users who don't realize multiple plans exist. The disambiguation layer (lines 81-96 in plan-parser.sh) tries to resolve by BATON:GO uniqueness, but if 2+ plans have BATON:GO, ambiguity persists.

## Summary

bash-guard.sh is a PreToolUse hook for the Bash tool. It blocks explicit file-write shell patterns (redirects, tee, in-place editors, file mutation commands) when no plan with `<!-- BATON:GO -->` exists. The most actionable surfaces for false positives are: (1) the output redirection regex matching non-redirect `>` characters, (2) command token detection in complex multi-command pipelines, and (3) content inside command substitutions or ANSI-C quotes not being stripped before pattern matching.

## 批注区

<!--
Processing rules:
- Read underlying evidence before responding
- Do not rewrite a challenge into a weaker one
- If accepted: update the relevant section
- If rejected: explain with evidence
- If unresolved: keep as ❓
- Impact = "blocks next phase" → document goes BLOCKED until resolved
-->

<!--
Per annotation, copy this block:

### [Annotation N]
- **Trigger / 触发点**:
- **Intent as understood / 理解后的意图**:
- **Response / 回应**:
- **Status**: ✅ / ❌ / ❓
- **Impact**: none / clarification only / affects conclusions / blocks next phase
-->
