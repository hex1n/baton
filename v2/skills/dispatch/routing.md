# Dispatcher Guide: Routing & State

> Read this module first. It owns state detection, execution-mode selection, role invocation mechanics, verifier handoff, micro-fix routing, and project bootstrap.

## State Detection

Structured control-plane fields:

```text
plan.md § Open Decisions   → explicit human questions + blocking status
plan.md § Round Contract   → agreed in-scope work + done threshold for the round
review.md § Routing Signals   → next route + human-review requirement + blocking reason
```

Scratch files under `.context/baton/active/` are optional tooling aids. Dispatcher never routes from them.

Read these files to determine current state:

```
project-profile.md  → exists? (project configured?)
.harness/plan.md   → exists? (task in progress?)
.harness/review.md    → exists? (round evaluated?)
```

| project-profile | plan.md | review.md | State | Action |
|----------------|----------|---------|-------|--------|
| ❌ | — | — | First time | Offer to generate project-profile.md, then proceed |
| ✅ | ❌ | — | New task | Invoke Planner (Round 1) |
| ✅ | ✅ | ❌ | Mid-round (no review yet) | Check git status, recover Builder state or invoke Verifier |
| ✅ | ✅ (Round N) | ✅ (Round N, PASS) | Round complete | Hand off to `checkpoints.md` for continue / change scope / close out |
| ✅ | ✅ (Round N) | ✅ (Round N, FAIL) | Needs fix | Route based on review.md finding category |
| ✅ | ✅ (Round N) | ✅ (Round < N) | New round pending | review.md is stale — invoke Verifier pre-flight for Round N |

**How to compare rounds:** Read `# Review: Round {N}` from `review.md`, compare to the current round in `plan.md`. If `plan.md` round > `review.md` round, the review is from a previous round.

## New Task Setup

For a new task or a new round pending:

```
0. Determine execution mode:
   → ≤5 ACs AND single slice? → Compact (inline, self-check)
   → >5 ACs OR multi-slice, standard project? → Standard (separate roles, core Verifier only)
   → Security-sensitive, Mode C/C+, multi-round, or human requests it? → Full (add Verifier add-on files)
   → Ask the human if unclear: "compact / standard / full"

1. Read project-profile.md
2. Invoke Planner → expected output: plan.md Round 1 or next round
   → If Planner returns without plan.md, re-invoke
   → If .harness/exploration.md exists and plan.md does not, tell Planner to reuse it
3. Invoke Verifier pre-flight
4. Read `review.md § Routing Signals`
```

Human approval, structural-trigger messaging, and post-pre-flight routing live in `checkpoints.md`.

## Verifier Handoff

After Builder completes, before invoking Verifier verification:

```
1. Check plan.md § AC → Test Mapping
   → If Status cells are empty, append Builder's output to fill them
   → If Builder did not provide mappings, note:
     "⚠️ AC→Test Mapping not updated by Builder"
     in the Verifier invocation context
2. Invoke Verifier verification
3. Route from `review.md § Routing Signals`:
   - `Next Route = builder` → route back to Builder
   - `Next Route = planner` → route to Planner revision, then back through pre-flight
   - `Next Route = human` → hand off to `checkpoints.md`
   - `Next Route = closeout` → finish the task through closeout
```

## Invocation Mechanics

How "invoke" works depends on execution mode:

```
Standard mode:
  "Invoke Planner"  → spawn Agent with Planner SKILL.md
  "Invoke Builder"  → spawn Agent with Builder SKILL.md
  "Invoke Verifier" → spawn Agent with:
    - v2/skills/verifier/SKILL.md
    - v2/skills/verifier/preflight.md or verification.md as needed
    → Tell Verifier: "execution mode: standard"

Full mode:
  Same as Standard, but Verifier also reads optional add-on files:
    - v2/skills/verifier/cross-model.md (Mode C+ / external reviewer available)
    - v2/skills/verifier/adversarial.md (final round or security-surface ACs)
    → Tell Verifier: "execution mode: full, modules: [crossmodel, adversarial]"

Compact mode:
  Planner + Builder merge into one inline execution:
    - Read v2/skills/planner/SKILL.md, follow planning steps
    - Read v2/skills/builder/SKILL.md, follow implementation steps
    - Run the compact self-check from protocol.md
    - Write review.md marked as "self-check"
  No separate Verifier — human provides independent review
```

Each role starts fresh. Pass context through arguments and artifacts, never through conversation history.

## Micro-fix Fast Path

When a Verifier finding or human request requires a trivial fix:

```
Guideline: usually a few files, a few lines each, no new logic or new files
  Examples: typo fix, rename, extracting a magic number, tiny assertion hardening

→ Execute as Compact mode: follow Builder's SKILL.md inline, then self-check
→ Dispatcher still does NOT read or modify source code directly
→ Record in plan.md § Discoveries:
  "Micro-fix (Compact): {what changed}"
→ If in doubt whether it qualifies, spawn a full Builder Agent instead
```

## Routing Rules

**To Planner:**
- New task → Round 1 planning
- Human adds requirement → incorporate into current or next round per scope rules
- Verifier escalates design issue → revise approach
- Builder discovers new information → evaluate impact

**To Builder:**
- Human approves the round contract → start implementation
- Verifier returns code-fix feedback → fix and hand back

**To Verifier:**
- Planner completes a round plan → pre-flight
- Builder completes implementation → verification

**To Human:**
- `plan.md § Open Decisions` has open rows → resolve them
- Pre-flight complete → approve / revise / reject the round contract
- `review.md § Routing Signals` requests human review → continue / change scope / close out
- Migration generated → approve schema-change script
- Repeated escalation or environment blocker → choose direction

## Project Profile Bootstrap

If `project-profile.md` does not exist:

```
"No project profile found. I'll generate one by scanning the project.
This takes ~5 minutes and only needs to happen once."

→ Invoke Planner in profile-generation mode
→ Planner scans build files, package structure, test infrastructure, and conventions
→ Planner outputs project-profile.md draft
→ Human reviews and adjusts
```
