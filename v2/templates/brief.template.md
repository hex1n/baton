# Brief: {task name}

## Task

| Key | Value |
|-----|-------|
| Name | {task name} |
| Description | {one-line description of the full task, not just current round} |
| Started | {YYYY-MM-DD} |
| Round | {N} |
| Verifier Mode | {A / B / C / C+} |
| Execution Mode | {compact / standard / full} |

## Context

> What Planner read. Cite specific files and line numbers.

- `{path/to/file}` L{N}-{M}: {what was found and why it matters}
- `{path/to/other-file}` L{N}: {relevant pattern or code}

### Exploration Boundary

| Explored | Not explored | Reason |
|----------|-------------|--------|
| `{package/module}` | | |
| | `{package/module}` | {not relevant / out of scope / ⚠️ GAP: might be affected} |

## Feature Decomposition

> Break the full task into independent feature blocks. Assess clarity.

| # | Feature | Clarity | Round |
|---|---------|---------|-------|
| F1 | {description} | Clear | 1 |
| F2 | {description} | Mostly clear | 1 |
| F3 | {description} | Fuzzy | future |

## Completed Rounds

> Compressed summaries. Keep brief.md from growing unbounded, but preserve key decisions and open discoveries.

### Round 1: {summary} ✅ ({N} tests)
- Decisions: {key decisions that affect future rounds}
- Open: {unresolved discoveries, or "none"}

### Round 2: {summary} ✅ ({N} tests)
- Decisions: {key decisions}
- Open: {unresolved discoveries, or "none"}

## Round {N}

### Acceptance Criteria

**AC-{N}.1: {short name}**
- Given: {precondition}
- When: {action}
- Then: {expected outcome — observable, testable, with specific values}

**AC-{N}.2: {short name}**
- Given: {precondition}
- When: {action}
- Then: {expected outcome}

### Approach Evaluation

> If only one viable approach, skip this section and write directly in § Approach.

| # | Approach | Confidence | Key trade-off |
|---|----------|------------|---------------|
| A | {name} | {高/中/低} | {one-line} |
| B | {name} | {高/中/低} | {one-line} |

**Approach A: {name}**
- Confidence: {高/中/低} — {why}
- Pros: {specific advantages}
- Cons: {specific disadvantages}
- Complexity: {batches, files, risk}

**Approach B: {name}**
- Confidence: {高/中/低} — {why}
- Pros: {specific advantages}
- Cons: {specific disadvantages}
- Complexity: {batches, files, risk}

**Recommendation:** {which and why}
**Human choice:** {selected approach, or human's own direction}

### Decisions

| Decision | Chose | Rejected | Why |
|----------|-------|----------|-----|
| {question} | {option A} | {option B} | {rationale} |

### Approach

{Selected approach details.}

{What we deliberately don't do this round and why.}

### Batch Plan

```
Batch 1: {Data layer — models, schemas, migrations}
  Files: {list}
  Check: {compile/check command from project-profile.md}
  Commit: "round-{N} batch 1: data layer"

Batch 2: {Logic layer — services, business logic + unit tests}
  Files: {list}
  Check: {compile + test commands from project-profile.md}
  Commit: "round-{N} batch 2: logic layer"

Batch 3: {Interface layer — API/CLI/UI + integration tests}
  Files: {list}
  Check: {full test suite}
  Commit: "round-{N} batch 3: interface layer + tests"
```

### AC → Test Mapping

> Updated by Builder after implementation.

| AC | Test identifier | Status |
|----|----------------|--------|
| AC-{N}.1 | {test file / function / method} | |
| AC-{N}.2 | {test file / function / method} | |

### Discoveries

> Updated by Builder during implementation. Planner reads this in future rounds.

{None yet.}

### Risks

- {What could go wrong and what to watch for}

## Future Rounds (tentative)

> Don't over-plan. These are rough placeholders, not commitments.

- Round {N+1}: {feature block} — {current clarity level}
- Round {N+2}: {feature block} — {current clarity level}
