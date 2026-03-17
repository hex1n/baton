---
name: using-baton
description: >
  Baton's entry-point skill. Defines output governance for all working documents
  regardless of which skill produced them. Loaded at SessionStart via hook.
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, skip this skill.
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
In a baton project, ALL working documents — regardless of which skill created
them — must comply with baton governance. This is not optional.
</EXTREMELY-IMPORTANT>

## The Rule

**Baton governs output, not tool choice.** Use any skill to do the work. The
output must comply with `constitution.md`. Hooks enforce compliance at write time;
review verifies quality after.

## Governance Model

Baton is a governance wrapper, not a capability provider:

- **What to do next** → baton phase workflow (research → plan → implement → review)
- **How to do it** → any skill (baton phase skill, external skill, or manual)
- **Is the output compliant?** → hooks + review check

When a baton phase skill exists for the current phase, it provides the best
procedure because it understands baton's governance requirements natively. But
the reason to prefer it is quality, not prohibition.

## Phase Routing

| Phase | Baton skill | Value over alternatives |
|-------|------------|----------------------|
| RESEARCH | /baton-research | Evidence model integration, convergence checks |
| PLAN | /baton-plan | First-principles decomposition, surface scan |
| IMPLEMENT | /baton-implement | Discovery protocol, continuous execution |
| REVIEW | /baton-review | Phase-specific review-prompt.md criteria |

## Output Compliance

Every working document must satisfy these regardless of which skill produced it:

1. **Location**: `baton-tasks/<topic>/`
2. **批注区**: research and plan documents end with `## 批注区`
3. **Evidence labels**: `[CODE]`/`[DOC]`/`[RUNTIME]`/`[HUMAN]` with status `✅`/`❌`/`❓`
4. **Self-Challenge**: `## Self-Challenge` with ≥3 substantive answers
5. **BATON:GO gate**: no source code changes without BATON:GO in the plan

If a skill produces non-compliant output, fix before presenting to the human.

## Red Flags

These thoughts mean STOP — the output will violate governance:

| Thought | Reality |
|---------|---------|
| "This skill's format doesn't include 批注区" | Append it. Compliance is on the output, not the skill. |
| "This doc goes in docs/ because the skill defaults there" | Override to `baton-tasks/<topic>/`. Hooks depend on it. |
| "Evidence labels are overkill for this" | Constitution invariant. Not optional. |
| "I'll add 批注区 later" | Append it NOW, before presenting to the human. |
| "The skill already reviewed the output" | Does it check constitution.md compliance? If not, review is incomplete. |

## Review Dispatch

baton-review provides phase-specific review-prompt.md criteria that general
reviewers lack. For baton-governed artifacts, prefer it unless the user
explicitly requests a different reviewer. Copy-paste templates:

**Plan review:**
```
Agent(prompt="<review-criteria>\n[paste .baton/skills/baton-plan/review-prompt.md]\n</review-criteria>\n\n<artifact>\n[paste plan text]\n</artifact>")
```

**Implementation review:**
```
Agent(prompt="<review-criteria>\n[paste .baton/skills/baton-implement/review-prompt.md]\n</review-criteria>\n\n<artifact>\n[paste git diff]\n</artifact>\n\n<plan>\n[paste plan text]\n</plan>")
```

**Research review:**
```
Agent(prompt="<review-criteria>\n[paste .baton/skills/baton-research/review-prompt-codebase.md]\n</review-criteria>\n\n<artifact>\n[paste research text]\n</artifact>")
```

## Annotation Protocol

When annotations, challenges, or objections arise, record in `## 批注区`:

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

## After Review

Review findings are challenges — process per Annotation Protocol above.
