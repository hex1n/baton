---
name: first-principles-planner
description: >
  Strategic planning from first principles. Creates execution plans or improvement
  proposals by deeply questioning the problem itself — surfacing hidden assumptions,
  separating true constraints from conventions, and rebuilding solutions from ground
  truth. Works from any input: research docs, analysis files, conversation context,
  or a mix. Use when the user needs a well-reasoned plan, improvement proposal, or
  strategic decision that goes beyond picking the first viable solution — especially
  when the right framing of the problem matters more than the solution itself.
  Covers: execution planning, process improvement, architecture decisions, technology
  evaluation, "should we X or Y" tradeoff analysis, assumption challenging, and
  rethinking approaches that feel stuck or conventional. This skill produces plans
  and proposals, not implementations or pure research.
user-invocable: true
---

## Core Principle

Most planning fails because the problem is wrong, not the solution. This skill
forces one discipline: **understand the problem at its roots before proposing
any solution.** Strip every assumption to ground truths, then reconstruct upward.
The value is in what you discard — hidden assumptions constraining the solution space.

---

## Depth Calibration

Not every plan needs full decomposition. Match depth to uncertainty:

| Signal | Depth | What to skip |
|--------|-------|--------------|
| Problem well-understood, narrow solution space | **Light** — skip to Phase 2 | Phase 1 assumption audit (brief inline instead of table) |
| Multiple viable approaches, unclear which is best | **Standard** — full phases | Nothing |
| Recurring problem, existing solutions feel wrong | **Deep** — emphasize Phase 1 | Nothing; expand assumption audit |
| "We've always done it this way" energy | **Deep** | Nothing; assumption audit is the whole point |

State the chosen depth and why at the start. The user can override.

---

## Phase 1: Problem Archaeology

Dig below the stated problem to find the real one.

### 1.0 — Input Gathering

Gather all context first. From documents: goals, constraints, evidence,
conclusions, unresolved questions. From conversation: what the user wants,
tried, and what feels wrong. Verify document claims against reality — stale
data and omissions are findings themselves.

### 1.1 — The Five Whys (adapted)

Start with the stated problem or goal. Ask "why" iteratively — not
mechanically five times, but until you hit a ground truth that the user
recognizes as the actual root.

```
Stated: "We need to migrate from X to Y"
Why?   → "X can't handle our scale"
Why?   → "X's architecture assumes single-tenant"
Why?   → "X was chosen when we were single-tenant"
Root:    The real problem is architectural mismatch with current scale,
         not "migration" per se. Migration is one solution category.
```

The goal is to separate **the problem** (architectural mismatch) from
**a solution** (migration) that may have been stated as if it were the problem.

### 1.2 — Problem Statement

Write a problem statement that:
- Describes the undesirable state without referencing any solution
- Identifies who is affected and how
- States what "solved" looks like in terms of outcomes, not mechanisms

**Bad**: "We need to add caching to the API" (solution masquerading as problem)
**Good**: "API response times exceed 2s at P95, causing user drop-off on the
dashboard page. Solved = P95 < 500ms without sacrificing data freshness."

### 1.3 — Surface Assumptions

For **Light** depth: list 3-5 key assumptions inline, note which are
constraints vs. conventions, and move on. No table needed.

For **Standard/Deep** depth: list assumptions embedded in the problem
statement, current approach, user's constraints, and your own reasoning.
Focus on **load-bearing** assumptions — the ones where "if wrong, the
plan collapses." The most dangerous assumptions are the ones that feel
like facts.

| # | Assumption | Type | If wrong... |
|---|-----------|------|-------------|
| 1 | ... | fact / convention / unknown | plan survives / plan collapses |

### 1.4 — Separate True Constraints from Conventions

For each constraint, ask: **"Can this be changed within scope, and what
would happen if it were?"**

- **True constraint** (external contract, physical limit, legal): design around it.
- **Convention** (changeable but unquestioned): candidate for removal — only
  when it produces a better solution, not for contrarianism.

Litmus test: "Who decided this, when, and does the reason still hold?"

---

## Phase 2: Solution Reconstruction

Build on Phase 1's root problem and true constraints to design solutions.

### 2.1 — Solution Categories

Enumerate fundamentally different approaches. "Fundamentally different" means
they differ in **mechanism or responsibility allocation**, not in parameters.

For each category:
- **Mechanism**: How does it solve the root problem?
- **Why it might be best**: What conditions favor it?
- **Why it might fail**: What risks or costs does it carry?
- **Which conventions does it challenge**: What "normal" things would you
  stop doing?

### 2.2 — Inversion Test

For the leading candidate: **"Under what conditions would this be the worst
possible approach?"** If the pre-mortem reveals a plausible failure, mitigate
or reconsider. Skip for Light depth or obvious approaches.

### 2.3 — Recommend with Reasoning

Truth over novelty: confirm the user's approach if evidence supports it.
If no approach is viable under true constraints, say so — state what must change.

Reasoning chain for recommendations:
- Root problem solved (trace to Phase 1)
- True constraints satisfied
- Conventions deliberately broken, and why
- Primary risk + mitigation

### 2.4 — Dissenting Path

When recommending against the user's stated approach, always provide:
(a) conditions that WOULD justify their approach, and (b) a concrete
"if you still want to proceed" plan. The goal is an informed decision,
not a veto.

---

## Phase 3: Plan Synthesis

Convert the recommended approach into an actionable plan. The plan must be
**operationally specific** — the user should be able to predict what will
change and in what order.

### Operational Granularity

Each recommendation must include:
- **What specifically changes** (not just "improve X" but "add function Y to file Z")
- **Effort estimate** (hours/days, not "soon")
- **Priority** — order by value/risk ratio, not by logical sequence alone
- **Code examples** when the change is non-obvious — show the mechanism

Use a priority table (Priority | Change | Effort | Risk | Value) with a
**Total** row for scannable scope.

### Artifact Structure: Conclusion First

Lead with actionable content (what to DO) in the first 20 lines. Analysis
goes last. No redundancy between Analysis (*why*) and Action Plan (*what/how*).

### Plan Template

Adapt structure to situation — use what fits, skip what doesn't:

**Required:** TL;DR (3-5 lines) → Action Plan (priority table + total row) → Self-Check

**When relevant:** What NOT to Do, Risks & Mitigations, Comparison table
(current vs proposed), Dissenting Path, Code examples (P1/P2 non-obvious)

**Always last:** Analysis — Phase 1-2 reasoning. Reference Action Plan's
code examples, don't repeat.

Light = TL;DR + Self-Check. Deep may need all sections.

---

## Self-Check (include in the plan artifact)

Write a visible Self-Check section in the plan. One core question plus
context-dependent follow-ups:

**Core**: "What is this plan's most likely failure mode, and what would
I do differently if I knew it would fail?"

Then address whichever of these are relevant (skip the rest):
- If the user stated a solution, not a problem: did you trace to the
  actual root problem?
- If you're recommending against the user's approach: what evidence
  would change your mind?
- If the plan has multiple steps: can the user predict the outcome from
  reading the plan alone?

Don't answer questions that don't apply. A 2-line self-check for a
Light-depth plan is fine. A genuine single insight beats 5 formulaic
answers.

---

## Output Conventions

- **Language**: Match the user's language (prose + headings). Code/technical terms stay English.
- Save plans where user specifies, or propose a location
- Include depth level and input sources used
- Evidence markers: ✅ verified, ❓ unverified
- Multiple viable approaches → present tradeoff honestly, don't force a pick
