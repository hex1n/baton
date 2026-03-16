---
normative-status: Authoritative specification for the RESEARCH phase.
name: baton-research
description: >
    Use for Medium/Large tasks that require systematic investigation before
    planning or implementation: reducing key uncertainties, validating framing,
    tracing behavior, reconciling contradictions, comparing alternatives, or
    building evidence-backed understanding across multiple surfaces.
    Also use for [PAUSE] investigations and when the user explicitly asks to research.
user-invocable: true
---

## Iron Law

```text
NO CONCLUSIONS WITHOUT EXPLICIT EVIDENCE
NO SOURCE CODE CHANGES DURING RESEARCH — INVESTIGATE ONLY
VERIFY = VISIBLE OUTPUT. "I checked" is not evidence.
FIRST PRINCIPLES BEFORE FRAMING.
```

This skill is the local source of truth for research-phase framing.
`constitution.md` defines cross-phase invariants (Challenge Model, Evidence Model, Permission Model);
local field requirements including annotation format and evidence extensions are defined here.

Research produces understanding, not code. Write findings down for the plan phase.

## Red Flags

These thoughts mean STOP — you're rationalizing:

| Thought | Reality |
|---------|---------|
| "A quick glance at the code is enough" | Insufficient investigation = insufficient conclusions. Follow the process |
| "This conclusion is obvious, no evidence needed" | Obvious ≠ correct. Find evidence or mark ❓ |
| "No need to decompose dimensions, just investigate sequentially" | Decomposition discipline matters, not parallelism. Sequential is fine — skipping dimension decomposition is not |
| "I've investigated enough already" | Did you write Self-Challenge? Shallow self-challenge = skipped self-challenge |
| "This is a quick lookup, no need for full research" | If it's truly trivial, the skill says "When NOT to use." If you're here, follow the process |
| "I can answer from what I already know" | Memory is unreliable. Verify with evidence |
| "The counterexample sweep found nothing" | Did you actively search for disproving evidence, or just not find any by default? |

## When to Use

- Medium/Large tasks requiring cross-module behavior tracing
- Ambiguous or contradictory requirements needing evidence-backed clarification
- Multi-surface consistency checks (N IDEs, N API endpoints, N config formats)
- Root-cause analysis across multiple execution paths
- Design analysis: framework comparison, architecture evaluation, pattern assessment
- External research: documentation, API, ecosystem investigation
- User says "research" or "deep research"
- After `[PAUSE]` annotation

**When NOT to use**: Quick lookups, single-file explanations, Trivial/Small tasks.

**Trigger heuristics** (when the boundary is unclear):
- Crosses 2+ modules/files AND requires reconstructing a behavior chain → use
- Contradictory evidence sources or requirement statements exist → use
- Comparing 2+ approaches/frameworks/design axes → use
- Only need to explain single file/function/concept → don't use
- Only need "where is it / what is it / roughly how it works" → don't use

## The Process

### Step 0: Frame the Investigation

Define at top of research file:

- **Question**: what exactly is being investigated
- **Why**: what later decision this supports
- **Scope / Out of scope**: boundaries
- **Known constraints**: repo, platform, tooling
- **System goal being served**: what outcome this research enables
- **Claimed framing from human/docs**: the framing as stated
- **What must be validated before accepting that framing**: assumptions to verify

### Step 0.5: Investigation Methods

Use ≥2 independent evidence acquisition methods. Record what you used, what each returned, why sufficient.

Independence levels:
- **Strong**: code reading + runtime verification; official docs + actual API response; source tracing + test behavior
- **Moderate**: grep + targeted file read; official docs + versioned release notes
- **Weak**: two similar searches; same-site different-page summaries

Aim for at least moderate independence. Two weak methods don't count.

If the question is naturally constrained to a single authoritative source
(e.g., internal script behavior = only source + runtime), state why stronger
independence is impossible, and compensate with deeper source-internal
cross-checks (e.g., multiple code paths, multiple test scenarios).

### Step 0.75: Dimension Decomposition

If the problem has independent dimensions, explicitly decompose them before investigation.
Decomposition discipline matters; parallelism is optional.

Use agent dispatch only when:
- the dimensions are meaningfully independent,
- parallel investigation is likely to reduce latency,
- and merge / reconciliation cost is not likely to outweigh the benefit.

If host capabilities do not support agent dispatch, or if merge complexity would be high,
perform the decomposition explicitly and investigate sequentially.

**Minimum requirement**:
- Name each dimension
- State why it is distinct
- State whether it is investigated in parallel or sequentially
- Preserve a final reconciliation step before conclusions

**When dispatching agents**, construct per-dimension context:
- The specific sub-question for this dimension
- Investigation targets (file paths, URLs, or search terms)
- Output format requirements (align with main research document)

After all dimensions complete, cross-validate for consistency and mark
cross-dimension contradictions as ❓.

Skip this step when: single-dimension question, or the question is narrow
enough that decomposition adds no value.

### Step 1: Investigation Targets

Start from the human's request or the most relevant targets:
- **Code**: affected files, entry points, call sites
- **External**: URLs, documentation, API endpoints, framework repositories
- **Design**: architecture docs, competing implementations, prior art

Targets are starting points, not research categories.
Observe-then-decide: after examining each target, decide next based on what you found.

### Step 2: Reduce Uncertainty

Drive the investigation by the most blocking uncertainty, not by a fixed category.

At each point in the investigation, ask:
1. What is the most important thing I still do not know?
2. What evidence would reduce that uncertainty?
3. What is the next investigation move most likely to produce that evidence?
4. Did that move reduce the uncertainty enough, or does the investigation need to change direction?

Do not force the task into a single research type.
Use whatever investigation move best fits the next evidentiary need.

A single research task may:
- use multiple investigation moves,
- repeat the same move multiple times,
- switch direction as findings change the question.

When the investigation direction materially changes, record:
- **Previous uncertainty**:
- **New uncertainty**:
- **Why the previous line of investigation was no longer sufficient**:
- **What the new line is expected to clarify**:

### Common investigation moves

These are common moves, not fixed branches.
Use them as needed, combine them freely, and switch when the evidentiary need changes.

#### Trace actual behavior

Use when you need to reconstruct what the system actually does.

Typical use cases:
- call chain tracing
- state flow / data flow / control flow reconstruction
- entry-point to sink analysis
- root-cause analysis
- failure-path tracing
- “where does this value / decision / side effect come from?”

Guidance:
- Read implementations, not just interfaces
- Distinguish observed behavior from assumed behavior
- Stop at framework internals / stdlib only with an explicit stop reason
- If runtime behavior and static reading diverge, surface the contradiction explicitly

#### Test a claim directly

Use when a statement, promise, framing, or external claim must be checked.

Typical use cases:
- docs say X — does code/runtime actually do X?
- the human says X is the problem — is that framing valid?
- comments or interfaces imply Y — is Y implemented?
- official API/docs claim Z — is that current and applicable?
- requirement statement vs current behavior validation

Guidance:
- Test the claim directly when direct testing is possible
- Separate “false” from “true only under constraints”
- If the claim is external, note version/date/currency
- If the claim conflicts with current behavior, record the mismatch explicitly

#### Compare alternatives

Use when you need to compare approaches, architectures, fixes, or strategies.

Typical use cases:
- choosing between implementation paths
- comparing frameworks / protocols / orchestration patterns
- evaluating trade-offs
- deciding whether a proposed fix solves the right problem
- making a recommendation under constraints

Guidance:
- State evaluation criteria explicitly before comparing
- Separate descriptive comparison from normative judgment
- “A does X, B does Y” may be fact
- “A is better” is judgment unless criteria are stated
- Do not smuggle preference in as fact
- If a recommendation depends on priorities or constraints, say so explicitly
- For comparison conclusions, mark whether each is **Fact**, **Inference**, or **Judgment**

#### Resolve contradictions

Use when important evidence sources disagree, or when two parts of the investigation cannot currently both be true.

Typical use cases:
- docs vs runtime
- code vs comments/interface promises
- human-stated intent vs current implementation
- one module says X, another behaves as Y
- one investigation path implies A, another implies not-A

Guidance:
- Name the contradiction explicitly
- Do not smooth conflicting findings into vague prose
- Prefer resolution by stronger evidence, not rhetorical convenience
- Apply Step 3 conflict-resolution rules explicitly
- If unresolved, keep it visible as ❓ rather than hand-waving it away

#### Build systematic coverage

Use when multiple surfaces, implementations, configs, entry points, or dimensions must be checked systematically.

Typical use cases:
- N IDE integrations
- N API endpoints
- N config formats
- feature parity across implementations
- consistency across adapters / hooks / surfaces
- “does every relevant surface behave the same way?”

Guidance:
- Use a comparison matrix when parallel coverage matters
- Every cell must contain direct evidence, explicit N/A, or documented ❓
- Blank cells are not allowed
- Mark asymmetries explicitly
- Separate missing coverage from confirmed parity

#### Probe an unknown assumption

Use when progress depends on an assumption that has not yet been tested directly.

Typical use cases:
- “this probably only happens in one path”
- “the framework likely guarantees this”
- “this config is probably inherited”
- “this behavior should be impossible”
- “this earlier conclusion likely generalizes”

Guidance:
- Surface the assumption explicitly
- Test the assumption as an object of investigation, not as background belief
- If the assumption remains unverified, keep it visible in conclusions

#### Challenge the leading interpretation

Use when a plausible explanation is forming and you need to actively search for disconfirming evidence before converging.

Typical use cases:
- a root cause appears likely
- one design judgment is becoming dominant
- one explanation seems to fit all current evidence
- one fix looks obviously correct

Guidance:
- Search for evidence that would disprove the current leading interpretation
- Do not treat “nothing obvious contradicted it” as a completed challenge
- Record what was checked and how the result changed confidence

### Minimum record for any investigation move

For each investigation move, record only what is needed:

- **Question or uncertainty being addressed**:
- **Evidence sought**:
- **What was checked**:
- **What was found**:
- **Status**: ✅ confirmed / ❌ problem / ❓ unresolved
- **What remains unresolved**:
- **Next step**: continue / switch direction / stop

Use more structure only when the investigation complexity requires it.

### Systematic coverage matrix

When systematic parallel checking is needed, use a matrix like this:

| Dimension | Surface A | Surface B | Surface C |
|-----------|-----------|-----------|-----------|
| Item 1    | ...       | ...       | ...       |
| Item 2    | ...       | ...       | ...       |

Rules:
- Every cell must contain direct evidence, explicit N/A, or documented ❓
- Blank cells are not allowed
- Highlight asymmetry, not just parity
- Missing verification is not the same as confirmed absence

### Step 2b: Synthesize across moves

When multiple investigation moves were used, add a short synthesis section before conclusions:

#### Cross-Move Synthesis
- **Moves used**:
- **Why each was needed**:
- **Key findings by move**:
- **Where findings reinforce each other**:
- **Where findings remain in tension**:
- **What remains unresolved**:

Purpose:
- prevent mixed investigations from becoming fragmented
- make direction changes explicit and reviewable
- prepare for convergence into final conclusions

### Step 2c: Counterexample Sweep

Before forming conclusions, actively search for evidence that would disprove the current leading interpretation.

Record:
- **Leading interpretation being challenged**:
- **Disproving evidence sought**:
- **What was checked**:
- **Result**: disproving evidence found / no disproving evidence found / insufficient search
- **Effect on confidence**:

Do not treat “nothing obvious contradicted it” as a completed counterexample sweep.

### Step 3: Evidence Standards

- `[CODE]` file:line — `[DOC]` external docs — `[RUNTIME]` command output — `[HUMAN]` chat
- `[DESIGN]` design decision or pattern — `[EMPIRICAL]` observed behavior in practice
- `✅` confirmed — `❌` problem — `❓` unverified
- Keep Facts / Inferences / Judgments distinct

**Conflict resolution** (when evidence types disagree):
- Runtime observed behavior > stale docs, unless runtime setup is suspect
- Code implementation > interface comments, unless dead code or non-executed path
- Human-stated intent ≠ current behavior → mark as requirement/expectation mismatch
- Design preference cannot override evidence of current behavior; it only informs judgment

When multiple investigation moves are used, preserve evidence provenance per move.
Do not merge findings across moves so aggressively that the original evidence path becomes unclear.

### Step 4: Self-Challenge (write into artifact, not just think)

Before presenting, write `## Self-Challenge` into the research file:
1. What's the weakest conclusion and why? What evidence would disprove it?
2. What did I NOT investigate that I should have?
3. What assumptions did I make without verifying?

Visible output — human judges depth. Shallow answers signal skipped self-challenge.

### Step 5: Review the Research

After self-challenge, perform an explicit review before presenting conclusions.

Choose the review strategy based on engineering judgment, not form preference.
The goal is review quality — not isolation for its own sake.

**Option A — Isolated review via subagent**  
Prefer this when:
- the artifact is sufficiently self-contained,
- the reviewer can provide a meaningfully independent perspective,
- and handoff/context-loss risk is low.

If using isolated review:
- provide only the research artifact text,
- process findings before presenting,
- record accepted / rejected / unresolved review findings in the artifact.

**Option B — Structured self-review**  
Prefer this when:
- host capabilities do not support isolated review,
- critical context would be lost in handoff,
- or the artifact still depends heavily on conversation history.

If using structured self-review, write `## Self-Review` and answer:
1. What is the actual problem? Does the problem statement reference a solution?
2. Is this solving the right problem, or patching within an inherited frame?
3. What fundamentally different approaches were not considered?
4. Does each piece serve the stated problem, or is it inherited baggage?

Both review paths are legitimate.
Choose based on artifact self-sufficiency, host capabilities, and context-loss risk.

### Step 6: Convergence Check

Before transitioning to plan:
1. Mark superseded conclusions: `→ Revised in [section]`
2. Write `## Final Conclusions` — each conclusion states:
   - **Confidence**: high / medium / low (use percentages only with quantitative evidence) + one-sentence rationale
   - **Evidence**: reference to supporting evidence
   - **Uncertainty**: what remains unverified
   - **Plan implication**: actionable / watchlist / judgment-needed / blocked
3. Capture chat requirements: `Human requirement (chat): ...`

If multiple investigation moves were used, reconcile them before final conclusions.
Do not present parallel findings as if they were already a single conclusion.

## Exit Criteria

1. Main path verified with evidence, no ❓ on critical paths
2. Key unknowns explicitly marked ❓ with reason
3. Human judgment questions in `## Questions for Human Judgment`
4. Every final conclusion classifies its plan implication (actionable / watchlist / judgment-needed / blocked)
5. Open unknowns classified by blocking severity: blocks plan / does not block plan

## Output

Default path: `baton-tasks/<topic>/research.md` — always include a topic.
If host/repo defines a different task workspace convention, follow that instead.
`mkdir -p` the target directory before writing.

**Update policy**:
- If continuing the same investigation, update the existing artifact in place
- Preserve still-valid findings
- Mark superseded conclusions with `→ Revised in [section]`
- Keep unresolved items visible
- Maintain section stability so later phases can consume the artifact consistently

- If resuming after `[PAUSE]`, append new findings under the existing investigation structure
- Preserve prior section structure
- Reconcile new findings back into the required sections before handoff to plan

- If starting a genuinely new investigation on the same topic, archive/rename the old file
  (for example `research-YYYY-MM-DD.md`) and create a fresh `research.md`

Do not silently erase prior reasoning that later findings corrected.
Preserve traceability when conclusions change.

**Required section structure** (preserve regardless of path):
1. Question / Why / Scope / Constraints / Framing validation
2. Investigation Methods
3. Investigation body (findings organized by investigation move; include Cross-Move Synthesis if multiple moves were used)
4. Self-Challenge
5. Self-Review or Review findings (if applicable)
6. Final Conclusions
7. Questions for Human Judgment (if any)
8. 批注区

## Annotation Protocol

Cross-phase annotation conventions may supplement this section, but local field requirements are defined here.

If annotations, challenges, review comments, or human objections arise during research,
record them in `## 批注区`. Do not handle strong challenges silently.

### Required format for each annotation item

- **Trigger / 触发点**: original annotation, objection, or review finding
- **Intent as understood / 理解后的意图**: what concern or claim is being raised
- **Response / 回应**: evidence-backed response
- **Status**: ✅ accepted / ❌ rejected / ❓ unresolved
- **Impact**:
  - none
  - research clarification only
  - affects final conclusion
  - blocks plan until resolved

### Rules

- Read the underlying evidence before responding
- Infer intent cautiously; do not rewrite a challenge into a weaker one
- Check whether the annotation exposes contradiction, missing evidence, weak framing, or scope drift
- If accepted, update the relevant research section and mark superseded text when needed
- If rejected, explain why with evidence
- If unresolved, keep it visible as ❓ rather than silently dismissing it

### Escalation heuristic

If repeated annotations expose the same class of depth problem
(e.g., repeated missing evidence, repeated framing errors, repeated scope confusion),
note that the task may have been under-scoped and suggest upgrading complexity.
Use pattern judgment, not a rigid numeric threshold.

### `## 批注区` minimum structure

Each entry should use this template:

```md
### [Annotation N]
- Trigger / 触发点:
- Intent as understood / 理解后的意图:
- Response / 回应:
- Status: ✅ / ❌ / ❓
- Impact: none / research clarification only / affects final conclusion / blocks plan until resolved
```
