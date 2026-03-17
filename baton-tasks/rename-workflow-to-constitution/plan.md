# Plan: workflow.md → constitution.md

**Complexity**: Small-Medium (many files, mechanical rename)
**State**: COMPLETE

## Requirements

- [HUMAN] Rename `.baton/workflow.md` → `.baton/constitution.md`
- [HUMAN] Change title "Baton Workflow — Constitutional Protocol" → "Baton Constitution"
- Historical/archival files (plans/, baton-tasks/) are not changed
- Generic "workflow" references (meaning general process, not the file) are not changed

## First Principles

**Problem**: The file `.baton/workflow.md` defines cross-phase invariants (authority, permissions, evidence, state, completion models). Its name "workflow" implies step-by-step process, but the file explicitly disclaims that role. The title's "Constitutional Protocol" half already names it correctly.

**Constraints**:
- setup.sh has dead migration logic for already-removed `workflow-full.md`; should be replaced with `workflow.md → constitution.md` migration
- Test assertions are tightly coupled to the filename
- CI job names reference the filename
- Backward compatibility for already-installed projects

**Solution categories**:
1. **Pure rename** — change filename everywhere, add migration path in setup.sh
2. **Symlink** — keep both names, old pointing to new → rejected: adds complexity, doesn't solve the naming problem
3. **Alias in code** — keep old filename, just change title → rejected: doesn't fix the core confusion

**Evaluation**: Category 1 is the only one that solves the problem cleanly. setup.sh already has precedent for migration (workflow-full → workflow), so the pattern is established.

## Surface Scan

All rows below are evidence-based from grep/glob results earlier in this conversation.

| File | Level | Disposition | Evidence |
|------|-------|-------------|----------|
| `.baton/workflow.md` | L1 | rename + edit title + self-reference on line 47 | [CODE] `.baton/workflow.md:47` |
| `CLAUDE.md` | L1 | modify: `@.baton/workflow.md` → `@.baton/constitution.md` | [CODE] `CLAUDE.md:1` |
| `README.md` | L1 | modify: ~5 `workflow.md` references | [CODE] `README.md:48,139,156,157` |
| `setup.sh` | L1 | modify: ~15 references + add migration path | [CODE] `setup.sh:1250-1521` |
| `.baton/hooks/failure-tracker.sh` | L1 | modify: `workflow.md rule 5` → `constitution.md rule 5` | [CODE] `failure-tracker.sh:54` |
| `.baton/skills/baton-research/SKILL.md` | L1 | modify: `workflow.md defines...` → `constitution.md defines...` | [CODE] `baton-research/SKILL.md:23` |
| `tests/test-workflow-consistency.sh` | L1 | rename → `test-constitution-consistency.sh` + update internal refs (~30) | [CODE] throughout |
| `tests/test-setup.sh` | L1 | modify: ~20 `workflow.md` assertions | [CODE] throughout |
| `.github/workflows/ci.yml` | L2 | modify: job name + test script reference | [CODE] `ci.yml:80-85` |
| `.baton/skills/baton-plan/SKILL.md` | L2 | skip: "workflow" means general process, not file | [CODE] lines 32, 118, 151 — all generic |
| `.baton/skills/baton-review/SKILL.md` | L2 | skip: "workflow" means general process | [CODE] line 166 — generic |
| `plans/*.md` | L2 | skip: historical archives | no live references |
| `baton-tasks/superpowers-comparison/` | L2 | skip: historical research | no live references |
| `BatonContractAudit.md` | L2 | skip: historical audit | no live references |
| `baton-review.md` | L2 | skip: historical review | no live references |
| `install.sh` | L2 | skip: no workflow.md references | [CODE] grep returned 0 matches |

## Recommendation

Pure rename (Category 1). Execution order:

1. `git mv .baton/workflow.md .baton/constitution.md`
2. Edit `constitution.md`: title → "Baton Constitution", self-reference line 47 → `constitution.md`
3. Edit `CLAUDE.md`: single-line import update
4. Edit `README.md`: ~5 reference updates
5. Edit `setup.sh`: all `workflow.md` → `constitution.md` + **replace** dead `workflow-full.md → workflow.md` migration with `workflow.md → constitution.md` migration (and `workflow-full.md → constitution.md` one-step for edge cases)
6. Edit `failure-tracker.sh`: 1 reference
7. Edit `baton-research/SKILL.md`: 1 reference
8. `git mv tests/test-workflow-consistency.sh tests/test-constitution-consistency.sh`
9. Edit `test-constitution-consistency.sh`: update internal refs
10. Edit `test-setup.sh`: update assertions
11. Edit `.github/workflows/ci.yml`: job name + script path
12. Run tests to verify

**Write set**: steps 1-11 above (12 files).

## Self-Challenge

1. **Is this the best approach?** Yes — the alternatives (symlink, alias) add complexity without solving the core naming confusion. The rename is mechanical and the codebase has precedent migration logic.

2. **Assumptions**:
   - Assumed no external consumers reference `.baton/workflow.md` by hardcoded path. **Risk**: users who have already installed baton have `@.baton/workflow.md` in their CLAUDE.md. **Mitigation**: setup.sh migration logic handles this — next `setup.sh` run will migrate them automatically.
   - Assumed "workflow" in baton-plan/SKILL.md and baton-review/SKILL.md is generic. **Verified**: read the lines, they say "this workflow" / "generating workflow" meaning the general process, not the file.

3. **Skeptic's first challenge**: "Why rename at all? It works fine." Response: naming accuracy matters for a protocol document — the file explicitly says it's NOT a workflow, yet is named `workflow.md`. The cognitive dissonance is real and the fix is low-risk.

## Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Already-installed projects break | Medium | setup.sh migration path auto-fixes on next run |
| Missed reference somewhere | Low | Comprehensive grep already done; tests will catch |
| test-setup.sh assertions outdated after content changes | Low | Update assertions to match new filename |

## Implementation Notes

**B-level write set expansion**: Review agent identified 5 files not in original surface scan that reference `workflow.md`:
- `tests/test-annotation-protocol.sh` — `$SLIM` variable points to workflow.md, will cause CI failure
- `tests/test-multi-ide.sh` — assertions check for `@.baton/workflow.md`
- `bin/baton` — doctor command checks for `@.baton/workflow.md` in CLAUDE.md/AGENTS.md
- `tests/test-cli.sh` — doctor test fixtures use workflow.md
- `docs/stable-surface.md` — references "workflow.md rule 5/6"

All are adjacent integrations requiring mechanical update only. No new behavior introduced.

**A-level**: `.claude/skills/` and `.agents/skills/` are generated copies of `.baton/skills/`. The canonical source was already updated. These will be refreshed on next `setup.sh` run (out of scope — generated artifacts).

## Todo

- [x] 1. Rename core file ✅
- [x] 2. Edit constitution.md internals ✅
- [x] 3. Update CLAUDE.md ✅
- [x] 4. Update README.md ✅
- [x] 5. Update setup.sh ✅
- [x] 6. Update failure-tracker.sh ✅
- [x] 7. Update baton-research/SKILL.md ✅
- [x] 8. Rename test file ✅
- [x] 9. Update test-constitution-consistency.sh ✅
- [x] 10. Update test-setup.sh ✅
- [x] 11. Update CI yml ✅
- [x] 12a. test-setup.sh: all rename-related assertions pass (6 pre-existing Codex trust FAILs) ✅
- [x] 12b. test-constitution-consistency.sh: all rename-related assertions pass (~20 pre-existing content DRIFTs) ✅
- [x] 13. (B-level) Update tests/test-annotation-protocol.sh ✅
- [x] 14. (B-level) Update tests/test-multi-ide.sh ✅
- [x] 15. (B-level) Update bin/baton doctor ✅
- [x] 16. (B-level) Update tests/test-cli.sh ✅
- [x] 17. (B-level) Update docs/stable-surface.md ✅
- [x] 18. Final verification: test-multi-ide.sh 16/16, test-cli.sh 49/50 (1 pre-existing Codex FAIL) ✅

## Retrospective

1. **Wrong prediction**: Surface scan missed 5 files (`test-annotation-protocol.sh`, `test-multi-ide.sh`, `bin/baton`, `test-cli.sh`, `docs/stable-surface.md`). Root cause: initial grep searched for `workflow\.md` but review output was too large (288KB) and was truncated — the skipped files were likely in the truncated portion. Should have run a focused `grep -r workflow\.md --include='*.sh' --include='*.md' tests/ bin/ docs/` instead of repo-wide with preview truncation.

2. **Surprise**: The `bin/baton` CLI tool has a `doctor` subcommand with its own validation logic for import references — this was not obvious from the plan's surface scan methodology (focused on file references, not behavioral code).

3. **Research improvement**: For rename tasks, surface scan should systematically cover `tests/`, `bin/`, `docs/` directories with targeted file-type filtering rather than relying on a single repo-wide grep whose output may be truncated.

<!-- BATON:COMPLETE -->

## 批注区
现在已经没有workflow-full.md了呀

> **回应**: 确认 ✅ `workflow-full.md` 已不存在（glob 0 results）。setup.sh 中旧迁移逻辑是死代码。Plan 已修正：替换旧迁移逻辑而非新增并行路径。test-setup.sh 中对应的 `workflow-full.md` 迁移测试也将更新为 `workflow.md → constitution.md`。

<!-- BATON:GO -->

Retrospective 中的2 3 点问题如何更好的改进