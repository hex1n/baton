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

Before writing any human-facing artifact or status message:

1. If `.harness/profile.local.yaml` sets `documentation.artifact_language` to
   `zh` or `en`, use that language.
2. If it is `auto`, follow the current user request language.
3. If the setting is missing, default to Chinese.

Do not localize `task-status.md`.

## Structured Question Tool

When this skill says "use structured question", use the platform's
interactive question tool:

- **Claude Code**: `AskUserQuestion` (supports single-select, multi-select)
- **Codex**: `request_user_input` (present choices as a numbered list,
  wait for reply)
- **Other hosts**: present choices clearly and wait for the user's response

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
   │                + codex:review (opt)      ↓ advisory consistency check
   ▼                                         ↓ exit:  user confirms
Phase 4  Architect ── baton-architect ────→ architecture.md
   │                 + codex:adversarial (opt) ↓ review→repair loop
   ▼                                         ↓ exit:  Gate 2 (human approval)
   ▼
Phase 5  Verify ── baton-verifier ────────→ verification-path.md
   │                                         ↓ exit:  Gate 3 pass
   ▼
Phase 6  Generate ── baton-generator ─────→ code changes
   │                  + codex:rescue (opt)    ↓ exit:  verification pass
   ▼
Phase 7  Review ── codex:review (opt) ────→ review findings
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

- If not, run `init-harness.sh` first.
- If it exists, check for an active (non-complete) task.
  - Active task found: use structured question (single-select):
    "Resume existing task [task-id] or start a new task?"
    Options: Resume / Start new
  - If resuming: read the current state from `task-status.md` and jump
    to the corresponding phase.

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

### 0.4 Start Task

```bash
bash spec/bootstrap/start-task.sh --repo-root . --task-id <task-id>
```

**Next** → Phase 1 (if Vague/Partial) or Phase 2 (if Clear).

---

## Phase 1: Clarify

> Runs BEFORE the state machine. Turns vague requests into validated
> requirement sets.

**Entry**: Vague or Partial clarity assessment from Phase 0.
**Tool**: `baton-clarifier`
**Output**: `.harness/clarification-brief.md`

```
Skill("baton-clarifier", args: "<user's original request>")
```

The clarifier interviews the user with one question at a time, tracking
confidence across 6 dimensions (problem, users, boundaries, success
criteria, constraints, risks). See `baton-clarifier` SKILL.md for the
full interview protocol.

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

- Low risk: invoke inline via Skill tool.
- Medium/High risk: invoke via Agent tool for context isolation.

Pass `clarification-brief.md` (if exists) to the explorer so clarified
requirements guide the exploration scope. The explorer adapts its depth
based on the risk level from Phase 0.

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

### Codex Advisory Review (Medium/High risk, optional)

For Medium/High risk tasks, if the Codex plugin is available, run a
single advisory review of `requirements.md` before presenting to the user:

```
Skill("codex:review", args: "--wait --scope working-tree")
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

### Codex Architecture Challenge (Medium/High risk, optional)

For Medium/High risk tasks, if the Codex plugin is available, run a
cross-model adversarial review before presenting to the human:

```
Skill("codex:adversarial-review", args: "--wait --scope working-tree")
```

If Codex finds major issues (logical contradictions, missing failure
modes, unaddressed requirements, security/data risks):
1. Revise `architecture.md` to address the findings
2. Re-run the adversarial review
3. If still major issues after one revision, present both the
   architecture and unresolved findings to the human for judgment

This ensures the human reviews an architecture that has already
survived cross-model challenge.

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

```
Agent(subagent_type: "baton-verifier",
      prompt: "Verify the validation path for task <task-id>.")
```

**Output**: `.harness/verification-path.md`

### Gate 3: Verification Path Check

- [ ] Requirements and architecture contain no unresolved contradiction
- [ ] Exact validation commands listed
- [ ] Commands executable in current repo context
- [ ] Isolation mode declared
- [ ] Fallback validation defined

If BLOCKED: report blockers, route back to Phase 4 or Phase 3.

**Next** → Phase 6. State: `generating`, owner: `generator`.

---

## Phase 6: Generate — `generating`

**Entry**: `verification-path.md` exists and Gate 3 passes.
**Tool**: `baton-generator`
**Output**: Code changes, execution notes.

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

### Layer A: Codex Review (optional, cross-model)

If the codex plugin is available, run cross-model review for an
independent second opinion from a different AI model:

```
Skill("codex:review", args: "--wait")
```

For Large tasks, also run adversarial review:

```
Skill("codex:adversarial-review", args: "--wait")
```

Codex review findings are collected and passed to the evaluator as
additional context. They are advisory input, not the final verdict.

If the codex plugin is not available, skip this layer — the evaluator
still runs independently.

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
2. Offer to run `baton-retrospective` for process lessons
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
| `codex:review` | Requirements advisory + code review | Optional (Medium/High) |
| `codex:adversarial-review` | Architecture challenge + design review | Optional (Medium/High) |
| `codex:rescue` | Parallel task delegation | Optional (High only) |

All required tools are baton-native. Codex tools enhance quality but
are not required for the flow to complete.

## State Machine Reference

```
exploring → specifying → architecting → awaiting_human_arch
  → verification_check → generating → reviewing
  → ready_for_human_close → complete
```

Any state can transition to `blocked`. See baton-status for the blocked
exit table.
