## Baton — Shared Understanding Construction Protocol

Write lock: source code writes require `<!-- BATON:GO -->` in plan.md. Markdown is always writable.
Remove `<!-- BATON:GO -->` to roll back to the annotation cycle.

### Flow
Scenario A (clear goal): research.md → human states requirement → plan.md → annotation cycle → generate todo → BATON:GO → implement
Scenario B (exploration): research.md ← annotation cycle → plan.md ← annotation cycle → generate todo → BATON:GO → implement
Simple changes may skip research.md.

### Annotation Protocol
Human adds annotations in research.md or plan.md. AI responds to each, records in ## Annotation Log:
- `[NOTE]` additional context → incorporate, explain how it affects conclusions
- `[Q]` question → answer with file:line evidence
- `[CHANGE]` request modification → if problematic, explain with evidence + offer alternatives, let human decide
- `[DEEPER]` not deep enough → continue investigation in specified direction
- `[MISSING]` something omitted → investigate and supplement
- `[RESEARCH-GAP]` needs more research → pause current document, do research, then return

**The human is not always right.** When there's a problem, explain with evidence, offer alternatives. Final decision is the human's.

### Rules
- No source code before BATON:GO. NEVER add BATON:GO yourself
- plan.md does not contain a todolist. Append ## Todo only after human says "generate todolist"
- Every annotation must be responded to + recorded in Annotation Log
- Only modify files in the plan; propose additions (file + reason) in plan first
- Same approach fails 3× → stop and report
- Discover omission during implementation → stop, update plan.md, wait for human confirmation
- When all items complete, remind to archive to plans/

### Session handoff
- Stopping mid-work → append ## Lessons Learned to plan.md (what worked / what didn't / what to try next)
- When archiving, preserve Lessons Learned and Annotation Log (long-term reference)

### Parallel sessions (optional)
- Use git worktrees: each session gets its own working copy
- BATON_PLAN for different plan files: `BATON_PLAN=plan-auth.md`

---

### [RESEARCH] Research Phase

Goal: build AI's understanding of the code, produce a document the human can review.

research.md should let the human judge:
1. Whether the AI sufficiently understands the code
2. Whether the AI's understanding is correct
3. Whether anything was missed

No fixed template, but research should answer:
- **What was studied** — scope, which files were read, why those files
- **How the code works** — key execution paths, call chains, each node with file:line
  Trace call chains to leaf nodes or explicit stopping points (annotate why you stopped)
- **What risks exist** — mark with ✅ (confirmed safe) / ❌ (problem found) / ❓ (unverified)
  Each risk with verification evidence or reason it's unverified
- **What's still unknown** — unread files and why, unverified assumptions

Depth tips:
- Don't stop call chains at the interface layer — trace to implementations
- For every "should be fine" — ask: have you actually verified this?
- Use subagents to trace different call chain branches in parallel (10+ files)

In Scenario B, research.md may go through annotation cycles:
Human uses [DEEPER]/[MISSING]/[Q]/[NOTE] → AI responds and updates → cycle until human is satisfied

### [PLAN] Plan Phase

Goal: based on research and requirements, produce a change proposal the human can approve.

plan.md should let the human judge:
- What the AI intends to do (specific changes)
- Why this approach (reasoning, trade-offs)
- What risks exist (mitigation strategies)

plan.md should include:
- **What** — specific changes, referencing research findings
- **Why** — design rationale, alternatives considered and their trade-offs
- **Impact** — files involved, affected callers/consumers
- **Risks + mitigation** — what could go wrong and the strategy for each

plan.md does not contain a todolist.
After human approves the plan and says "generate todolist" → AI appends ## Todo to plan.md.
Each todo item should include: specific change, files involved, verification method.

#### Approach Analysis (First Principles)

Plans should not jump to "how to do it" — they should **derive** approaches from research findings:

1. **Extract fundamental constraints**: identify hard constraints from research.md that limit approach choices
   (architecture limitations, performance bottlenecks, dependencies, backward compatibility, team conventions, etc.)

2. **Derive 2-3 approaches**, each with:
   - Feasibility: ✅ feasible / ⚠️ risky / ❌ not feasible, with evidence (file:line)
   - Pros and cons (analyzed against each fundamental constraint)
   - Estimated impact scope (number of files, number of callers affected)

3. **Recommend one + reasoning**
   The recommendation is not preference — it's the optimal choice given the constraints. Reasoning should trace back to specific findings in research.

#### When Research Discovers Fundamental Problems

If the research phase discovers that the project's existing design itself is problematic (e.g., architecture can't support new requirements, tech debt makes safe modification impossible), the AI must **present this honestly** rather than force a solution on a broken foundation:

1. Use evidence to explain the problem's nature (not "I think" but "file:line shows...")
2. Present two categories of approaches:
   - **Approach A: Patch within existing structure** (what to do, risks, tech debt increment)
   - **Approach B: Fix the root problem** (what to change, cost, long-term benefit)
3. Explicitly state: this is an architectural decision that requires human judgment
4. Don't decide for the human, and don't hide problems pretending everything is fine

### [ANNOTATION] Annotation Cycle

The annotation cycle is Baton's core mechanism. It applies to both research.md and plan.md.

#### Full Flow
1. AI produces a document (research.md or plan.md)
2. Human reads it, adds annotations directly in the document
3. AI reads the document, finds all new annotations
4. AI responds to each:
   - If the human is right → adopt, update document
   - If the human's suggestion is problematic → explain with evidence, offer alternatives, let human decide
5. All responses recorded in ## Annotation Log
6. Human reviews AI responses, may add more annotations → back to step 3
7. Human is satisfied → exit annotation cycle (say "generate todolist" / "start implementing" / add BATON:GO)

#### Annotation Format
Human writes annotations directly at the relevant location in the document:

    [ANNOTATION_TYPE] specific content

Example:

    ### Design: Use Service Layer Validation
    [Q] Why not do this uniformly in middleware? Each service would repeat the logic
    [NOTE] Historically middleware did validation but it was moved to service layer due to performance issues

#### Core Principles for AI Responses

The human is not always right. AI's responsibility is to convey what it knows, not to blindly comply.

Correct AI behavior:
- Human says "switch to Redis" → AI finds 0 Redis dependencies in project → explain adoption cost + offer alternatives → let human decide
- Human says "this function is unsafe" → AI verifies and finds it's true → acknowledge the error, update document
- Human says "remove this check" → AI finds the check prevents null pointer → explain the risk + ask if human is sure

Incorrect AI behavior:
- Change whatever the human says (blind compliance)
- AI thinks the human is wrong but stays silent (hiding information)
- AI argues repeatedly and won't let the human decide (excessive resistance)

#### Annotation Log Format

    ## Annotation Log

    ### Round 1 (YYYY-MM-DD)

    **[Q] § Design Approach**
    "Why not do this uniformly in middleware?"
    → Middleware doesn't understand business semantics, can't do field-level validation (evidence: src/middleware/validate.ts:30 only does JSON schema validation).
      Doing business validation would couple business logic into middleware.
    → Result: human accepts, keeping service layer validation

    **[CHANGE] § Caching Strategy**
    "Switch to Redis"
    → ⚠️ Entire project currently uses in-process cache (evidence: 0 Redis dependencies).
      Adopting Redis requires: (1) docker-compose config (2) connection management (3) serialization
      Alternative: add TTL to existing CacheManager (src/cache.ts:30)
    → Awaiting human decision

#### [RESEARCH-GAP] Handling
1. Pause processing other annotations on the current document
2. Conduct supplementary research for the gap
3. Append results to research.md (as ## Supplement: <topic>)
4. Return to the current document, continue processing remaining annotations
5. Record in Annotation Log: gap content + key findings + impact on current document

### [IMPLEMENT] Implementation Phase
> Only active after plan.md contains <!-- BATON:GO -->

- Implement in ## Todo order
- After each item: typecheck/build → mark [x] when passing
- After ALL items: run full test suite, record results at the bottom of plan.md
- Discover plan omission during implementation:
  · Small addition → update plan.md with explanation, wait for human confirmation
  · Requires design direction change → stop, inform human. Human removes BATON:GO to roll back to annotation cycle
- All complete + tests passing → remind to archive:
  mkdir -p plans && mv plan.md plans/plan-$(date +%Y-%m-%d)-topic.md
- Stopping mid-implementation → append ## Lessons Learned to plan.md (what worked / what didn't / what to try next)

Todo items with dependencies should execute sequentially (later items need to see earlier code).
Independent items can run in parallel (subagent). Long todolists (10+) should be batched.