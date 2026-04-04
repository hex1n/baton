---
name: baton-orchestrator
description: >
  One-command entry point for baton tasks. Accepts a vague or detailed user
  request, drives requirement clarification, and runs the full state machine
  using only baton-native skills and optional Codex cross-model review.
  Trigger when the user says "baton task", "start a task", "run this through
  baton", or gives a feature/bug request in a baton-governed repo.
argument-hint: "[task description, issue URL, or vague idea]"
user-invocable: true
---

# Orchestrator

> Top-level driver. Chains baton roles end-to-end with explicit handoffs.
> No external workflow dependencies required.

## Artifact Language Policy

The orchestrator detects the artifact language once in Phase 0 and
writes it to `task-status.md` § State Notes as `- artifact_language: <value>`.
All downstream skills read this value instead of re-detecting.

Detection logic (run once in Phase 0, after harness check):
1. If `.harness/profile.local.yaml` sets `documentation.artifact_language` to
   `zh` or `en`, use that value.
2. If it is `auto`, detect from the current user request language.
3. If the setting is missing, detect from the current user request language.
   If indeterminate, default to `zh`.

Write the resolved value (always `zh` or `en`, never `auto`) to State Notes.

Do not localize `task-status.md`.

## Structured Question Tool

When this skill says "use structured question", you MUST use the
platform's structured input mechanism — not free-form text:

- **Claude Code**: Invoke the `AskUserQuestion` tool as a tool call.
- **Codex / Cursor**: Present choices as a numbered list in chat and
  wait for the user to reply with a number. This matches the AGENTS.md
  host contract (`AskUserQuestion → numbered list`). Do NOT call
  `request_user_input` — it is only available in Plan mode.
- **Other hosts**: Present choices clearly and wait for the user's response.

**Do NOT present options as unstructured prose.** The user must see
distinct, selectable options — not a paragraph that mentions choices.

Wrong — buried in prose (DO NOT do this):
> "I think we should proceed. Do you agree? We could also adjust the
> risk level or change the clarity assessment if you prefer."

Right — Claude Code tool call:
> AskUserQuestion({ question: "是否继续？", options: ["是", "否"] })

Right — Codex numbered list:
> 是否继续？
> 1. 是
> 2. 否
> (reply with a number)

## Input

<task_request> #$ARGUMENTS </task_request>

If empty, ask the user what they want to build or fix. Do not proceed
without a clear request.

---

## Flow Overview

```
Phase 0  Triage ─────────────────────────── assess clarity + complexity
   │
   ▼
Phase 1  Clarify ── baton-clarifier ──────→ clarification-brief.md
   │                                         ↓ entry: vague/partial request
   ▼                                         ↓ exit:  confidence sufficient
Phase 2  Explore ── baton-explorer ───────→ scoped-map.md
   │                                         ↓ exit:  Gate 1 pass
   ▼
Phase 3  Specify ── baton-specifier ──────→ requirements.md
   │                + codex:rescue (M/H)      ↓ advisory consistency check
   ▼                                         ↓ exit:  user confirms
Phase 4  Architect ── baton-architect ────→ architecture.md
   │                 + codex:rescue (M/H)     ↓ adversarial review→repair loop
   ▼                                         ↓ exit:  Gate 2 (human approval)
   ▼
Phase 5  Verify ── baton-verifier ────────→ verification-path.md
   │                                         ↓ exit:  Gate 3 pass
   ▼
Phase 6  Generate ── baton-generator ─────→ code changes
   │                  + codex:rescue (opt)    ↓ exit:  verification pass
   ▼
Phase 7  Review ── codex:rescue (M/H) ───→ review findings
   │               + baton-evaluator          ↓ exit:  Gate 4 (evaluator verdict)
   ▼
Phase 8  Human Close ────────────────────→ Gate 5 (human confirms)
   │
   ▼
Phase 9  Complete ── baton-retrospective ─→ retrospective.md (optional)
```

---

## Phase 0: Triage

### 0.1 Harness Check

Check whether `.harness/task-status.md` exists.

- **No `.harness/` at all** — first-time setup. Run `init-harness.sh`:
  ```bash
  bash spec/bootstrap/init-harness.sh --adapter <host> --language <lang> --task-id <id> --force
  ```
  This creates the `.harness/` directory, seeds `profile.local.yaml`,
  copies templates, AND registers the first task row. After this,
  skip `start-task.sh` — the task is already registered.

- **`.harness/` exists but no active task** — harness was initialized
  in a previous session. Register a new task with `start-task.sh`:
  ```bash
  bash spec/bootstrap/start-task.sh --repo-root . --task-id <id>
  ```

- **Active (non-complete) task found** — use structured question
  (single-select): "Resume existing task [task-id] or start new?"
  Options: Resume / Start new
  - If resuming: read the current state from `task-status.md` and jump
    to the corresponding phase. Also run the **Draft Artifact Recovery**
    check below.

### 0.1b Draft Artifact Recovery

When resuming an active task, scan `.harness/` for artifacts that have
`**Status**: \`draft\`` in their header. A draft artifact means the
previous skill was interrupted mid-write.

| Draft artifact found | Action |
|---------------------|--------|
| `scoped-map.md` | Re-run Phase 2 (Explore) |
| `requirements.md` | Re-run Phase 3 (Specify) |
| `architecture.md` | Re-run Phase 4 (Architect) |
| `verification-path.md` | Re-run Phase 5 (Verify) |
| `evaluation.md` | Re-run Phase 7 (Review) |

If a draft is found, inform the user which artifact was incomplete and
which phase will re-run. The re-run overwrites the draft — no manual
cleanup needed. If no drafts are found, resume normally from the
current state.

### 0.1c Artifact Language Detection

Resolve the artifact language and write to `task-status.md` § State Notes
as `- artifact_language: zh` or `- artifact_language: en`. See the
Artifact Language Policy section above for detection logic. All
downstream skills read this value from State Notes instead of
independently detecting the language.

### 0.2 Requirement Clarity Assessment

| Clarity | Signals | Route |
|---------|---------|-------|
| **Vague** | No acceptance criteria, unclear scope, ambiguous intent | → Phase 1 |
| **Partial** | Some requirements but gaps remain, boundaries unclear | → Phase 1 (lighter) |
| **Clear** | Specific criteria, named files, constrained scope | → Phase 2 |

**Default to Vague.** Most company requests have hidden ambiguities.

### 0.3 Risk Assessment

Assess risk, not just size. Risk drives process depth for all downstream phases.

Dimensions in priority order (higher = more weight in judgment):

1. **Security impact** — auth, encryption, user data, permissions
2. **Data integrity** — state mutation, schema migration, persistent storage changes
3. **Public API** — external interface change, breaking compatibility
4. **Concurrency** — locks, queues, distributed transactions, race conditions
5. **Change scope** — file count, module boundaries crossed

Use holistic judgment, not a formula. A task touching only 2 files in the
auth layer is High risk. A 50-file CSS rename is Low risk.

Risk level: **Low** / **Medium** / **High**

Record the risk level in `task-status.md` under `## State Notes` →
`- Risk level: Low/Medium/High`. All downstream skills read this value
to adapt their depth (see each skill's Risk-Adaptive Depth section).

Present clarity assessment, risk level, and reasoning to the user.
Use structured question (single-select) to confirm:
Options: Confirm / Adjust clarity level / Adjust risk level

### 0.3b Codex Availability Check

Detect whether the Codex cross-model review capability is available.
Check in order (stop at the first match):

1. `codex:rescue` — the programmatically-invocable skill from the
   Claude Code Codex plugin (openai-codex). This is the preferred path
   because it does NOT set `disable-model-invocation` and can be called
   via `Skill()`.
2. `codex:codex-rescue` — fully qualified name for the same skill.
3. If neither is found, check whether any skill matching `codex*` with
   review/rescue capabilities is available.

Record in `task-status.md` under `## State Notes`:

- **Available**: `codex_available: true` + the detected skill name
  (e.g., `codex_skill: codex:rescue`). Cross-model review is the
  **default** for Medium/High risk tasks — run it automatically.
- **Unavailable**: `codex_available: false`. Skip all Codex integration
  points silently. The self-challenge step and baton-evaluator still
  provide review coverage.

> **Why `codex:rescue`?** The `codex:review` and `codex:adversarial-review`
> skills set `disable-model-invocation: true`, which prevents programmatic
> invocation via `Skill()`. Only `codex:rescue` can be called
> automatically. Users can still manually run `/codex:review` or
> `/codex:adversarial-review` for structured pipeline output.

### 0.4 Start Task

If `init-harness.sh` was already run in step 0.1 (with `--task-id`), it
has already created the task row — skip straight to Phase 1 or Phase 2.

Otherwise, register the task:

```bash
bash spec/bootstrap/start-task.sh --repo-root . --task-id <task-id>
```

**Next** → Phase 1 (if Vague/Partial) or Phase 2 (if Clear).

### task-status.md Schema Reference

The task table uses this exact format (do not deviate):

```
| Scope | Owner | State | Eval Round | Updated At | Notes |
|-------|-------|-------|------------|------------|-------|
| <task-id> | <role> | <state> | 0 | <timestamp> | <notes> |
```

- **Scope**: task identifier (e.g., `rate-limit-001`)
- **Owner**: current role token (`orchestrator`, `explorer`, `specifier`,
  `architect`, `human`, `generator`, `evaluator`)
- **State**: current state machine state
- **Eval Round**: incremented on each evaluator re-run (starts at 0)
- **Updated At**: ISO timestamp or short date
- **Notes**: free-form; for `blocked` state, must start with
  `[verification_blocker]`, `[scope_blocker]`, `[environment_blocker]`,
  or `[design_blocker]`

### Risk-Adaptive Matrix (canonical reference)

This is the single source of truth for phase depth across all risk
levels. Each skill's Risk-Adaptive Depth section implements the
detail for its row. Per-phase sections below reference this matrix.

| Phase | Low | Medium | High |
|-------|-----|--------|------|
| 1 Clarify | **Skip** (if Clear) or 1 question | Quick confirm — 1-2 key questions | Full interview — 6 dimensions |
| 2 Explore | Convention Scan — entry points + write surface | Dependency Scan — + interfaces, data models | Impact Scan — full call chains + reverse refs + test coverage |
| 3 Specify | Minimal — P0 only, skip traceability | Standard — P0+P1, traceability if brief exists | Full — P0+P1+P2, mandatory traceability, security constraints |
| 4 Architect | Single approach, skip delivery order | Multiple approaches, delivery order recommended | Full comparison + delivery order + security threat modeling |
| 5 Verify | Quick check — build/test infra only, no artifact | Standard — `verification-path.md`, skip perf baseline | Full — `verification-path.md` + CI compat + perf baseline |
| 6 Generate | 1-2 batches, simplified self-review | Logical-unit batches, full self-review | Strict delivery order, security tests per batch |
| 7 Review | Evaluator only (Layer 1+3) | Codex + Evaluator (all layers) | Codex adversarial + Evaluator (all layers) |
| Repair | Max 1 round, then escalate | Up to 3 rounds | Up to 3 rounds |

**Invariants across all risk levels:**

- Verification (Phase 5) and Evaluation (Phase 7 Layer B) never skip.
- Human gates still apply — `awaiting_human_arch` (Gate 2) and
  `ready_for_human_close` (Gate 5) require confirmation at all levels.
- State machine path is the same; only execution depth varies.

---

## Phase 1: Clarify

> Runs BEFORE the state machine. Turns vague requests into validated
> requirement sets.

**Entry**: Vague or Partial clarity assessment from Phase 0.
**Tool**: `baton-clarifier`
**Output**: `.harness/clarification-brief.md`

### Risk-adaptive depth

See **Risk-Adaptive Matrix** row "1 Clarify" in Phase 0.

```
Skill("baton-clarifier", args: "<user's original request>")
```

### Exit criteria

- Problem and Boundaries are clear, remaining gaps resolvable downstream, OR
- User explicitly says to proceed, OR
- Interview has converged (no new information)

### After exit

Re-assess risk — requirements may reveal the task is higher or lower
risk than initially estimated.

**Next** → Phase 2.

---

## Phase 2: Explore — `exploring`

**Entry**: Clarification brief exists (or clarity was already Clear).
**Tool**: `baton-explorer`
**Output**: `.harness/scoped-map.md`

Always invoke via Agent tool — explorer declares `context: fork` and
requires isolation.

### Risk-adaptive depth

See **Risk-Adaptive Matrix** row "2 Explore" in Phase 0.

Pass `clarification-brief.md` (if exists) to the explorer so clarified
requirements guide the exploration scope.

### Gate 1: Scoped Exploration Complete

- [ ] Primary entry points identified
- [ ] Likely write surface identified
- [ ] Test landing points identified
- [ ] High-risk directories called out

**Next** → Phase 3. State: `specifying`, owner: `specifier`.

---

## Phase 3: Specify — `specifying`

**Entry**: `scoped-map.md` exists and Gate 1 passes.
**Tool**: `baton-specifier`
**Output**: `.harness/requirements.md`

### Risk-adaptive depth

See **Risk-Adaptive Matrix** row "3 Specify" in Phase 0.

The specifier takes three inputs:
1. `scoped-map.md` from Phase 2
2. `clarification-brief.md` from Phase 1 (if exists)
3. Risk level from Phase 0

When the clarification brief exists, the specifier **refines and
formalizes** it rather than starting from scratch:
- Maps clarified requirements to formal requirements with traceability
- Assigns priority (P0/P1/P2) to each requirement
- Adds dependency links between requirements
- Adds edge cases discovered during exploration
- Hints test type (unit/integration/e2e) for each acceptance criterion

### Codex Advisory Review (Medium/High risk, default when available)

For Medium/High risk tasks, when Codex is available (detected in
Phase 0), run a single advisory review of `requirements.md` before
presenting to the user:

```
Skill("codex:rescue", args: "--wait --fresh Review .harness/requirements.md against .harness/scoped-map.md. Focus: internal contradictions, coverage gaps, priority consistency, missing edge cases. Output a structured findings list.")
```

Focus: internal contradictions, coverage gaps, priority consistency.
This is a single pass — no repair loop. Present both the requirements
and the Codex findings to the user for their review. The user decides
whether to revise; do not auto-fix based on Codex findings alone.

Present requirements (and advisory findings if available) to the user
for review.

**Low-risk shortcut**: If risk is Low and the clarification brief
already has clear acceptance criteria, produce a minimal requirements
doc. Skip Codex advisory.

**Next** → Phase 4. State: `architecting`, owner: `architect`.

---

## Phase 4: Architect — `architecting`

**Entry**: `requirements.md` exists and user has confirmed it.
**Tool**: `baton-architect`
**Output**: `.harness/architecture.md`

### Codex Architecture Challenge (Medium/High risk, default when available)

For Medium/High risk tasks, when Codex is available (detected in
Phase 0), run a cross-model adversarial review before presenting to
the human:

```
Skill("codex:rescue", args: "--wait --fresh Adversarial review of .harness/architecture.md. Challenge: approach choice, assumptions, risk analysis, failure modes. Question whether the current design is the right one. Compare against .harness/requirements.md for coverage. Output: major issues (blockers) vs minor suggestions.")
```

If Codex finds major issues (logical contradictions, missing failure
modes, unaddressed requirements, security/data risks):
1. Revise `architecture.md` to address the findings
2. Re-run the adversarial review
3. If still major issues after one revision, present both the
   architecture and unresolved findings to the human for judgment

This ensures the human reviews an architecture that has already
survived cross-model challenge.

### Delivery Order Check (High risk)

For **High risk** tasks, `architecture.md` MUST include a `## Delivery
Order` section with an ordered list of implementation units and their
dependencies. If this section is missing, send the architecture back
to the architect for revision before presenting to the human.

Low/Medium risk: delivery order is recommended but not required.

### Gate 2: Architecture Approved

**STOP and wait for human approval.** Present:

- Recommended approach and rejected alternatives
- Write surface and file impact
- Risks and self-challenge
- Codex adversarial findings (if ran): which were addressed, which
  remain as accepted trade-offs
- Requirements sync (if architecture changes requirements-level truth)

Use structured question (single-select) for the decision:
Options: Approved / Partial revision needed / Rejected — wrong direction / Rejected — requirements misunderstood

Do not proceed without explicit human confirmation.

**Next** → Phase 5. State: `verification_check`, owner: `verification-explorer`.

---

## Phase 5: Verify — `verification_check`

**Entry**: `architecture.md` exists, human approved, requirements synced.
**Tool**: `baton-verifier` (Agent — **must be isolated**)

### Risk-adaptive depth

See **Risk-Adaptive Matrix** row "5 Verify" in Phase 0.

```
Agent(subagent_type: "baton-verifier",
      prompt: "Verify the validation path for task <task-id>.")
```

**Output**: `.harness/verification-path.md` (Medium/High only)

### Gate 3: Verification Path Check

- [ ] Requirements and architecture contain no unresolved contradiction
- [ ] Exact validation commands listed (or recorded in State Notes for Low)
- [ ] Commands executable in current repo context
- [ ] Isolation mode declared (Medium/High)
- [ ] Fallback validation defined (Medium/High)

If BLOCKED: report blockers, route back to Phase 4 or Phase 3.

**Next** → Phase 6. State: `generating`, owner: `generator`.

---

## Phase 6: Generate — `generating`

**Entry**: `verification-path.md` exists and Gate 3 passes.
**Tool**: `baton-generator`
**Output**: Code changes, execution notes.

**Before invoking the generator**, ensure the generator records
`base_commit` (current HEAD) to State Notes. The Evaluator in Phase 7
uses this to compute `git diff <base_commit>..HEAD` instead of the
unreliable `HEAD~1`.

```
Skill("baton-generator")
```

The generator reads artifacts in order (architecture → requirements →
verification-path), implements in logical-unit batches (one batch per
independently verifiable requirement), and runs checkpoint validation
after each batch.

### Large tasks — optional parallel delegation

For Large tasks with independent modules in `architecture.md`, delegate
independent units to Codex for parallel execution:

```
Skill("codex:rescue", args: "--background <unit description with files>")
```

Monitor with `/codex:status`. Collect with `/codex:result`.
Run dependent units sequentially with `baton-generator`.

### Post-generation validation

After all implementation is complete, run the verification commands from
`verification-path.md` to confirm the implementation passes.

**Next** → Phase 7. State: `reviewing`, owner: `evaluator`.

---

## Phase 7: Review — `reviewing`

**Entry**: Implementation complete, verification commands pass.

This phase has two layers: optional cross-model review, then the
mandatory evaluator gate.

### Layer A: Codex Review (Medium/High risk, default when available)

For Medium/High risk tasks, when Codex is available (detected in
Phase 0), run cross-model review for an independent second opinion.
**Skip for Low-risk tasks** — the evaluator provides sufficient coverage.

```
Skill("codex:rescue", args: "--wait --fresh Review the implementation changes (git diff). Check against .harness/requirements.md and .harness/architecture.md. Focus: correctness, regressions, missing tests, edge cases. Output: structured findings list with severity.")
```

For Large tasks, also run adversarial review:

```
Skill("codex:rescue", args: "--wait --fresh Adversarial review of the implementation. Challenge design choices and tradeoffs in the current diff. Compare against .harness/architecture.md. Output: major issues (blockers) vs minor suggestions.")
```

Codex review findings are collected and passed to the evaluator as
additional context. They are advisory input, not the final verdict.

If Codex is not available, skip this layer — the evaluator still
runs independently.

### Layer B: Evaluator (mandatory, gate of record)

**Tool**: `baton-evaluator` (Agent — **must be isolated**)

The evaluator runs in a fresh, isolated context with no prior
conversation history. It is the sole gate of record.

```
Agent(subagent_type: "baton-evaluator",
      prompt: "Evaluate the implementation for task <task-id>.
               [If Codex review ran:]
               Cross-model review findings: <summary>")
```

**Output**: `.harness/evaluation.md`

### Gate 4: Independent Review

- [ ] Findings are explicit
- [ ] Blockers are either fixed or accepted
- [ ] No unresolved contradiction between implementation and requirements
- [ ] evaluation.md records review mode, execution context, and verdict

Verdict outcomes:
- **PASS**: all criteria met → Phase 8
- **PASS WITH WARNINGS**: criteria met, warnings documented → Phase 8
- **BLOCKED**: criteria unmet → Repair Loop

**Next** → Phase 8. State: `ready_for_human_close`, owner: `human`.

---

## Phase 8: Human Close — `ready_for_human_close`

**Entry**: Evaluator verdict is PASS or PASS WITH WARNINGS.

### Gate 5: Human Confirmation

Present to the user:

1. Evaluator verdict and residual risks
2. Review coverage:
   - Codex review findings (if ran)
   - Evaluator key findings
3. Acceptance criteria status (all should be met)
4. Any accepted residual risks

**STOP and wait for human confirmation.** Use structured question
(single-select) for the decision:
Options: Accept and close / Reject — needs more work

The user must explicitly accept the result.

**Next** → Phase 9. State: `complete`.

---

## Phase 9: Complete

**Entry**: Human confirmed close.

1. Update `task-status.md` → state `complete`
2. **Conditional retrospective** — run `baton-retrospective` only when
   any of these conditions is true:
   - User explicitly requests it
   - Repair loop occurred (eval round > 1 in task-status.md)
   - Task entered `blocked` state at any point (check Transition Log)
   - Risk level is High
   Otherwise, skip retrospective for routine completions.
3. Suggest next steps:
   - Commit changes
   - Create PR
   - Run `/codex:review --base main` for a final branch-level check

---

## Repair Loop

When the evaluator returns BLOCKED:

```
Phase 7 BLOCKED
  │
  ▼
Read evaluation.md findings
  │
  ▼
Route to baton-generator (or codex:rescue for independent fixes)
  │
  ▼
Re-run verification commands
  │
  ▼
Re-run Phase 7 (full re-evaluation, not incremental)
  │
  ▼
Increment eval round in task-status.md
  │
  ├─ Findings converging (mostly FIXED): continue loop
  └─ Findings not converging (RECURRING/REGRESSED): escalate to human
```

---

## Tool Dependency Summary

| Tool | Role | Required |
|------|------|----------|
| `baton-clarifier` | Requirement interviewing | Yes (skip if Clear) |
| `baton-explorer` | Codebase scoping | Yes |
| `baton-specifier` | Requirements formalization | Yes |
| `baton-architect` | Architecture design | Yes |
| `baton-verifier` | Verification path proof | Yes (isolated) |
| `baton-generator` | Implementation | Yes |
| `baton-evaluator` | Independent review gate | Yes (isolated) |
| `baton-retrospective` | Process lessons | Optional |
| `codex:rescue` | Cross-model review + parallel delegation | Default when available (Medium/High) |

All required tools are baton-native. Codex tools enhance quality but
are not required for the flow to complete.

### Agent vs Skill Decision Tree

Use this to decide how to invoke each role:

- **Agent tool** (isolated context): Use for roles that declare
  `context: fork` — `baton-explorer` (repo-wide), `baton-verifier`,
  `baton-evaluator`. These roles must NOT see prior conversation to
  ensure independent judgment.
- **Skill tool** (same context): Use for roles that need conversation
  state — `baton-clarifier` (needs interview history),
  `baton-specifier`, `baton-architect`, `baton-generator`.
  These roles benefit from seeing prior context.
- **Codex rescue**: Use for cross-model review. Always via
  `Skill("codex:rescue", ...)` since it is the only codex skill
  that supports programmatic invocation.

When `Agent` tool is unavailable (e.g., host does not support it),
fall back to `Skill` tool with `compat` isolation mode and document
the fallback in the artifact's Execution Provenance section.

**Codex invocation note**: `codex:review` and `codex:adversarial-review`
have `disable-model-invocation: true` and cannot be called via `Skill()`.
All automated Codex integration uses `codex:rescue` with task-specific
review prompts. Users can still manually run `/codex:review` or
`/codex:adversarial-review` for structured pipeline output.

## State Machine Reference

```
exploring → specifying → architecting → awaiting_human_arch
  → verification_check → generating → reviewing
  → ready_for_human_close → complete
```

Any state can transition to `blocked`. See baton-status for the blocked
exit table.
