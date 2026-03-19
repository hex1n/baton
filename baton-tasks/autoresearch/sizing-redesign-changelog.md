# Sizing Redesign Changelog

**Date**: 2026-03-20
**Branch**: claude/beautiful-dubinsky
**Motivation**: autoresearch identified sizing boundary ambiguity as a root issue —
the condition-table model required a tiebreaker rule because its primary dimensions
(line count, file count, cross-module) could conflict, leaving the AI uncertain
which level applied. Switching the decisive dimension to verification complexity
eliminates the conflict: there is no volume/structure tiebreaker needed when
verification complexity is primary.

---

## Changes Made

### 1. `constitution.md` §Task Sizing — New Table and Explanation

**Before:**
- Column header: `Conditions`
- Row criteria: `< 5 lines, single file, no behavior change` / `< 50 lines, few files, clear change` / `Cross-module, design decisions` / `Architecture-level, multi-system`
- Tiebreaker paragraph: "structural/behavioral criteria override volume criteria"

**After:**
- Added explicit preamble: "verification complexity is the decisive factor … when they conflict, verification complexity wins"
- Column header: `验证需求` (Verification Requirements)
- Row criteria: describes verification cost directly (目视检查 / 单步验证 / 多步验证 / 验证需要设计)
- Removed the tiebreaker paragraph — no longer needed since primary dimension is single

**Why the tiebreaker existed**: The old table had two competing dimensions (volume + structure). When a task was small by volume but cross-module by structure, neither dimension was authoritative, so a tiebreaker rule was bolted on. The new table uses a single dimension — no conflict is possible.

**Scoring validation (autoresearch criteria)**:
- ❌ old: "Boundary ambiguity: < 50 lines cross-module falls in two levels simultaneously" → ✅ fixed: verification complexity of a cross-module change is multi-step by definition; maps to Medium without ambiguity
- ❌ old: "Tiebreaker is an afterthought, not a principle" → ✅ fixed: decisive dimension is stated upfront, tiebreaker removed
- ❌ old: "Volume signals can mislead (small diff, large verification surface)" → ✅ fixed: volume demoted to heuristic signal; verification complexity is what the level decision is based on

---

### 2. `constitution.md` §Sizing Checkpoint — New Section

**Added** between §Task Sizing and §Authority.

**Content**: Three reassessment questions at the research→plan transition, with rules for sizing increases and decreases, and requirement to record changes at the top of the plan.

**Why**: Entry-time sizing is an estimate under uncertainty. Research regularly surfaces information that changes the verification picture (e.g., a "simple" config change turns out to require cross-environment validation). Without a formal checkpoint, the initial estimate drives the rest of the process even when research has invalidated it.

**Scoring validation**:
- ❌ old: "No reassessment mechanism when research changes the verification picture" → ✅ fixed: explicit checkpoint with three concrete questions
- ❌ old: "Stale sizing propagates silently through plan and implement" → ✅ fixed: sizing change must be recorded at the top of the plan; baton-plan updated to enforce this

---

### 3. `using-baton/SKILL.md` — Phase Routing and Sizing Caveat

**Phase Routing paragraph**: Added explicit statement of verification complexity as the decisive dimension, and reference to §Sizing Checkpoint.

**Sizing caveat**: Clarified Trivial definition to match the new table ("verification by visual inspection only").

---

### 4. `baton-research/SKILL.md` — Trigger Heuristics

**Added trigger**: "Verification requires multi-step strategy or designed test scenarios → use"

**Why**: The old heuristics were structural (2+ modules, contradictory sources, multi-framework comparison). A task that touches a single module but requires a designed verification strategy (e.g., constructing a test scenario, multi-environment check) should trigger research — the old heuristics would have missed it.

---

### 5. `baton-plan/SKILL.md` — Complexity-Based Scope

**Added**:
- Explanation of how to read the level via verification complexity (one step = Small, multiple coordinated steps = Medium, verification itself needs design = Large)
- Reference to §Sizing Checkpoint: if level changed after research, record at plan top and apply higher level's process

**Why**: baton-plan §Complexity-Based Scope used Trivial/Small/Medium/Large labels but gave no guidance on how to assign them. Without that anchor, AI would fall back to volume signals, reintroducing the old problem at the plan phase.

---

## Simulation Against autoresearch Scoring Items

The autoresearch identified the following sizing-related weaknesses. Each is re-evaluated below:

| Issue | Old behavior | New behavior | Resolved? |
|-------|-------------|--------------|-----------|
| Boundary ambiguity: small-volume cross-module task | Falls in two levels; tiebreaker required | Verification of cross-module change = multi-step → Medium, no conflict | ✅ |
| Volume can mislead (tiny diff, large verification surface) | Small volume → Trivial/Small sizing | Verification surface drives level; volume is a signal only | ✅ |
| No reassessment between research and plan | Entry estimate persists silently | §Sizing Checkpoint requires explicit re-assessment | ✅ |
| Sizing change after research not recorded | Undocumented; downstream phases use stale level | Plan must record change at top with reason | ✅ |
| Research trigger heuristics miss verification-complex single-module tasks | No trigger for "hard to verify" when structure is simple | "Verification requires multi-step strategy" added as explicit trigger | ✅ |
| baton-plan complexity scope gives no clue how to read levels | Phase relies on cross-module signal anyway | Verification complexity explanation added in §Complexity-Based Scope | ✅ |

---

## What Was NOT Changed

- **Level labels** (Trivial/Small/Medium/Large): preserved for backward compatibility with all phase skill references
- **Process column** in the table: unchanged — what changes is the *criterion for reaching each level*, not what the level requires
- **baton-implement/SKILL.md**: does not reference sizing levels directly; no change needed
- **baton-review/SKILL.md**: review criteria are level-agnostic; no change needed

---

## 批注区
