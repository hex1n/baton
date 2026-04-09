# Plan: {task name}

## Metadata

| Key | Value |
|-----|-------|
| Name | {task name} |
| Description | {one-line description of the full task, not just current round} |
| Started | {YYYY-MM-DD} |
| Round | {N} |
| Verifier Mode | {A / B / C / C+} |
| Execution Mode | {compact / standard / full} |
| Scope Class | {S1 / S2 / S3 / S4} |
| Risk Class | {R1 / R2 / R3} |
| Expected Rounds | {1 / 2 / 3+} |
| Expected Slices This Round | {1 / 2 / 3+} |

## Context

> What Planner read. Cite specific files and line numbers.

- `{path/to/file}` L{N}-{M}: {what was found and why it matters}
- `{path/to/other-file}` L{N}: {relevant pattern or code}

### Exploration Boundary

| Explored | Not explored | Reason |
|----------|-------------|--------|
| `{package/module}` | | |
| | `{package/module}` | {not relevant / out of scope / ⚠️ GAP: might be affected} |

### Metrics Baseline

> Required when ACs reference numeric targets (line counts, dependency counts, method counts, etc.). Each metric must include the verification command and its output.

| Metric | Value | Verification command |
|--------|-------|---------------------|
| {e.g., Orchestrator @Resource count} | {14} | `grep -c '@Resource' path/to/File.java` |
| {e.g., OrchestratorTest line count} | {2570} | `wc -l path/to/FileTest.java` |

## Scope Breakdown

> Break the full task into independent feature blocks. Assess clarity.

| # | Feature | Clarity | Round |
|---|---------|---------|-------|
| F1 | {description} | Clear | 1 |
| F2 | {description} | Mostly clear | 1 |
| F3 | {description} | Fuzzy | future |

## Round History

> Compressed summaries. Keep plan.md from growing unbounded, but preserve key decisions and open discoveries.

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

### Plan Quality

> Required on `Planning Depth = deepen`. On normal rounds, keep this section brief but explicit.

| Key | Value |
|-----|-------|
| Planning Depth | {`normal` / `deepen`} |
| Problem Statement | {outcome-focused problem, or `Normal-depth round.`} |
| Load-Bearing Assumptions | {1-3 assumptions, or `None.`} |
| Constraints vs Conventions | {true constraints vs inherited conventions, or `None.`} |
| Alternatives Considered | {Approach A / Approach B / single viable path because ...} |
| Failure Mode | {most likely failure mode, or `None.`} |

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
- Complexity: {slices, files, risk}

**Approach B: {name}**
- Confidence: {高/中/低} — {why}
- Pros: {specific advantages}
- Cons: {specific disadvantages}
- Complexity: {slices, files, risk}

**Recommendation:** {which and why}
**Human choice:** {selected approach, or human's own direction}

### Decisions

| Decision | Chose | Rejected | Why |
|----------|-------|----------|-----|
| {question} | {option A} | {option B} | {rationale} |

### Open Decisions

> Planner records unresolved human choices here. Dispatcher asks these questions; Planner does not ask directly.

| ID | Question | Options | Status | Blocking |
|----|----------|---------|--------|----------|
| OD-{N}.1 | {question or "None."} | {option A / option B / —} | {open / resolved} | {yes / no} |

### Round Contract

> The explicit contract for this round. Verifier pre-flight must either agree with it or request revision.

| Key | Value |
|-----|-------|
| Scope In | {what this round will deliver} |
| Key Entry Points | {semicolon-separated critical files/modules that must remain in scope, or `None.`} |
| Scope Out | {what is explicitly deferred} |
| Done Criteria | {what must be true for the round to count as done} |
| Verification Plan | {how Verifier should validate the round} |
| Budget Note | {why this round should stay single-round, or `None.`} |
| Overload Override | {`none` / `human-approved`} |
| Exit Threshold | {e.g., all ACs pass + no blocking findings} |
| Deferred Items | {follow-up items, or `None.`} |

### Approach

{Selected approach details.}

{What we deliberately don't do this round and why.}

### Implementation Slices

```
Slice 1: {Data layer — models, schemas, migrations}
  Files: {list}
  Check: {compile/check command from project-profile.md}
  Commit: "round-{N} slice 1: data layer"

Slice 2: {Logic layer — services, business logic + unit tests}
  Files: {list}
  Check: {compile + test commands from project-profile.md}
  Commit: "round-{N} slice 2: logic layer"

Slice 3: {Interface layer — API/CLI/UI + integration tests}
  Files: {list}
  Check: {full test suite}
  Commit: "round-{N} slice 3: interface layer + tests"
```

### AC → Test Mapping

> Updated by Builder after implementation.

| AC | Test identifier | Status |
|----|----------------|--------|
| AC-{N}.1 | {test file / function / method} | |
| AC-{N}.2 | {test file / function / method} | |

### Commit Checkpoints

> Updated by Builder after each passing slice. Human commits at their discretion.

| Slice | Files | Suggested message | Compile | Tests |
|-------|-------|-------------------|---------|-------|
| {M} | {file list} | round-{N} slice {M}: {description} | ✅ | ✅ / [deferred — Mode C] |

### Discoveries

> Updated by Builder during implementation. Planner reads this in future rounds.

{None yet.}

### Risks

- {What could go wrong and what to watch for}

## Future Rounds (tentative)

> Don't over-plan. These are rough placeholders, not commitments.

- Round {N+1}: {feature block} — {current clarity level}
- Round {N+2}: {feature block} — {current clarity level}
