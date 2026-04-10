# Dispatcher Guide: Routing & State

> Read this module first. It owns state detection, execution-mode selection, role invocation mechanics, verifier handoff, micro-fix routing, and project bootstrap.

## State Detection

Structured control-plane fields:

```text
plan.md § Metadata         → Scope Class + Risk Class + round forecasts + Verifier/Execution modes
plan.md § Plan Quality     → planning depth + recommendation confidence + problem framing + alternatives for the current round
plan.md § Open Decisions   → explicit human questions + blocking status
plan.md § Round Contract   → agreed in-scope work + done threshold for the round + overload override
review.md § Routing Signals   → next route + human-review requirement + blocking reason + design-review add-ons + pre-flight triage + verify-pass add-ons + plan-quality assessment + confidence calibration + round-load assessment
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
0. Read project-profile.md
1. Invoke Planner → expected output: plan.md Round 1 or next round
   → If Planner returns without plan.md, re-invoke
   → If .harness/exploration.md exists and plan.md does not, tell Planner to reuse it
2. Read `plan.md § Metadata`
   → Scope Class + Risk Class explain the round
   → Expected Rounds + Expected Slices This Round are forecasts
3. Determine execution mode:
   → `S1 + R1 + Mode A/B`, ≤5 ACs, `Expected Slices This Round = 1`? → Compact candidate
   → `S2/S3` with `R1/R2`? → Standard
   → `S4`, `R3`, or `Mode C/C+`? → Full
   → Ask the human if classification and constraints still leave doubt: "compact / standard / full"
4. Invoke Verifier pre-flight
5. Read `review.md § Routing Signals`
   → If `Pre-flight Triage != none`, hand off to `checkpoints.md` before Builder can start
   → If `Blocking = overload`, hand off to `checkpoints.md` before Builder can start
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
2. Read `review.md § Routing Signals`
   → Capture `Verification Add-ons`
3. Invoke Verifier verification
   → In Full mode, activate only the add-on files listed in `Verification Add-ons`
4. Route from `review.md § Routing Signals`:
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
  Verifier pre-flight:
    - invoke with "execution mode: full"
    - pre-flight may run selected design-review add-on files before Builder starts
    - pre-flight records `Design Review Add-ons`, `Pre-flight Triage`, and `Verification Add-ons` in review.md
  Verifier verification:
    - read `review.md § Routing Signals` → `Verification Add-ons`
    - activate only the listed add-on files
      - v2/skills/verifier/cross-model.md
      - v2/skills/verifier/adversarial.md
    - tell Verifier: "execution mode: full, modules: [{selected modules}]"

Compact mode:
  Planner + Builder merge into one inline execution:
    - Read v2/skills/planner/SKILL.md, follow planning steps
    - Read v2/skills/builder/SKILL.md, follow implementation steps
    - Run the compact self-check from protocol.md
    - Write review.md marked as "self-check"
  No separate Verifier — human provides independent review
```

Each role starts fresh. Pass context through arguments and artifacts, never through conversation history.

Dispatcher reads `Verification Add-ons` literally from `review.md § Routing Signals`. It does not infer add-ons from prose.
Dispatcher reads `Design Review Add-ons` and `Pre-flight Triage` literally from `review.md § Routing Signals`. It does not infer pre-flight routing from prose.
Dispatcher reads `Plan Quality` literally from `review.md § Routing Signals`. It does not infer "under-searched" from narrative text.
Dispatcher reads `Confidence Calibration` literally from `review.md § Routing Signals`. It does not infer overconfidence from narrative text.
Dispatcher reads `Round Load` and `Blocking = overload` literally from `review.md § Routing Signals`. It does not infer overload from narrative text.

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
