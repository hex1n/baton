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

See constitution.md → Authority Model for the complete hierarchy.
External skills must comply with constitution.md and shared-protocols.md.
If an external skill's default conflicts with baton governance, baton governance wins.

## The Rule

**Use baton phase skills for their respective phases. External skills may supplement
but not replace the phase skill's authority. Every working document must comply with
`.baton/shared-protocols.md`.**

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

- **External skill produces a document** → baton governance applies (location, 批注区, evidence labels, shared-protocols.md)
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
| "Self-Challenge isn't needed for this artifact" | shared-protocols.md Section 2 applies to all artifacts. |
| "I'll add 批注区 later" | Append it NOW, before presenting to the human. |
| "This external skill already reviewed the output" | Does it check shared-protocols.md compliance? If not, insufficient. |
| "Simple doc, governance is overhead" | Simple docs get simple compliance. Still must comply. |
| "The external skill is more capable here" | Capability ≠ authority. Phase skill defines procedure. |

## Artifact Governance

All artifact invariants (location, 批注区, evidence labels, BATON:GO gate) are defined
in `constitution.md` → Artifact Model. They are always loaded and not restated here.

Operational protocols for all working documents are in `.baton/shared-protocols.md`:
- Section 1: Evidence standards
- Section 2: Self-Challenge
- Section 3: Review protocol
- Section 4: 批注区 protocol (annotation format, template, escalation)

**Enforcement**: when any skill produces a document, check compliance with both
the Artifact Model invariants and shared-protocols.md. If non-compliant, fix
before presenting to the human.

**Failure boundary**: follow constitution.md → Permission Model → Failure boundary.

## After Review

Review findings are challenges — process per constitution.md Challenge Model.
