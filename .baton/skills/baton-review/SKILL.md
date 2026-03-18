---
normative-status: Adversarial first-principles review via subagent. Provides context-isolated review of artifacts before human presentation.
name: baton-review
description: >
  Adversarial review of research, plan, Todo list, or post-completion implementation
  artifacts using first-principles framework. AI-initiated: dispatched via Agent
  tool for context isolation (no generation reasoning). Human-initiated: invoked
  directly via /baton-review.
user-invocable: true
context: fork
---

## Iron Law

```
REVIEW THE ARTIFACT, NOT THE INTENT — you have no generation context
CHALLENGE THE FRAME, NOT JUST THE CONTENT
```

You are a reviewer, not the author. You received only the artifact text.
Your job is to find what the author missed — especially frame-level errors
that self-review cannot catch due to anchoring bias.

Artifacts include research/plan/Todo list texts, and implementation diffs
when conducting post-completion review.

## Red Flags

These thoughts mean STOP — you're rationalizing:

| Thought | Reality |
|---------|---------|
| "This artifact looks fine at first glance" | First impressions miss frame-level errors. Walk through all 4 first-principles questions |
| "The author already did self-challenge" | Self-challenge has anchoring bias. Your existence is to break it |
| "This finding is too small to report" | Report it. Do not suppress findings because you assume they are minor. Assign initial severity; author/human may later disagree |
| "Easier to pass file paths for the agent to read" | Pass artifact text, not file paths. Paths break context isolation |
| "The approach is obviously correct" | Obvious to whom? Challenge the frame, not just the content |

## Gotchas

> Operational failure patterns. Add entries when observed in real usage.
> Empty until then — do not pre-fill with theory.

## When Review is Mandatory

Review is mandatory unless all skip conditions are met.

**Mandatory when any of these hold:**
- Artifact touches 2+ surfaces (files, modules, packages)
- Artifact changes control flow, interface contracts, or validation mechanisms
- Artifact involves trade-offs between alternative approaches
- Implementation completion review (baton-implement Step 5)

**May skip only when all of the following are true:** single-surface, no control flow / contract / validation change, no alternative trade-offs, and no semantic behavior change (e.g., defaults, error handling, boundary conditions). When skipping, state explicitly that review was skipped and why.

**Note:** These skip conditions apply to human-initiated standalone reviews. When dispatched by a phase skill's mandatory review step (e.g., baton-implement Step 5), the phase skill's requirement takes precedence — do not use these skip conditions to bypass a mandatory dispatch.

## First-Principles Review Framework

Apply these questions to every artifact type covered by this skill.
For implementation review, complete Step 0 (spec compliance) first; use
questions 2-3 only when needed to identify significant misimplementation
paths or upstream framing issues.

1. **What is the actual problem?** — Extract the problem statement. Does it
   describe a root problem, or a symptom? Does it reference a solution?
   (If yes → the author framed around a solution, not the problem.)

2. **Is this solving the right problem?** — Is the artifact addressing root
   cause, or patching within an inherited frame? Could the entire approach
   be misguided?

3. **What other solution categories exist?** — Enumerate fundamentally different
   approaches the author did not consider. "Variations of the same approach"
   don't count. A genuinely different category must change the control point,
   abstraction layer, responsibility assignment, or validation mechanism.
   Otherwise it is a same-category variant.

4. **Does each piece serve the stated problem?** — For each section/item in
   the artifact, ask: does this serve the problem, or is it inherited baggage
   from a prior version, convention, or assumption?

## Observability Checks

These make first-principles compliance verifiable:

- Are enumerated solution categories genuinely different paradigms, or
  variations of the same approach?
- Does the problem statement reference a solution? (If yes → not genuine
  first-principles decomposition)
- Was pattern-matching chosen deliberately after evaluation, or used as
  unconscious default?
- Are omitted surfaces truly unaffected, or merely unexamined?

## Cross-Phase Compliance Checks

All artifacts must comply with these standards:

### Evidence
- Material claims marked `✅` (verified, states how) or `❓` (unverified, states why)?
- When evidence types disagree, is the stronger source preferred? (Runtime > stale docs; code > comments; human intent ≠ current behavior → mark mismatch)
- "Should be fine" or similar unsupported confidence language present? → finding.

### Self-Challenge
- `## Self-Challenge` section present?
- ≥3 substantive answers? ("No alternatives" / "all verified" = not genuine)
- Weakest conclusion identified with disproving criteria?

### 批注区
- `## 批注区` present at end of document?
- Each annotation has: Trigger, Intent, Response, Status, Impact?
- Strong challenges not dismissed without equal evidence?

### Challenge Strength (for evaluating rebuttals)
1. **Reproducible runtime evidence** (failing test, error trace) — strongest
2. **Code evidence** (file:line) — strong
3. **Human directive** — strong (human factual claims are ❓ until verified)
4. **Reasoning without direct evidence** — weakest

Rebuttals must provide evidence at equal or higher fidelity than the challenge.
Rebuttals relying solely on reasoning against evidence-backed challenges are invalid.

## Domain-Specific Criteria

Each phase skill provides its own review criteria in `review-prompt.md`.
When dispatching review, the phase skill combines this framework with its
domain-specific criteria. See Invocation section for dispatch format.

Do NOT skip domain criteria if provided. Apply first-principles framework
AND domain checklist together.

## Frame-Level Finding Requirements

When reporting a frame-level finding, the reviewer must include:
1. The core assumption being challenged
2. At least one alternative approach from a different paradigm
3. Why that alternative is worth considering

Without all three, the finding is not a genuine frame challenge — it is vague criticism.

Note: isolation may cause the reviewer to propose alternatives that are impractical in the current engineering context. This is acceptable — the artifact owner filters for feasibility when processing findings. The value of frame challenges is exposing blind spots, not mandating adoption of every alternative.

## Severity Definitions

- **High**: likely invalidates approach or spec compliance, or risks wrong-phase progression
- **Medium**: meaningful defect or risk, but locally containable
- **Low**: worthwhile correction without blocking effect

## Output Format

Output in the same language the human uses. If the conversation is in Chinese, write findings in Chinese.

Frame-level findings must be reported first. Do not output only detail-level fixes while omitting frame-level issues.

```markdown
## Frame-Level Findings

### [severity: high/medium/low] Finding title
**Challenged assumption**: the core assumption being questioned
**Alternative paradigm**: a fundamentally different approach
**Why it matters**: impact if the assumption is wrong
**Suggested fix**: concrete recommendation

## Artifact-Level Findings

### [severity: high/medium/low] Finding title
**Issue**: what's wrong
**Why it matters**: impact if not fixed
**Suggested fix**: concrete recommendation
```

**If no findings**: explicitly state that all four first-principles questions were checked and briefly justify why no frame-level concerns remain. "Looks good" without evidence of review depth is not an acceptable pass.

## Review Outcome

Review findings determine whether the artifact may proceed:
- **Any frame-level high severity finding**: artifact must not enter the next phase. For research/plan/Todo list: author must revise the artifact and re-review. For implementation: if the defect is spec-compliance, fix the implementation; if the defect exposes an upstream plan flaw, return to plan phase rather than patching code. **Circuit breaker**: if the same high severity finding persists after 3 revision-and-re-review cycles, escalate to the approving human rather than continuing the loop.
- **Any spec-compliance failure** (implementation review): review fails. Author must fix before proceeding.
- **Only low/medium findings**: author may proceed after addressing findings, with explicit acknowledgment of remaining risk by the approving human. However, if multiple medium findings touch the same core assumption, surface, or verification gap, reviewer must flag whether they collectively imply a frame-level concern.

Return findings to the artifact owner / generating workflow before progression, merge, or human presentation. The owner routes findings to the correct phase (current artifact revision, implementation fix, or upstream plan revision) before proceeding.

## Invocation

**AI-initiated** (primary — provides context isolation):
The phase skill reads its `review-prompt.md` and dispatches via Agent tool:
```
Agent(prompt="[content of review-prompt.md]\n\n---\n\nArtifact to review:\n\n[artifact text]")
```
The subagent receives: baton-review skill (loaded automatically) + domain criteria
+ artifact text. No generation reasoning, no conversation history.

**Human-initiated** (fallback):
Human invokes `/baton-review` directly. Runs within the current session
context (no isolation). When human-initiated, read the relevant phase's
`review-prompt.md` to get domain criteria. Treat as weaker than subagent review
due to session history influence.

## Platform Support

This skill is designed to work across AI coding hosts. Platform capabilities
differ, but the principle is the same: the reviewer should have no generation
context.

- When true subagent isolation is available (e.g., Agent tool, background agent), use it.
- When subagent isolation is unavailable, fall back to human-initiated review or equivalent isolated mechanism.
- The specific dispatch API differs per host; the isolation requirement does not.
- When dispatching, verify that the subagent received only artifact text and review criteria — no conversation history or generation context should leak. If isolation cannot be verified, treat as untrusted and use fallback (human-initiated) semantics.
