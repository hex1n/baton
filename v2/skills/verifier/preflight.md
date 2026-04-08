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

Read `plan.md § Approach` and challenge it on four dimensions:

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

Challenge rules:
- be specific and cite file paths + line numbers
- propose alternatives, not just criticism
- max 5 challenges per pre-flight
- if the plan is solid, say so explicitly

## Step 6: Output Pre-flight Section in `review.md`

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

### Recommendation
{Specific action items before proceeding, or "Plan is ready for implementation."}

## Routing Signals
| Key | Value |
|-----|-------|
| Next Route | human |
| Human Review Needed | yes |
| Blocking | {none / assumption / environment} |
```

## Lightweight Pre-flight (Small Tasks)

For tasks with `≤5` ACs and a single batch, full pre-flight is often unnecessary. Use:

```markdown
## Pre-flight

ACs: {N} total, all testable ✅
Baseline: {test count or N/A}
Mode: {A/B/C}
Challenges: {none / 1-2 bullet points}
Recommendation: Ready for implementation.
```

Lightweight mode still must write `review.md`, because Dispatcher depends on the file for recovery and state detection.
