# Implementation Review Criteria

Apply baton-review first-principles framework (Q1-Q4) AND the checklist below.
Step 0 is mandatory first. Step 1 only after Step 0 passes.

## Must-Check

### Step 0 — Spec Compliance (mandatory first)

- Does each change match the plan's stated intent?
- Are all plan-listed files modified? Any missing from the diff?
- Does the diff implement what was specified, not a reinterpretation?
- Would a line-by-line comparison against plan intent show material deviation?
- Would the plan author recognize this as their design?
- Are there changes NOT in the plan's write set? If so, do they meet all three
  implementation-local conditions (mechanically required, no new behavior, recorded)?

Implementation review assumes the approved plan is the current spec baseline.
Challenges to the plan itself belong in prior plan review, not in
reinterpretation during implementation.

### Step 1 — Code Quality (only after Step 0 passes)

#### Correctness
- Unintended side effects? Missed edge cases? Boundary conditions?
- Consumers of changed files affected? Check imports/references.
- Same bug pattern elsewhere in codebase?
- Are error paths tested or just happy paths?

#### Responsibility & Structure
- Does each file/function have a single clear purpose?
- Files doing too much → suggest split. New files should be focused.
- Can a consumer understand the interface without reading internals?
- Does the change follow existing codebase patterns and conventions?

#### Error Handling
- Are errors handled at the right level? Swallowed silently?
- Are errors propagated with sufficient context for debugging?
- Missing error paths? Unhandled promise rejections / unchecked returns?

#### File Health
- Does the change make a file unwieldy? Growth beyond ~300 lines of logic
  is a signal to check if it's doing too much.
- Does the change introduce copy-paste patterns that should be extracted?
  (But don't flag premature abstraction for 2 similar lines.)

#### Testing
- Are new behaviors covered by tests?
- Do tests verify the right thing (behavior, not implementation details)?
- Are edge cases and error paths tested, not just happy paths?
- Would tests catch a regression if the implementation changed?

#### Production Readiness
- Are there hardcoded values that should be configurable?
- Are there debug artifacts left in (console.log, TODO comments, commented-out code)?
- Are there security concerns (injection, unvalidated input at system boundaries)?

### Todo List Review (when reviewing Todo list separately)

- Does each item trace to a specific plan section?
- Missing steps that the plan implies but Todo omits?
- Vague verification criteria? ("verify it works" → what specifically?)
- Wrong dependency order? Would executing in order fail?
- Are independent items marked for safe parallelization?
- Are Files: fields present and accurate?

## Should-Check (skip if hooks enforce)

### Cross-Phase Compliance Checks

- [ ] Changes match approved write set? Out-of-set files mechanically required + no new behavior + recorded?
- [ ] Unexpected discoveries evaluated: assumptions valid? plan still applies? If no → BLOCKED?
- [ ] Impact statements present for any discoveries made during implementation?
- [ ] Evidence contradictions surfaced (not silently resolved)?
- [ ] Completion conditions: scope finished, validation executed, result matches objective?
- [ ] BLOCKED state entered when required (unresolved challenge, invalidated assumptions, failure boundary)?
- [ ] No unsupported confidence claims ("should be fine") in implementation notes?
