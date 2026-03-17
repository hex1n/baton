---
name: using-baton
description: >
  Baton's entry-point skill. Orchestrates baton/external skills and enforces
  artifact governance. Loaded at SessionStart via hook — do not invoke manually.
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, skip this skill.
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
In a baton project, ALL working documents — regardless of which skill created
them — must comply with baton governance. This is not optional.
</EXTREMELY-IMPORTANT>

## Instruction Priority

Human instruction > constitution.md > phase skills > extension skills > external skills.
External skills must comply with baton governance.
If an external skill's default conflicts with baton governance, baton governance wins.

## The Rule

**Use baton phase skills for their respective phases. External skills may supplement
but not replace the phase skill's authority. Every working document must comply with
`constitution.md`.**

## Skill Orchestration

### Phase routing

| Phase | Baton skill | When to use |
|-------|------------|-------------|
| RESEARCH | /baton-research | Systematic investigation, evidence gathering |
| PLAN | /baton-plan | Translating findings into implementation contract |
| IMPLEMENT | /baton-implement | Executing approved plan with BATON:GO |
| REVIEW | /baton-review | Adversarial review of any artifact |

### Working with external skills

External skills (superpowers:brainstorming, superpowers:writing-plans, etc.) may be
used alongside baton skills. The orchestration rule:

- **External skill produces a document** → baton governance applies (location, 批注区, evidence labels)
- **External skill overlaps with a phase skill** → baton phase skill takes precedence for procedure; external skill may add supplementary value
- **External skill has its own format** → adapt to include baton requirements, don't strip them

### Skill priority

When multiple skills could apply:

1. **Baton phase skills first** — they define the phase procedure
2. **Extension skills second** (baton-debug, etc.) — supplementary
3. **External skills third** — must operate within baton governance

## Red Flags

These thoughts mean STOP — you're bypassing governance:

| Thought | Reality |
|---------|---------|
| "This external skill has its own format" | External format + baton governance. Both apply. |
| "批注区 is only for baton skills" | 批注区 is for ALL documents in a baton project. |
| "This doc goes in docs/ because the skill defaults there" | Override to `baton-tasks/<topic>/`. Parser depends on it. |
| "Evidence labels are overkill for this" | Constitution-level invariant. Not optional. |
| "Self-Challenge isn't needed for this artifact" | Self-Challenge applies to all plan and research artifacts. |
| "I'll add 批注区 later" | Append it NOW, before presenting to the human. |
| "This external skill already reviewed the output" | Does it check constitution.md compliance? If not, insufficient. |
| "Simple doc, governance is overhead" | Simple docs get simple compliance. Still must comply. |
| "The external skill is more capable here" | Capability ≠ authority. Phase skill defines procedure. |
| "I'll use an external review skill for this baton artifact" | baton-review has phase-specific criteria that external reviewers lack. Use Review Dispatch templates below, unless the user explicitly requests a different reviewer. |

## Artifact Governance

When any skill produces a working document, it must comply with:

1. **Location**: `baton-tasks/<topic>/` (unless repo convention overrides)
2. **批注区**: every research or plan document ends with `## 批注区` (see Annotation Protocol below)
3. **Evidence labels**: `[CODE]`/`[DOC]`/`[RUNTIME]`/`[HUMAN]` with status `✅`/`❌`/`❓`
4. **Self-Challenge**: `## Self-Challenge` with ≥3 substantive answers
5. **BATON:GO gate**: no source code changes without BATON:GO in the plan

If non-compliant, fix before presenting to the human.

Phase skills define the detailed format and review criteria for their phases.

## Annotation Protocol

When annotations, challenges, or objections arise in any working document, record them in `## 批注区` with:

- **Trigger / 触发点**: the original annotation or objection
- **Intent as understood / 理解后的意图**: what concern is being raised
- **Response / 回应**: evidence-backed response
- **Status**: ✅ accepted / ❌ rejected / ❓ unresolved
- **Impact**: none / clarification only / affects conclusions / blocks next phase

Rules:
- Read underlying evidence before responding
- Do not rewrite a challenge into a weaker one
- If accepted, update the relevant section
- If rejected, explain why with evidence
- If unresolved, keep visible as ❓
- If repeated annotations expose the same depth problem, suggest upgrading complexity

## Review Dispatch

For baton-governed artifacts (research, plan, implementation), use baton-review — it
applies phase-specific review-prompt.md criteria that external review skills lack.
Copy-paste the matching template:

**Plan review:**
```
Agent(prompt="<review-criteria>\n[paste content of .baton/skills/baton-plan/review-prompt.md]\n</review-criteria>\n\n<artifact>\n[paste plan text]\n</artifact>")
```

**Implementation review:**
```
Agent(prompt="<review-criteria>\n[paste content of .baton/skills/baton-implement/review-prompt.md]\n</review-criteria>\n\n<artifact>\n[paste git diff output]\n</artifact>\n\n<plan>\n[paste plan text]\n</plan>")
```

**Research review:**
```
Agent(prompt="<review-criteria>\n[paste content of .baton/skills/baton-research/review-prompt-codebase.md]\n</review-criteria>\n\n<artifact>\n[paste research text]\n</artifact>")
```

Steps: (1) Read the matching review-prompt.md → (2) Read the artifact → (3) Dispatch via Agent with template above.

## After Review

Review findings are challenges — process per Annotation Protocol above.
