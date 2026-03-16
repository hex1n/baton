# Investigation Infrastructure

Shared infrastructure for baton investigation phases.
Extends the Evidence Model and Challenge Model defined in `constitution.md`.

---

## Section 1: Extended Evidence Standards

Base labels (from constitution.md Evidence Model):
- `[CODE]` file:line — `[DOC]` external docs — `[RUNTIME]` command output — `[HUMAN]` chat

Extended labels:
- `[DESIGN]` design decision or pattern
- `[EMPIRICAL]` observed behavior in practice

Status: `✅` confirmed — `❌` contradicted / problematic — `❓` unverified

Keep Facts / Inferences / Judgments distinct.

### Conflict resolution

When evidence types disagree:
- Runtime observed behavior > stale docs, unless runtime setup is suspect
- Code implementation > interface comments, unless dead code or non-executed path
- Human-stated intent ≠ current behavior → mark as requirement/expectation mismatch
- Design preference cannot override evidence of current behavior; it only informs judgment

### Evidence provenance

When multiple investigation moves are used, preserve evidence provenance per move.
Do not merge findings across moves so aggressively that the original evidence path
becomes unclear.

---

## Section 2: Self-Challenge

Before presenting conclusions, write `## Self-Challenge` into the artifact:

1. What's the weakest conclusion and why? What evidence would disprove it?
2. What did I NOT investigate that I should have?
3. What assumptions did I make without verifying?

This is **visible output** — the human judges depth.
Shallow answers ("no other alternatives" / "all assumptions verified") signal
that self-challenge was not genuine. Fix before presenting.

---

## Section 3: Review Protocol

After self-challenge, perform an explicit review before presenting conclusions.

Choose the review strategy based on engineering judgment, not form preference.
The goal is review quality — not isolation for its own sake.

### Option A — Isolated review via subagent

Prefer this when:
- the artifact is sufficiently self-contained,
- the reviewer can provide a meaningfully independent perspective,
- and handoff/context-loss risk is low.

If using isolated review:
- provide only the artifact text,
- process findings before presenting,
- record accepted / rejected / unresolved review findings in the artifact.

### Option B — Structured self-review

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

---

## Section 4: 批注区 Protocol

If annotations, challenges, review comments, or human objections arise during work,
record them in `## 批注区`. Do not handle strong challenges silently.

### Required format for each annotation item

- **Trigger / 触发点**: original annotation, objection, or review finding
- **Intent as understood / 理解后的意图**: what concern or claim is being raised
- **Response / 回应**: evidence-backed response
- **Status**: ✅ accepted / ❌ rejected / ❓ unresolved
- **Impact**:
  - none
  - clarification only
  - affects conclusions
  - blocks next phase until resolved

### Rules

- Read the underlying evidence before responding
- Infer intent cautiously; do not rewrite a challenge into a weaker one
- Check whether the annotation exposes contradiction, missing evidence, weak framing, or scope drift
- If accepted, update the relevant section and mark superseded text when needed
- If rejected, explain why with evidence
- If unresolved, keep it visible as ❓ rather than silently dismissing it

### Escalation heuristic

If repeated annotations expose the same class of depth problem
(e.g., repeated missing evidence, repeated framing errors, repeated scope confusion),
note that the task may have been under-scoped and suggest upgrading complexity.
Use pattern judgment, not a rigid numeric threshold.

### Minimum structure

Each entry should use this template:

```md
### [Annotation N]
- Trigger / 触发点:
- Intent as understood / 理解后的意图:
- Response / 回应:
- Status: ✅ / ❌ / ❓
- Impact: none / clarification only / affects conclusions / blocks next phase until resolved
```
