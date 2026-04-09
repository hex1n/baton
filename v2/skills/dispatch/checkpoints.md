# Dispatcher Guide: Checkpoints & Lifecycle

> Read this file whenever Dispatcher needs a human decision: round-contract approval, task recovery, scope change, task closeout, or a protocol-defined checkpoint.

## New Task Approval Checkpoint

After Planner completes and Verifier pre-flight finishes:

```
1. Read plan.md § Open Decisions.
   → If any row has `Status = open`, present each question + options first.
   → After the human answers, route Planner to fold the answers into plan.md
     and mark the row resolved.
   → If any row still has `Blocking = yes`, do NOT ask for round-contract approval yet.

2. Present plan.md § Round Contract + pre-flight summary + recommended `Verification Add-ons` + `Plan Quality` + `Round Load` to the human once blocking open decisions are resolved.

3. Decision tag check:
   → Scan plan.md § Decisions for `[diverges from human choice]`
   → If found, prepend:
     "⚠️ Planner diverged from your choice on: {decision list}.
      See plan.md § Decisions for rationale."

4. Ask:
   If `Blocking = overload`:
     "Round contract is technically coherent, but Verifier classified it as overloaded.

     Pre-flight confirms ACs are testable and approach is consistent.
     But this round currently exceeds Baton's default single-round load guard:
     - Do the ACs match what you actually want built?
     - Should this round be split before Builder starts?
     - If not, do you want to record a human-approved overload override?
     - Do you want to keep the recommended verification add-ons for the verify pass?

     [See plan.md § Round N → Acceptance Criteria]

     split / override / revise / reject"

   Else if `Plan Quality = under-searched`:
     "Round contract is coherent, but Verifier marked the plan as under-searched.

     Pre-flight does not think the round contract is wrong.
     It thinks the planning search was too shallow for this round:
     - Is the plan solving the right problem?
     - Were the real alternatives explored enough?
     - Do you want a deepen pass before Builder starts?
     - Or do you want to proceed with this plan anyway?

     [See plan.md § Round N → Plan Quality]

     approve / deepen / revise / reject"

   Otherwise:
     "Round contract ready for review.

     Pre-flight confirms ACs are testable and approach is consistent.
     But only you can confirm the ACs are correct:
     - Do the ACs match what you actually want built?
     - Are there scenarios the ACs don't cover?
     - Any AC where the expected outcome is wrong?
     - Do you want to keep the recommended verification add-ons for the verify pass?

     [See plan.md § Round N → Acceptance Criteria]

     approve / revise / reject"
```

## Structural Trigger Messaging

Before routing on the human response, check protocol-defined triggers:

```
- plan.md § Exploration Boundary has `⚠️ GAP`
  → append: "⚠️ Planner flagged exploration gaps: {list}. Proceed anyway?"

- review.md has ≥2 [Correctness] or [Completeness] challenges
  → append: "⚠️ Pre-flight raised {N} correctness/completeness concerns. Review before approving."

- Any AC marked `[assumed — verify]`
  → append: "⚠️ Unconfirmed assumptions: {list}. Confirm or revise?"

- review.md has [cross-model] findings
  → append: "⚠️ Cross-model review raised additional concerns: {summary}."

- `Plan Quality = under-searched`
  → append: "⚠️ Verifier thinks this plan is coherent but under-searched. Consider a deepen pass before approval."

- `Round Load = heavy`
  → append: "⚠️ Planner forecasted a heavy full-mode round. Review `plan.md § Round Contract → Budget Note` before approving."

- `Round Load = overloaded`
  and `Blocking = overload`
  → append: "⛔ Verifier classified this round as overloaded. Builder cannot start until you split the round or record a human-approved overload override."

- `Round Load = overloaded`
  and `Blocking = none`
  → append: "⚠️ Human-approved overload override is already recorded. Builder may proceed, but this round is still above Baton's default load guard."
```

**Routing rule:** triggers inform, not block, except `[assumed — verify]`, `§ Open Decisions` rows with `Blocking = yes`, and `Round Load = overloaded` without a recorded override. Those block Builder until they are resolved.

## Approval Routing

Route based on the human response:

```
approve:
  → only valid if no blocking trigger or blocking open decision remains
  → invoke Builder

deepen:
  → invoke Planner in Revision mode with a deepen request:
      improve problem framing, assumptions, alternatives, and failure mode
      without changing the task unless the deeper search proves the framing itself is wrong
  → re-run Verifier pre-flight
  → return to the approval checkpoint

split:
  → invoke Planner in Revision mode to reduce the round or split work into a new round
  → Planner must clear `plan.md § Round Contract → Overload Override` back to `none`
  → re-run Verifier pre-flight
  → return to the approval checkpoint

override:
  → invoke Planner in Revision mode to record `plan.md § Round Contract → Overload Override = human-approved`
  → Planner must refresh `Budget Note` to explain why the round remains single-round despite overload
  → re-run Verifier pre-flight
  → return to the approval checkpoint

revise:
  → if the revision only changes verify-pass add-ons:
      re-run Verifier pre-flight with the human add-on note
      return to the approval checkpoint
  → otherwise:
      invoke Planner in Revision mode
      re-run Verifier pre-flight
      return to the approval checkpoint

reject:
  → ask: "Describe a different direction, or abandon task?"
  → new direction: invoke Planner with the new input, then re-run pre-flight
  → abandon task: archive .harness/*, task ends
```

## Post-Verification Checkpoint

After Verifier verification:

```
1. Read review.md § Routing Signals:
   - `Next Route`
   - `Human Review Needed`
   - `Blocking`

2. Route mechanically:
   - `Next Route = builder` → route to Builder with the code-bug findings
   - `Next Route = planner` → route to Planner with the design-issue findings
   - `Next Route = closeout` → follow Task Closeout below
   - `Next Route = human` → continue to step 3

3. Present review.md summary.
   → If `Human Review Needed = yes`, include any Mode C warning from
     `§ Human Judgment`
   → Ask: "continue / change scope / close out"

4. Route the human response:
   continue:
     → copy .harness/review.md to .harness/review-round-{N}.md
     → Planner compresses completed round in plan.md
     → Planner adds next round
     → re-run pre-flight for the new round

   change scope:
     → copy .harness/review.md to .harness/review-round-{N}.md
     → ask: "Describe the scope change"
     → apply Scope Change Flow below
     → Planner updates plan.md
     → re-run pre-flight

   close out:
     → follow Task Closeout below
```

## Task Recovery Flow

If `plan.md` already exists:

```
1. Read plan.md → determine current round and progress
2. Read review.md (or latest review-round-{N}.md) → determine last verdict
3. Read git log / status → determine what Builder has already completed
4. Report:
   "Task: {name}, Round {N}, last state: {state}"
5. Ask:
   "continue current task / reset task / abandon task"
6. Route:
   continue current task:
     → pick up at the appropriate new-task or post-verification checkpoint
   reset task:
     → archive current .harness/* to .harness/archive/
     → clear .harness/ (preserve archive/)
     → start new-task flow
   abandon task:
     → archive current .harness/*
     → task ends
```

## Scope Change Flow

When the human requests a scope change, behavior depends on the current round state:

```
Current round NOT started (Planner done, Builder not started):
  → Planner updates current round ACs
  → Re-run Verifier pre-flight
  → No work is lost

Current round IN PROGRESS (Builder started):
  → Do NOT disrupt ongoing work
  → Create a new round for the scope change
  → Builder finishes current round first

Current round COMPLETE (review exists, round complete):
  → Create a new round for the scope change
  → Planner compresses completed round, adds new round

Always:
  → ask the human to confirm scope before Planner proceeds
  → flag conflicts with existing ACs before continuing
```

## Task Closeout

When the human chooses "close out":

```
1. Ensure the project test command from project-profile.md passes
2. Ask: "Create a PR?" → if yes, generate the PR from plan.md summary
3. Ask: "Update project-profile.md?" → if discoveries warrant it
4. Run: bash v2/tools/archive-task.sh --repo-root .
   (archive after PR creation — the archive step is the final part of closeout)
```
