# Harness Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the baton governance system with harness-spec-v1 — restructure the repo, write 6 role skills, establish lean governance via CLAUDE.md.

**Architecture:** Three-layer structure: `spec/` (portable protocol), `.claude/skills/` (Claude Code role skills + preserved capability skills), and root-level governance (`CLAUDE.md`). Skills embed their role contract from the protocol rather than referencing it at runtime. CLAUDE.md loads only a ~50 line governance summary, not the full protocol.

**Tech Stack:** Markdown, YAML, Bash (Git operations)

**Source spec:** `docs/superpowers/specs/2026-03-26-harness-restructure-design.md` (conversation-based, not file-based — design was confirmed in brainstorming dialogue)

---

## File Structure

### New files to create

| File | Responsibility |
|------|---------------|
| `CLAUDE.md` | Lean governance summary (~50 lines) — state machine + gates + artifact naming |
| `README.md` | Repo overview with structure and quick start |
| `.claude/skills/harness-explorer.md` | Role skill: code exploration (repo + scoped) |
| `.claude/skills/harness-specifier.md` | Role skill: requirements specification |
| `.claude/skills/harness-architect.md` | Role skill: technical architecture |
| `.claude/skills/harness-verifier.md` | Role skill: verification path check |
| `.claude/skills/harness-generator.md` | Role skill: code implementation |
| `.claude/skills/harness-evaluator.md` | Role skill: independent evaluation |

### Files to move

| From | To |
|------|-----|
| `harness-spec-v1/*` | `spec/*` |

### Files to preserve (move to new location)

| From | To |
|------|-----|
| `skills/deep-research/SKILL.md` | `.claude/skills/deep-research/SKILL.md` |
| `skills/first-principles-planner/SKILL.md` | `.claude/skills/first-principles-planner/SKILL.md` |

### Files/directories to delete

| Path | Reason |
|------|--------|
| `constitution.md` | Replaced by spec/protocol/ |
| `.baton/` | Old skills + constitution + adapters |
| `hooks/` | Old enforcement layer (Option C: no hooks) |
| `tests/` | Tests for deleted hooks |
| `baton-tasks/` | Old task artifacts (git history preserves) |
| `AGENTS.md` | Pointed to old constitution |
| `skills/using-baton/` | Old baton entry skill |
| `skills/verify/` | Old verify skill |
| `install.sh` | Old baton installer |
| `setup.sh` | Old baton installer |
| `bin/baton` | Old baton CLI |
| `scripts/` | Old baton scripts (context-bar.sh, x-reader/) |
| `.agents/` | Old agent skill references |
| `.codex/` | Old Codex adapter config |
| `.github/workflows/ci.yml` | CI for deleted hooks/tests — will break if kept |
| `baton-review.md` | Old baton review doc |
| `docs/` | Old design docs (entire directory except this plan) |
| `README.md` | Old baton README (will be rewritten) |
| `.claude/skills/baton-*` | Symlinks to deleted .baton/skills/ |
| `.claude/skills/codex-dispatch*` | Old codex adapter skills |
| `.claude/skills/deep-research-workspace/` | Workspace copy (source preserved) |
| `.claude/skills/first-principles-planner-workspace/` | Workspace copy (source preserved) |
| `nul` | Accidental Windows artifact |

---

## Task 1: Delete old baton assets

**Files:**
- Delete: `constitution.md`, `.baton/`, `hooks/`, `tests/`, `baton-tasks/`, `AGENTS.md`, `nul`
- Delete: `skills/using-baton/`, `skills/verify/`
- Delete: `.claude/skills/baton-*` (all symlinks), `.claude/skills/codex-dispatch*`, `.claude/skills/*-workspace/`

- [ ] **Step 1: Remove tracked old assets**

```bash
git rm -r constitution.md .baton/ hooks/ tests/ baton-tasks/ AGENTS.md
git rm -r skills/using-baton/ skills/verify/
git rm -r install.sh setup.sh bin/ scripts/ .agents/ .codex/
git rm -r .github/workflows/ci.yml baton-review.md
git rm -r docs/design-comparison.md docs/first-principles.md docs/gstack-deep-analysis.md
git rm -r docs/ide-capability-matrix.md docs/implementation-design.md
git rm -r docs/research-ide-hooks.md docs/research-zed-terminal-refresh.md docs/stable-surface.md
git rm -r docs/superpowers/plans/2026-03-17-governance-workflow-decoupling.md
git rm -r docs/superpowers/plans/2026-03-17-install-architecture-redesign.md
git rm -r docs/superpowers/specs/2026-03-17-install-architecture-redesign.md
git rm README.md
```

- [ ] **Step 2: Remove untracked old assets**

```bash
rm -rf .claude/skills/baton-debug .claude/skills/baton-evolve .claude/skills/baton-implement
rm -rf .claude/skills/baton-implement-workspace .claude/skills/baton-plan .claude/skills/baton-plan-workspace
rm -rf .claude/skills/baton-research .claude/skills/baton-research-workspace .claude/skills/baton-review
rm -rf .claude/skills/baton-subagent .claude/skills/codex-dispatch .claude/skills/codex-dispatch-workspace
rm -rf .claude/skills/deep-research-workspace .claude/skills/first-principles-planner-workspace
rm -f nul
```

- [ ] **Step 3: Update .gitignore**

Remove old baton patterns, keep relevant ones. The `.gitignore` should retain
patterns for `.claude/settings.local.json`, `CLAUDE.local.md`, etc. Remove
references to old baton-specific paths.

- [ ] **Step 4: Verify deletion**

```bash
ls .baton/ 2>&1       # Expected: No such file or directory
ls hooks/ 2>&1        # Expected: No such file or directory
ls tests/ 2>&1        # Expected: No such file or directory
ls bin/ 2>&1          # Expected: No such file or directory
ls scripts/ 2>&1      # Expected: No such file or directory
ls .agents/ 2>&1      # Expected: No such file or directory
ls .codex/ 2>&1       # Expected: No such file or directory
ls .github/ 2>&1      # Expected: No such file or directory
ls .claude/skills/    # Expected: only deep-research/ and first-principles-planner/ source dirs (if already moved)
```

---

## Task 2: Restructure — move harness-spec-v1/ to spec/

**Files:**
- Move: `harness-spec-v1/*` → `spec/*`

- [ ] **Step 1: Unstage harness-spec-v1 and move to spec/**

harness-spec-v1/ files are staged as adds (not yet committed). Reset staging, move physically, re-stage at new path.

```bash
git reset HEAD harness-spec-v1/
mv harness-spec-v1 spec
git add spec/
```

- [ ] **Step 2: Verify structure**

```bash
ls spec/
# Expected: 11.md  README.md  adapters  bootstrap  extensions  profiles  protocol  templates
ls spec/protocol/
# Expected: artifact-schema.md  gates.md  role-contracts.md  state-machine.md
ls spec/bootstrap/
# Expected: init-harness.md  init-harness.ps1  init-harness.sh  start-task.md  start-task.ps1  start-task.sh
```

---

## Task 3: Move preserved skills to .claude/skills/

**Files:**
- Move: `skills/deep-research/` → `.claude/skills/deep-research/`
- Move: `skills/first-principles-planner/` → `.claude/skills/first-principles-planner/`
- Delete: `skills/` (now empty)

- [ ] **Step 1: Move skill directories**

```bash
mkdir -p .claude/skills
git mv skills/deep-research .claude/skills/deep-research
git mv skills/first-principles-planner .claude/skills/first-principles-planner
git rm -r skills/using-baton skills/verify
```

Note: `git mv` preserves rename detection in history. The `skills/` directory
will be fully removed after the remaining subdirectories are deleted.

- [ ] **Step 2: Verify preserved skills**

```bash
head -5 .claude/skills/deep-research/SKILL.md
# Expected: frontmatter with "name: deep-research"
head -5 .claude/skills/first-principles-planner/SKILL.md
# Expected: frontmatter with "name: first-principles-planner"
```

---

## Task 4: Write CLAUDE.md

**Files:**
- Create: `CLAUDE.md`

- [ ] **Step 1: Write the governance summary**

```markdown
# Harness Governance

This project uses the portable harness protocol defined in `spec/`.
Role skills in `.claude/skills/harness-*.md` implement the protocol for Claude Code.

## State Machine

Tasks progress through these states in order:

```
exploring → specifying → architecting → awaiting_human_arch
  → verification_check → generating → reviewing
  → ready_for_human_close → complete
```

- Any state can transition to `blocked` (must state reason and next decision needed)
- `blocked` exits to: `verification_check`, `architecting`, or `generating`
- One active task per workspace. Parallel work uses worktrees.
- `complete` requires human confirmation.

## Gates

| # | Gate | Required Before | Key Criteria |
|---|------|----------------|-------------|
| 1 | Scoped Exploration Complete | Specifier | Entry points, write surface, test landing points, risks identified |
| 2 | Architecture Approved | Verification Check | Requirements ↔ architecture consistent, human approved |
| 3 | Verification Path Check | Generator | Validation commands executable, fallback defined |
| 4 | Independent Review | Human Close | Findings explicit, blockers resolved or accepted |
| 5 | Human Close | Complete | Human accepts residual risk, confirms objective met |

## Artifacts

Tasks produce artifacts in `.harness/`:

| Artifact | Purpose |
|----------|---------|
| `scoped-map.md` | Task-local understanding |
| `requirements.md` | Implementation contract |
| `architecture.md` | Change design |
| `verification-path.md` | Validation proof |
| `module-status.md` | Control plane (state tracking) |
| `retrospective.md` | Process lessons |

## Principles

1. **Verification before generation** — prove you can validate before writing code
2. **File-based communication** — artifacts are the source of truth, not conversation history
3. **Explicit blockers** — blocked states must name the reason and next decision
4. **Human gates** — architecture approval and task close require human confirmation
5. **Context isolation** — each role operates from artifacts, not prior role's reasoning
```

- [ ] **Step 2: Verify CLAUDE.md loads cleanly**

```bash
wc -l CLAUDE.md
# Expected: ~45-50 lines
head -3 CLAUDE.md
# Expected: "# Harness Governance"
```

- [ ] **Step 3: Commit restructure**

Commit all restructure changes together (Tasks 1-4).
Stage specific paths to avoid accidentally including unrelated files:

```bash
git add spec/ .claude/skills/deep-research .claude/skills/first-principles-planner
git add CLAUDE.md .gitignore .gitattributes .claude/settings.json
git status
# Review staged changes — verify nothing unexpected is included
git commit -m "refactor: replace baton with harness-spec-v1 protocol

- Delete old governance: constitution, hooks, phase skills, tests
- Move harness-spec-v1/ to spec/ (portable protocol)
- Preserve deep-research and first-principles-planner skills
- Write lean CLAUDE.md governance summary (~50 lines)
- Option C: protocol-first, no enforcement layer"
```

---

## Task 5: Write harness-explorer.md

**Files:**
- Create: `.claude/skills/harness-explorer.md`

- [ ] **Step 1: Write the skill file**

```markdown
---
name: harness-explorer
description: >
  Code exploration for harness tasks. Produces scoped-map.md with entry points,
  call chains, test surfaces, and risk areas. Two modes: repo-wide (first adoption)
  and task-scoped (every task). Trigger: "explore", "map the code", "understand
  the codebase", "trace the call chain", or at the start of any harness task.
user-invocable: true
---

# Explorer

> Derived from spec/protocol/role-contracts.md — Repo Explorer + Scoped Explorer

## Role Contract

**Two modes, one skill:**
- **Repo mode**: first harness adoption in a repository — map the full repo
- **Scoped mode**: every concrete task — map the task-local surface

**Inputs:**
- Repo mode: repo root, repo profile
- Scoped mode: user request, repo map or local repo context

**Outputs:**
- Repo mode: repo-map.md (optional), high-risk directories, default verification entry points
- Scoped mode: scoped-map.md (required)

## Gate: Scoped Exploration Complete

Before handing off to Specifier, all of these must be true:
- Primary entry points identified
- Likely write surface identified
- Test landing points identified
- High-risk directories called out

## Required Artifact: scoped-map.md

Sections: task statement, scope, entry points, call chain, existing behavior,
existing tests, risks, suggested next step.

## Execution Guide

### Mode Selection

- No `.harness/` exists → repo mode first, then scoped mode
- `.harness/` exists, new task → scoped mode only
- User explicitly requests full repo mapping → repo mode

### Repo Mode

1. Scan project structure — modules, packages, layers
2. Analyze dependencies — build files, package manifests
3. Identify entry points — controllers, CLI handlers, main files
4. Identify test infrastructure — test directories, fixtures, CI config
5. Mark high-risk areas — high coupling, TODOs/FIXMEs, environment-sensitive config
6. Write repo-map.md

### Scoped Mode

1. Read the user request — identify the business domain and likely code surface
2. Find entry points — grep for relevant endpoints, handlers, function names
3. Trace the call chain — from entry point through service layer to data layer
4. Identify write surface — which files need modification?
5. Find existing tests — what tests cover the current behavior?
6. Assess risks — what could break? What's fragile? What's coupled?
7. Write scoped-map.md with all required sections

## State Transition

On completion, update module-status.md:
- State → `specifying`
- Owner → `specifier`
- scoped-map.md must exist and satisfy gate criteria
```

- [ ] **Step 2: Verify**

```bash
head -5 .claude/skills/harness-explorer.md
# Expected: frontmatter with "name: harness-explorer"
grep -c "##" .claude/skills/harness-explorer.md
# Expected: 8-10 section headers
```

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/harness-explorer.md
git commit -m "feat: add harness-explorer role skill"
```

---

## Task 6: Write harness-specifier.md

**Files:**
- Create: `.claude/skills/harness-specifier.md`

- [ ] **Step 1: Write the skill file**

```markdown
---
name: harness-specifier
description: >
  Requirements specification for harness tasks. Converts exploration findings and
  user intent into explicit, checkable requirements with acceptance criteria.
  Independent of technical architecture — defines WHAT, not HOW. Trigger:
  "specify requirements", "write requirements", or after Explorer completes.
user-invocable: true
---

# Specifier

> Derived from spec/protocol/role-contracts.md — Specifier

## Role Contract

**Inputs:** user request, scoped-map.md

**Outputs:** in-scope/out-of-scope boundaries, functional requirements, acceptance criteria

**Key principle:** Independent of technical architecture. Do not make technology
choices or bind to implementation patterns. Define the problem and success criteria.

## Required Artifact: requirements.md

Sections: problem, scope (in-scope / out-of-scope), requirements (functional, per
feature), non-goals, acceptance criteria (checkbox list), constraints, validation intent.

## Execution Guide

1. Read scoped-map.md — understand the current codebase context
2. Decompose user request into independent functional requirements
3. For each requirement, derive:
   - Input and output
   - Validation rules
   - Exception scenarios
   - Boundary conditions
4. Map state transitions explicitly (if stateful behavior)
5. Identify edge cases and concurrency scenarios
6. Mark uncertain points — ask the user rather than assuming
7. For legacy systems, note interaction points with existing functionality
8. Write acceptance criteria as a checkbox list — each item independently verifiable
9. Write requirements.md

### Asking the User

Frame questions around specific ambiguities:
- "Same product configured twice — overwrite or reject?"
- "Concurrent requests both trigger the threshold — one notification or many?"

Mark confirmed decisions with 【已确认】.

### Quality Check

Before handoff, verify:
- Every requirement has at least one acceptance criterion
- Acceptance criteria are testable (by API call, by test, by inspection)
- No acceptance criterion requires reading source code to verify (behavioral, not structural)

## State Transition

On completion, update module-status.md:
- State → `architecting`
- Owner → `architect`
- requirements.md must exist with all required sections
```

- [ ] **Step 2: Verify and commit**

```bash
head -5 .claude/skills/harness-specifier.md
git add .claude/skills/harness-specifier.md
git commit -m "feat: add harness-specifier role skill"
```

---

## Task 7: Write harness-architect.md

**Files:**
- Create: `.claude/skills/harness-architect.md`

- [ ] **Step 1: Write the skill file**

```markdown
---
name: harness-architect
description: >
  Technical architecture for harness tasks. Converts requirements into
  implementation approach, module decomposition, decision records, and
  verification strategy. Trigger: "design the architecture", "write
  architecture", "technical approach", or after Specifier completes.
user-invocable: true
---

# Architect

> Derived from spec/protocol/role-contracts.md — Architect

## Role Contract

**Inputs:** scoped-map.md, requirements.md

**Outputs:** recommended implementation category, file-level impact (write surface),
validation strategy, known tradeoffs and residual risks

## Gate: Architecture Approved

Before Verification Check:
- Requirements and architecture are internally consistent
- Main approach and rejected alternatives are visible
- **Human has approved the direction**

This gate requires explicit human approval. Present the architecture and wait.

## Required Artifact: architecture.md

Sections: problem framing, first-principles decomposition, recommended approach,
surface scan, verification strategy, risks, self-challenge.

## Execution Guide

1. Read requirements.md and scoped-map.md
2. **First-principles decomposition** — break the problem into sub-problems
   independent of any specific implementation pattern
3. **Enumerate approaches** — 2-3 fundamentally different implementation
   categories (different in mechanism, not parameters). For each:
   mechanism, why it might be best, why it might fail
4. **Recommend with reasoning** — select the best approach with explicit
   tradeoff rationale. Record rejected approaches and why
5. **Module breakdown** (if applicable) — define implementation modules with
   clear boundaries, dependencies, and execution order
6. **Surface scan**:
   - Level 1: direct references (files to modify)
   - Level 2: dependency tracing (files depending on modified files)
   - Level 3: behavioral equivalence (similar patterns needing consistent changes)
7. **Verification strategy** — map requirements to validation commands or test types
8. **Self-challenge** — weakest part of this architecture? Failure conditions?
9. Write architecture.md
10. Present to human. **Do not proceed until approved.**

### Decision Records

For significant technical choices, record:
- What was chosen / what was not chosen
- Why (reasoning) / Why Not (rejection rationale)
- When to revisit this decision

Core v1: include in architecture.md. java-backend-strict extension: separate decisions.md.

## State Transition

On human approval, update module-status.md:
- State → `verification_check`
- Owner → `verifier`
- Record human approval in notes
```

- [ ] **Step 2: Verify and commit**

```bash
head -5 .claude/skills/harness-architect.md
git add .claude/skills/harness-architect.md
git commit -m "feat: add harness-architect role skill"
```

---

## Task 8: Write harness-verifier.md

**Files:**
- Create: `.claude/skills/harness-verifier.md`

- [ ] **Step 1: Write the skill file**

```markdown
---
name: harness-verifier
description: >
  Verification path check for harness tasks. Proves that intended validation
  commands are executable before implementation begins. Gate 3 — the most
  important pre-implementation checkpoint. Trigger: "verify the path", "check
  verification", "can we test this", or after Architecture is approved.
user-invocable: true
---

# Verifier

> Derived from spec/protocol/role-contracts.md — Verification Explorer

## Role Contract

**Inputs:** architecture.md, repo profile (profile.local.yaml if available)

**Outputs:** exact validation commands, proof of executability, blocking conditions

## Gate: Verification Path Check

Before Generator can start, ALL must be true:
- Exact validation commands or checks are listed
- Commands are executable in the current repo context
- Toolchain blockers are known
- Fallback validation is defined if primary path is unavailable

**Fail criteria** (any one blocks Generator):
- Test/build chain is unknown
- Validation path is blocked by environment or repo issues
- Generator would implement without a realistic verification path

## Required Artifact: verification-path.md

Sections: intended checks, commands, dependencies and prerequisites,
dry-run result, blockers, fallback strategies.

## Execution Guide

1. Read architecture.md — extract the verification strategy
2. **List intended checks** — for each requirement/module, what concrete command
   verifies it? Be specific: `mvn -pl module test`, `pytest path/`,
   `curl localhost:8080/api/...`, not "run the tests"
3. **Check prerequisites**:
   - Build tool exists and works? (`mvn -v`, `npm -v`, `pytest --version`)
   - Dependencies installable?
   - Test infrastructure functional? (fixtures, test DB, etc.)
4. **Dry-run** — execute the validation commands (or a safe subset) now.
   Record output. If tests exist: run them, note baseline. If build works:
   compile, note clean/dirty. If commands fail: this is a blocker.
5. **Identify blockers** — any reason validation won't work during implementation?
6. **Define fallback** — if primary path is blocked, what's the alternative?
7. Write verification-path.md

### The Core Question

This role answers: **"If Generator writes the code correctly, can we prove
it works?"** If the answer is no or uncertain — the task is blocked.

## State Transition

On pass, update module-status.md:
- State → `generating`
- Owner → `generator`

On fail, update module-status.md:
- State → `blocked`
- Blocker type → `verification_blocker`
- Document what's blocked and what's needed
```

- [ ] **Step 2: Verify and commit**

```bash
head -5 .claude/skills/harness-verifier.md
git add .claude/skills/harness-verifier.md
git commit -m "feat: add harness-verifier role skill"
```

---

## Task 9: Write harness-generator.md

**Files:**
- Create: `.claude/skills/harness-generator.md`

- [ ] **Step 1: Write the skill file**

```markdown
---
name: harness-generator
description: >
  Code implementation for harness tasks. Implements approved changes following
  architecture, verification strategy, and decision records. Works by module
  or bounded context with compile/test checkpoints. Trigger: "implement",
  "generate code", "write the code", or after Verification Path Check passes.
user-invocable: true
---

# Generator

> Derived from spec/protocol/role-contracts.md — Generator

## Role Contract

**Inputs:** approved requirements.md, approved architecture.md, verified verification-path.md

**Outputs:** code changes, local execution notes, updated module-status.md

## Precondition

Do not begin without a passing verification-path.md. If it doesn't exist
or has unresolved blockers, hand back to Verifier.

## Execution Guide

### Reading Phase

1. Read architecture.md — module breakdown and execution order
2. Read requirements.md — what each module must achieve
3. Read verification-path.md — how to validate your work
4. Read decisions.md if it exists — respect approved technical choices

### Implementation Phase

For each module (or the full task if no module breakdown):

1. **Scope** — identify files to create/modify
2. **Implement in batches** — group related files (data layer → service → API).
   Keep batches to 3-5 related files
3. **Checkpoint** — after each batch, run relevant validation command from
   verification-path.md. Fix before moving on
4. **Commit** — each passing checkpoint gets a git commit

### Constraint Rules

1. **Do not modify requirements.md or decisions.md** — if you find a design
   problem, document it, don't silently fix it
2. **Stick to the approved write surface** — if you need to modify a file not
   in architecture.md, note it before proceeding
3. **Minimize changes in high-risk areas** — if scoped-map.md flagged it,
   make the smallest possible change
4. **Migration/DDL scripts are drafts** — mark as requiring human review

### Architecture Mismatch

If architecture doesn't fit during implementation:
- Minor (parameter names, utility placement) → proceed, note for review
- Structural (wrong boundary, missing dependency, approach fails) → stop,
  update module-status.md to `blocked`, document the mismatch

## State Transition

On completion, update module-status.md:
- State → `reviewing`
- Owner → `evaluator`
- All validation commands from verification-path.md must pass
```

- [ ] **Step 2: Verify and commit**

```bash
head -5 .claude/skills/harness-generator.md
git add .claude/skills/harness-generator.md
git commit -m "feat: add harness-generator role skill"
```

---

## Task 10: Write harness-evaluator.md

**Files:**
- Create: `.claude/skills/harness-evaluator.md`

- [ ] **Step 1: Write the skill file**

```markdown
---
name: harness-evaluator
description: >
  Independent evaluation for harness tasks. Reviews implementation against
  requirements, runs verification, produces findings-first assessment. Operates
  in separate context from Generator. Trigger: "evaluate", "review the
  implementation", "check the code", or after Generator completes.
user-invocable: true
---

# Evaluator

> Derived from spec/protocol/role-contracts.md — Reviewer + Evaluator (deliberately
> merged: both are independent-from-Generator assessments at different depths)

## Role Contract

**Inputs:** changed files (diff), requirements.md, architecture.md, verification-path.md

**Outputs:** findings (explicit, specific, actionable), residual risks, go/no-go conclusion

## Gate: Independent Review

Before Human Close:
- Findings are explicit
- Blockers are either fixed or accepted
- No unresolved contradiction between implementation and requirements

## Execution Guide

### Context Independence

Operate with fresh context. Read artifacts and the diff — form your own
assessment. Do not carry over Generator's reasoning.

### Layer 1: Deterministic Checks

Run verification commands from verification-path.md:
- Compile/build → must pass
- Existing tests → must pass (no regressions)
- New tests → must pass

Any failure here stops evaluation. Report and hand back to Generator.

### Layer 2: Diff Review

- Does the diff match what architecture.md prescribed?
- Unexpected changes outside approved write surface?
- Obvious bugs, missing error handling, security issues?
- Consistency with existing codebase patterns?

### Layer 3: Requirements Verification

Walk through requirements.md acceptance criteria:
- For each criterion: is it met? How do you know?
- Mark: ✅ met (evidence) / ❌ not met (reason) / ❓ cannot verify
- Identify missing edge cases or untested scenarios

### Output Format

```
## Evaluation Summary

**Verdict**: PASS / PASS WITH WARNINGS / BLOCKED

### Blockers (must fix)
- [issue with file:line and what's wrong]

### Warnings (should fix)
- [issue with reasoning]

### Acceptance Criteria
- [x] Criterion 1 — ✅ verified by [how]
- [ ] Criterion 2 — ❌ [what's missing]

### Residual Risks
- [risks human should know]
```

### Repair Loop

If blockers found:
1. Write findings → Generator fixes → re-evaluate
2. After 3 blocked rounds → escalate to human

Warnings do not block unless they threaten correctness or deployment safety.

### java-backend-strict Extension

When active, add between Layer 1 and Layer 3:
- Runtime signal collection (SQL logs, transactions, performance, Spring runtime)
- Source independence: derive expectations from requirements, not Generator's code

## State Transition

On PASS, update module-status.md:
- State → `ready_for_human_close`
- Owner → `human`

On BLOCKED, update module-status.md:
- State → `blocked`
- Owner → `generator`
- Write findings to evaluation-report.md or review-notes.md
```

- [ ] **Step 2: Verify and commit**

```bash
head -5 .claude/skills/harness-evaluator.md
git add .claude/skills/harness-evaluator.md
git commit -m "feat: add harness-evaluator role skill"
```

---

## Task 11: Write README.md

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write the repo overview**

```markdown
# Baton Harness

A portable AI coding agent collaboration protocol with a Claude Code reference implementation.

Based on [Anthropic's harness design for long-running apps](https://www.anthropic.com/engineering/harness-design-long-running-apps).

## Structure

```
spec/              Portable harness protocol (tool-agnostic)
.claude/skills/    Claude Code role skills (reference implementation)
CLAUDE.md          Governance summary loaded into every conversation
```

## Protocol

The protocol defines a closed loop for AI-assisted coding tasks:

**Explorer** → **Specifier** → **Architect** → human approval → **Verifier** → **Generator** → **Evaluator** → human close

Each role produces file-based artifacts in `.harness/`. State is tracked in `module-status.md`.

See [spec/README.md](spec/README.md) for the full portable protocol.

## Quick Start

### Adopt in a new repo

```bash
# Bootstrap .harness/ directory with templates
spec/bootstrap/init-harness.sh --repo-root /path/to/repo --profile auto --adapter claude-code

# Start a task
spec/bootstrap/start-task.sh --repo-root /path/to/repo --task-id my-task
```

### Copy role skills to target repo

```bash
cp .claude/skills/harness-*.md /path/to/repo/.claude/skills/
```

## Role Skills

| Skill | Role | Gate |
|-------|------|------|
| `harness-explorer` | Code exploration (repo + scoped) | Scoped Exploration Complete |
| `harness-specifier` | Requirements specification | — |
| `harness-architect` | Technical architecture | Architecture Approved (human) |
| `harness-verifier` | Verification path check | Verification Path Check |
| `harness-generator` | Code implementation | — |
| `harness-evaluator` | Independent evaluation | Independent Review |

## Capability Skills

| Skill | Purpose |
|-------|---------|
| `deep-research` | Systematic investigation of code, APIs, docs |
| `first-principles-planner` | Strategic planning from first principles |
```

- [ ] **Step 2: Verify and commit**

```bash
head -3 README.md
git add README.md
git commit -m "docs: add repo README"
```

---

## Task 12: Fix spec internal references

**Files:**
- Modify: `spec/README.md` — update directory path from `docs/harness-spec-v1/` to `spec/`
- Modify: `spec/extensions/java-backend-strict/README.md` — fix absolute paths to relative
- Modify: `spec/extensions/java-backend-strict/artifact-overlay.md` — fix absolute paths to relative

- [ ] **Step 1: Fix spec/README.md**

Two fixes needed:
1. Change `docs/harness-spec-v1/` references to `spec/` in the directory listing
2. Fix absolute path on line ~131 (java-backend-strict link): replace
   `/C:/Users/hexin/Desktop/project/fundsalesmrksupport/docs/harness-spec-v1/extensions/java-backend-strict/README.md`
   with `./extensions/java-backend-strict/README.md`

- [ ] **Step 2: Fix extension absolute paths**

In `spec/extensions/java-backend-strict/README.md` and `spec/extensions/java-backend-strict/artifact-overlay.md`,
replace ALL absolute paths like `/C:/Users/hexin/Desktop/project/fundsalesmrksupport/docs/harness-spec-v1/...`
with relative paths (e.g., `./artifact-overlay.md`, `./templates/codebase-map.template.md`).

- [ ] **Step 3: Verify and commit**

```bash
grep -r "C:/Users" spec/ | head -5
# Expected: no results
git add spec/
git commit -m "fix: update internal references after restructure"
```

---

## Task 13: Final verification

- [ ] **Step 1: Verify repo structure**

```bash
echo "=== Root ==="
ls -la *.md
echo "=== Spec ==="
ls spec/
echo "=== Protocol ==="
ls spec/protocol/
echo "=== Skills ==="
ls .claude/skills/
echo "=== Bootstrap ==="
ls spec/bootstrap/
```

Expected:
- Root: `CLAUDE.md`, `README.md`
- Spec: `11.md`, `README.md`, `adapters/`, `bootstrap/`, `extensions/`, `profiles/`, `protocol/`, `templates/`
- Protocol: `artifact-schema.md`, `gates.md`, `role-contracts.md`, `state-machine.md`
- Skills: `deep-research/`, `first-principles-planner/`, `harness-architect.md`, `harness-evaluator.md`, `harness-explorer.md`, `harness-generator.md`, `harness-specifier.md`, `harness-verifier.md`
- Bootstrap: `init-harness.md`, `init-harness.ps1`, `init-harness.sh`, `start-task.md`, `start-task.ps1`, `start-task.sh`

- [ ] **Step 2: Verify no old baton artifacts remain**

```bash
echo "=== Should not exist ==="
ls constitution.md 2>&1
ls .baton/ 2>&1
ls hooks/ 2>&1
ls tests/ 2>&1
ls AGENTS.md 2>&1
# All should show "No such file or directory"
```

- [ ] **Step 3: Verify no broken references**

```bash
grep -r "constitution.md" . --include="*.md" | grep -v ".git" | grep -v "spec/11.md"
# Expected: no results (11.md may mention it in historical context, that's fine)
grep -r "BATON:GO" . --include="*.md" | grep -v ".git"
# Expected: no results
grep -r "C:/Users" spec/ --include="*.md"
# Expected: no results
```
