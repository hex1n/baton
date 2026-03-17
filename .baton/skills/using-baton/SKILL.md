---
name: using-baton
description: >
  Baton's entry point and governance adapter. Routes to baton phase skills when
  available; enforces minimum governance when external skills produce the output.
  Loaded at SessionStart via hook.
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

Assess task size first (see constitution.md §Task Sizing). Sizing determines
which phases and process steps apply.

| Phase | Baton skill | Value over alternatives |
|-------|------------|----------------------|
| RESEARCH | /baton-research | Evidence model integration, convergence checks |
| PLAN | /baton-plan | First-principles decomposition, surface scan |
| IMPLEMENT | /baton-implement | Discovery protocol, continuous execution |
| REVIEW | /baton-review | Phase-specific review-prompt.md criteria |

## Two Modes

**Mode A — Baton phase skill handles the work:**
Using-baton acts as router only. The phase skill owns both procedure and
governance. No additional process is layered on top.

**Mode B — External skill (or manual work) produces the output:**
Using-baton enforces minimum governance. The external skill handles content
generation; using-baton ensures the output passes review before phase transition.

Minimum governance for Mode B:
- Output must satisfy Output Compliance (below)
- Output must pass through baton-review before proceeding to next phase
- 批注区 annotation cycle must complete before BATON:GO

Phase skills define detailed process loops (self-challenge cycles, convergence
checks, circuit breakers). When in Mode B, these details do not apply — only
the minimum governance above.

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

批注区 is not just a section to append — it is an interactive loop. Human writes
annotations → AI processes each one (with evidence) → updates the document →
human reviews again → repeat until satisfied. A document with an empty 批注区
that was never reviewed by the human has not completed the annotation cycle.

When annotations, challenges, or objections arise, record in `## 批注区`.

Template — copy per annotation:

```md
### [Annotation N]
- **Trigger / 触发点**:
- **Intent as understood / 理解后的意图**:
- **Response / 回应**:
- **Status**: ✅ / ❌ / ❓
- **Impact**: none / clarification only / affects conclusions / blocks next phase
```

Rules:
- Read underlying evidence before responding
- Do not rewrite a challenge into a weaker one
- If accepted, update the relevant section
- If rejected, explain why with evidence
- If unresolved, keep visible as ❓
- If repeated annotations expose the same depth problem, suggest upgrading complexity

## After Review

Review findings are challenges — process per Annotation Protocol above.
