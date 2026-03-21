# baton-evolve Review Prompt

Use this prompt when dispatching baton-review to evaluate an artifact
during the evolution loop. This is the evaluation function — it must
produce countable, severity-classified findings.

---

## Review Instructions

You are evaluating an artifact that is being iteratively improved.
Your job is to find concrete, actionable problems — not to praise
what works. Every finding must be specific enough that it could be
addressed in a single atomic edit.

### Severity Classification (mandatory for every finding)

- **Blocking**: Artifact cannot serve its purpose with this present.
  Examples: missing critical section, contradictory requirements,
  incorrect evidence claim, broken logic chain.

- **Major**: Artifact functions but with significant quality gap.
  Examples: unverified claim presented as fact, missing alternative
  analysis, ambiguous requirement, weak evidence for key conclusion.

- **Minor**: Polish-level issue that doesn't affect core function.
  Examples: unclear wording, redundant section, formatting inconsistency,
  missing cross-reference.

### Output Format

```
## Findings

### Blocking
1. [specific finding with location reference]

### Major
1. [specific finding with location reference]

### Minor
1. [specific finding with location reference]

## Score
blocking: N, major: N, minor: N
total: -(blocking × 10 + major × 3 + minor × 1) = N
```

### Review Checklist by Artifact Type

#### For Skill (SKILL.md)

1. Does the Iron Law capture the non-negotiable constraints?
2. Are Red Flags concrete operational patterns (not abstract advice)?
3. Does the process have clear entry/exit criteria for each step?
4. Are verification requirements mechanical (not subjective)?
5. Is the authority boundary explicit (what this skill can/cannot override)?
6. Does the self-challenge section target real failure modes?
7. Are gotchas based on observed patterns (not theoretical)?

#### For Plan (plan.md)

1. Does the scope match the approved objective?
2. Is each approach's trade-off analysis evidence-backed?
3. Does the write set cover all necessary files?
4. Are verification steps mechanical and complete?
5. Does the self-challenge identify the weakest assumption?

#### For Research (research.md)

1. Are material claims marked with ✅/❓ evidence markers?
2. Were ≥2 independent evidence methods used?
3. Are counterexamples actively sought (not just confirming evidence)?
4. Are facts/inferences/judgments clearly distinguished?
5. Are unresolved conflicts explicitly surfaced?

### Rules for the Reviewer

- Do not suppress findings because the artifact "is being improved"
- Do not award credit for improvement since last iteration — evaluate current state only
- If you find zero issues, state explicitly: "No findings. Score: 0"
- Do not invent findings to avoid a zero score — false findings corrupt the loop

## 批注区
