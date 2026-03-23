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

Most planning fails not because the solution is wrong, but because the problem
is wrong. This skill forces a specific discipline: **understand the problem at
its roots before proposing any solution.**

First principles thinking is not "brainstorm hard." It is a specific operation:
strip away every assumption until you reach ground truths that cannot be
further decomposed, then reconstruct upward. The value is in what you discard
during the stripping — those are the hidden assumptions that constrain your
solution space unnecessarily.

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

Before analysis, gather all available context. From documents: read and
extract goals, constraints, evidence, conclusions, unresolved questions.
From conversation: extract what the user is trying to achieve, what they've
tried, what feels wrong.

**When working from a document**: verify its claims against reality. Documents
go stale. If the document says "5 hooks" but there are 10, say so — the
mismatch itself is a finding. Go beyond stated issues: what did the document
miss? Codebase exploration or external verification often reveals problems
the author didn't see.

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

Every situation carries assumptions — some are load-bearing facts, others are
inherited conventions nobody questions. The most dangerous assumptions are the
ones that feel like facts.

For **Light** depth: list 3-5 key assumptions inline, note which are
constraints vs. conventions, and move on. No table needed.

For **Standard/Deep** depth: use the full process below.

List assumptions embedded in:
- The problem statement itself
- The current approach (if one exists)
- The constraints the user mentioned
- Your own reasoning so far

Focus on **load-bearing** assumptions — the ones where "if wrong, the plan
collapses." Don't exhaustively catalog every minor assumption.

| # | Assumption | Type | If wrong... |
|---|-----------|------|-------------|
| 1 | ... | fact / convention / unknown | plan survives / plan collapses |

### 1.4 — Separate True Constraints from Conventions

This is the core move of first principles thinking. For each constraint
the user or situation imposes, ask: **"Can this be changed within scope,
and what would happen if it were?"**

- If it cannot be changed (external contract, physical limit, legal
  requirement): it's a **true constraint**. Design around it.
- If it could be changed but hasn't been questioned: it's a **convention**.
  Conventions are candidates for removal — but only when removing them
  produces a better solution, not for the sake of being contrarian.

The test is simple: "Who decided this, when, and does the reason still
hold?" Decisions made under old conditions often survive as constraints
long after the conditions change.

---

## Phase 2: Solution Reconstruction

Now — and only now — design solutions. You're working with:
- A clearly stated root problem (Phase 1)
- Only true constraints, not conventions (Phase 1 assumption audit)
- A wider solution space than you started with

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

For the leading candidate, flip the question: **"Under what conditions
would this be the worst possible approach?"** This is a pre-mortem — it
catches failure modes that forward reasoning misses because you're
optimizing for success, not scanning for failure.

If the pre-mortem reveals a plausible failure scenario, either mitigate
it in the plan or reconsider the recommendation. If you can't articulate
a plausible failure, you haven't thought hard enough — every approach
has a failure mode.

Skip inversion for Light depth or when the approach is obvious.

### 2.3 — Recommend with Reasoning

If the analysis confirms the user's original approach, say so directly with
the supporting evidence. The goal is truth, not novelty — don't force a
reframe when the user's instinct is already correct. If no approach is
viable under the true constraints, say that too — state what would need
to change before the problem becomes solvable.

When recommending, state the specific reasoning chain:
- Which root problem does it solve (trace to Phase 1)?
- Which true constraints does it satisfy?
- Which conventions does it deliberately break, and why that's acceptable?
- What's the primary risk, and how to mitigate it?

### 2.4 — Dissenting Path

When recommending against the user's stated approach (e.g., "don't rewrite
to Python"), always provide: (a) what conditions WOULD justify the user's
approach, and (b) a concrete "if you still want to proceed" plan. This
respects the user's autonomy — they may have context you don't. The goal is
an informed decision, not a veto.

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

Use a priority table with a **total row** to make execution order and
overall scope scannable:

```markdown
| Priority | Change | Effort | Risk | Value |
|----------|--------|--------|------|-------|
| P1 | ... | 1h | Low | High — fixes root cause |
| P2 | ... | 2d | Med | Med — reduces duplication |
| P3 | ... | ... | ... | Low — nice-to-have |
| **Total** | | **~Xh** | | |
```

### Artifact Structure: Conclusion First

The plan artifact must lead with the actionable content. The reader should
know what to DO within the first 20 lines. Detailed analysis (Phase 1-2
reasoning) goes in a later section — it supports the plan but should not
block the reader from reaching the action items.

**No redundancy between sections.** The Analysis section must NOT repeat
code examples or details already shown in the Action Plan. Instead,
reference them: "See P1 above for the code example." The Analysis section
adds the *reasoning* (why this approach, what alternatives were rejected,
what assumptions were challenged) — the Action Plan section contains the
*what and how*.

### Plan Template

The plan structure adapts to the situation. These are the building blocks
— use what fits, skip what doesn't:

**Always include:**
- **TL;DR** (3-5 lines: problem, insight, recommendation)
- **Action Plan / Proposed Changes** (priority table with total row)
- **Self-Check** (see below)

**Include when relevant:**
- **What NOT to Do/Change** — when alternatives were considered and rejected,
  or when over-correction is a risk
- **Risks & Mitigations** — when the plan has non-obvious failure modes
- **Comparison table** — when improving something existing (current vs proposed)
- **Dissenting Path** — when recommending against the user's stated approach
- **Code examples** — for P1/P2 changes where the mechanism isn't obvious

**Always last:**
- **Analysis** section — Phase 1-2 reasoning that supports the plan.
  Reference the Action Plan's code examples rather than repeating them.

Don't force sections that don't apply. A Light-depth plan might be just
TL;DR + "no action needed" + Self-Check.
A Deep plan might need all sections. Let the content drive the structure.

---

## Self-Check (include in the plan artifact)

Write a Self-Check section INTO the plan. This is visible output — the
user judges whether the self-examination was genuine.

The self-check has one core question and context-dependent follow-ups:

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

- **Language**: Write the plan in the same language the user used. If the
  user writes in Chinese, the plan should be in Chinese. Code examples and
  technical terms can stay in English (they're universal), but prose,
  headings, and Self-Check should match the user's language. The template
  headings in this skill (e.g., "Action Plan", "Analysis", "Self-Check")
  are structural guides — translate them to the user's language in the
  output. "TL;DR" is a universal abbreviation and can stay as-is.
- Save plans to a location the user specifies, or propose one
- Include the depth level chosen and the input sources used
- Mark evidence: ✅ verified, ❓ unverified
- If multiple viable approaches remain after analysis, present the tradeoff
  honestly rather than forcing a recommendation — the user may have context
  you don't
