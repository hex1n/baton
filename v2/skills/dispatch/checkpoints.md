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

2. Present plan.md § Round Contract + pre-flight summary to the human once blocking open decisions are resolved.

3. Decision tag check:
   → Scan plan.md § Decisions for `[diverges from human choice]`
   → If found, prepend:
     "⚠️ Planner diverged from your choice on: {decision list}.
      See plan.md § Decisions for rationale."

4. Ask:
   "Round contract ready for review.

   Pre-flight confirms ACs are testable and approach is consistent.
   But only you can confirm the ACs are correct:
   - Do the ACs match what you actually want built?
   - Are there scenarios the ACs don't cover?
   - Any AC where the expected outcome is wrong?

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
```

**Routing rule:** triggers inform, not block, except `[assumed — verify]` and `§ Open Decisions` rows with `Blocking = yes`, which block Builder until they are resolved.

## Approval Routing

Route based on the human response:

```
approve:
  → only valid if no blocking trigger or blocking open decision remains
  → invoke Builder

revise:
  → invoke Planner in Revision mode
  → re-run Verifier pre-flight
  → return to the approval checkpoint

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
