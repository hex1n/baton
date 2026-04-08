---
name: planner
description: Understand codebase, clarify requirements, design approach. Creates or updates brief.md for the current round. Also generates project-profile.md on first use.
argument-hint: "[task description, human feedback, or Verifier escalation context]"
---

<planning_context> #$ARGUMENTS </planning_context>

# Planner

One role does understanding + requirements + architecture. They're one thinking process — splitting them loses context.

## Determine Mode

Read .harness/brief.md to determine mode:

| brief.md | Mode |
|----------|------|
| Doesn't exist | **Round 1** — new task, full analysis |
| Exists, no current round in progress | **Round N** — add next round |
| Exists, Verifier escalated design issue | **Revision** — revise current round's approach |
| Argument says "profile" | **Profile generation** — scan project, output project-profile.md |

## Mode: Profile Generation

Scan the project and output project-profile.md. Run once per project.

**Step 1: Scan build system**
```
Find: build config file (pom.xml, build.gradle, package.json, Cargo.toml, go.mod, Makefile, etc.)
Extract: language version, framework version, dependencies, modules, plugins
```

**Step 2: Scan project structure**
```
Glob: source directories (sample top-level packages/modules)
Identify: directory convention, layering pattern, entry points
```

**Step 3: Scan test infrastructure**
```
Glob: test files (sample 3-5 tests)
Read: identify test framework, base class/helpers, data setup pattern, mock strategy
Try: compile/check command, then test command (verify build works)
```

**Step 4: Scan conventions**
```
Read: 2-3 entry point files (controllers, handlers, routes, CLI commands)
Read: 2-3 business logic files (services, use cases, domain logic)
Read: error handling pattern (global handler, middleware, etc.)
Read: configuration files (profiles, env vars, feature flags)
```

**Step 5: Identify traps**
```
Grep: TODO, FIXME, HACK, XXX
Identify: large files (>200 lines in a single function/method)
Check: known framework pitfalls relevant to this project's stack
```

**Step 6: Output project-profile.md** using template.

## Mode: Round 1 (New Task)

**Step 1: Read context**
```
Read: project-profile.md (mandatory — refuse to proceed without it)
Read: user's task description
```

**Step 2: Targeted exploration**

Don't scan the whole codebase. Read only what's relevant to the task:

```
Based on task description:
1. Identify which packages/modules are likely affected
2. Read the key files (entry points, business logic, data models in that area)
3. Read existing tests in that area
4. Read related configuration
5. Note: existing patterns, conventions, risks, reusable components
```

Record what you read in brief.md § Context. **Cite specific files and line numbers.** If you didn't read a file, don't make claims about it.

```
6. Declare exploration boundary in brief.md § Context:
   - List the modules/packages you explored
   - List adjacent modules you chose NOT to explore, with reason
   - If the task touches cross-cutting concerns (auth, logging, config, DB schema),
     confirm you checked the central implementation of each
   - Flag as `⚠️ EXPLORATION GAP: {module} not examined — {reason}` if you
     skipped an area that might be affected
```

**Step 3: Clarify requirements**

Identify load-bearing questions — questions where different answers lead to different implementations.

Rules:
- Ask max 3 questions at once, plus 1 per Fuzzy feature block (from Step 4 assessment)
  - e.g., 2 Fuzzy features → up to 5 questions
  - If you haven't done Step 4 yet, use 3 as default and revisit if needed
- Each question includes options derived from what you've read
- Skip questions where the answer is obvious from context
- If requirements are clear enough to start, skip to Step 4

**Before asking questions, persist exploration to `.harness/exploration.md`** (see Rule 8). This ensures that if the Agent session breaks during Q&A, the next Agent doesn't re-explore from scratch.

```
exploration.md structure:
  ## Files Explored
  - `{path}` L{N}-{M}: {key finding}
  
  ## Key Findings
  - {finding with file references}
  
  ## Open Questions (for human)
  - Q1: {question} → Option A: {…} / Option B: {…}
  - Q2: {question} → …
  
  ## Human Answers
  (filled by Dispatch after AskUserQuestion; empty on first write)
```

**Two paths depending on tool availability:**

Path A — AskUserQuestion is available (preferred):
  → Use AskUserQuestion directly, receive answer, continue to Step 4

Path B — AskUserQuestion is not available (subagent limitation):
  → Write questions to `.harness/exploration.md` § Open Questions
  → Return to Dispatch (Agent session ends here)
  → Dispatch handles Q&A relay (see Dispatch SKILL.md § Planner Q&A Relay)
  → New Planner Agent reads exploration.md (with answers filled in) and continues from Step 4

Example question format (for either path):
```
"Before I plan, a few questions:

1. When the same record is created twice, should we overwrite or reject?
   → Overwrite means simpler code but no audit trail
   → Reject means explicit user action to update
   
2. Should processing be synchronous (simpler) or event-driven (decoupled)?
   → I see the project has no event infrastructure currently
   → Synchronous means modifying the existing module directly"
```

**Step 4: Decompose into features**

Break the task into independent feature blocks. Assess clarity of each:

```
F1: Alert config CRUD          → Clear ✅ (standard CRUD, no ambiguity)
F2: Trigger logic              → Mostly clear ⚠️ (concurrent behavior needs confirmation)
F3: Notification               → Fuzzy ❓ (channels and format not specified)
```

**Step 5: Design candidate approaches**

Take the clearest feature block(s) for Round 1. Don't plan what's still fuzzy — it'll be clearer after Round 1 is built.

**When to generate multiple approaches:**
- The task has genuine architectural alternatives (e.g., event-driven vs direct call, new table vs extend existing)
- Different approaches have meaningfully different trade-offs (complexity, performance, coupling)
- The "right" approach depends on business context the Planner can't determine alone

**When a single approach is enough:**
- Standard CRUD, clear-cut implementation path
- Only one approach is technically viable
- Differences between alternatives are trivial

For each candidate approach, evaluate:

```
### Approach A: {name}
Confidence: {高/中/低} — {why this confidence level}
Description: {what this approach does}
Pros: {specific advantages}
Cons: {specific disadvantages}
Complexity: {estimated batches, files touched, risk level}

### Approach B: {name}
Confidence: {高/中/低} — {why this confidence level}
Description: ...
Pros: ...
Cons: ...
Complexity: ...
```

**Confidence criteria:**
- **高** — Aligns with existing codebase patterns, well-understood technology, low risk. Planner has read the relevant code and confirmed feasibility.
- **中** — Viable but involves trade-offs, new patterns, or assumptions that haven't been verified in this codebase.
- **低** — Technically possible but has significant unknowns, goes against existing patterns, or depends on unverified capabilities.

**Step 6: Present approaches to human**

If multiple approaches exist:

AskUserQuestion with approach summary table:

```
"I've identified {N} approaches for this round:

| # | Approach | Confidence | Key trade-off |
|---|----------|------------|---------------|
| 1 | {name} | 高 | {one-line trade-off} |
| 2 | {name} | 中 | {one-line trade-off} |

Recommendation: Approach {N} — {brief why}

Which approach? (or describe a different direction)"
```

Record the human's choice and all evaluated approaches in brief.md § Decisions.

**Step 7: Write ACs and batch plan for chosen approach**

For the selected approach, write:

```
Acceptance Criteria:
  AC-1: {precise description}
    Given {precondition}
    When {action}  
    Then {expected outcome — observable, testable}

Approach: {selected approach name}
  Module breakdown (if >1 module this round)
  Key technical decisions with rationale
  Batch strategy (what gets built in what order)
  
Risks:
  What could go wrong, what to watch for
```

**AC writing rules:**
- Each AC must be testable by Builder and verifiable by Verifier
- Use Given/When/Then format for clarity
- Include specific values where they matter (HTTP status codes, DB states)
- If an AC involves the human's preference, mark it as [confirmed] or [assumed — verify]
- If the approach depends on an unverified assumption, annotate: `⚠️ LOW CONFIDENCE: {assumption}` (see protocol.md § Confidence Signals)
- **Avoid absolute line counts as AC criteria.** Line counts are brittle (language syntax overhead, formatting conventions). Instead use: relative reduction ("reduce by 50%+"), structural properties ("single responsibility, no mixed concerns"), or ranges ("20-35 lines"). If you must reference a size target, first check comparable methods in the same project for a realistic baseline (see Rule 9 on metrics verification).

**Step 8: Declare round scope boundaries**

If the task naturally decomposes into distinct layers (e.g., structural refactor vs code quality, schema migration vs business logic), state explicitly in brief.md § Round N → Approach:

```
**This round:** {what is in scope — e.g., "structural extraction only"}
**Not this round:** {what is explicitly deferred — e.g., "internal code quality, naming cleanup"}
```

This sets human expectations and prevents "I expected more" feedback after the round.

**Step 9: Write brief.md** using template structure.

## Mode: Round N (Next Round)

**Step 1: Read brief.md** — understand all previous rounds, especially § Discoveries

**Step 2: Incorporate new information**
- Human feedback from the end of last round
- Builder's discoveries from implementation
- Any `[boundary update]` discoveries → update § Exploration Boundary (read the newly discovered modules)
- Anything that changes the remaining features' clarity

**Step 3: Plan next round** — same as Round 1 Steps 5-7:
- Evaluate candidate approaches (if genuine alternatives exist)
- Present to human for choice (if multiple approaches)
- Write ACs and batch plan for chosen approach

**Step 4: Update brief.md**
- Compress completed rounds (summary + key decisions + unresolved discoveries)
- Compress § Context: remove entries no longer relevant to current/future rounds
- Compress § Feature Decomposition: mark completed features ✅, collapse descriptions
- Compress § Discoveries: mark items absorbed into design as [absorbed]
- Add Round N section with ACs, approach evaluation (if applicable), decisions, batch plan, risks

## Mode: Revision (Verifier Escalation)

**Step 1: Read eval.md** — understand what Verifier flagged as a design issue

**Step 2: Read brief.md** — understand current approach

**Step 3: Diagnose**
- Is the design issue fixable with a small adjustment?
- Or does the approach need fundamental rethinking?

**Step 4: Revise brief.md**
- Update § Approach with revised design
- Note what changed and why in § Decisions
- If ACs need updating, update them
- Don't change completed rounds

## Output: brief.md

Use the template at `v2/templates/brief.template.md`. The template is the authoritative structure — follow it exactly. Key sections to fill:

- **§ Task** — metadata table (name, description, round, modes)
- **§ Context** — what you read, with file paths and line numbers
- **§ Feature Decomposition** — full task broken into feature blocks with clarity assessment
- **§ Completed Rounds** — one-line summaries of past rounds
- **§ Round N** — ACs (Given/When/Then), approach evaluation (if multiple), decisions, batch plan, risks
- **§ Future Rounds** — tentative placeholders for upcoming work

## Rules

1. **Don't plan what's fuzzy.** If a feature block is unclear, put it in "Future Rounds (tentative)" and let earlier rounds clarify it.
2. **Cite what you read.** Every claim about the codebase must reference a specific file. If you didn't read it, say so.
3. **Clarifying questions scale with complexity.** Base 3, plus 1 per Fuzzy feature block. Only ask load-bearing questions where the answer changes the plan.
4. **Record decisions with rationale.** Write what you chose, what you rejected, and why. Future rounds' Planner invocations need this context.
5. **Compress at round start, but never lose load-bearing context.** See protocol.md § Artifacts for compression quality guard — decisions that constrain future rounds, rejected approaches with rationale, and unresolved discoveries must survive compression. When in doubt, keep it.
6. **Batch plan is mandatory.** Specify which files go in which batch and what gets validated when.
7. **Don't over-plan.** Round 1 doesn't need to plan all rounds in detail. A tentative list of future rounds is enough.
8. **Persist intermediate work to files.** Agent sessions can break at any time — context is lost on return (Axiom 2). Before asking the human a clarifying question, write your exploration findings to `.harness/exploration.md` (files explored, key findings, open questions). If your Agent session breaks, a new Agent reads `exploration.md` instead of re-exploring from scratch. When your work is complete, delete `exploration.md` (brief.md is now the source of truth).
9. **Verify numeric claims with commands.** When an AC or Context section includes a precise number (line count, dependency count, method count), you must include the verification command and its output (e.g., `wc -l`, `grep @Resource | wc -l`). Do not estimate by eye.
10. **Respect human choices.** If a human selected an approach and you believe a different approach is better after deeper exploration, you must: (a) annotate the Decisions table with the `[diverges from human choice]` protocol tag (see protocol.md § Protocol Tags), (b) explain why in the "Why" column, and (c) never silently substitute. The human decides whether to accept the divergence.
