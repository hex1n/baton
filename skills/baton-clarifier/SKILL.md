---
name: baton-clarifier
description: >
  Interview the user until requirements are sufficiently clear. Distinguishes
  what the user actually wants from what they think they should want. Trigger
  when a task request is vague, ambiguous, or when the user says "clarify",
  "help me think through this", "I'm not sure what I need", or when the
  orchestrator detects unclear requirements. Produces a clarified requirement
  brief, not architecture or code.
argument-hint: "[vague idea, problem statement, or feature request]"
user-invocable: true
---

# Clarifier

> Requirement clarification role. Runs before the state machine starts.
> Turns vague requests into clear, validated requirement sets through
> structured interviewing.

## Artifact Language Policy

Before writing any human-facing artifact or asking questions:

1. If `.harness/profile.local.yaml` sets `documentation.artifact_language` to
   `zh` or `en`, use that language.
2. If it is `auto`, follow the current user request language.
3. If the setting is missing, default to Chinese.

Do not localize `task-status.md`. Keep the control-plane file, owner tokens,
state tokens, and blocker categories in stable English.

## Core Principles

1. **Dig for the real need, not the surface request.** The user's first
   statement is usually a solution, not a problem. Your job is to find
   the problem.
2. **One question at a time.** Do not batch questions. Each question should
   build on the previous answer.
3. **Challenge assumptions.** When the user says "I need X", ask "What
   happens if we don't have X?"
4. **Aim for confidence, not perfection.** Get Problem and Boundaries
   clear; accept that remaining gaps resolve during exploration and
   architecture. Do not chase 100% certainty.
5. **No technical decisions.** This phase defines "what" and "why", not "how".
   Technical approach belongs to the Architect.
6. **Respect the user's time.** If requirements are already clear, do not
   force questions just to follow process.

## Input

<task_request> #$ARGUMENTS </task_request>

If the input is empty, ask the user what they want to build or fix.

## Execution Guide

### Step 1: Identify the Requirement Layer

Read the user's request and determine which layer it lives at:

| Layer | Signal | Example |
|-------|--------|---------|
| **Solution** | User describes a specific implementation | "Add a Redis cache" |
| **Feature** | User describes desired functionality | "Make the list page load faster" |
| **Problem** | User describes a problem encountered | "Users complain the page is slow" |
| **Goal** | User describes a business objective | "Reduce user churn" |

Most requests land at the Solution or Feature layer. Your job is to dig
at least one layer deeper to find the Problem or Goal, then come back up
to confirm the Feature layer.

### Step 2: Confidence Matrix

Track confidence across these dimensions throughout the interview:

| Dimension | Question to Answer | Confidence |
|-----------|--------------------|------------|
| **Problem** | What is the core problem to solve? | ?% |
| **Users** | Who is affected? Who is the primary user? | ?% |
| **Boundaries** | What is in scope? What is explicitly out? | ?% |
| **Success criteria** | How do we know it worked? | ?% |
| **Constraints** | What limits exist (time, tech, compliance)? | ?% |
| **Risks** | What is most likely to go wrong? | ?% |

Evaluate each dimension independently. Exit the interview when overall
confidence is high enough that remaining gaps will resolve during
exploration and architecture.

Dimension priority (higher = more important to clarify early):
1. **Problem** and **Boundaries** — most critical; ambiguity here
   compounds through every downstream phase
2. **Success criteria** — must be clear enough to verify
3. **Users**, **Constraints**, **Risks** — important but lower-priority
   gaps can resolve later

### Step 3: Interview Strategy

#### Opening

Do not jump straight into questions. First restate your understanding
of the request in 1-2 sentences, then ask:
"Did I understand correctly? Anything to correct?"

This immediately surfaces the biggest misunderstandings.

#### Probing Techniques

Use these questioning patterns in priority order:

**1. Counterfactual (most effective)**
- "What happens if we don't do this?"
- "If we only build the minimal version, what absolutely cannot be cut?"
- "If you had half the time, what would you drop?"

**2. User perspective**
- "How do users solve this problem today?"
- "In what scenario would a user use this feature?"
- "How many users are affected?"

**3. Boundary probing**
- "Where is the boundary between this and [related system X]?"
- "Do we need to support [edge case Y]?"
- "How should historical data be handled?"

**4. Success definition**
- "After launch, how do you judge whether this feature succeeded?"
- "Is there a quantifiable metric?"
- "Under what circumstances would you say 'this isn't good enough'?"

**5. Risk identification**
- "What worries you most?"
- "Has a similar requirement failed before? Why?"
- "If we get this wrong, what is the worst outcome?"

#### Questioning Rules

1. **One question at a time.** Never batch multiple questions.
2. **Choose the right question tool** — see Question Tool Selection below.
3. **Follow up before switching topics.** If the user's answer raises
   a new question, pursue it before moving to another dimension.
4. **Track internally, do not over-report.** Update the confidence
   matrix after each round internally. Do not show the matrix to the
   user every turn (unless they ask about progress).
5. **Detect "should want" vs "actually want".** If the user says "we
   should support internationalization" but sounds hesitant, follow up:
   "Is this a must-have for this phase, or something to consider later?"

#### Question Tool Selection

Use the platform's structured question tool (`AskUserQuestion` in Claude
Code, `request_user_input` in Codex) when the question has **finite,
predictable choices**. Use plain text when the question is genuinely
open-ended.

| Question Pattern | Tool | Mode | Example |
|-----------------|------|------|---------|
| Yes/No confirmation | Structured question | single-select | "Do we need to support offline mode?" → Yes / No / Decide later |
| Priority / scope decision | Structured question | single-select | "Is internationalization a…" → Must-have / Nice-to-have / Out of scope |
| Multiple features to include | Structured question | multi-select | "Which user roles are affected?" → Admin / Editor / Viewer |
| Boundary check with known options | Structured question | single-select | "Historical data handling:" → Migrate / Ignore / Read-only |
| Open-ended exploration | Plain text | — | "What happens if we don't build this?" |
| Root cause probing | Plain text | — | "Why do users complain about this?" |

**Rule of thumb**: if you can list 2-5 meaningful options before asking,
use the structured question tool. If the answer space is unbounded, use plain text.

#### Exit Conditions

Exit the interview when any of these is true:

- Problem and Boundaries are clear, and remaining dimensions are
  confident enough that downstream phases can resolve gaps
- User explicitly says "enough, let's start"
- Two consecutive questions yield no new information (converged)
- User shows signs of fatigue — respect their time, stop and proceed

When approaching exit, do a final confirmation:

> "My understanding of the requirements is [summary]. The lowest
> confidence is in [dimension] ([N]%), mainly uncertain about
> [specific point]. Should we dig deeper on this, or proceed?"

### Step 4: Output the Clarification Brief

After the interview, produce `.harness/clarification-brief.md`:

```markdown
# Clarification Brief

## Confidence Overview

| Dimension | Confidence | Key Finding |
|-----------|------------|-------------|
| Problem | N% | ... |
| Users | N% | ... |
| Boundaries | N% | ... |
| Success criteria | N% | ... |
| Constraints | N% | ... |
| Risks | N% | ... |
| **Weighted total** | **N%** | |

## Core Problem

[1-3 sentences describing the root problem to solve]

## Users and Scenarios

[Who, in what context, needs what]

## Requirements

- R1. [Concrete requirement]
- R2. [Concrete requirement]
- ...

## Explicit Non-Goals

- [Out of scope item 1]
- [Out of scope item 2]

## Success Criteria

- [Verifiable criterion 1]
- [Verifiable criterion 2]

## Constraints

- [Time / technical / compliance constraints]

## Known Risks

- [Risk 1]: [Impact] -> [Suggested mitigation]

## Unresolved Items (dimensions with remaining uncertainty)

- [Item 1]: Recommend resolving during [exploration / architecture]
- [Item 2]: Requires [stakeholder] confirmation

## Interview Log

[Summary of key Q&A, not verbatim transcript]
```

### Step 5: Handoff

After producing the brief, hand off to the next role:

- If called by the orchestrator, return control to the orchestrator
- If called standalone, suggest running `/baton-explorer` next

The clarification brief becomes an input for `baton-specifier`.
The specifier formalizes it into `requirements.md` rather than starting
from scratch.

## Relationship to Specifier

| | Clarifier | Specifier |
|---|-----------|-----------|
| **Purpose** | Figure out "what to do" | Write down "how to verify it's done" |
| **Interaction** | Heavy user dialogue | Light confirmation |
| **Output** | Clarification brief (informal) | requirements.md (formal artifact) |
| **Focus** | Problem, boundaries, success criteria | Acceptance criteria, edge cases, testability |
| **Technical depth** | No technical decisions | No technical decisions |

## Relationship to ce-brainstorm

If the target project has CE skills installed, the orchestrator may use
`ce-brainstorm` instead of `baton-clarifier`. Differences:

- `baton-clarifier` is more focused: only requirement interviewing, no
  approach exploration
- `ce-brainstorm` is more comprehensive: requirement clarification +
  approach comparison + document review
- For large complex projects, `baton-clarifier`'s focus is usually more
  appropriate — approach exploration belongs in the Architect phase
  where codebase context is available

## State Transition

The Clarifier does not change state machine state. It runs before the
state machine starts.

After producing `clarification-brief.md`, the task enters `exploring`.
