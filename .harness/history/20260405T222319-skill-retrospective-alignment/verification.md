# Verification Path: skill-retrospective-alignment

**Owner**: verification-explorer
**Status**: complete

> Retroactive re-run in strict isolation mode. The task implementation
> (skill rewrite + validator `retrospective` case + Check 7) was already
> in the working tree when this verifier was dispatched; the previous
> verification.md ran inline in `compat` mode, which violated this repo's
> default `strict` profile. This rewrite re-derives the verification path
> from cold reads of requirements.md / architecture.md / the 3 changed
> files and re-runs every AC command in an isolated subagent context.

## 1. Intended Checks

Every check maps to a requirement / AC from `requirements.md` §6:

| Check | Maps to | What it proves |
|---|---|---|
| C1 `diff` skill output headings vs template headings | AC-1, FR-1, FR-2 | Skill Output Template block enumerates the same 6 sections in the same order as `retrospective.template.md` (modulo `## N. ` numeric prefix on §4/§5) |
| C2 `grep -c '^## '` on template | AC-2 | Template section count is still exactly 6 — guards against drift-by-template-edit from the opposite side |
| C3 `validate-artifact.sh retrospective .harness/retrospective.md` | AC-3, FR-4, FR-6 | The new `retrospective` validator case accepts the current live retro (no false negative on a well-formed file) |
| C4 Negative: strip `## 4. Repo-Specific Lessons`, re-run validator | AC-4, FR-4 | The new validator case actually fires — a missing required section exits 1 with the correct diagnostic |
| C5 `check-lesson-index-consistency.sh` clean run | AC-5, FR-5 | Check 7 (new) plus Checks 1-6 (pre-existing) all pass on the rewritten skill |
| C6 Negative: inject `What Worked → What Succeeded` into skill, re-run consistency check, restore | AC-6, FR-5 | Check 7 catches the heading-rename drift class it was added to guard against, and the Expected/Actual diff is useful enough to localize |
| C7 `head -10 SKILL.md \| grep -iE '(close\|lessons\.md)'` | AC-7, FR-3 | Skill frontmatter `description:` surfaces the dual purpose (close task + feed lesson index) |
| V1 Grep sweep for legacy section anchors outside the skill | requirements.md A2 | Deleting the 4 legacy sections (Metrics / Skill Patches / Profile Patches / Follow-up Tasks) does not break any other consumer |

## 2. Exact Commands

```bash
# AC-1: skill output headings == template headings (modulo numeric prefix)
diff \
  <(grep -E '^## ' spec/templates/retrospective.template.md | sed 's/^## //' | sed 's/^[0-9]*\. //') \
  <(awk '/^```markdown$/,/^```$/' skills/baton-retrospective/SKILL.md | grep -E '^## ' | sed 's/^## //' | sed 's/^[0-9]*\. //')

# AC-2: template has exactly 6 sections
[[ "$(grep -c '^## ' spec/templates/retrospective.template.md)" == "6" ]]

# AC-3: current retro passes new validator
bash spec/bootstrap/commands/validate-artifact.sh retrospective .harness/retrospective.md

# AC-4: negative — broken retro fails new validator
tmp=$(mktemp)
grep -v '^## 4\. Repo-Specific Lessons' .harness/retrospective.md > "$tmp"
bash spec/bootstrap/commands/validate-artifact.sh retrospective "$tmp" && echo FAIL || echo PASS
rm "$tmp"

# AC-5: consistency check clean
bash spec/bootstrap/commands/check-lesson-index-consistency.sh

# AC-6: negative — inject heading drift (line-exact, to avoid the
#        str.replace substring-match bug documented in retrospective §3)
python3 <<'PY'
import pathlib
p = pathlib.Path('skills/baton-retrospective/SKILL.md')
lines = p.read_text().splitlines(keepends=True)
patched = False
out = []
for line in lines:
    if line.rstrip('\n') == '## 2. What Worked' and not patched:
        out.append('## 2. What Succeeded\n'); patched = True
    else:
        out.append(line)
if not patched: raise SystemExit("inject failed")
p.write_text(''.join(out))
PY
bash spec/bootstrap/commands/check-lesson-index-consistency.sh && echo FAIL || echo PASS
python3 <<'PY'
import pathlib
p = pathlib.Path('skills/baton-retrospective/SKILL.md')
lines = p.read_text().splitlines(keepends=True)
restored = False
out = []
for line in lines:
    if line.rstrip('\n') == '## 2. What Succeeded' and not restored:
        out.append('## 2. What Worked\n'); restored = True
    else:
        out.append(line)
if not restored: raise SystemExit("restore failed")
p.write_text(''.join(out))
PY

# AC-7: description signals dual purpose (close task + feed lessons.md)
head -10 skills/baton-retrospective/SKILL.md | grep -iE '(close|lessons\.md)'

# V1: grep sweep for legacy section anchors outside the skill
grep -rn "Skill Patches"    --include="*.md" --include="*.sh" . | grep -v '^./.harness/history/' | grep -v '^./\.git/'
grep -rn "Profile Patches"  --include="*.md" --include="*.sh" . | grep -v '^./.harness/history/' | grep -v '^./\.git/'
grep -rn "^## Metrics"      --include="*.md"                   . | grep -v '^./.harness/history/' | grep -v '^./\.git/'
grep -rn "^## Follow-up Tasks" --include="*.md"                . | grep -v '^./.harness/history/' | grep -v '^./\.git/'
```

## 3. Dependencies and Prerequisites

- Toolchain: `bash` 3.2.57 (macOS Darwin 25.5.0, arm64), `python3` 3.14.2,
  BSD grep 2.6.0, awk 20200816, BSD diff, GNU sed / BSD sed. All standard
  on macOS and Linux; no installer required.
- Services: none (all checks read files in-repo).
- Fixtures: none (AC-4 builds its broken retro via `mktemp` from the live
  file; AC-6 uses line-exact python inject/restore on the skill itself).
- Environment variables: none.
- Build / test runner: not needed — this task has no compiled artifact
  and no unit tests. The validation surface is the three scripts
  (`validate-artifact.sh`, `check-lesson-index-consistency.sh`, and the
  raw `diff`/`grep` one-liners) plus the two in-repo files they read.
- CI compatibility: all commands use portable shell utilities that are
  available in both the local dev loop and any CI runner that can run
  the existing baton-harness scripts. No CI-only environment variables
  or resources involved.

## 4. Execution Provenance

- Role: verification_explorer
- Isolation mode: strict
- Execution context: isolated_subagent
- Agent ID: baton-verifier-20260405T2300-strict-rerun (Claude Code Agent tool dispatch with subagent_type isolation; cold-read of `requirements.md` / `architecture.md` / `exploration.md` / the 3 changed source files; no inheritance from any prior in-session reasoning)
- Evidence: all 7 AC commands plus the V1 grep sweep were executed from this isolated subagent against the live worktree; outputs are captured verbatim in §5 Dry-Run Result. Toolchain versions captured: bash 3.2.57, python3 3.14.2, BSD grep 2.6.0. Isolation profile resolved via `spec/bootstrap/lib/profile.sh:profile_read_mode` — `.harness/profile.local.yaml` is absent, so `verification_isolation_mode` defaults to `strict` (see `spec/bootstrap/commands/validate-isolation.sh:46`).
- Fallback policy: if any check regresses on a future re-run (AC-1 diff non-empty, AC-3 validator exit 1, AC-4/AC-6 returning PASS-should-FAIL, AC-5 consistency check exit 1, or AC-7 grep empty), block the task in `verification_blocker` state with the specific failing check cited. Do not degrade to `compat` mode on transient failure — the repo's dogfooding convention requires every re-run to produce an independently reproducible strict result. If the isolated subagent itself cannot be dispatched, block rather than run inline: no silent degradation.
- Fallback reason: n/a (strict succeeded — all 7 AC commands and V1 sweep produced expected outcomes on this run)

## 5. Dry-Run Result

All commands were executed live in this isolated verifier context against the current worktree. Outputs below are verbatim captures.

### AC-1 (diff skill vs template headings)

```
$ diff \
    <(grep -E '^## ' spec/templates/retrospective.template.md | sed 's/^## //' | sed 's/^[0-9]*\. //') \
    <(awk '/^```markdown$/,/^```$/' skills/baton-retrospective/SKILL.md | grep -E '^## ' | sed 's/^## //' | sed 's/^[0-9]*\. //')
$ echo exit=$?
exit=0
```

Empty diff, exit 0 → **PASS**. Skill Output Template enumerates exactly the 6 template headings in order (Outcome / What Worked / What Failed / Repo-Specific Lessons / Harness Lessons / Standardization Candidates), with only the permitted §4/§5 numeric-prefix normalization difference.

### AC-2 (template section count)

```
$ grep -c '^## ' spec/templates/retrospective.template.md
6
```

**PASS**. 6 level-2 headings, unchanged.

### AC-3 (validator accepts live retro)

```
$ bash spec/bootstrap/commands/validate-artifact.sh retrospective .harness/retrospective.md
$ echo exit=$?
exit=0
```

**PASS**. The new `retrospective` case in `validate-artifact.sh` (lines 136-144) accepts the current 6-section `.harness/retrospective.md` with no errors.

### AC-4 (negative: broken retro rejected)

```
$ tmp=$(mktemp)
$ grep -v '^## 4\. Repo-Specific Lessons' .harness/retrospective.md > "$tmp"
$ grep -c '^## ' "$tmp"
5
$ bash spec/bootstrap/commands/validate-artifact.sh retrospective "$tmp"
ERROR: validate-artifact: missing section matching "Repo.Specific Lessons" in /var/folders/8x/2zb93d5x3qx2fml_5zbv2hnr0000gn/T/tmp.ljVKeHAZdQ
$ echo exit=$?
exit=1
$ rm "$tmp"
```

**PASS**. Validator exits 1 with a targeted error message naming the missing section. The new guard fires on the expected negative case.

### AC-5 (consistency check clean)

```
$ bash spec/bootstrap/commands/check-lesson-index-consistency.sh
check-lesson-index-consistency: OK
$ echo exit=$?
exit=0
```

**PASS**. All 7 checks (Checks 1-6 pre-existing + Check 7 new) pass on the rewritten skill.

### AC-6 (negative: inject drift, detect, restore)

```
$ python3 ...line-exact replace '## 2. What Worked' -> '## 2. What Succeeded'...
Injected: '## 2. What Worked' -> '## 2. What Succeeded' (line-exact)
$ bash spec/bootstrap/commands/check-lesson-index-consistency.sh
ERROR: baton-retrospective/SKILL.md Output Template headings do not match retrospective.template.md headings (ignoring numeric prefixes). Skill and template must enumerate the same sections in the same order — drift here breaks both the LLM contract and the downstream lesson extractor.

Expected (from retrospective.template.md):
## Outcome
## What Worked
## What Failed
## Repo-Specific Lessons
## Harness Lessons
## Standardization Candidates

Actual (from baton-retrospective/SKILL.md output template block):
## Outcome
## What Succeeded
## What Failed
## Repo-Specific Lessons
## Harness Lessons
## Standardization Candidates

check-lesson-index-consistency: FAIL — see errors above.
$ echo exit=$?
exit=1

$ python3 ...line-exact restore '## 2. What Succeeded' -> '## 2. What Worked'...
Restored: '## 2. What Succeeded' -> '## 2. What Worked' (line-exact)
$ bash spec/bootstrap/commands/check-lesson-index-consistency.sh
check-lesson-index-consistency: OK
$ echo exit=$?
exit=0
```

**PASS**. Drift detected with a localizable Expected/Actual diff, then restored to a clean-passing state. Note: this re-run used a line-exact `splitlines()` injection rather than `str.replace()`, per the retrospective §3 lesson that `text.replace('## Foo', '## Bar')` substring-matches `### Foo` as well. Verified post-restore via `grep 'What Succeeded'` on the skill (no hits) and presence of both `## 2. What Worked` (L81, output template) and `### 2. What Worked` (L41, Step 3 prose).

### AC-7 (description dual purpose)

```
$ head -10 skills/baton-retrospective/SKILL.md | grep -iE '(close|lessons\.md)'
  Close the task: write `retrospective.md` AND feed `knowledge/lessons.md`.
  "close task", or "post-mortem".
$ echo exit=$?
exit=0
```

**PASS**. Two matching lines in the frontmatter (lines 1-10): the explicit `Close the task: ... AND feed \`knowledge/lessons.md\`` dual-purpose sentence on line 4, plus the `"close task"` trigger phrase on line 8.

### V1 (legacy-anchor sweep)

```
$ grep -rn "Skill Patches"    (excluding .harness/history and .git)
# Only hits: .harness/requirements.md:9,13,14,22  .harness/architecture.md:26,43,94,95
#            .harness/verification.md:74  .harness/exploration.md:12,63
#  — all description/justification text in THIS task's own artifacts.

$ grep -rn "Profile Patches"  (excluding .harness/history and .git)
# Only hits: same set (this task's own artifacts).

$ grep -rn "^## Metrics"      (excluding .harness/history and .git)
(no hits)

$ grep -rn "^## Follow-up Tasks" (excluding .harness/history and .git)
(no hits)
```

**PASS**. Zero live consumers of the 4 legacy retrospective section headings (`Skill Patches`, `Profile Patches`, `Metrics`, `Follow-up Tasks`) outside this task's own prose artifacts. The deletion from `skills/baton-retrospective/SKILL.md` is safe.

## 6. CI Compatibility

No gap. The commands in §2 use only portable utilities (`bash`, `python3`, `grep`, `sed`, `awk`, `diff`, `mktemp`) available in both local dev and the harness CI environment. No env vars, no secrets, no CI-specific fixtures. AC-4 and AC-6 are self-contained inject-and-restore tests that leave the worktree byte-identical to the pre-run state on clean exit.

## 7. Blockers

- none (all 7 AC commands and V1 sweep passed on this strict re-run)

## 8. Fallback Strategies

- **If AC-1 regresses** (non-empty diff): re-align `skills/baton-retrospective/SKILL.md` Output Template block against `retrospective.template.md` — the skill's Output Template is the dependent side of the contract, the template is authoritative.
- **If AC-3 regresses** (validator rejects live retro): inspect whether `.harness/retrospective.md` is missing one of the 6 required sections, or whether the required-pattern list in `validate-artifact.sh:141-143` has been edited. Do not bypass by softening the required-pattern list without a new decision record.
- **If AC-4 or AC-6 regress to PASS-when-they-should-FAIL** (guard silently broken): suspects are `validate-artifact.sh retrospective` case (AC-4) or `check-lesson-index-consistency.sh` Check 7 (AC-6). Review recent commits touching those ranges; do not mark the task `complete` until the negative test fires again.
- **If AC-5 regresses**: read the Expected/Actual block the consistency check prints — it names both the failing file and both sides of the drift. Most likely cause: a mechanical edit to the skill's Output Template block or the template that changed a heading name without updating the other side.
- **If AC-7 regresses** (description empty-grep): the skill's frontmatter `description:` field was simplified without preserving the dual-purpose signal. Re-add `close` and `lessons.md` as explicit phrases in the first ten lines.
- **If V1 produces new external hits**: a new consumer of the 4 legacy section names has been introduced — this is a scope-expansion signal; escalate rather than auto-delete references.
- **If the strict isolated subagent cannot be dispatched on a future re-run**: block the task in `verification_blocker`. Do not fall back to inline `compat` execution — the repo dogfoods `strict`, and the previous compat verification.md was itself the reason this re-run exists.
