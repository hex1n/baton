---
normative-status: Authoritative specification for the RESEARCH phase.
name: baton-research
description: >
  Use for initial code research on Medium/Large tasks: cross-module behavior
  tracing, ambiguous or contradictory requirements, multi-surface consistency
  checks, or root-cause analysis. Also use for [PAUSE] investigations and
  when user explicitly says "research".
user-invocable: true
context: fork
---

## Iron Law

```
NO CONCLUSIONS WITHOUT EXPLICIT EVIDENCE
NO SOURCE CODE CHANGES DURING RESEARCH — INVESTIGATE ONLY
VERIFY = VISIBLE OUTPUT. "I checked" is not evidence.
FIRST PRINCIPLES BEFORE FRAMING. (reference workflow.md)
```

Research produces understanding, not code. Write findings down for the plan phase.

## When to Use

- Medium/Large tasks requiring cross-module behavior tracing
- Ambiguous or contradictory requirements needing evidence-backed clarification
- Multi-surface consistency checks (N IDEs, N API endpoints, N config formats)
- Root-cause analysis across multiple execution paths
- User says "research" or "deep research"
- After `[PAUSE]` annotation

**When NOT to use**: Quick lookups, single-file explanations, Trivial/Small tasks.

## The Process

### Step 0: Frame the Investigation

Define at top of research file:
- **Question**: what exactly is being investigated
- **Why**: what later decision this supports
- **Scope / Out of scope**: boundaries
- **Known constraints**: repo, platform, tooling

### Step 0.5: Tool Inventory

Use ≥2 distinct search methods beyond Read (e.g., Grep + Glob, Grep + docs,
Grep + runtime verification). Record what you used, what each returned,
why sufficient.

### Step 1: Start from Entry Points

Begin at the human's request or affected files. Observe-then-decide: after
reading each file, decide next based on what you found.

### Step 2: Trace Call Chains

Follow execution paths with evidence:

```
### [Path Name]
**Call chain**: A (file:line) → B (file:line) → C (file:line) → [Stop: reason]
**Risk**: ✅/❌/❓ + description
**Unverified assumptions**: what code was not read and why
```

- Read implementations, not just interfaces — signatures lie
- Stop at framework internals/stdlib — annotate WHY you stopped

### Step 2b: Consistency Matrix (cross-cutting)

When a feature touches N parallel implementations, build a comparison matrix:

| Entity | Detect | Configure | Install |
|--------|--------|-----------|---------|
| IDE A  | ...    | ...       | ...     |

Every cell: direct evidence (file:line), explicit N/A, or documented ❓.
Blank cells not allowed.

### Step 2c: Counterexample Sweep

Before forming conclusions, search for evidence that would disprove them.
Record counterexamples found (or their absence).

### Step 3: Evidence Standards

- `[CODE]` file:line — `[DOC]` external docs — `[RUNTIME]` command output — `[HUMAN]` chat
- `✅` confirmed — `❌` problem — `❓` unverified
- Keep Facts / Inferences / Judgments distinct

### Step 4: Self-Challenge (write into artifact, not just think)

Before presenting, write `## Self-Challenge` into the research file:
1. What's the weakest conclusion and why? What evidence would disprove it?
2. What did I NOT investigate that I should have?
3. What assumptions did I make without reading the code?

Visible output — human judges depth. Shallow answers signal skipped self-challenge.

### Step 5: Dispatch Review

After self-challenge, dispatch review subagent via Agent tool with
only the research artifact. Process findings before presenting.

### Step 6: Convergence Check

Before transitioning to plan:
1. Mark superseded conclusions: "→ Revised in [section]"
2. Write `## Final Conclusions` — currently-valid conclusions with confidence,
   evidence reference, uncertainty, implication
3. Capture chat requirements: "Human requirement (chat): ..."

## Exit Criteria

1. Main path verified with file:line evidence, no ❓ on critical paths
2. Key unknowns explicitly marked ❓ with reason
3. Human judgment questions in `## Questions for Human Judgment`

## Output

Create in `baton-tasks/<topic>/research.md` — always include a topic. End with `## 批注区`.
`mkdir -p baton-tasks/<topic>` before writing.

## Annotation Protocol

Cross-cutting rules in workflow.md apply. For each annotation: read code,
infer intent, respond with evidence, check for contradictions. If 3+
annotations signal depth issues → suggest upgrading complexity.
