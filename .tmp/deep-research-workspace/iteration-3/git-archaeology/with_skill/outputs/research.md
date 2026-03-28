# Research: write-lock.sh Fail-Open Design History

**Depth**: Standard — spans git history (6+ commits), current code, and design rationale.

## Overview

**write-lock.sh has always failed open on errors.** The fail-open behavior was present from the very first version (v1.0, commit `5bafc84`) and was a deliberate, consistent design choice across all 12+ commits that touched the file. The script has never failed closed on unexpected errors at any point in its history.

However, the story is more nuanced than a simple "always fail-open": the script distinguishes between **error conditions** (fail-open) and **governance decisions** (fail-closed). The fail-open policy applies only to situations where the hook *cannot determine what to do* — not to situations where it *knows the answer is no*.

## Findings

### 1. The Three Eras of write-lock.sh

The file has gone through three major versions across its history:

| Era | Commits | Version | Key characteristics |
|-----|---------|---------|-------------------|
| **v1.0** | `5bafc84` | Original | No trap. Fail-open only on target-resolution failure. `exit 1` for blocks. python3/sed parsing. |
| **v2.0** | `78e42d4` → `697fbbb` | Restructured | Adds explicit `trap` for fail-open. Moves to `.baton/write-lock.sh`. jq/awk parsing replaces python3/sed. `exit 1` for blocks. |
| **v3.0–3.1** | `8aa2597` → current | Hooks architecture | Moves to `.baton/hooks/write-lock.sh`. Sources `_common.sh`/`lib/common.sh`. Adds path canonicalization, governance marker blocking, write-set enforcement. `exit 1` changes to `exit 2` at `668b0c1`. |

### 2. What "Fail-Open" Means — and What It Doesn't

The fail-open policy applies to a specific, bounded set of error conditions:

| Condition | Behavior | Since |
|-----------|----------|-------|
| Cannot determine target file path | `exit 0` + warning | v1.0 (`5bafc84`) |
| Unexpected signal (HUP/INT/TERM) | `exit 0` + warning via `trap` | v2.0 (`78e42d4`) |
| `_common.sh` / `lib/common.sh` not found | `exit 0` + warning | v3.0 (`de3e985`) |

The fail-**closed** behavior applies to all *governance decisions*:

| Condition | Behavior | Exit code |
|-----------|----------|-----------|
| No plan file found | Block | `1` (v1–v3.0) → `2` (v3.1+) |
| Plan exists but no `BATON:GO` marker | Block | `1` → `2` |
| AI trying to add `BATON:GO`/`BATON:OVERRIDE` markers | Block | `2` (added in `bda6737`) |
| File not in approved write set | Block | `2` (added in `394ea3a`) |
| Multiple plan files, ambiguous | Block | `2` (added in `668b0c1`) |

### 3. The v1.0 Implicit Fail-Open (commit `5bafc84`)

The original version had no `trap` statement and no `set -e`. It had exactly one fail-open path:

```bash
# Can't determine target -> fail-open (with warning)
if [ -z "$TARGET" ]; then
    echo "... allowing (fail-open)" >&2
    exit 0
fi
```

Without `set -e`, bash scripts naturally continue on most errors (failed commands return nonzero but execution continues). So the v1.0 script was *implicitly* fail-open for most error classes — e.g., if `python3` or `sed` crashed during target parsing, `$TARGET` would end up empty, and the explicit fail-open check would catch it. (Verified: `5bafc84:write-lock.sh` has no `set -e`, no `trap`, and the target-resolution block uses `2>/dev/null` on all subcommands.)

The comment "fail-open (with warning)" in v1.0 shows this was an intentional design choice from the start, not an accidental default.

### 4. The v2.0 Explicit Fail-Open (commit `78e42d4`)

The v2.0 rewrite made the fail-open policy explicit with a `trap`:

```bash
trap 'echo "... unexpected error, allowing operation (fail-open)" >&2; exit 0' HUP INT TERM
```

This catches signals that could terminate the script unexpectedly. Combined with the existing target-resolution fail-open, this covers two failure modes:
1. **Parsing failures** (target can't be determined) — handled by the `if [ -z "$TARGET" ]` check
2. **Unexpected termination** (signals) — handled by the `trap`

The trap has remained unchanged across every subsequent version. (Verified: identical trap line exists in current `write-lock.sh:14`.)

### 5. The v3.0 Third Fail-Open Path (commit `de3e985`)

When shared functions were extracted to `_common.sh`, a third fail-open path was added:

```bash
if [ -f "$SCRIPT_DIR/_common.sh" ]; then
    . "$SCRIPT_DIR/_common.sh"
else
    echo "... _common.sh not found, allowing operation (fail-open)" >&2
    exit 0
fi
```

This handles the case where the hook infrastructure itself is broken (shared library missing). The rationale is the same: a broken hook system shouldn't block the developer from writing code.

### 6. Exit Code Evolution: `exit 1` to `exit 2`

The blocking exit code changed from `1` to `2` at commit `668b0c1` ("Slim skills, add baton-review, replace archive with COMPLETE lifecycle"). This is a semantic distinction in Claude Code's hook protocol:
- `exit 1` — general failure
- `exit 2` — explicit "block this operation" signal

This change made the blocking *more explicit* to the IDE hook system, not less. It's a protocol refinement, not a change in fail-open/fail-closed philosophy.

### 7. Design Rationale

The fail-open design follows a clear principle visible across the entire commit history: **infrastructure failures must not block the developer; governance decisions must**.

The distinction maps cleanly:

- **"I don't know what file is being written to"** → This is an infrastructure failure (parsing broke, jq missing, stdin malformed). Blocking here would prevent all writes with no clear user action to fix it. Fail open, warn loudly.

- **"I know what file is being written to, and the plan isn't approved"** → This is a governance decision. The user has a clear action (approve the plan). Fail closed.

This is also consistent with the constitution's defense model (`.baton/constitution.md`): "Hooks enforce structure. Review enforces quality. Neither is sufficient alone." The write-lock is a structural enforcement — it catches the common case (writing before planning) but doesn't claim to be a security boundary. The `BATON_BYPASS=1` escape hatch, present since v1.0, confirms this: the lock is a guardrail, not a gate.

## Open Questions

1. **The trap only catches HUP/INT/TERM, not ERR.** If a command inside the script fails after the target is resolved (e.g., `grep` crashes on the plan file), the script could exit with a nonzero code that the IDE interprets as "block." This is a narrow edge case — `grep -q ... 2>/dev/null` suppresses most such failures — but it means the fail-open guarantee is not 100% airtight for all error classes. Whether this matters depends on how the IDE handles unexpected nonzero exit codes from hooks. (Not verified: would need to test specific IDE hook protocol behavior.)

2. **No `set -e` has been intentional.** The absence of `set -e` across all versions is consistent with the fail-open philosophy — `set -e` would cause the script to exit nonzero on any failed command, which would be interpreted as "block." This is an implicit but important part of the fail-open design.

## 批注区
