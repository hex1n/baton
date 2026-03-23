# Research: bash-guard.sh Blocking Logic

**Sizing**: Small — single-step verification (read the source, confirm behavior).

## Frame

- **Question**: What rules does bash-guard.sh use to decide whether to block or allow a Bash command?
- **Why**: User is experiencing a false positive (legitimate command being blocked) and needs to understand the decision logic to fix it.
- **Scope**: bash-guard.sh blocking logic, gate detection, pattern matching rules.
- **Out of scope**: Modifying bash-guard.sh, fixing the specific false positive, other hooks.
- **Known constraints**: Windows platform, Git Bash shell, baton hook system.
- **System goal being served**: Enable the user to diagnose and fix a false-positive block.
- **Claimed framing**: "bash-guard blocks commands it shouldn't" — a false positive exists.
- **What must be validated before accepting that framing**: Understand all blocking rules so the false positive can be identified.

## Orient

- **System familiarity**: deep — bash-guard.sh is a 164-line script with clear structure.
- **Evidence type**: codebase-primary
- **Strategy**: Read bash-guard.sh end-to-end, trace the decision flow, catalog every blocking rule and its regex/pattern, then cross-check with the test suite for edge cases.

## Investigation Methods

| Method | What it returned | Independence level |
|--------|-----------------|-------------------|
| Direct source reading of bash-guard.sh | Complete blocking logic, all patterns | strong |
| Test suite reading (test-bash-guard.sh) | 23 test groups confirming expected behavior + edge cases | moderate |

## Investigation

### Move 1: Decision Flow

- **Question**: What is the top-level decision flow for allow vs. block?
- **What was checked**: `bash-guard.sh:1-31` (gate logic), `bash-guard.sh:33-51` (command extraction)
- **What was found**:

The decision flow has three stages:

1. **Gate check** (lines 20-31): Source `common.sh`, call `resolve_plan_name` and `find_plan` to locate the active plan file. If a plan with `<!-- BATON:GO -->` is found, **exit 0 immediately** (allow everything). Exception: if multiple plans exist and `BATON_PLAN` env is not set, treat as gate-closed even if one plan has GO. ✅ read bash-guard.sh:24-30

2. **Command extraction** (lines 33-51): Read stdin JSON, extract `.tool_input.command` via `jq` (or `awk` fallback). If no command found, **exit 0** (allow). ✅ read bash-guard.sh:34-51

3. **Pattern matching** (lines 53-163): Strip quoted segments from the command, then check against block list and warn list. ✅ read bash-guard.sh:54-163

- **Status**: ✅
- **What remains unresolved**: Nothing for this move.

### Move 2: Blocking Rules Catalog

- **Question**: What exact patterns trigger a block (exit 2)?
- **What was checked**: `bash-guard.sh:54-152`
- **What was found**:

**Pre-processing** (line 92): The command is processed through `strip_quoted_segments()` which removes all content inside single and double quotes. The stripped version (`_SCAN_CMD`) is used for most checks. This prevents false positives on commands like `echo 'cp src dst'`. ✅ read bash-guard.sh:54-92

**Helper** `_is_cmd_token()` (lines 96-98): Checks if a token appears as a command name at the start of the line or after `;`, `&`, `|`, or `(`. Also matches path-qualified variants like `/bin/cp`. Pattern: `(^|[;&|(]\s*)(/[^ ]*/)?<token>(\s|$)`. ✅ read bash-guard.sh:96-98

**Block list** (all checked on `_SCAN_CMD` unless noted):

| # | Pattern | Detection method | Blocked label |
|---|---------|-----------------|---------------|
| 1 | Heredoc with redirect: `<<[-]?[space]*[^>]*>[space]*[^&space]` | regex on `_SCAN_CMD` | "heredoc with redirect" |
| 2 | Output redirection: `(^|[^<])([012]?>>?|>>?)[space]*[^&space]` | `has_output_redirection()` regex | "output redirection" |
| 3 | `tee` as a command token | `_is_cmd_token 'tee'` | "tee (write sink)" |
| 4 | `sed -i` anywhere in stripped command | case match on `_SCAN_CMD` | "sed -i (in-place edit)" |
| 5 | `perl -pi` anywhere in stripped command | case match on `_SCAN_CMD` | "perl -pi (in-place edit)" |
| 6 | `python -c` / `python3 -c` with `open(..., 'w')` or `open(..., 'a')` | case match on `_SCAN_CMD` for python, then case match on raw `$CMD` for open patterns | "python -c with file write" |
| 7 | `cp` as a command token | `_is_cmd_token 'cp'` | "cp (file copy)" |
| 8 | `mv` as a command token | `_is_cmd_token 'mv'` | "mv (file move)" |
| 9 | `install` as a command token | `_is_cmd_token 'install'` | "install (file install)" |
| 10 | `truncate` as a command token | `_is_cmd_token 'truncate'` | "truncate" |
| 11 | `patch` as a command token | `_is_cmd_token 'patch'` | "patch (in-place diff application)" |

✅ read bash-guard.sh:100-152

**Warn-only** (exit 0 with stderr warning):

| Pattern | Warning |
|---------|---------|
| `rm` as a command token | "rm detected while plan gate is closed (destructive)" |
| `touch ` in stripped command (case match) | "touch detected while plan gate is closed (allowed)" |

✅ read bash-guard.sh:155-162

- **Status**: ✅
- **What remains unresolved**: Nothing for this move.

### Move 3: False Positive Surfaces

- **Question**: Where could false positives arise from these rules?
- **What was checked**: Regex patterns, `_is_cmd_token` logic, test suite edge cases (test-bash-guard.sh tests 21-23).
- **What was found**:

Known false-positive surfaces:

1. **Output redirection regex** (`has_output_redirection`): The regex `(^|[^<])([012]?>>?|>>?)[[:space:]]*[^&[:space:]]` could match `>` in contexts that aren't file writes. For example, comparison operators or here-strings in certain patterns. ✅ read bash-guard.sh:88-90

2. **`_is_cmd_token` breadth**: Any command containing `cp`, `mv`, `install`, `tee`, `truncate`, or `patch` as a standalone token after a command separator will be blocked, even if the command is read-only usage (e.g., `patch --dry-run`, `install --help`). The regex doesn't check flags. ✅ read bash-guard.sh:96-98, 136-146

3. **`install` false positives**: `npm install`, `pip install`, etc. would be matched by `_is_cmd_token 'install'` since the regex looks for `install` after `;`, `&`, `|`, `(`, or at start. Commands like `npm install` would NOT match because `npm install` has `npm` before `install` without a separator — but `pip install` with a pipe like `yes | install pkg` would. More importantly, standalone `install` in package manager contexts could trigger. ✅ read bash-guard.sh:140-141

4. **`patch` false positives**: `git format-patch` would NOT match (patch isn't at command position). But `patch --check file.patch` (dry-run check) WOULD be blocked. ✅ read bash-guard.sh:144-145

5. **Heredoc regex**: The heredoc pattern `<<[-]?[[:space:]]*[^>]*>[[:space:]]*[^&[:space:]]` could match non-heredoc uses of `<<` if followed by `>`. ✅ read bash-guard.sh:102-103

6. **Quote stripping limitations**: The `strip_quoted_segments` function handles simple quoting but does not handle `$()` command substitution or backtick substitution. A command name inside `$(...)` would still be visible in `_SCAN_CMD`. ✅ read bash-guard.sh:54-86

- **Status**: ✅
- **What remains unresolved**: Which specific false positive the user is hitting (not in scope).

## Counterexample Sweep

- **Leading interpretation**: bash-guard blocks a fixed list of write-pattern commands unless `BATON:GO` is present in the plan, using quote-stripped command text and command-position-aware matching.
- **Disproving evidence sought**: A bypass path that would allow writes even without GO, or a blocking path that doesn't match the catalog above.
- **What was checked**: Searched bash-guard.sh for any `exit 0` or `exit 2` paths not covered in the catalog. Checked for environment variable bypasses (e.g., `SKIP_GUARD`, `BATON_SKIP`). Found none — the only early exits are: (a) missing common.sh → exit 0, (b) gate open → exit 0, (c) empty command → exit 0. ✅ read bash-guard.sh:10-18, 28-29, 51
- **Result**: No disproving evidence found. Active search confirmed.
- **Effect on confidence**: High confidence that the catalog above is complete.

## Self-Challenge

**Q1: Weakest conclusion**:
- **Conclusion**: The `_is_cmd_token` regex correctly limits matching to command position only.
- **Why weakest**: The regex `(^|[;&|(]\s*)(/[^ ]*/)?TOKEN(\s|$)` may have edge cases with complex shell constructs (e.g., `$( )` subshells, `{ }` brace groups, `||` vs `|`).
- **Falsification condition**: If a command like `echo "checking install status"` (after quote stripping yields `echo checking install status`) matched `install` via `_is_cmd_token`, the conclusion would be wrong.
- **Checked for it**: The regex requires `install` to follow `^`, `;`, `&`, `|`, or `(`. In `echo checking install status`, `install` follows a space, not a separator. Confirmed test 22 verifies `echo 'install -m 644 src dst'` is ALLOWED (quote stripping removes the argument). However, `echo checking install status` after quote stripping still contains `install` as a word — but NOT after a separator, so it would not match. ✅ confirmed by regex analysis.

**Q2: What did I NOT investigate that I should have?**
- Did not run the test suite to confirm all tests pass currently (out of scope for understanding logic).
- Did not investigate whether `has_output_redirection` produces false positives with comparison operators like `[[ $x > 5 ]]` (the `[^<]` prefix guard partially handles this but `[[ ]]` syntax was not tested).

**Q3: What assumptions did I make without verifying?**
- Assumed `strip_quoted_segments` works correctly for nested or escaped quotes. The implementation handles backslash-escaping in double quotes but does not handle `$'...'` ANSI-C quoting.

## Self-Review

Checklist applied (fallback — no agent dispatch for Small task):
- [x] Frame matches behavior-neutral question
- [x] Evidence markers on all material claims
- [x] Two investigation methods used (source reading + test suite)
- [x] Counterexample sweep performed with active search
- [x] Self-challenge written with required format

## One-Sentence Summary

"In the context of bash-guard false positives, investigating the blocking logic in bash-guard.sh, I found it uses a two-stage approach (gate check via BATON:GO, then 11 pattern-based block rules on quote-stripped commands) with known false-positive surfaces in command-flag-unaware token matching and output redirection regex, with high confidence, accepting that edge cases in complex shell constructs were not runtime-tested."

## Final Conclusions

**C1**: bash-guard has exactly two modes: gate-open (BATON:GO present → allow all) and gate-closed (check 11 block patterns).
- **Confidence**: high — directly read from source, confirmed by 23 test groups.
- **Evidence**: ✅ bash-guard.sh:24-30, test-bash-guard.sh tests 1, 12, 14.
- **Verification path**: Add `<!-- BATON:GO -->` to plan.md and confirm all commands pass.
- **Uncertainty**: None.
- **Plan implication**: actionable — if false positive occurs with gate open, the issue is in gate detection (plan discovery), not pattern matching.

**C2**: Block patterns are checked on quote-stripped command text, and command-name checks use position-aware matching (`_is_cmd_token`), but they do NOT examine flags.
- **Confidence**: high — ✅ bash-guard.sh:96-98, 114-146.
- **Evidence**: `_is_cmd_token` regex, case-match blocks.
- **Verification path**: Test with `patch --dry-run` or `install --help` — both would be blocked despite being read-only.
- **Uncertainty**: None on the mechanism; specific false positive unknown.
- **Plan implication**: actionable — flag-unaware matching is the most likely source of false positives for commands like `patch --check` or `install --help`.

**C3**: The output redirection regex may produce false positives with comparison operators or other `>` uses that aren't file writes.
- **Confidence**: medium — regex analysis only, not runtime-tested.
- **Evidence**: ✅ bash-guard.sh:88-90 regex: `(^|[^<])([012]?>>?|>>?)[[:space:]]*[^&[:space:]]`.
- **Verification path**: Test `[[ $x > 5 ]]` or `echo $((3 > 2))` against bash-guard.
- **Uncertainty**: Did not enumerate all non-write uses of `>` in bash. ❓
- **Plan implication**: watchlist — check if the user's false positive involves `>` in a non-redirect context.

## Questions for Human Judgment

**Blocks plan** — none (this is understanding-only research).

**Can wait for implementation** — none.

**Out of scope but related**:
- Which specific command is being falsely blocked? Knowing this would immediately narrow the fix to one of the 11 rules or the redirection regex.

**Open unknowns**:
- The specific false positive the user is experiencing: does not block plan (research scope was to understand the logic).

## 批注区

<!--
Processing rules:
- Read underlying evidence before responding
- Do not rewrite a challenge into a weaker one
- If accepted: update the relevant section
- If rejected: explain with evidence
- If unresolved: keep as ?
- Impact = "blocks next phase" -> document goes BLOCKED until resolved
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
