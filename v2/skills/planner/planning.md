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

### Step 5: Design candidate approaches

Take the clearest feature block(s) for the current round. Do not over-plan what is still fuzzy.

Generate multiple approaches only when:
- there are genuine architectural alternatives
- trade-offs materially differ
- the right answer depends on business context the Planner cannot determine alone

For each candidate approach, evaluate:

```markdown
### Approach A: {name}
Confidence: {高/中/低} — {why}
Description: {what it does}
Pros: {specific advantages}
Cons: {specific disadvantages}
Complexity: {estimated batches, files, risk}
```

Confidence criteria:
- **高** — aligns with existing patterns, low risk, feasibility already confirmed in code
- **中** — viable but involves trade-offs or unverified assumptions
- **低** — technically possible but heavy unknowns or pattern mismatch

### Step 6: Record approach decisions for Dispatcher

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

### Step 7: Write ACs and batch plan

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
  Batch strategy (what gets built in what order)

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

### Step 8: Declare round scope boundaries

If the task naturally decomposes into layers or distinct concerns, state explicitly in `plan.md § Round N → Approach`:

```text
This round: {what is in scope}
Not this round: {what is explicitly deferred}
```

### Step 9: Write `plan.md`

Use the plan template exactly, including `§ Open Decisions`.

## Round N (Next Round)

For later rounds:

```
1. Read plan.md, especially § Discoveries and completed-round summaries
2. Incorporate:
   - human feedback from the previous checkpoint
   - Builder discoveries
   - any `[boundary update]` discoveries
   - anything that changes remaining feature clarity
3. Repeat Round 1 Steps 5-8 for the next slice of work
4. Update plan.md:
   - compress round history
   - trim stale context
   - mark completed features
   - preserve unresolved discoveries and rejected approaches that still matter
   - carry forward only unresolved or newly introduced `§ Open Decisions`
```
