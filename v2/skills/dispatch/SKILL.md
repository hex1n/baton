---
name: dispatch
description: Entry point for baton tasks. Detects current state from artifacts, routes to Planner/Builder/Verifier, manages rounds and human interaction.
argument-hint: "[task description or empty to resume]"
---

<task_request> #$ARGUMENTS </task_request>

# Dispatch

Orchestration router. Detects state from artifacts, invokes the right role, handles transitions, enforces structural triggers and blocking rules. Makes no technical decisions — all routing is artifact-driven.

## State Detection

Read these files to determine current state:

```
project-profile.md  → exists? (project configured?)
.harness/brief.md   → exists? (task in progress?)
.harness/eval.md    → exists? (round evaluated?)
```

| project-profile | brief.md | eval.md | State | Action |
|----------------|----------|---------|-------|--------|
| ❌ | — | — | First time | Offer to generate project-profile.md, then proceed |
| ✅ | ❌ | — | New task | Invoke Planner (Round 1) |
| ✅ | ✅ | ❌ | Mid-round (no eval yet) | Check git status, resume Builder or Verifier |
| ✅ | ✅ (Round N) | ✅ (Round N, PASS) | Round done | Ask human: continue / add requirement / done |
| ✅ | ✅ (Round N) | ✅ (Round N, FAIL) | Needs fix | Route based on eval.md finding category |
| ✅ | ✅ (Round N) | ✅ (Round < N) | New round pending | eval.md is stale — invoke Verifier pre-flight for Round N |

**How to compare rounds:** Read `# Evaluation: Round {N}` from eval.md header, compare to brief.md current round number. If brief.md round > eval.md round, the eval is from a previous round.

## New Task Flow

```
0. Determine execution mode:
   → ≤5 ACs AND single batch? → Compact (inline, self-check)
   → >5 ACs OR multi-batch, standard project? → Standard (subagents, core Verifier only)
   → Security-sensitive, Mode C/C+, multi-round, or human requests it? → Full (subagents, all Verifier modules)
   → AskUserQuestion if unclear: "compact / standard / full"
   When invoking Verifier, pass the mode: "execution mode: {compact/standard/full}"
1. Read project-profile.md
2. Invoke Planner → brief.md Round 1
3. Invoke Verifier pre-flight
4. Present brief.md + pre-flight summary to human. Frame around correctness:
   → AskUserQuestion:
     "Plan ready for review.

     Pre-flight confirms ACs are testable and approach is consistent.
     **But only you can confirm the ACs are correct:**
     - Do the ACs match what you actually want built?
     - Are there scenarios the ACs don't cover?
     - Any AC where the expected outcome is wrong?

     [See brief.md § Round N → Acceptance Criteria]

     approve / revise / reject"
5. Before routing, check structural triggers (see protocol.md § Confidence Signals):
   - brief.md § Exploration Boundary has `⚠️ GAP` → append to AskUserQuestion:
     "⚠️ Planner flagged exploration gaps: {list}. Proceed anyway?"
   - eval.md has ≥2 [Correctness] or [Completeness] challenges → append:
     "⚠️ Pre-flight raised {N} correctness/completeness concerns. Review before approving."
   - Any AC marked `[assumed — verify]` → append:
     "⚠️ Unconfirmed assumptions: {list}. Confirm or revise?"
   - eval.md has [cross-model] findings from codex-plugin-cc → append:
     "⚠️ Cross-model review (Codex) raised additional concerns: {summary}."
   - If any trigger fires and human still approves, proceed. Triggers inform, not block
     (except: `[assumed — verify]` blocks Builder until human explicitly confirms or Planner removes the tag)
6. Route based on answer:
   a. "approve" (and no blocking triggers) → invoke Builder
   b. "revise" → invoke Planner in Revision mode → re-run Verifier pre-flight → back to step 4
   c. "reject" → AskUserQuestion: "Describe a different direction, or abort?"
      → new direction: invoke Planner with new input → back to step 3
      → abort: archive .harness/*, task ends
7. After Builder (on approval path) → invoke Verifier verification
8. Handle Verifier result:
   - All pass → go to step 9
   - Code bugs → route back to Builder (up to 3x per Rule 5)
   - Design issues → route to Planner revision, then back to step 6a
   - Requirement gaps → go to step 9 with flag
9. If eval.md states Mode C was used, enforce human code review checkpoint:
   → AskUserQuestion: "Verifier ran in Mode C (no runtime). Please review the
     code changes before proceeding. continue / add requirement / done"
   Otherwise, present eval.md summary to human:
   → AskUserQuestion: "continue / add requirement / done"
10. Route based on answer:
   a. "continue":
      → Archive current eval: cp .harness/eval.md → .harness/eval-round-{N}.md
      → Planner compresses completed round in brief.md
      → Planner adds next round, go to step 3
   b. "add requirement":
      → Archive current eval: cp .harness/eval.md → .harness/eval-round-{N}.md
      → AskUserQuestion: "Describe the new requirement"
      → Determine scope (see Add Requirement Flow below)
      → Planner compresses completed round, incorporates requirement
      → Go to step 3
   c. "done" → archive brief.md, task complete
```

## Resume Flow

If brief.md exists (task in progress):

```
1. Read brief.md → determine current round and progress
2. Read eval.md (or latest eval-round-{N}.md) → if exists, check last verdict
3. Read git log → determine what Builder has committed
4. Report status to human:
   "Task: {name}, Round {N}, last state: {state}"
5. AskUserQuestion: "resume / start fresh / abort"
6. Route:
   a. "resume" → pick up at the appropriate step in New Task Flow
   b. "start fresh" → archive current .harness/* to .harness/archive/
      → clear .harness/ (keep archive/)
      → back to New Task Flow step 0
   c. "abort" → archive current .harness/* → task ends, no further action
```

## Add Requirement Flow

When human says "add requirement", behavior depends on current round state:

```
Current round NOT started (Planner done, Builder hasn't begun):
  → Planner updates current round's ACs to incorporate new requirement
  → Re-run Verifier pre-flight
  → No work is lost

Current round IN PROGRESS (Builder has started):
  → Do NOT disrupt ongoing work
  → Create new round for the requirement
  → Builder finishes current round first
  → New requirement handled in next round

Current round DONE (eval.md exists, round complete):
  → Create new round for the requirement
  → Planner compresses completed round, adds new round

Always:
  → AskUserQuestion to confirm scope before Planner proceeds
  → If new requirement conflicts with existing ACs, flag to human
```

## Invocation Mechanics

How "invoke" works depends on execution mode:

```
Standard / Full mode:
  "Invoke Planner" → spawn Agent tool with Planner's SKILL.md as instructions
  "Invoke Builder" → spawn Agent tool with Builder's SKILL.md as instructions
  "Invoke Verifier" → spawn Agent tool with Verifier's SKILL.md as instructions
    → Pass "execution mode: standard" or "execution mode: full" in arguments
    → Verifier uses the Step Index to decide which [core]/[module] steps to run
  Each agent starts fresh — pass task context via arguments

Compact mode:
  Planner + Builder are merged into one inline execution:
    → Read v2/skills/planner/SKILL.md, follow planning steps
    → Read v2/skills/builder/SKILL.md, follow implementation steps
    → Run self-check checklist (see protocol.md § Compact Mode)
    → Write eval.md marked as "self-check"
  No separate Verifier — human provides independent review
```

## Routing Rules

**To Planner:**
- New task → Round 1 planning
- Human adds requirement → incorporate into next round
- Verifier escalates design issue → Planner revises approach
- Builder discovers new info → Planner evaluates impact

**To Builder:**
- Human approves plan → start implementation
- Verifier returns code-fix feedback → Builder fixes

**To Verifier:**
- Planner completes round plan → Verifier pre-flight
- Builder completes implementation → Verifier verification

**To Human:**
- After Verifier pre-flight → approve plan
- After Verifier verification → review guidance + next step
- Migration generated → approve schema change script
- 3x escalation → decide direction
- Pre-flight BLOCKER (build broken) → AskUserQuestion: "Build environment broken: {reason}. Fix and retry / degrade to Mode C / abort"

## Project Profile Bootstrap

If project-profile.md doesn't exist:

```
"No project profile found. I'll generate one by scanning the project.
This takes ~5 minutes and only needs to happen once."

→ Invoke Planner in profile-generation mode
→ Planner scans: build files, package structure, test infrastructure, conventions
→ Outputs project-profile.md draft
→ Human reviews and adjusts
```

## Task Completion

When human says "done":

```
1. Ensure all tests pass (test command from project-profile.md)
2. AskUserQuestion: "Create a PR?" → if yes, generate PR from brief.md summary
3. AskUserQuestion: "Update project-profile.md?" → if discoveries warrant it
4. Run: bash v2/tools/archive-round.sh --repo-root .
   (archive AFTER PR creation — archive script deletes originals)
```

## Rules

- Dispatch does NOT make technical decisions
- Dispatch does NOT read source code
- Dispatch reads only: project-profile.md, brief.md, eval.md, git status
- All technical routing is based on artifact content, not judgment
- When in doubt about state, ask the human
