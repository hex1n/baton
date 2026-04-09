# Baton v2 Protocol

## Three Assumptions

This harness encodes exactly three assumptions about what AI cannot do reliably:

1. **AI cannot evaluate its own work honestly** → independent Verifier, never reads Builder's code
2. **AI loses coherence over long tasks** → file-based communication, context resets between roles
3. **Requirements emerge through building** → round-based progressive elaboration, not upfront specification

Everything else, the model handles on its own. If a component doesn't map to one of these assumptions, it shouldn't exist.

## Document Hierarchy

This file is the single source of truth for all protocol rules. Other files derive from it:

| File | Role | Rule: when protocol.md changes… |
|------|------|--------------------------------|
| `v2/protocol.md` | **Source of truth** | — |
| `v2/skills/*.md` | Execution instructions | Sync any referenced rules, modes, thresholds |
| `v2/templates/*.md` | Artifact structure | Sync field values (modes, formats) |
| `README.md` / `README.zh-CN.md` | Projection layer (mental model) | Sync simplified descriptions; never restate exact thresholds — reference protocol.md |
| `v2/CLAUDE.md` | Entry index | Sync summary rules; reference protocol.md for details |
| `CONTRIBUTING.md` | Change policy | Sync repository-layer boundaries and validation expectations for core changes |

**When adding or changing a rule:** update protocol.md first, then propagate to the files above. If a downstream file contradicts protocol.md, protocol.md wins.

**Verify consistency:** run `bash v2/tools/check-consistency.sh` after protocol changes. It checks execution modes, verifier modes, companion files, projection-layer rules, live round-contract linting, language neutrality, and Baton's contract tests.

## Repository Layers

Keep Baton split into three layers:

| Layer | Location | Purpose |
|-------|----------|---------|
| **Core** | `v2/` | General-purpose Baton protocol, public roles, templates, and validators |
| **Companion** | root `skills/` | Optional supporting skills that may help research or planning, but are not part of the Baton core loop |
| **External adapters / plugins** | `v2/tools/` wrappers or separate repos/plugins | Host-specific or provider-specific integrations kept outside the protocol core |

If a change is project-specific, domain-specific, or primarily about one host/provider, it belongs in a companion skill, adapter, or separate plugin — not in Baton core.

## Change Governance

Protocol files, public role files, templates, validators, and projection-layer docs are behavior-shaping files. Changing them is equivalent to changing code that controls agent behavior.

For behavior-shaping changes:

1. Update `v2/protocol.md` first if the rule itself changed
2. Sync all affected downstream files in the same change
3. Record an eval note in the task / commit / PR describing the problem, changed behavior, validation commands, and residual risk
4. Prefer one behavior problem per change instead of bundled rewrites

## Task Classification

Every round carries four planning inputs in `plan.md § Metadata`:

| Field | Meaning |
|-------|---------|
| `Scope Class` | How large and coupled the round is |
| `Risk Class` | How costly a mistake would be |
| `Expected Rounds` | Forecast for how many Baton rounds the full task will likely need |
| `Expected Slices This Round` | Forecast for how many Builder implementation slices this round will likely use |

These fields explain the round. They do not replace `Verifier Mode` or `Execution Mode`.

### Scope Class

| Class | Meaning |
|-------|---------|
| `S1` | Single-round, single-slice, local change with clear boundaries |
| `S2` | Single-round, multi-slice work with clear boundaries |
| `S3` | Multi-module or dependency-chain work with meaningful coordination cost |
| `S4` | Multi-round, cross-boundary work where requirements are likely to keep evolving during delivery |

### Risk Class

| Class | Meaning |
|-------|---------|
| `R1` | Low risk, easy to roll back, impact stays local |
| `R2` | Medium risk, affects core logic, shared state, or existing behavior |
| `R3` | High risk, involves security, migrations, public interfaces, or irreversible side effects |

### Forecast Fields

`Expected Rounds` and `Expected Slices This Round` are forecasts, not task labels. They help humans and Dispatcher reason about likely shape and cost, but do not override the actual artifact state. Forecasts still feed the round-load guard, because overload is a coordination failure mode, not a replacement for `Execution Mode`.

If `Expected Slices This Round = 3+` on a `Full`-mode round or a round classified `S4` / `R3`, Planner must justify the single-round budget in `plan.md § Round Contract → Budget Note` and leave `Overload Override = none` unless a human-approved exception is already recorded.

### Planning Depth

Planner must classify whether the round needs normal planning or a deepen pass.

| Depth | Meaning |
|-------|---------|
| `normal` | Problem is well-understood, solution space is narrow, and the round does not need substantial search before Builder starts |
| `deepen` | The round needs stronger first-principles search before implementation because the framing or solution space is still load-bearing |

Default deepen triggers:

- `Scope Class = S3/S4`
- `Risk Class = R2/R3`
- the round changes protocol / validators / control-plane behavior
- the user stated a solution more clearly than the underlying problem
- multiple viable approaches obviously exist

`Planning Depth` is not an execution mode. It controls how much search Baton requires before Builder starts. On deepen rounds, Planner must fill `plan.md § Plan Quality`, Verifier must assess search adequacy during pre-flight, and Dispatcher must support a `deepen` route before Builder starts.

### Round Load Guard

Verifier pre-flight must classify each round as `normal`, `heavy`, or `overloaded` and record the result in `review.md § Pre-flight` and `review.md § Routing Signals`.

Default classification:

- `normal` — the round should fit one Builder pass and one verification pass without unusual coordination pressure
- `heavy` — notable load exists, but the overload condition below is not met
- `overloaded` — all of:
  - `Expected Slices This Round = 3+`
  - verifier pressure is elevated: `Verifier Mode = C/C+` or selected `Verification Add-ons != none`
  - uncertainty or blast radius is elevated: `Scope Class = S4`, `Risk Class = R3`, or `plan.md § Exploration Boundary` contains `⚠️ GAP`

If `Round Load = heavy`, Dispatcher must surface a budget warning at approval.

If `Round Load = overloaded` and `plan.md § Round Contract → Overload Override != human-approved`, Dispatcher must not start Builder. The human must either:

1. ask Planner to split / reduce the round, then re-run pre-flight
2. explicitly approve the single-round exception, have Planner record `Overload Override = human-approved` and refresh `Budget Note`, then re-run pre-flight before Builder starts

### Default Execution-Mode Mapping

Dispatcher chooses `Execution Mode` after Planner writes the round classification. Default mapping:

| Signals | Default mode |
|---------|--------------|
| `S1 + R1 + Verifier Mode A/B`, `≤5` ACs, `Expected Slices This Round = 1` | Compact candidate |
| `S2` or `S3`, with `R1` or `R2` | Standard |
| `S4`, `R3`, or `Verifier Mode C/C+` | Full |

`Execution Mode` is an orchestration decision derived from classification, verifier capability, and human preference. `Verifier Mode` remains the evidence environment; it is not a task size label. In `Full` mode, the Verifier add-on envelope is available, but the specific add-ons activated for the round are selected during pre-flight and recorded in `review.md § Routing Signals`. `Round Load` is a separate admission-control judgment, not a fourth execution mode.

## Execution Modes

The harness supports three execution modes. Dispatcher selects after reading the round classification in `plan.md § Metadata`; human can override.

### Compact Mode (simple low-risk rounds: typically `S1 + R1`)

Planner and Builder merge into one execution. Verifier role is replaced by a self-check checklist + human review.
- **No context isolation** — planning and building happen in the same conversation
- **No independent Verifier** — Builder self-verifies against a checklist; human provides the independent review
- **Lower cost** — no subagent overhead, no separate Verifier invocations
- **Verifier add-ons:** none (self-check only)

```
Compact mode flow:
  1. Planner+Builder: understand → design → implement → test → self-check
  2. Self-check (Builder runs before handing off to human):
     □ All ACs have corresponding tests?
     □ All tests pass (test command from project-profile.md)?
     □ No new failures vs baseline?
     □ Test assertions actually match AC requirements?
  3. Write review.md (marked as "self-check, not independent verification")
  4. Human reviews review.md + code changes
```

**Why no fake Verifier:** Assumption ① says AI can't self-evaluate. In compact mode, the Verifier shares Builder's context — making it structurally non-independent. Rather than pretend, compact mode is honest: Builder self-checks, human provides the real independent review.

### Standard Mode (medium rounds: typically `S2/S3` with `R1/R2`)

Each role runs as an independent subagent. Verifier runs **core steps only** — deterministic verification + AC coverage. No cross-model review, no adversarial testing, no structural triggers.
- **Full context isolation** — each role starts fresh, reads only from artifacts
- **Verifier independence guaranteed** — cannot see Builder's process, only results
- **Moderate cost** — subagent overhead, but Verifier reads ~50% less than Full mode
- **Verifier add-ons:** `[core]` only

```
Dispatcher (main conversation)
  → spawn Agent: Planner → writes plan.md
  → spawn Agent: Verifier pre-flight (core) → writes review.md
  → human approves
  → spawn Agent: Builder → writes code + tests
  → spawn Agent: Verifier verification (core) → writes review.md
```

### Full Mode (complex, high-risk, or degraded-evidence rounds)

Same as Standard, but Dispatcher may activate **selected add-on files** for the round — cross-model review, adversarial testing, or other protocol-defined Verifier add-ons. Use when: task is security-sensitive, multi-round, or operates in Mode C/C+.
- **Full context isolation** — same as Standard
- **Verifier runs selected add-on files** — deeper verification when the round warrants it
- **Higher cost** — Verifier reads full SKILL.md, may invoke external reviewer
- **Verifier add-ons:** `[core]` + selected add-on steps

**When to use which mode:**

| Signal | Mode |
|--------|------|
| `S1 + R1 + Mode A/B`, `≤5` ACs, single slice | Compact |
| `S2/S3` with `R1/R2` | Standard |
| `S4`, `R3`, `Mode C/C+`, or human requests it | Full |

**Dispatcher selects the mode** from `plan.md § Metadata`, `project-profile.md`, and the human's preference. Human can override.

## Roles

Three public roles. No more.

### Planner

Understands the codebase, identifies load-bearing requirement questions, designs the technical approach, and records human decisions for Dispatcher to ask.

- **Reads:** project-profile.md, plan.md (all rounds), relevant source code
- **Writes:** plan.md (creates Round 1 or appends Round N)
- **Runs:** once per round; re-invoked if Verifier escalates a design issue
- **Context:** fresh subagent per invocation; plan.md carries continuity

### Builder

Implements code and writes tests. The only role that modifies source code.

- **Reads:** project-profile.md (conventions, traps), plan.md (current round only)
- **Writes:** source code, tests, plan.md § AC → Test Mapping, § Commit Checkpoints, § Discoveries
- **Runs:** once per round; may re-run after Verifier code-fix feedback
- **Context:** fresh subagent per round; reads plan.md + relevant source for context
- **Optional internal delegation:** in Standard/Full mode, Builder may delegate one approved implementation slice or fix slice to an internal worker, but Builder remains responsible for every canonical write and handoff

### Verifier

Independently verifies implementation quality. Challenges plan quality before build.

- **Reads:** project-profile.md, plan.md (current round ACs), test results, runtime signals
- **Does NOT read:** Builder's source code during verification mode
- **Writes:** review.md only
- **Runs:** twice per round (pre-flight before build, verification after build)
- **Context:** isolated subagent; plan.md + observed behavior only
- **Boundary:** never modifies source code, tests, or the working tree as part of verification

## Builder Delegation

Builder may optionally use internal workers in Standard/Full mode. This is an implementation detail inside Builder, not a fifth Baton role.

- **Compact mode:** no delegation. Compact mode is a single-context self-check path.
- **Scope unit:** one approved implementation slice or one fix slice at a time. Internal workers may not widen scope, reinterpret ACs, or invent new work.
- **Canonical ownership:** only Builder writes source code/tests in the shared workspace and only Builder updates `.harness/plan.md`.
- **Scratch only:** worker packets, reports, and temporary patches belong under `.context/baton/active/`. Dispatcher and recovery flows never route from them directly.
- **No control-plane authority:** internal workers may not ask the human directly, update `.harness/review.md`, invoke external review, or change execution mode.
- **Escalation stays normal:** if a worker reports missing context, scope confusion, or a design blocker, Builder routes back through Planner or Human using the normal Baton artifact flow.

## Artifacts

### project-profile.md — project level, persistent

- **Location:** project root (not in .harness/)
- **Maintained by:** human; Planner can generate initial draft on first task
- **Contains:** build commands, test infrastructure, conventions, known traps, Verifier capability mode
- **Read by:** all roles at the start of every invocation
- **Lifecycle:** lives across tasks, updated occasionally

### .harness/plan.md — task level, living document

- **Location:** .harness/
- **Maintained by:** Planner (structure, ACs, approach); Builder (§ Discoveries only)
- **Contains:** task metadata, round classification + forecasts, round-by-round acceptance criteria, `§ Plan Quality`, `§ Round Contract` (including budget rationale and any overload override), approach, decisions, `§ Open Decisions`, implementation slices, checkpoints, discoveries
- **Lifecycle:** created at Round 1, appended each round, archived to .harness/archive/ at task end
- **Structured control-plane field:** `§ Open Decisions` is the only place Planner records unresolved human choices. Dispatcher reads this section literally instead of inferring questions from narrative text.
- **Structured round field:** `§ Round Contract` is the explicit agreement for what this round delivers, what stays out of scope, which key entry points must remain in scope, how Verifier should check it, and what threshold counts as done.
- **Compression:** Planner compresses at the START of each new round (not end of previous), so Verifier has full info during verification. Compression rules per section:
  - § Round History: summary + key decisions + unresolved discoveries (not just one-line)
  - § Context: only keep entries relevant to current/future rounds
  - § Scope Breakdown: completed features marked ✅, descriptions collapsed
  - § Discoveries: items absorbed into design marked [absorbed], only open items remain
- **Compression quality guard — never compress away:**
  - Decisions that constrain future rounds (e.g., "chose sync over async" limits Round 3 options)
  - Unresolved discoveries (even if they seem minor — future rounds may re-evaluate)
  - Exploration boundary GAP entries (they carry forward until explicitly addressed)
  - The reason an approach was rejected (not just which was chosen)
  - If unsure whether to keep or compress an item, keep it

### .harness/review.md — round level, archived per round

- **Location:** .harness/
- **Maintained by:** Verifier (writes), Dispatcher (archives)
- **Contains:** pre-flight results, verification findings, human judgment, `§ Routing Signals` (including verify-pass add-on selection, plan-quality assessment, and round-load assessment), and an optional findings-sidecar pointer
- **Lifecycle:** Verifier writes review.md for current round. Before starting a new round, Dispatcher copies review.md → review-round-{N}.md to preserve history. Previous rounds' reviews are always available in .harness/ without needing git.
- **Round tag:** review.md header must include `# Review: Round {N}` so Dispatcher can compare against plan.md's current round
- **Structured control-plane field:** `§ Routing Signals` is the only place Verifier tells Dispatcher what should happen next (`builder / planner / human / closeout`), whether human review is required, which verify-pass add-ons to activate, whether the plan is `adequate / under-searched`, and whether the round is `normal / heavy / overloaded`.

### .context/baton/ — scratch state, non-canonical

- **Location:** `.context/baton/active/`
- **Maintained by:** tools and role add-on files
- **Contains:** raw external-review outputs, temporary exploration notes, normalized findings sidecars, Builder slice packets, worker reports, and optional temporary patches
- **Read by:** humans and optional tooling; Dispatcher never routes from scratch files
- **Lifecycle:** ephemeral for the active task. Closeout may copy it into the archive as scratch history, but Baton control flow never depends on it.
- **Rule:** if information matters for routing, approval, or recovery, it must also be summarized in `.harness/plan.md` or `.harness/review.md`

## Round Lifecycle

Every task is a sequence of rounds. Simple tasks complete in one round. Complex tasks unfold over many.

```
Round N:
  1. Planner    → writes/updates plan.md with this round's metadata classification,
                    forecasts, ACs, and planning depth
                    + `§ Plan Quality` when the round needs deeper search
                    + `§ Open Decisions`
                    + `§ Round Contract`
                    + `§ Implementation Slices`
  2. Verifier   → pre-flight (testability + baseline + round-contract challenge)
                    + plan-quality / search-adequacy assessment
                    + verify-pass add-on recommendation
                    + round-load assessment (`normal / heavy / overloaded`)
                    + contract agreement / revision
                    + `§ Routing Signals`
  3. Human      → resolves Open Decisions, then approves / deepens / revises / splits the round
                    or records a single-round overload override before Builder starts
  4. Builder    → implements code + tests in slices
  5. Verifier   → verification (Tier 1 → Tier 2 → Tier 3)
                    + selected add-on passes when activated
                    + `§ Routing Signals`
  6. Resolution → Dispatcher routes from review.md § Routing Signals
  7. Completion → optional human tag / checkpoint after the round is accepted
  8. Human      → continue / change scope / close out
```

Steps 4-6 may iterate (Builder ⇄ Verifier) up to 3 times before escalation.

## Feedback Paths

Four paths, three speeds:

| Path | Trigger | Speed |
|------|---------|-------|
| Verifier → Builder | Code bug, test failure | Minutes (inner loop) |
| Verifier → Planner | Design flaw, approach doesn't work | Hour (middle loop) |
| Builder → Planner | Discovered new info that changes the plan | Hour (middle loop shortcut) |
| Anyone → Human | Requirement gap, ambiguity, irreversible decision | Async (outer loop) |

**Escalation rule:** If the same issue survives 3 Builder ⇄ Verifier cycles, auto-escalate one level up (code → design → requirement → human). See Rule 5.

## Human Checkpoints

Only at decision points. Never for status updates. Planner and Verifier write structured decision / routing fields into artifacts; Dispatcher is the only role that asks the human. All human interactions use `AskUserQuestion` with explicit options.

| When | What human sees | AskUserQuestion options |
|------|----------------|------------------------|
| After Planner + Verifier pre-flight | plan.md § Open Decisions + § Plan Quality + § Round Contract + pre-flight challenges + verify-pass add-ons + plan-quality assessment + round-load assessment | resolve decisions, then approve / deepen / split / override / revise / reject |
| After Round completion | review.md § Human Judgment + § Routing Signals | continue / change scope / close out |
| Migration generated | Migration / schema change script | approve / reject |
| 3x Builder ⇄ Verifier without resolution | Failure history | change approach / change scope / abandon task |
| Recover existing task | Task status summary | continue current task / reset task / abandon task |

## Lifecycle Terms

Use these names consistently across the protocol and skill layer:

| Term | Meaning | Replaces |
|------|---------|----------|
| **Task Recovery** | Re-enter an in-progress task from artifact state after a pause, crash, or resumed session | `resume` |
| **Scope Change** | Add or revise requirements without discarding already completed work unless the human explicitly resets the task | `add requirement` |
| **Task Closeout** | Finalize a completed task: optional PR/update prompts, then archive artifacts as the terminal step | `done` / `archive-time` |

`archive` is an implementation detail of Task Closeout, not the user-facing concept.

## Verifier Verification Modes

Detected during pre-flight. Recorded in project-profile.md for future rounds.

### Evidence Levels

Verifier evidence is classified by independence from Builder:

| Level | Description | Examples |
|-------|------------|---------|
| **L1** Independent | Builder cannot influence the outcome | Test pass/fail, runtime behavior, compile results |
| **L2** Auditable | Builder produced it, but Verifier can verify | Test code quality, AC→test mapping |
| **L2.5** Cross-model | A different model reviews Builder's output | External reviewer configured in project-profile.md § External Reviewer and invoked through `v2/tools/external-review.sh` |
| **L3** Non-independent | Same model reviews same model's output | Production code review, AI judgment |

L2.5 exists because cross-model review has different blind spots from Builder — it is structurally more independent than L3, but still AI judgment (not deterministic like L1). It is only available when project-profile.md configures an external reviewer.

**Cross-examination rule:** L2.5 findings are never accepted blindly. Verifier must cross-examine each finding against codebase evidence and classify as confirmed (✅ with file:line proof), plausible (⚠️ needs human), or rejected (❌ with reason). This produces higher-quality signal than either model alone — the external reviewer catches what the primary model misses, the primary model grounds or filters what the external reviewer claims.

### Mode Table

| Mode | What works | Tier 1 (L1) | Tier 2 (L1) | Tier 3 (L2+L3) |
|------|-----------|-------------|-------------|----------------|
| **A** Full runtime | App starts + services accessible | compile + test | Runtime behavior verification | Test quality audit (L2) + AI judgment (L3) |
| **B** Partial | Some services, app won't start | compile + test | Partial runtime assertions | Test quality audit (L2) + AI judgment (L3) |
| **C** Static | Only build tool works | compile + test | — | Test quality audit (L2) + production code review (L3) + AI judgment (L3) |
| **C+** Static + external reviewer | Build tool + external AI reviewer | compile + test | — | Test quality audit (L2) + cross-model code review (L2.5) + AI judgment (L3) |

**Mode C explicitly permits reading production code** — without runtime evidence, code review is the only deep verification available. This is an honest degradation, not a contradiction.

**Mode C+ upgrades code review independence** by delegating production code review to an external reviewer (configured in project-profile.md § External Reviewer and invoked through `v2/tools/external-review.sh`). The external model has different training and blind spots, breaking the "same model evaluates same model" problem. See `verifier/cross-model.md` for the adapter workflow. C+ is not as strong as Mode A/B (still AI judgment, not deterministic), but is meaningfully more independent than C.

**review.md must state which mode was used and the evidence level distribution.** Mode B/C must include: "⚠️ Verification independence: degraded — human review weight is higher."

## Test Baseline Protocol

Flaky tests are reality. The harness handles them.

1. **Before Builder starts:** Verifier runs the project's test command (from project-profile.md) on unmodified code → records pass/fail/skip with test IDs
2. **After Builder completes:** Verifier runs the same test command again → compares to baseline
3. **Only NEW failures count** as Builder-introduced issues
4. **Baseline failures** are listed in review.md but do not block

## Git Strategy

**AI must not run git commands that mutate the repository** (index, working tree, history, or remote state). All mutating operations (commit, push, add, reset, etc.) are human-operated. AI may only run read-only git commands that inspect state without changing anything.

**Builder signals commit checkpoints** after each passing slice by recording them in plan.md. The human commits at their discretion.

**Recommended workflow** (human-operated):
- Create feature branch before Round 1
- Commit after each slice checkpoint: `git commit -m "round-{N} slice {M}: {description}"`
- Tag after each successful round if you use tags: `git tag round-N-accepted`
- Create PR during task closeout if needed

**Rules:**
- Never force push
- Never commit directly to main/master for code changes
- `git add` specific files, not `git add -A`
- Never commit failing code

## Independence Rule

**Verifier prioritizes higher-level evidence.** The goal is not "never read code" — it is "evaluation evidence should not be controlled by the party being evaluated."

- **Mode A/B:** Verifier does NOT read Builder's production code. L1 evidence (test results, runtime behavior) is sufficient.
- **Mode C:** Verifier MAY read production code (L3) because no runtime evidence exists. review.md must declare this degradation.
- **Mode C+:** Verifier delegates production code review to an external reviewer through the adapter (L2.5). Verifier still reads test files and coordinates, but the code judgment comes from a different model. review.md must state "Cross-model review (L2.5)" for those findings.
- **All modes:** Verifier MAY read test files (L2) to audit test quality, but must independently judge whether tests actually verify ACs — not just trust Builder's AC→test mapping.
- **All verifier techniques must be read-only.** No mutation testing, temporary source edits, or rescue-style fixes during verification. If stronger proof requires code changes, route back to Builder with a concrete finding.

**Pre-flight CAN always read source code** — pre-flight is a planning review (challenging the approach), not a code review (evaluating the implementation).

This prevents the "self-evaluation leniency" problem while being honest about what's possible in degraded environments.

## Protocol Tags

Tags are exact strings used across artifacts for mechanical detection by Dispatcher. Roles must use these exact tags — Dispatcher scans for them literally, not semantically.

| Tag | Where | Set by | Detected by | Meaning |
|-----|-------|--------|-------------|---------|
| `⚠️ LOW CONFIDENCE: {what}` | plan.md, review.md | Any role | Dispatcher | Uncertain assumption, needs human verification |
| `⚠️ GAP` | plan.md § Exploration Boundary | Planner | Dispatcher | Unexplored area that might be affected |
| `[assumed — verify]` | plan.md § ACs | Planner | Dispatcher | AC depends on unconfirmed assumption, blocks Builder |
| `[diverges from human choice]` | plan.md § Decisions | Planner | Dispatcher | Planner overrode a human's explicit selection |
| `[deferred — Mode C]` | plan.md § AC → Test Mapping | Builder | Verifier | Test compiles but run-verification skipped (no runtime) |
| `[boundary update]` | plan.md § Discoveries | Builder | Planner | New module found that wasn't in exploration boundary |

**When adding a new protocol tag:** define it in this table first, then reference it from SKILL.md files. Tags are protocol-level contracts, not role-level conventions.

## Confidence Signals

All three roles share the same AI model. Shared blind spots are a systemic risk. Confidence signals are the escape hatch.

**When to signal low confidence:**
- Planner is uncertain about a fundamental technical assumption (e.g., "I think this framework supports X but haven't verified")
- Verifier cannot determine whether an AC is truly satisfied (evidence is ambiguous)
- Builder discovers the approach may not work but isn't certain

**How to signal:**
- In plan.md or review.md, annotate: `⚠️ LOW CONFIDENCE: {what}. Reason: {why}. Suggest: {what human should verify}`

**Protocol-level trigger:**
- If both Planner and Verifier independently flag the same assumption as low-confidence → mandatory human review before proceeding
- Dispatcher detects low-confidence markers and adds them to AskUserQuestion options

**Structural triggers (fire automatically, no AI judgment needed):**
- Planner's § Exploration Boundary has any `⚠️ GAP` entry → Dispatcher adds to AskUserQuestion
- Verifier pre-flight found ≥2 [Correctness] or [Completeness] challenges → Dispatcher flags to human
- Any AC marked `[assumed — verify]` not yet confirmed → Dispatcher blocks Builder start
- Mode C verification → Dispatcher enforces mandatory human code review checkpoint (not just advisory)

## Failure Recovery

| Scenario | Response |
|----------|----------|
| Compilation fails 3x on same slice | Builder re-reads the original files, rewrites the slice from scratch, and only escalates if the regenerated slice still fails. If human has committed a checkpoint, human may `git reset` to recover. |
| Verifier rejects Builder 3x on same issue | Escalate: code bug → design issue → Planner |
| Planner revision doesn't resolve | Escalate to human with full history |
| Session crash mid-round | Read plan.md progress + `git log` → recover from the last checkpoint |
| Someone else pushed to branch | Verifier pre-flight detects baseline change → re-baseline |
| App won't start for Tier 2 | Degrade to Mode B/C, note in review.md |

## Rules

### Core Rules (all modes)

1. plan.md is the single source of truth for what's being built
2. Builder is the only public role that modifies source code or tests. Planner, Dispatcher, Verifier, and Verifier add-on files are read-only with respect to the codebase. Internal Builder workers may assist only under Builder control and never own canonical writes.
3. Verifier verification never reads Builder's source code in Mode A/B (see § Independence Rule for Mode C/C+)
4. Human approval required before Builder starts each round. If pre-flight marks the round `overloaded`, Builder stays blocked until Planner revises the round or records a human-approved overload override in `plan.md`
5. Max 3 Builder ⇄ Verifier iterations per round before escalation
6. In Standard/Full mode, each role starts with a fresh context; files carry state, not conversation. In Compact mode, Planner+Builder merge and Verifier is replaced by self-check + human review.
7. Dispatcher determines execution mode (Compact/Standard/Full) at task start; human can override
8. If an assumption encoded by a harness component is invalidated, remove the component

### Module Rules (Standard/Full mode)

9. Planner compresses plan.md at the start of each new round (summary + key decisions + open discoveries per section)
10. All work on feature branches
11. Git tag after each successful round
12. Migration scripts require separate human approval
13. Round scope lock: after human approves a round's plan, its ACs are frozen. New scope changes go to the next round (see Dispatcher § Scope Change Flow). Builder and Verifier work against the approved ACs, not a moving target
14. Dispatcher routes but never judges. Execution mode selection, finding categorization, and severity assessment always involve human confirmation or read from artifact labels — Dispatcher never auto-decides these

### Governance Rules

15. `v2/` stays general-purpose Baton core. Domain-, project-, and host-specific workflow rules do not belong there.
16. Root `skills/` are companion capabilities. Baton core may reference them as optional help, but the Dispatcher → Planner → Builder → Verifier loop cannot depend on them.
17. Host/provider-specific integrations live in adapters, add-on files, or external plugins. `protocol.md` and the public role entrypoints stay host-neutral.
18. Changes to protocol, public role files, templates, validators, or projection-layer docs are behavior-shaping changes. They require an eval note and must update affected projections/tests in the same change.
19. `.harness/` stores canonical control-plane artifacts. `.context/baton/` stores scratch state only. Dispatcher and recovery flows must never depend on scratch-only data.
20. Builder delegation must remain internal to Builder. It cannot create a new public role, bypass `.harness/*`, or grant scratch artifacts control-plane authority.
