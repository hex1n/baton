# Planner Guide: Round Planning

> Use this file for Round 1 and later round planning. Round 1 includes targeted exploration; later rounds reuse the prior plan, discoveries, and human feedback.

## Round 1 (New Task)

### Step 1: Read context

```
Read: project-profile.md (mandatory — refuse to proceed without it)
Read: user's task description
```

### Step 2: Targeted exploration

Don't scan the whole codebase. Read only what the task needs:

```
Based on the task description:
1. Identify the packages / modules likely affected
2. Read key files in that area (entry points, business logic, data models)
3. Read existing tests in that area
4. Read related configuration
5. Note patterns, conventions, reusable components, and risks
```

Record what you read in `plan.md § Context`. **Cite specific files and line numbers.** If you did not read a file, do not make claims about it.

If a file or module is a load-bearing technical entry point for the round, carry it forward into `plan.md § Round Contract → Key Entry Points` so Verifier and validators can check that `Scope Out` does not accidentally exclude it.

Then declare the exploration boundary in `plan.md § Context`:

```
- List explored modules / packages
- List adjacent modules you intentionally did NOT explore, with reason
- If the task touches cross-cutting concerns (auth, logging, config, DB schema),
  confirm you checked the central implementation of each
- Flag `⚠️ EXPLORATION GAP: {module} not examined — {reason}` if you skipped an area that might matter
- Write the findings to .harness/exploration.md as a checkpoint
```

### Step 3: Clarify requirements

Identify load-bearing questions, where different answers produce different implementations.

Rules:
- Ask at most 3 questions at once, plus 1 per Fuzzy feature block
- Each question should include options grounded in what you read
- Skip questions whose answer is already obvious from context
- If requirements are already clear enough, skip to Step 4

Do not ask the human directly from Planner. If clarification is needed:
- record the question in `plan.md § Open Decisions`
- include concrete options grounded in what you read
- mark the row `Status = open`
- set `Blocking = yes` if Builder must not start until the decision is made
- if you proceed with an assumption, tag the affected AC as `[assumed — verify]`

Example:

```text
OD-1.1 | When the same record is created twice, should we overwrite or reject? |
       | overwrite / reject | open | yes

OD-1.2 | Should processing be synchronous or event-driven? |
       | synchronous / event-driven | open | no
```

### Step 4: Decompose into features

Break the task into independent feature blocks and assess clarity:

```text
F1: Alert config CRUD   → Clear ✅
F2: Trigger logic       → Mostly clear ⚠️
F3: Notification        → Fuzzy ❓
```

### Step 5: Classify the round

Before locking the approach, fill the round metadata in `plan.md § Metadata`:

```text
Scope Class:
  S1 = single-round, single-slice, local change
  S2 = single-round, multi-slice, clear boundaries
  S3 = multi-module or dependency-chain work
  S4 = multi-round, cross-boundary, evolving requirements

Risk Class:
  R1 = low risk, easy rollback
  R2 = medium risk, affects core logic or shared state
  R3 = high risk, security / migration / public interface / irreversible side effects

Forecast:
  Expected Rounds = likely total Baton rounds for the task
  Expected Slices This Round = likely implementation slices in this round
```

Rules:
- classify the round that is about to be executed, not the whole project
- use the highest justified risk class, not the average one
- forecasts should be honest and coarse; `3+` is better than fake precision
- these fields explain `Execution Mode`; they do not replace it

### Step 5b: Choose planning depth

Set `plan.md § Plan Quality → Planning Depth`:

```text
normal:
  - the problem is well-understood
  - the solution space is narrow
  - no substantial architectural search is needed

deepen:
  - Scope Class = S3/S4
  - or Risk Class = R2/R3
  - or the round changes protocol / validators / control-plane behavior
  - or the user stated a solution rather than a problem
  - or multiple viable approaches obviously exist
```

If `Planning Depth = deepen`, write a compact first-principles block in `§ Plan Quality`:

- `Problem Statement` — state the outcome problem without solution wording where possible
- `Load-Bearing Assumptions` — list the 1-3 assumptions that would collapse the plan if false
- `Constraints vs Conventions` — separate what is truly fixed from what is inherited but changeable
- `Alternatives Considered` — compare at least two meaningfully different approaches, or explain why only one path is viable
- `Failure Mode` — state how the recommendation is most likely to fail

### Step 6: Design candidate approaches

Take the clearest feature block(s) for the current round. Do not over-plan what is still fuzzy.

Generate multiple approaches only when:
- there are genuine architectural alternatives
- trade-offs materially differ
- the right answer depends on business context the Planner cannot determine alone

If `Planning Depth = deepen`, "multiple approaches" means different mechanisms or responsibility allocations, not small parameter tweaks.

For each candidate approach, evaluate:

```markdown
### Approach A: {name}
Confidence: {高/中/低} — {why}
Description: {what it does}
Pros: {specific advantages}
Cons: {specific disadvantages}
Complexity: {estimated slices, files, risk}
```

Confidence criteria:
- **高** — aligns with existing patterns, low risk, feasibility already confirmed in code
- **中** — viable but involves trade-offs or unverified assumptions
- **低** — technically possible but heavy unknowns or pattern mismatch

### Step 7: Record approach decisions for Dispatcher

If multiple approaches exist, write the comparison in `§ Approach Evaluation` and add an open decision row for Dispatcher:

```markdown
| # | Approach | Confidence | Key trade-off |
|---|----------|------------|---------------|
| 1 | {name} | 高 | {one-line trade-off} |
| 2 | {name} | 中 | {one-line trade-off} |

Recommendation: Approach {N} — {brief why}
```

Then record in `plan.md § Open Decisions`:

```text
OD-{N}.X | Which approach should this round take? |
         | {Approach A / Approach B / different direction} | open | yes
```

If only one viable approach exists, record `None.` as resolved in `§ Open Decisions`.

If `Planning Depth = deepen` and only one approach is viable, record why the alternatives are not viable in `§ Plan Quality → Alternatives Considered`.

### Step 8: Write ACs, round contract, and implementation slices

For the chosen approach, write:

```text
Acceptance Criteria:
  AC-{N}.1: {precise description}
    Given {precondition}
    When  {action}
    Then  {observable, testable outcome}

Approach:
  Module breakdown (if >1 module this round)
  Key technical decisions with rationale
  Slice strategy (what gets built in what order)

Round Contract:
  Scope In / Scope Out
  Key Entry Points
  Done Criteria
  Verification Plan
  Exit Threshold
  Deferred Items

Risks:
  What could go wrong, what to watch for
```

AC writing rules:
- every AC must be testable by Builder and verifiable by Verifier
- use Given / When / Then
- include specific values where they matter
- tag human-preference ACs as `[confirmed]` or `[assumed — verify]`
- annotate unverified assumptions as `⚠️ LOW CONFIDENCE: {assumption}`
- avoid brittle absolute line-count ACs unless you first verify the baseline with commands

### Step 9: Declare round scope boundaries

If the task naturally decomposes into layers or distinct concerns, state explicitly in `plan.md § Round N → Approach`:

```text
This round: {what is in scope}
Not this round: {what is explicitly deferred}
```

### Step 10: Write `plan.md`

Use the plan template exactly, including `§ Open Decisions`, `§ Round Contract`, and `§ Implementation Slices`. When the round depends on a facade, controller, orchestrator, adapter, or other load-bearing entry point, list it explicitly in `Key Entry Points` instead of leaving that constraint implicit in prose.

## Round N (Next Round)

For later rounds:

```
1. Read plan.md, especially § Metadata, § Discoveries, and completed-round summaries
2. Incorporate:
   - human feedback from the previous checkpoint
   - Builder discoveries
   - any `[boundary update]` discoveries
   - anything that changes remaining feature clarity
3. Repeat Round 1 Steps 5-9 for the next slice of work
4. Update plan.md:
   - compress round history
   - trim stale context
   - mark completed features
   - preserve unresolved discoveries and rejected approaches that still matter
   - carry forward only unresolved or newly introduced `§ Open Decisions`
```
