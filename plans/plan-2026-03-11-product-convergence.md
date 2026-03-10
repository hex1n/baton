# Plan: Product Convergence — Stable Surface + Host Capability Matrix

**Complexity**: Small
**Source**: Audit chain conclusion — protocol layer stabilized (166/166 baseline), now formalize what Baton actually guarantees.

## Requirements

1. [HUMAN] Define minimal stable surface — the 5-6 capabilities Baton commits to
2. [HUMAN] Formalize capability tiers — hard gate / soft guard / protocol discipline
3. [HUMAN] Consolidate host capability matrix — one canonical source instead of 3 scattered descriptions

## Constraints

- workflow.md is frozen — no changes (per explicit agreement)
- README.md is user-facing onboarding — keep it lightweight, don't turn it into a spec
- Existing `docs/ide-capability-matrix.md` has 4-line table + 2 maintenance rules — undersized for its purpose
- setup.sh has hardcoded IDE help strings (lines 474-478) — these are installer UX, not product spec
- Current enforcement tiers already declared in `workflow.md:79-84` — derive from there, don't contradict

## Approach

**Single approach**: Create `docs/stable-surface.md` as the canonical product spec. Expand `docs/ide-capability-matrix.md` with per-host hook inventory + enforcement levels.

### Why not update README.md?

README is entry-point documentation. A product spec document is reference material. Mixing them would either bloat the README or force the spec to be too brief. README already has a table (lines 133-145) that points to the right bucket; the new doc provides depth behind that table.

### Why not a single combined document?

Stable surface (what Baton promises) and host matrix (what each host gets) serve different audiences. The stable surface is for understanding Baton's contract; the host matrix is for debugging and installation support. Keeping them separate maintains clarity.

## Changes

### Change 1: `docs/stable-surface.md` — New file

Content derived from `workflow.md:79-84` (Enforcement Boundaries) + actual hook inventory.

Structure capabilities by enforcement tier, not as a flat list — they are fundamentally different kinds of guarantees:

**Layer 1 — Hard Gate** (technical block, hook returns non-zero):

| Capability | Hook | What it does |
|-----------|------|--------------|
| GO gate | write-lock.sh | Source writes blocked until `<!-- BATON:GO -->` in plan |

This is the only capability Baton can technically guarantee. Everything below depends on AI cooperation.

**Layer 2 — Soft Guard** (advisory, hook exits 0 but emits stderr guidance):

| Capability | Hook | What it does |
|-----------|------|--------------|
| Phase detection | phase-guide.sh | 6-state machine (RESEARCH → ... → ARCHIVE), routes to skills or fallback |
| Write-set drift warning | post-write-tracker.sh | Warns when modified file not mentioned in plan |
| Todolist gate | phase-guide.sh | AWAITING_TODO: reminds to generate todolist before implementing |
| Retrospective enforcement | completion-check.sh | Soft-blocks task completion until Retrospective exists |

These guide AI behavior but cannot prevent violations.

**Layer 3 — Protocol Discipline** (no hook, relies on skill Iron Laws + human review):

| Capability | Where defined | What it does |
|-----------|---------------|--------------|
| A/B write-set additions | baton-implement skill | Narrowly scoped file additions without replanning |
| 3-failure stop | workflow.md rule 5 | Same approach fails 3× → must stop |
| C/D discovery stop | workflow.md rule 6 | Scope extension → must stop and update plan |
| Fallback conservatism | workflow.md:84 | Without skills, guidance is intentionally stricter |

These exist only as text instructions. Enforcement = skill loading + human review.

### Change 2: Expand `docs/ide-capability-matrix.md`

Add per-host hook inventory table showing exactly which hooks fire for each host:

| Hook | Claude Code | Factory | Cursor | Codex |
|------|-------------|---------|--------|-------|
| write-lock.sh | ✅ hard block | ✅ hard block | ✅ via adapter | ❌ |
| phase-guide.sh | ✅ | ✅ | ✅ | ❌ |
| stop-guard.sh | ✅ | ✅ | ❌ | ❌ |
| bash-guard.sh | ✅ | ✅ | ✅ | ❌ |
| post-write-tracker.sh | ✅ | ✅ | ❌ | ❌ |
| subagent-context.sh | ✅ | ✅ | ✅ | ❌ |
| completion-check.sh | ✅ | ✅ | ❌ | ❌ |
| pre-compact.sh | ✅ | ✅ | ✅ | ❌ |

Evidence: [CODE] `setup.sh:964-1002` (Cursor hook list), `setup.sh:474-478` (IDE labels)

Add "Three product tiers" section — Cursor is NOT equivalent to Claude/Factory:

- **Tier 1 — Full protection** (8/8 hooks): Claude Code, Factory. All hooks fire, including post-write-tracker (write-set drift), stop-guard (session end reminders), completion-check (retrospective enforcement).
- **Tier 2 — Core protection** (5/8 hooks): Cursor. Has write-lock (via adapter) + phase-guide + bash-guard + subagent-context + pre-compact. Missing: post-write-tracker, stop-guard, completion-check. Write-set drift and session-end discipline are unguarded.
- **Tier 3 — Rules guidance** (0/8 hooks): Codex. AGENTS.md + .agents/skills only. No technical enforcement of any kind.

## Self-Review

### Internal Consistency
- Both changes derive from the same source (workflow.md enforcement tiers + hook inventory) ✅
- stable-surface.md and ide-capability-matrix.md don't overlap — one is "what", the other is "where" ✅
- No contradiction with frozen workflow.md ✅

### External Risks
- **Biggest risk**: The hook inventory for Cursor is derived from `setup.sh:964-1002`. If setup.sh is wrong, the matrix will be wrong. Mitigation: the existing `test-ide-capability-consistency.sh` validates this.
- **What could make this wrong**: If a host adds hook support (e.g., Codex adds custom hooks), the matrix would be instantly stale. Mitigation: `docs/ide-capability-matrix.md` already has maintenance rules (lines 12-16).
- **Rejected alternative**: Putting everything in README.md — rejected because README is onboarding, not spec.

## Todo

- [x] ✅ 1. Change: Create `docs/stable-surface.md` with 3-layer capability spec | Files: docs/stable-surface.md | Verify: content matches plan layers, consistent with workflow.md:79-84 | Deps: none | Artifacts: none
- [x] ✅ 2. Change: Expand `docs/ide-capability-matrix.md` with hook inventory + 3 product tiers | Files: docs/ide-capability-matrix.md | Verify: test-ide-capability-consistency 20/20 pass, hook counts match setup.sh:964-1002 | Deps: none | Artifacts: none

## Annotation Log

### Round 1

**[inferred: change-request] § stable-surface.md capability structure**
"把 5 项能力改成分层表达，不要假装它们是同一种能力"
→ Correct. Hard gate (write-lock) and protocol discipline (3-failure stop) are fundamentally different guarantees. Flat table obscured this. Restructured into 3 layers: Hard Gate → Soft Guard → Protocol Discipline.
→ Consequence: no direction change, same content restructured
→ Result: accepted

**[inferred: change-request] § ide-capability-matrix.md host tiers**
"把 Cursor 从和 Claude/Factory 同质的 Tier 1 里解耦一点"
→ Correct. Cursor gets 5/8 hooks, missing post-write-tracker, stop-guard, completion-check. These are meaningful gaps (no write-set drift warning, no session-end discipline). Changed from 2-tier to 3-tier: Full (8/8) → Core (5/8) → Rules (0/8).
→ Consequence: no direction change, finer granularity
→ Result: accepted

## Retrospective

**What the plan got wrong:** Matrix used short product names (Factory, Cursor) but existing test expects full names (Factory AI, Cursor IDE). Caught immediately by test-ide-capability-consistency.sh — the existing test infrastructure worked.

**What surprised me:** Nothing. This was pure documentation work with no behavioral changes. The annotation cycle improved both documents before implementation.

**What to research differently next time:** When modifying files that have consistency tests, run the test before committing to verify format expectations.

## 批注区

<!-- 写下你的反馈，AI 会判断如何处理。 -->
<!-- 如果需要暂停当前工作去做其他调查，写 [PAUSE]。 -->
<!-- 审阅完成后添加 BATON:GO 批准标记，然后告诉 AI "generate todolist" -->

第一，把 stable-surface.md 里的 5 项能力改成分层表达，不要假装它们是同一种“能力”。
第二，把 Cursor 从“和 Claude/Factory 同质的 Tier 1”里解耦一点，至少明确它是较窄的 hook surface。

<!-- BATON:GO -->