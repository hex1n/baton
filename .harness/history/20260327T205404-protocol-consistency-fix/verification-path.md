# Verification Path: protocol-consistency-fix

**Derived from**: `architecture.md` (proposed) + `requirements.md` (approved)
**Status**: `BLOCKER FOUND — cannot proceed to Generator`
**Verifier context**: isolated subagent, no conversation history inherited

---

## 1. Intended Checks

Each of the 8 architecture steps maps to one or more validation checks.

| Step | File Changed | Validation Check | Mechanism |
|------|-------------|-----------------|-----------|
| 1 | `spec/protocol/owners.txt` (new) | File exists, contains exactly 9 tokens | `wc -l`, `cat` |
| 2 | `skills/harness-architect.md:116,143` | No `owner \`verifier\`` remains; `owner \`verification-explorer\`` present | `grep` |
| 3 | `skills/harness-evaluator.md:137` | `eval_round` reference points to State Notes, not table column | `grep` |
| 4 | `spec/templates/task-status.template.md:3-5` | **SEE BLOCKER B-1** — D1 vs FR-2 conflict |  |
| 5a | `spec/bootstrap/start-task.sh:27-35` | Usage text no longer hardcodes owner list (or reads from file) | `grep` |
| 5b | `spec/bootstrap/start-task.sh:99-105` | Whitelist validation uses `grep -Fxq "$owner" owners.txt` | `grep`, dry-run |
| 6 | `spec/bootstrap/start-task.ps1:4` | `ValidateSet` removed; runtime `Get-Content` validation added | `grep` |
| 7 | `spec/bootstrap/check-consistency.sh` (new) | File exists, is executable, runs exit 1 before fixes and exit 0 after | `bash` |
| 8 | `README.md` | Contains `link-skills.sh` usage + `Verifier` -> `verification-explorer` mapping | `grep` |

---

## 2. Commands

All commands run from repo root `/Users/hex1n/IdeaProjects/baton`.

### FR-1 — owner token consistency (Step 2)

```bash
# Before fix — should return lines with 'verifier'
grep 'owner `' skills/harness-architect.md

# After fix — expected: zero results
grep 'owner `verifier`' skills/harness-architect.md
echo "exit: $?"   # expected: 1 (no match = pass)

# After fix — expected: two results
grep 'owner `verification-explorer`' skills/harness-architect.md
echo "exit: $?"   # expected: 0
```

### FR-1 — owners.txt created (Step 1)

```bash
# After fix — file exists
test -f spec/protocol/owners.txt && echo "OK" || echo "MISSING"

# After fix — contains exactly 9 lines
wc -l < spec/protocol/owners.txt   # expected: 9

# After fix — all skill tokens are in owners.txt
while IFS= read -r token; do
  grep -Fxq "$token" spec/protocol/owners.txt || echo "NOT IN owners.txt: $token"
done < <(grep -h 'owner `' skills/harness-*.md | grep -oE '`[^`]+`' | tr -d '`' | sort -u)
```

### FR-1 — whitelist validation works (Step 5b)

```bash
# After fix — 'verifier' must be rejected
bash spec/bootstrap/start-task.sh --task-id test-v --owner verifier --dry-run 2>&1
# expected: "Unsupported owner: verifier", exit 1

# After fix — 'verification-explorer' must be accepted past the whitelist check
# (will then fail on open task guard — that is correct)
bash spec/bootstrap/start-task.sh --task-id test-ve --owner verification-explorer --dry-run 2>&1
# expected: "Cannot start a new task while non-complete task rows exist...", exit 1
# (NOT "Unsupported owner")
```

### FR-2 — schema consistency (Step 4 + Step 5)

**NOTE: Expected values depend on resolution of BLOCKER B-1 (see Section 5).**

```bash
# Current template header
sed -n '3p' spec/templates/task-status.template.md

# Current script write header
grep "printf '| Scope" spec/bootstrap/start-task.sh

# After fix — these two must match (exact string equality)
TEMPLATE=$(sed -n '3p' spec/templates/task-status.template.md)
SCRIPT=$(grep -o "'| Scope.*|'" spec/bootstrap/start-task.sh | tr -d "'")
[ "$TEMPLATE" = "$SCRIPT" ] && echo "MATCH" || echo "MISMATCH: template='$TEMPLATE' script='$SCRIPT'"
```

### FR-3 — eval_round writability (Step 3)

```bash
# Before fix — points to table column
grep 'eval_round' skills/harness-evaluator.md

# After fix — must reference State Notes, not table column
grep 'eval_round' skills/harness-evaluator.md
# expected: zero matches, or matches describing State Notes text update

# After fix — must contain 'Current eval round:' format example
grep 'Current eval round' skills/harness-evaluator.md
# expected: at least one match
```

### FR-4 — link-skills.sh documentation (Step 8)

```bash
# After fix
grep 'link-skills' README.md
# expected: at least one match, exit 0
```

### FR-5 — role name mapping (Step 8)

```bash
# After fix
grep 'verification-explorer' README.md
# expected: at least one match, exit 0
```

### FR-6 — check-consistency.sh (Step 7)

```bash
# After creation — file must exist and be executable
test -x spec/bootstrap/check-consistency.sh && echo "EXECUTABLE" || echo "MISSING OR NOT EXECUTABLE"

# Before other fixes complete — must exit 1
bash spec/bootstrap/check-consistency.sh
echo "exit: $?"   # expected: 1

# After all fixes — must exit 0
bash spec/bootstrap/check-consistency.sh
echo "exit: $?"   # expected: 0
```

### Propagation check (Surface Scan L2 — .claude/skills/ and .agents/)

```bash
# After fix — .claude/skills copies must match skills/
cmp skills/harness-architect.md .claude/skills/harness-architect.md && echo "MATCH" || echo "DIVERGED"
cmp skills/harness-evaluator.md .claude/skills/harness-evaluator.md && echo "MATCH" || echo "DIVERGED"

# After fix — .agents/ copies must match skills/
cmp skills/harness-architect.md .agents/harness-architect.md && echo "MATCH" || echo "DIVERGED"
cmp skills/harness-evaluator.md .agents/harness-evaluator.md && echo "MATCH" || echo "DIVERGED"
```

---

## 3. Dependencies and Prerequisites

| Dependency | Required For | Status |
|-----------|-------------|--------|
| `bash` | All `.sh` commands | Available at `/bin/bash` |
| `grep` | FR-1, FR-3, FR-4, FR-5 | Available at `/usr/bin/grep` |
| `cmp` | FR-6 invariant-3, propagation check | Available at `/usr/bin/cmp` |
| `awk` | check-consistency.sh | Available at `/usr/bin/awk` |
| `wc`, `sed`, `test` | Helper checks | Available (macOS POSIX) |
| `grep -oE` | Token extraction (NOT -oP — macOS grep lacks PCRE) | Verified working |
| `spec/protocol/owners.txt` | Step 5b whitelist validation | Does NOT exist yet (Step 1 must run first) |
| `spec/bootstrap/check-consistency.sh` | FR-6 | Does NOT exist yet (Step 7, runs last) |
| `.harness/` directory | `start-task.sh` execution | Present |
| Active task `protocol-consistency-fix` | blocks `start-task.sh --dry-run` new-task path | Present (expected) |

**Tool note**: macOS `grep` does not support `-P` (PCRE). `grep -oE` with extended regex must be used instead. Verified working for token extraction.

---

## 4. Dry-Run Result (Before-State Baseline)

All commands executed against the unmodified repo at verification time.

### start-task.sh --help

```
Usage:
  start-task.sh --task-id ID [--repo-root PATH] [--owner ROLE] [--state STATE] [--notes TEXT] [--dry-run]

Owners:
  repo-explorer
  scoped-explorer
  specifier
  architect
  verification-explorer
  generator
  reviewer
  evaluator
  human

States:
  exploring
  specifying
  ...
EXIT:0
```

Infrastructure status: WORKING.

### start-task.sh --dry-run (blocked by open task — expected)

```
Cannot start a new task while non-complete task rows exist: protocol-consistency-fix:verification_check
EXIT:1
```

Infrastructure status: WORKING. The script correctly blocks due to the active task row, not a tool failure.

### FR-1 current state (before fix)

```
skills/harness-architect.md:116: Update `task-status.md` -> state `verification_check`, owner `verifier`.
skills/harness-architect.md:144: owner `verifier`.
```

`verifier` token present at lines 116 and 144. Bug confirmed. Fix is a 2-line string replacement.

### FR-2 current state (before fix)

```
Template header (line 3):  | Scope | Owner | State | Eval Round | Updated At | Notes |
Script detect (line 144):  | Scope | Owner | State | Updated At | Notes |
Script write  (line 258):  | Scope | Owner | State | Updated At | Notes |
Result: MISMATCH — template is 6-column, script detects and writes 5-column
```

Bug confirmed. Resolution depends on BLOCKER B-1.

### FR-3 current state (before fix)

```
skills/harness-evaluator.md:136-137: Increment `eval_round` in `task-status.md`.
```

References table column. Bug confirmed. Fix: rewrite line 137 to reference State Notes.

### FR-4 current state (before fix)

```
grep 'link-skills' README.md -> EXIT:1 (no match)
```

Missing. Bug confirmed.

### FR-5 current state (before fix)

```
grep 'verification-explorer' README.md -> EXIT:1 (no match)
grep 'Verifier' README.md -> line 19 match (display name present, no token mapping)
```

Display name present but no `verification-explorer` token mapping. Bug confirmed.

### FR-6 / check-consistency.sh current state (before fix)

```
ls spec/bootstrap/check-consistency.sh -> No such file or directory
```

Does not exist. Expected — this is Step 7 (to be created by Generator).

### owners.txt current state (before fix)

```
ls spec/protocol/owners.txt -> No such file or directory
```

Does not exist. Expected — this is Step 1 (to be created by Generator).

### Propagation current state

```
cmp skills/harness-architect.md .claude/skills/harness-architect.md -> CMP:0 (identical)
cmp skills/harness-evaluator.md .claude/skills/harness-evaluator.md -> CMP:0 (identical)
cmp skills/harness-architect.md .agents/harness-architect.md        -> CMP:0 (identical)
```

All copies currently in sync. After Generator modifies `skills/`, Generator must re-run `sync-skills.sh` (copy mode) to propagate.

### start-task.sh whitelist baseline

```
bash start-task.sh --task-id x --owner verifier --dry-run
-> "Unsupported owner: verifier", EXIT:1   (correct rejection)

bash start-task.sh --task-id x --owner verification-explorer --dry-run
-> "Cannot start a new task while non-complete task rows exist...", EXIT:1
   (passes whitelist, blocked by open task guard — correct)
```

---

## 5. Blockers

### B-1 (CRITICAL): requirements.md FR-2 and architecture.md D1 are contradictory

**Nature**: Specification conflict between two approved/proposed harness artifacts. This is NOT a tool infrastructure failure.

**requirements.md FR-2** explicitly states:
> `start-task.sh` and `start-task.ps1` must read and write the **6-column format**:
> `| Scope | Owner | State | Eval Round | Updated At | Notes |`

**requirements.md AC-2** explicitly states:
> After `start-task.sh` runs, the generated Header must be:
> `| Scope | Owner | State | Eval Round | Updated At | Notes |`

**requirements.md Constraint (line 138)** explicitly states:
> Do not modify `task-status.template.md` (it is already the correct 6-column format)

**architecture.md D1** states:
> Completely delete the Eval Round column.
> The fix is: modify the template to 5-column, script requires no changes.

These two documents define incompatible implementations. The Generator cannot write correct code without a definitive answer:

1. **If D1 wins (5-col)**: `task-status.template.md` line 3-5 changes to remove Eval Round. `start-task.sh` is unchanged for schema. requirements.md FR-2, AC-2, and Constraint must be updated to reflect 5-column reality.

2. **If FR-2 wins (6-col)**: architecture.md D1 decision is reversed. `start-task.sh` lines 144, 153, 258-259 must be upgraded to detect and write 6-column format including Eval Round. `start-task.ps1` line 193 similarly upgraded. `task-status.template.md` is unchanged. This is the larger code change.

check-consistency.sh invariant-2 also depends on this decision (expected header value differs).

**Decision needed from human**: Which document takes precedence?

### B-2 (DEPENDENT on B-1): check-consistency.sh invariant-2 expected value is undefined

check-consistency.sh invariant-2 checks:
> "start-task.sh 写出的 Header 与 task-status.template.md Header 一致"

The structural check is feasible, but the expected canonical value cannot be defined until B-1 is resolved.

---

## 6. Fallback Strategies

### For B-1 and B-2 (specification conflict — primary path)

**Preferred resolution**: Human reads B-1, confirms which artifact wins, updates the losing artifact. Re-dispatch Generator after update.

**Fallback A — "5-col wins, follow D1"** (simpler code change):
- Update requirements.md FR-2, AC-2, and Constraint section to state 5-column format
- Generator proceeds with template change only; `start-task.sh` schema unchanged
- check-consistency.sh invariant-2 compares against `| Scope | Owner | State | Updated At | Notes |`

**Fallback B — "6-col wins, follow FR-2"** (larger code change, preserves approved requirements):
- Update architecture.md D1 to reflect that start-task scripts are upgraded to 6-column
- Generator modifies `start-task.sh` lines 144, 153, 251, 258-259 (detect + write 6-col with Eval Round `—`)
- Generator modifies `start-task.ps1` line 193 (write 6-col)
- `task-status.template.md` is NOT touched
- check-consistency.sh invariant-2 compares against `| Scope | Owner | State | Eval Round | Updated At | Notes |`

### For steps independent of B-1

Steps 1, 2, 3, 6, 8 (owners.txt creation, architect token fix, evaluator eval_round fix, ps1 ValidateSet removal, README updates) are not affected by B-1. They could be generated while B-1 is being resolved. However, to avoid partial-state confusion, the recommended default is to block until B-1 is resolved before any generation begins.

### If bash is unavailable

Not applicable — bash confirmed available at `/bin/bash` on macOS 25.4.0.

### If .harness/ is missing

Not applicable — `.harness/` directory and all existing artifacts are present.

---

## Summary

**Gate 3 verdict**: BLOCKED

The verification infrastructure is fully sound. All tools (`bash`, `grep`, `cmp`, `awk`) are available. All validation commands are structurally executable. The before-state baseline has been recorded for all six functional requirements.

The blocker is a specification contradiction:

| | requirements.md (approved) | architecture.md D1 (proposed) |
|-|---------------------------|-------------------------------|
| Eval Round column | KEEP (6-col mandatory) | DELETE (5-col, template change only) |
| template.md action | no change | modify to 5-col |
| start-task.sh action | upgrade to write 6-col | no schema change needed |

**Human decision required before Generator is dispatched.**

Unblocked paths (all clear, no issues found):
- FR-1: owners.txt creation + token replacement in harness-architect.md
- FR-3: eval_round rewrite in harness-evaluator.md
- FR-4: README link-skills.sh documentation
- FR-5: README role name mapping
- FR-6 invariant-1: skills token vs owners.txt check (logic confirmed feasible with `grep -oE`)
- FR-6 invariant-3: skills vs .claude/skills vs .agents propagation check (cmp confirmed working)
- Propagation: copy mode confirmed; sync-skills.sh exists and must be run post-generation
