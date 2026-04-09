# Verifier Guide: Pre-flight

> Invoked before Builder starts. Goal: catch bad plans early.

## Step 1: Read inputs

```text
Read: project-profile.md
Read: .harness/plan.md (current round only)
Read: relevant source files referenced in plan.md § Context
      (pre-flight CAN read source code — this is plan review, not code review)
```

## Step 2: AC Testability Check

For each AC in the current round:

```text
AC-{N}.1: "Given {precondition}, When {action}, Then {specific status + state change}"
  → Testable? ✅ (clear input, clear output, observable state change)

AC-{N}.3: "System should be timely"
  → Testable? ❌ (what is "timely"? no threshold defined)
  → Feedback: "AC-{N}.3 is not testable. Define a specific threshold or measurable outcome."
```

Every AC must be verifiable. If it is not, flag it before Builder wastes time.

## Step 3: Test Baseline

Run the project's test command from `project-profile.md` on the current unmodified state:

```text
Record:
  Total: {count}
  Pass: {count}
  Fail: {count} (IDs: {test identifiers})
  Skip: {count}
  Duration: {time}
```

This baseline distinguishes new failures from pre-existing ones later.

## Step 4: Environment Capability Detection

```text
Test each capability level (commands from project-profile.md):

1. Compile/check command works?
   Yes → Tier 1 available
   No  → BLOCKER — cannot proceed, fix build first

2. Test command works?
   Yes → Tier 1 fully available
   No  → Tier 1 partial (compile only)

3. Application starts?
   Yes → Tier 2 available
   No  → Tier 2 unavailable, record reason

4. Database / external services accessible at runtime?
   Yes → Tier 2 fully available
   No  → Tier 2 partial

Result: Mode A / B / C
Record in review.md and suggest updating project-profile.md if capability changed
```

If capability was already established in earlier rounds and nothing changed, trust `project-profile.md`.

## Step 5: Plan Quality Challenge

Read `plan.md § Plan Quality`, `§ Approach`, and `§ Round Contract`, then challenge the plan on six dimensions:

**a) Consistency with existing code**

```text
"Brief says 'use direct call' but I see the project uses an event/message
pattern for similar decoupled triggers (see {file}:L{N}).
Why not use the existing pattern?"
```

**b) Completeness of acceptance criteria**

```text
"ACs cover happy path and basic errors. Missing:
- Concurrent access to the same resource
- Input validation boundaries
- Behavior when dependent service is down"
```

**c) Simplicity**

```text
"Brief proposes 3 new classes/modules. {Name} could use the framework's
built-in capability instead. This reduces implementation to 2 files."
```

**d) AC semantic correctness**

```text
"Cross-check each AC's expected outcome against observed codebase behavior:
- Does the 'Then' clause match what similar operations return in this codebase?
- Does the 'Given' precondition reflect actual system states?
- Flag: 'AC-{N}.{X} outcome conflicts with {file}:L{N} — existing behavior is {X}, AC says {Y}.'"
```

**e) Round contract quality**

```text
"Round Contract says Scope In = X and Done Criteria = Y.
Check whether:
- Scope In matches the actual ACs
- Scope Out really excludes adjacent risky work
- Scope Out does not exclude anything named in `Round Contract → Key Entry Points`
- Mode C deferrals do not incorrectly remove required structural test work
- Budget Note exists when the round forecast is intentionally heavy
- Overload Override stays `none` unless a human exception has already been recorded
- Done Criteria are observable
- Verification Plan is realistic for the configured mode
- Verification Plan matches Done Criteria
- Exit Threshold is strict enough for the round"
```

**f) Search adequacy**

```text
"This plan may be coherent but still under-searched.
Check whether:
- the plan solves the real problem, not just the user's stated solution
- `Planning Depth` is appropriate for the round
- deepen rounds actually list load-bearing assumptions
- constraints are separated from conventions
- alternatives are meaningfully different, or the single-path justification is credible
- the stated failure mode is real rather than ceremonial
- a clearly smaller / simpler approach was skipped without explanation"
```

Challenge rules:
- be specific and cite file paths + line numbers
- propose alternatives, not just criticism
- max 5 challenges per pre-flight
- if the plan is solid, say so explicitly

## Step 6: Plan Quality Assessment

Assess whether the plan has been searched deeply enough for the declared planning depth:

```text
adequate:
  - normal-depth round with a narrow solution space
  - or deepen round with a credible problem statement, assumptions, alternatives, and failure mode

under-searched:
  - deepen-triggered round still uses `Planning Depth = normal`
  - or the problem statement still describes a solution rather than an outcome
  - or alternatives are missing / trivial when real alternatives exist
  - or the plan clearly skipped a simpler path without explaining why
  - or the failure mode / assumptions block is missing or non-informative
```

If the plan is coherent but under-searched:

```text
- keep `Contract Status` about coherence
- set `Plan Quality = under-searched`
- recommend a deepen pass before Builder starts
- keep `Next Route = human` so Dispatcher can offer `deepen`
```

## Step 7: Verification Add-on Recommendation

Recommend verify-pass add-ons for the current round:

```text
Recommend `adversarial` if any of:
  - Risk Class = R3
  - Scope Class = S4
  - Verifier Mode = C/C+
  - ACs or Round Contract involve:
      shared-state mutation
      transaction boundaries
      concurrency or locking
      idempotency chains
      delete-and-rebuild flows
      irreversible side effects

Recommend `cross-model` only if:
  - project-profile.md enables an external reviewer
  - and at least one of:
      the human explicitly asked for cross-model review
      the round is both high-risk and final
      confidence remains degraded after the core challenge

Otherwise recommend `none`.
```

Record the result in `review.md` for the verify pass. The recommendation must be structured and brief.

## Step 8: Round Load Assessment

Classify the round load from the current round metadata, verifier pressure, and exploration uncertainty:

```text
normal:
  - round should fit one Builder pass and one verification pass
  - no unusual coordination pressure detected

heavy:
  - at least one notable load signal exists
  - but the overload condition below is not met

overloaded:
  - Expected Slices This Round = 3+
  - and verifier pressure is elevated:
      Verifier Mode = C/C+
      or recommended Verification Add-ons != none
  - and uncertainty / blast radius is elevated:
      Scope Class = S4
      or Risk Class = R3
      or Exploration Boundary contains ⚠️ GAP
```

Blocking rule:

```text
If Round Load = overloaded and plan.md § Round Contract → Overload Override != human-approved:
  - keep Contract Status about plan quality, not size
  - set Recommendation to "Split the round or record a human-approved overload override."
  - write `Blocking = overload`
  - write `Round Load = overloaded`

If Round Load = overloaded and Overload Override = human-approved:
  - keep `Round Load = overloaded`
  - set `Blocking = none`
  - set Action to `proceed-under-override`
  - state clearly that the round proceeds only under recorded human override
```

## Step 9: Output Pre-flight Section in `review.md`

```markdown
## Pre-flight

### AC Testability
- AC-{N}.1: ✅ Testable
- AC-{N}.2: ✅ Testable
- AC-{N}.3: ⚠️ Needs clarification — {what's ambiguous}

### Test Baseline
{pass} pass / {fail} fail (known) / {skip} skip — {duration}

### Environment
- Mode: {A/B/C} ({reason if not A})
- Tier 2: {full / partial / unavailable}

### Plan Challenges
1. [Consistency] {existing pattern conflicts with the proposed approach, cite file + line}
2. [Completeness] {missing scenario}
3. [Correctness] {AC expected outcome conflicts with observed behavior, cite file + line}
4. No other significant issues.

### Contract Status
- Status: {agreed / revise / blocked}
- Blocking ambiguities: {none / list}
- Verification readiness: {ready / partial / blocked}

### Recommendation
{Specific action items before proceeding, or "Plan is ready for implementation."}

### Verification Add-ons (for verify pass)
- Recommended: {none / adversarial / cross-model / adversarial,cross-model}
- Why: {brief reason}

### Plan Quality
- Depth: {normal / deepen}
- Search Adequacy: {adequate / under-searched}
- Why: {brief reason}

### Round Load
- Load: {normal / heavy / overloaded}
- Why: {brief reason}
- Action: {proceed / warn / split-or-override / proceed-under-override}

## Routing Signals
| Key | Value |
|-----|-------|
| Next Route | human |
| Human Review Needed | yes |
| Blocking | {none / assumption / environment / overload} |
| Verification Add-ons | {none / adversarial / cross-model / adversarial,cross-model} |
| Plan Quality | {adequate / under-searched} |
| Round Load | {normal / heavy / overloaded} |
```

## Lightweight Pre-flight (Small Tasks)

For tasks with `≤5` ACs and a single slice, full pre-flight is often unnecessary. Use:

```markdown
## Pre-flight

ACs: {N} total, all testable ✅
Baseline: {test count or N/A}
Mode: {A/B/C}
Challenges: {none / 1-2 bullet points}
Plan Quality: {adequate / under-searched}
Round Load: {normal / heavy / overloaded}
Contract Status: {agreed / revise}
Recommendation: Ready for implementation.
```

Lightweight mode still must write `review.md`, because Dispatcher depends on the file for recovery and state detection.
