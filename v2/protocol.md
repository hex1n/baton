# Baton v2 Protocol

## Three Assumptions

This harness encodes exactly three assumptions about what AI cannot do reliably:

1. **AI cannot evaluate its own work honestly** → independent Verifier, never reads Builder's code
2. **AI loses coherence over long tasks** → file-based communication, context resets between roles
3. **Requirements emerge through building** → round-based progressive elaboration, not upfront specification

Everything else, the model handles on its own. If a component doesn't map to one of these assumptions, it shouldn't exist.

## Execution Modes

The harness supports two execution modes. Choose based on task complexity and available tooling.

### Strict Mode (recommended for complex tasks)

Each role runs as an independent subagent via `Agent` tool:
- **Full context isolation** — each role starts fresh, reads only from artifacts
- **Verifier independence guaranteed** — cannot see Builder's process, only results
- **Higher token cost** — each subagent rebuilds context from files

```
Dispatch (main conversation)
  → spawn Agent: Planner → writes brief.md
  → spawn Agent: Verifier pre-flight → writes eval.md
  → human approves
  → spawn Agent: Builder → writes code + tests
  → spawn Agent: Verifier verification → writes eval.md
```

### Compact Mode (acceptable for simple tasks)

Planner and Builder merge into one execution. Verifier role is replaced by a self-check checklist + human review.
- **No context isolation** — planning and building happen in the same conversation
- **No independent Verifier** — Builder self-verifies against a checklist; human provides the independent review
- **Lower cost** — no subagent overhead, no separate Verifier invocations

```
Compact mode flow:
  1. Planner+Builder: understand → design → implement → test → self-check
  2. Self-check (Builder runs before handing off to human):
     □ All ACs have corresponding tests?
     □ All tests pass (test command from project-profile.md)?
     □ No new failures vs baseline?
     □ Test assertions actually match AC requirements?
  3. Write eval.md (marked as "self-check, not independent verification")
  4. Human reviews eval.md + code changes
```

**Why no fake Verifier:** Assumption ① says AI can't self-evaluate. In compact mode, the Verifier shares Builder's context — making it structurally non-independent. Rather than pretend, compact mode is honest: Builder self-checks, human provides the real independent review.

**When to use compact mode:** ≤5 ACs AND single batch. Dispatch recommends; human can override to strict.

**Dispatch decides the mode** based on project-profile.md and task complexity. Human can override.

## Roles

Three roles. No more.

### Planner

Understands the codebase, clarifies requirements with the user, designs the technical approach.

- **Reads:** project-profile.md, brief.md (all rounds), relevant source code
- **Writes:** brief.md (creates Round 1 or appends Round N)
- **Runs:** once per round; re-invoked if Verifier escalates a design issue
- **Context:** fresh subagent per invocation; brief.md carries continuity

### Builder

Implements code and writes tests. The only role that modifies source code.

- **Reads:** project-profile.md (conventions, traps), brief.md (current round only)
- **Writes:** source code, tests, brief.md § Discoveries (only this section)
- **Runs:** once per round; may re-run after Verifier code-fix feedback
- **Context:** fresh subagent per round; reads brief.md + relevant source for context

### Verifier

Independently verifies implementation quality. Challenges plan quality before build.

- **Reads:** project-profile.md, brief.md (current round ACs), test results, runtime signals
- **Does NOT read:** Builder's source code during verification mode
- **Writes:** eval.md
- **Runs:** twice per round (pre-flight before build, verification after build)
- **Context:** isolated subagent; brief.md + observed behavior only

## Artifacts

### project-profile.md — project level, persistent

- **Location:** project root (not in .harness/)
- **Maintained by:** human; Planner can generate initial draft on first task
- **Contains:** build commands, test infrastructure, conventions, known traps, Verifier capability mode
- **Read by:** all roles at the start of every invocation
- **Lifecycle:** lives across tasks, updated occasionally

### .harness/brief.md — task level, living document

- **Location:** .harness/
- **Maintained by:** Planner (structure, ACs, approach); Builder (§ Discoveries only)
- **Contains:** round-by-round acceptance criteria, approach, decisions, progress, discoveries
- **Lifecycle:** created at Round 1, appended each round, archived to .harness/archive/ at task end
- **Compression:** Planner compresses at the START of each new round (not end of previous), so Verifier has full info during verification. Compression rules per section:
  - § Completed Rounds: summary + key decisions + unresolved discoveries (not just one-line)
  - § Context: only keep entries relevant to current/future rounds
  - § Feature Decomposition: completed features marked ✅, descriptions collapsed
  - § Discoveries: items absorbed into design marked [absorbed], only open items remain
- **Compression quality guard — never compress away:**
  - Decisions that constrain future rounds (e.g., "chose sync over async" limits Round 3 options)
  - Unresolved discoveries (even if they seem minor — future rounds may re-evaluate)
  - Exploration boundary GAP entries (they carry forward until explicitly addressed)
  - The reason an approach was rejected (not just which was chosen)
  - If unsure whether to keep or compress an item, keep it

### .harness/eval.md — round level, archived per round

- **Location:** .harness/
- **Maintained by:** Verifier (writes), Dispatch (archives)
- **Contains:** pre-flight results, verification findings, human review guidance
- **Lifecycle:** Verifier writes eval.md for current round. Before starting a new round, Dispatch copies eval.md → eval-round-{N}.md to preserve history. Previous rounds' evals are always available in .harness/ without needing git.
- **Round tag:** eval.md header must include `# Evaluation: Round {N}` so Dispatch can compare against brief.md's current round

## Round Lifecycle

Every task is a sequence of rounds. Simple tasks complete in one round. Complex tasks unfold over many.

```
Round N:
  1. Planner    → writes/updates brief.md with this round's ACs
  2. Verifier      → pre-flight (testability + baseline + plan challenge)
  3. Human      → approves plan (or asks revision)
  4. Builder    → implements code + tests in batches
  5. Verifier      → verification (Tier 1 → Tier 2 → Tier 3)
  6. Resolution → code bugs back to Builder; design issues to Planner
  7. Completion → git tag round-N-done
  8. Human      → continue / add requirement / done
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

Only at decision points. Never for status updates. All human interactions use `AskUserQuestion` with explicit options.

| When | What human sees | AskUserQuestion options |
|------|----------------|------------------------|
| After Planner + Verifier pre-flight | brief.md + pre-flight challenges | approve / revise / reject |
| After Round completion | eval.md § Human Review Guidance | continue / add requirement / done |
| Migration generated | Migration / schema change script | approve / reject |
| 3x Builder ⇄ Verifier without resolution | Failure history | change approach / change requirements / abort |
| Resume existing task | Task status summary | resume / start fresh / abort |

## Verifier Verification Modes

Detected during pre-flight. Recorded in project-profile.md for future rounds.

### Evidence Levels

Verifier evidence is classified by independence from Builder:

| Level | Description | Examples |
|-------|------------|---------|
| **L1** Independent | Builder cannot influence the outcome | Test pass/fail, runtime behavior, compile results |
| **L2** Auditable | Builder produced it, but Verifier can verify | Test code quality, AC→test mapping |
| **L2.5** Cross-model | A different model reviews Builder's output | [codex-plugin-cc](https://github.com/openai/codex-plugin-cc) review via `/codex:review`, `/codex:adversarial-review` |
| **L3** Non-independent | Same model reviews same model's output | Production code review, AI judgment |

L2.5 exists because cross-model review has different blind spots from Builder — it is structurally more independent than L3, but still AI judgment (not deterministic like L1). It is only available when project-profile.md configures an external reviewer.

**Cross-examination rule:** L2.5 findings are never accepted blindly. Verifier must cross-examine each finding against codebase evidence and classify as confirmed (✅ with file:line proof), plausible (⚠️ needs human), or rejected (❌ with reason). This produces higher-quality signal than either model alone — Codex catches what Claude misses, Claude grounds or filters what Codex claims.

### Mode Table

| Mode | What works | Tier 1 (L1) | Tier 2 (L1) | Tier 3 (L2+L3) |
|------|-----------|-------------|-------------|----------------|
| **A** Full runtime | App starts + services accessible | compile + test | Runtime behavior verification | Test quality audit (L2) + AI judgment (L3) |
| **B** Partial | Some services, app won't start | compile + test | Partial runtime assertions | Test quality audit (L2) + AI judgment (L3) |
| **C** Static | Only build tool works | compile + test | — | Test quality audit (L2) + production code review (L3) + AI judgment (L3) |
| **C+** Static + external reviewer | Build tool + external AI reviewer | compile + test | — | Test quality audit (L2) + cross-model code review (L2.5) + AI judgment (L3) |

**Mode C explicitly permits reading production code** — without runtime evidence, code review is the only deep verification available. This is an honest degradation, not a contradiction.

**Mode C+ upgrades code review independence** by delegating production code review to [codex-plugin-cc](https://github.com/openai/codex-plugin-cc), which runs OpenAI Codex inside Claude Code. Codex has different training and blind spots, breaking the "same model evaluates same model" problem. Verifier uses `/codex:review` for standard review and `/codex:adversarial-review` for design challenge. C+ is not as strong as Mode A/B (still AI judgment, not deterministic), but is meaningfully more independent than C.

**eval.md must state which mode was used and the evidence level distribution.** Mode B/C must include: "⚠️ Verification independence: degraded — human review weight is higher."

## Test Baseline Protocol

Flaky tests are reality. The harness handles them.

1. **Before Builder starts:** Verifier runs the project's test command (from project-profile.md) on unmodified code → records pass/fail/skip with test IDs
2. **After Builder completes:** Verifier runs the same test command again → compares to baseline
3. **Only NEW failures count** as Builder-introduced issues
4. **Baseline failures** are listed in eval.md but do not block

## Git Strategy

**Mandatory** (all tasks):
- Never force push
- Never commit directly to main/master for code changes
- `git add` specific files, not `git add -A`
- Never commit failing code

**Recommended** (code implementation tasks):
- Create feature branch before Round 1
- Commit after each passing batch: `git commit -m "round-{N} batch {M}: {description}"`
- Tag after each successful round: `git tag round-N-done`
- Create PR after task completion

**Optional** (infrastructure/cleanup/docs tasks):
- Feature branch and round tags may be skipped when changes are easily reversible
- Dispatch may ask human: `AskUserQuestion: "Create feature branch? (recommended for code tasks)"`

## Independence Rule

**Verifier prioritizes higher-level evidence.** The goal is not "never read code" — it is "evaluation evidence should not be controlled by the party being evaluated."

- **Mode A/B:** Verifier does NOT read Builder's production code. L1 evidence (test results, runtime behavior) is sufficient.
- **Mode C:** Verifier MAY read production code (L3) because no runtime evidence exists. eval.md must declare this degradation.
- **Mode C+:** Verifier delegates production code review to an external AI tool (L2.5). Verifier still reads test files and coordinates, but the code judgment comes from a different model. eval.md must state "Cross-model review (L2.5)" for those findings.
- **All modes:** Verifier MAY read test files (L2) to audit test quality, but must independently judge whether tests actually verify ACs — not just trust Builder's AC→test mapping.

**Pre-flight CAN always read source code** — pre-flight is a planning review (challenging the approach), not a code review (evaluating the implementation).

This prevents the "self-evaluation leniency" problem while being honest about what's possible in degraded environments.

## Confidence Signals

All three roles share the same AI model. Shared blind spots are a systemic risk. Confidence signals are the escape hatch.

**When to signal low confidence:**
- Planner is uncertain about a fundamental technical assumption (e.g., "I think this framework supports X but haven't verified")
- Verifier cannot determine whether an AC is truly satisfied (evidence is ambiguous)
- Builder discovers the approach may not work but isn't certain

**How to signal:**
- In brief.md or eval.md, annotate: `⚠️ LOW CONFIDENCE: {what}. Reason: {why}. Suggest: {what human should verify}`

**Protocol-level trigger:**
- If both Planner and Verifier independently flag the same assumption as low-confidence → mandatory human review before proceeding
- Dispatch detects low-confidence markers and adds them to AskUserQuestion options

**Structural triggers (fire automatically, no AI judgment needed):**
- Planner's § Exploration Boundary has any `⚠️ GAP` entry → Dispatch adds to AskUserQuestion
- Verifier pre-flight found ≥2 [Correctness] or [Completeness] challenges → Dispatch flags to human
- Any AC marked `[assumed — verify]` not yet confirmed → Dispatch blocks Builder start
- Mode C verification → Dispatch enforces mandatory human code review checkpoint (not just advisory)

## Failure Recovery

| Scenario | Response |
|----------|----------|
| Compilation fails 3x on same batch | Git reset to last commit, Builder regenerates batch |
| Verifier rejects Builder 3x on same issue | Escalate: code bug → design issue → Planner |
| Planner revision doesn't resolve | Escalate to human with full history |
| Session crash mid-round | Read brief.md progress + `git log` → resume from last checkpoint |
| Someone else pushed to branch | Verifier pre-flight detects baseline change → re-baseline |
| App won't start for Tier 2 | Degrade to Mode B/C, note in eval.md |

## Rules

1. brief.md is the single source of truth for what's being built
2. Verifier verification never reads Builder's source code
3. Human approval required before Builder starts each round
4. Migration scripts require separate human approval
5. Max 3 Builder ⇄ Verifier iterations per round before escalation
6. Git tag after each successful round
7. Planner compresses brief.md at the start of each new round (summary + key decisions + open discoveries per section)
8. All work on feature branches
9. In strict mode, each role starts with a fresh context; files carry state, not conversation. In compact mode, Planner+Builder merge and Verifier is replaced by self-check + human review.
10. If an assumption encoded by a harness component is invalidated, remove the component
11. Dispatch determines execution mode (strict/compact) at task start; human can override
12. Round scope lock: after human approves a round's plan, its ACs are frozen. New requirements go to the next round (see Dispatch § Add Requirement Flow). Builder and Verifier work against the approved ACs, not a moving target
