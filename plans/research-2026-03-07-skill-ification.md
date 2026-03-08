# Research: Claude Code Skill (SKILL.md) Writing Best Practices

## Sources Consulted

| Source | Type | Value |
|--------|------|-------|
| [Anthropic Official: Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) | Official docs | Authoritative reference for all skill design |
| [Claude Code Docs: Extend Claude with skills](https://code.claude.com/docs/en/skills) | Official docs | Frontmatter fields, activation, subagents, context budget |
| [Claude Code plugin-dev SKILL.md](https://github.com/anthropics/claude-code/blob/main/plugins/plugin-dev/skills/skill-development/SKILL.md) | Official docs (via Context7) | Description 必须第三人称 + 引用触发短语 |
| [agentskills.io 规范](https://agentskills.io/specification) | Open standard (via Context7) | 跨 IDE SKILL.md 标准，20+ IDE 支持 |
| [superpowers plugin (obra/superpowers)](https://github.com/obra/superpowers) | Community exemplar | 14 battle-tested skills with TDD-based skill testing methodology |
| [superpowers-skills (obra/superpowers-skills)](https://github.com/obra/superpowers-skills) | Community exemplar | 30+ skills with categorized organization |
| [Anthropic's official skills repo (anthropics/skills)](https://github.com/anthropics/skills) | Official exemplar | skill-creator with eval framework + description optimization |
| [Gist: Claude Code Skills Structure Guide](https://gist.github.com/mellanon/50816550ecb5f3b239aa77eef7b8ed8d) | Community analysis | Activation rate data, optimization strategies |
| [alexop.dev: Claude Code Customization Guide](https://alexop.dev/posts/claude-code-customization-guide-claudemd-skills-subagents/) | Community guide | Skill vs command patterns, architecture |

---

## 1. How Skill Activation Works (Mechanism)

### The Matching Pipeline

Skills are NOT matched by keyword search, embeddings, or regex. The mechanism is **pure LLM reasoning**:

1. At startup, all skill `name` + `description` pairs are injected into Claude's system prompt as an `<available_skills>` block
2. When a user message arrives, Claude's transformer forward pass analyzes all descriptions against user intent
3. Claude decides whether to invoke the `Skill` tool to load the full SKILL.md content
4. Only then is the SKILL.md body loaded into context

**Critical implication**: The description is the ONLY thing Claude sees when deciding whether to activate a skill. The body content is invisible at selection time.

### Context Budget for Descriptions

- Budget scales at **2% of context window**, fallback of 16,000 characters
- If too many skills exist, some descriptions may be excluded entirely
- Each description: max 1,024 characters (hard limit in YAML frontmatter)
- Override with `SLASH_COMMAND_TOOL_CHAR_BUDGET` env var

### Activation Rate Data (from community testing)

| Approach | Activation Rate |
|----------|----------------|
| No optimization / vague description | ~20% |
| Optimized description ("Use when..." pattern) | ~50% |
| Description + examples in skill body | 72% |
| Description + examples + hook-based forcing | 84-90% |

---

## 2. Description Field: The Single Most Important Line

### What Makes a Good Description

The description must answer TWO questions:
1. **What** does the skill do?
2. **When** should Claude use it?

### Format Rules (verified from Anthropic docs)

- **Third person always** (description is injected into system prompt)
  - Good: "Processes Excel files and generates reports"
  - Bad: "I can help you process Excel files" / "You can use this to..."
- Max 1,024 characters
- No XML tags
- Cannot contain reserved words: "anthropic", "claude"

### The Superpowers Discovery: Description = Triggers Only, NOT Workflow

This is the most important finding from the superpowers project (writing-skills/SKILL.md:150-172):

> "Testing revealed that when a description summarizes the skill's workflow, Claude may follow the description instead of reading the full skill content."

Example: A description saying "code review between tasks" caused Claude to do ONE review, even though the skill's flowchart clearly showed TWO reviews. When changed to just triggering conditions, Claude correctly read and followed the full skill.

**The trap**: Descriptions that summarize workflow create a shortcut Claude will take. The skill body becomes documentation Claude skips.

```yaml
# BAD: Summarizes workflow - Claude may follow this instead of reading skill
description: Use when executing plans - dispatches subagent per task with code review between tasks

# BAD: Too much process detail
description: Use for TDD - write test first, watch it fail, write minimal code, refactor

# GOOD: Just triggering conditions, no workflow summary
description: Use when executing implementation plans with independent tasks in the current session

# GOOD: Triggering conditions only
description: Use when implementing any feature or bugfix, before writing implementation code
```

### Anthropic's Guidance: Be "Pushy"

From skill-creator/SKILL.md:67:

> "Currently Claude has a tendency to 'undertrigger' skills -- to not use them when they'd be useful. To combat this, please make the skill descriptions a little bit 'pushy'."

Example: Instead of "How to build a dashboard" write "How to build a dashboard. Make sure to use this skill whenever the user mentions dashboards, data visualization, internal metrics, or wants to display any kind of company data, even if they don't explicitly ask for a 'dashboard.'"

### Description Patterns from Superpowers (all verified from actual files)

| Skill | Description | Pattern |
|-------|-------------|---------|
| brainstorming | "You MUST use this before any creative work - creating features, building components, adding functionality, or modifying behavior." | Mandatory + trigger list |
| test-driven-development | "Use when implementing any feature or bugfix, before writing implementation code" | "Use when" + timing |
| systematic-debugging | "Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes" | "Use when" + symptom list |
| writing-plans | "Use when you have a spec or requirements for a multi-step task, before touching code" | "Use when" + prerequisite |
| verification-before-completion | "Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires running verification commands..." | "Use when" + timing + action |
| subagent-driven-development | "Use when executing implementation plans with independent tasks in the current session" | "Use when" + specific context |
| using-superpowers | "Use when starting any conversation - establishes how to find and use skills" | "Use when" + always |

**Pattern**: Start with "Use when" + specific triggering conditions. Never summarize process.

---

## 3. Content Structure That AI Follows Reliably

### The Three-Level Loading Model

| Level | What | When Loaded | Token Cost |
|-------|------|-------------|------------|
| 1. Metadata | name + description | Always in context | ~100 words |
| 2. SKILL.md body | Instructions, patterns, examples | When skill triggers | <500 lines |
| 3. Bundled resources | Reference docs, scripts, templates | When explicitly needed | Unlimited |

### Effective Body Structure (synthesized from all sources)

```markdown
---
name: skill-name
description: Use when [triggering conditions]. Activates for [symptoms/contexts].
---

# Skill Name

## Overview
Core principle in 1-2 sentences. What this IS.

## When to Use
- Bullet list with SYMPTOMS and use cases
- When NOT to use
- [Optional: small inline flowchart IF decision is non-obvious]

## The Iron Law / Core Rule
(For discipline skills) The ONE non-negotiable rule in a code block

## The Process / Core Pattern
Step-by-step or before/after code comparison

## Red Flags - STOP
What thoughts mean you're about to violate the skill

## Common Rationalizations
| Excuse | Reality | table

## Quick Reference
Table or bullets for scanning

## Integration
Cross-references to other skills (REQUIRED SUB-SKILL syntax)
```

### Key Structural Insights

**1. Iron Laws work** (superpowers pattern):
Every discipline-enforcing superpowers skill uses a "code block iron law" format:
```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```
This creates an absolute reference point that resists rationalization.

**2. Rationalization tables are essential for discipline skills** (TDD skill has 11 entries, debugging has 8, verification has 8). These are pre-computed counter-arguments that the AI can access when it's tempted to shortcut.

**3. Red Flags lists trigger self-monitoring**. Every superpowers skill lists thought patterns that indicate the AI is about to violate the skill. This creates metacognitive awareness.

**4. Flowcharts are used sparingly** but effectively for non-obvious decision points. The superpowers writing-skills SKILL.md explicitly says: "Use flowcharts ONLY for non-obvious decision points, process loops where you might stop too early, and 'When to use A vs B' decisions."

**5. `<HARD-GATE>` tags** block premature action (brainstorming:14-16):
```xml
<HARD-GATE>
Do NOT invoke any implementation skill, write any code, scaffold any project,
or take any implementation action until you have presented a design and the
user has approved it.
</HARD-GATE>
```

**6. `<EXTREMELY-IMPORTANT>` tags** for absolute requirements (using-superpowers:6-12):
```xml
<EXTREMELY-IMPORTANT>
If you think there is even a 1% chance a skill might apply...
YOU ABSOLUTELY MUST invoke the skill.
</EXTREMELY-IMPORTANT>
```

---

## 4. Persuasion vs Commanding: What Actually Works

### Research Foundation

Meincke et al. (2025) tested 7 persuasion principles with N=28,000 AI conversations. Persuasion techniques more than doubled compliance rates (33% to 72%, p < .001).

### The Seven Principles Ranked by Effectiveness for Skills

| Principle | Mechanism | Use For | Avoid For |
|-----------|-----------|---------|-----------|
| **Authority** | "YOU MUST", "Never", "No exceptions" | Discipline skills (TDD, verification) | Reference, flexible guidance |
| **Commitment** | Require announcements, checklists, explicit choices | Multi-step processes, accountability | Simple reference |
| **Scarcity** | "Before proceeding", "IMMEDIATELY after" | Verification, time-sensitive workflows | General guidance |
| **Social Proof** | "Every time", "X without Y = failure" | Universal practices, warning of failures | Niche patterns |
| **Unity** | "We're colleagues", "our codebase" | Collaborative workflows | Discipline enforcement |
| **Reciprocity** | Rarely effective | Almost never | Almost always |
| **Liking** | Creates sycophancy | Never for discipline | Always avoid |

### Superpowers Uses Persuasion Systematically

Superpowers skill patterns mapped to principles:

- **Iron Laws** = Authority + Commitment (absolute rules)
- **"Announce at start"** = Commitment (public declaration)
- **Rationalization tables** = Authority + Social Proof (pre-computed counter-arguments + "this is what failure looks like")
- **Red Flags** = Scarcity (urgency to stop before it's too late)
- **"Violating the letter is violating the spirit"** = Authority (closes the entire "spirit vs letter" rationalization category)

### Anthropic's Contrasting View: Explain the Why

From skill-creator/SKILL.md:302:

> "Try hard to explain the **why** behind everything. Today's LLMs are *smart*. If you find yourself writing ALWAYS or NEVER in all caps, that's a yellow flag -- if possible, reframe and explain the reasoning so that the model understands why."

**Synthesis**: The two approaches are NOT contradictory. They apply to different skill types:

| Skill Type | Approach | Why |
|------------|----------|-----|
| **Discipline-enforcing** (TDD, verification, baton write-lock) | Authority + rationalization prevention | LLMs rationalize around soft guidelines when under pressure |
| **Technique/guidance** (research strategy, plan structure) | Explain the why + moderate authority | LLMs perform better with understanding than blind compliance |
| **Reference** (API docs, syntax) | Clarity only, no persuasion needed | Information retrieval, not behavior modification |

---

## 5. Anti-Patterns to Avoid

### Description Anti-Patterns
1. **Vague descriptions**: "Helps with documents" (20% activation)
2. **First-person descriptions**: "I can help you..." (breaks system prompt injection)
3. **Workflow summaries in description**: Claude follows description instead of reading body
4. **Missing "when to use"**: Claude can't determine trigger conditions

### Content Anti-Patterns
1. **Over-explaining what Claude already knows**: "PDF (Portable Document Format) files are..." wastes tokens
2. **Too many options**: "You can use pypdf, or pdfplumber, or PyMuPDF, or..." -- provide a default with escape hatch
3. **Deeply nested references**: SKILL.md -> file A -> file B -> actual info. Keep references ONE level deep.
4. **Conflicting instructions between skills**: One says "always ask", another says "execute autonomously"
5. **Time-sensitive information**: "If before August 2025, use old API"
6. **Inconsistent terminology**: Mixing "endpoint/URL/route/path" for the same concept
7. **Narrative storytelling**: "In session 2025-10-03, we found..." -- not reusable
8. **Multi-language dilution**: example-js.js, example-py.py, example-go.go -- one excellent example beats many mediocre ones
9. **Code in flowcharts**: Can't copy-paste, hard to read
10. **Generic labels**: helper1, step2 -- labels need semantic meaning
11. **Force-loading with @**: `@skills/path/SKILL.md` burns context immediately (superpowers warns against this)

### Structural Anti-Patterns
1. **SKILL.md over 500 lines** (official recommendation: split into reference files)
2. **No progressive disclosure**: Everything in one file vs. splitting heavy reference
3. **No table of contents for reference files >100 lines**
4. **Windows-style paths**: `scripts\helper.py` -- always use forward slashes

---

## 6. Testing Skills

### Superpowers' TDD Approach to Skills

The writing-skills SKILL.md maps TDD concepts to skill testing:

| TDD Concept | Skill Creation |
|-------------|----------------|
| Test case | Pressure scenario with subagent |
| Production code | Skill document (SKILL.md) |
| Test fails (RED) | Agent violates rule without skill (baseline) |
| Test passes (GREEN) | Agent complies with skill present |
| Refactor | Close loopholes while maintaining compliance |

**Process**:
1. RED: Run pressure scenarios WITHOUT skill -> document baseline behavior + rationalizations
2. GREEN: Write minimal skill addressing those specific rationalizations
3. REFACTOR: Find new rationalizations -> plug them -> re-verify

### Anthropic's Eval-Based Approach

From skill-creator/SKILL.md:

1. Write draft skill
2. Create 2-3 realistic test prompts
3. Spawn with-skill AND without-skill (baseline) subagent runs
4. Grade assertions (programmatic where possible)
5. Generate eval viewer for human review
6. Iterate based on feedback
7. Optimize description with 20-query eval set (mix of should-trigger and should-not-trigger)

### Quick Testing Without Full Framework

For baton skills specifically:
1. Ask Claude to perform the task without the skill (baseline)
2. Invoke the skill explicitly with `/skill-name`
3. Compare behavior: does Claude follow the process? Does it resist rationalization?
4. Check that descriptions trigger on natural language ("let me research this codebase", "help me plan this feature")

---

## 7. Superpowers Pattern Analysis: What Makes Their Skills Effective

### Cross-Cutting Patterns Across All 14 Core Skills

**1. Mandatory announcements create commitment**:
- brainstorming: no explicit announcement but creates TodoWrite items
- writing-plans: "Announce at start: 'I'm using the writing-plans skill'"
- executing-plans: "Announce at start: 'I'm using the executing-plans skill'"

**2. Terminal states prevent drift**:
- brainstorming: "The terminal state is invoking writing-plans. Do NOT invoke frontend-design, mcp-builder, or any other implementation skill."
- Each skill has a clear "what happens next" that chains to the next skill.

**3. Cross-referencing uses explicit requirement markers**:
- "REQUIRED SUB-SKILL: Use superpowers:test-driven-development"
- "REQUIRED BACKGROUND: You MUST understand superpowers:systematic-debugging"
- Never uses `@` file references (which force-load into context)

**4. Checklists create accountability**:
- writing-plans: "IMPORTANT: Use TodoWrite to create todos for EACH checklist item"
- verification-before-completion: Gate function is a numbered checklist

**5. Good/Bad examples are inline**, using `<Good>` and `<Bad>` XML tags (TDD skill) or code blocks with comments.

**6. The "3 strikes" escalation pattern**:
- systematic-debugging: "If 3+ Fixes Failed: Question Architecture"
- baton workflow already uses this: "Same approach fails 3x -> MUST stop"

**7. Token efficiency is a design concern**:
- writing-skills says: getting-started workflows <150 words, frequently-loaded skills <200 words, other skills <500 words
- Cross-references instead of repeating content
- Tool help references instead of documenting all flags

---

## 8. Actionable Recommendations for Baton Skills

### Skill Architecture for Baton

Baton has three clear phases that map to skills: RESEARCH, PLAN, IMPLEMENT. These should be skills, not embedded in CLAUDE.md.

**Why skills instead of CLAUDE.md**:
- Skills load on demand (progressive disclosure) vs CLAUDE.md loads every session
- Skills have activation logic (description matching) vs CLAUDE.md is always-on
- Skills can be invoked explicitly with `/baton-research` etc.
- Phase guidance is currently "injected by SessionStart hook" but skill activation achieves the same with less infrastructure

### Description Design for Baton Skills

Based on all research, baton skill descriptions should:

1. Start with "Use when" + specific triggering conditions
2. List symptoms/contexts that signal this phase
3. Be "pushy" about activation -- include natural language triggers
4. NOT summarize the baton workflow process
5. Use third person

Draft descriptions:

```yaml
# baton-research
description: >
  Investigates unfamiliar code to build verified understanding. Use when starting
  analysis of a codebase, tracing execution paths, investigating how code works,
  or when the user asks to research, analyze, explore, or understand code.
  Produces research.md with file:line evidence for every claim.

# baton-plan
description: >
  Creates change proposals with approach analysis, impact assessment, and risk
  mitigation. Use when requirements are understood and a concrete plan is needed
  before implementation, when the user says "make a plan", "plan this", or after
  research is complete. Produces plan.md for human annotation and approval.

# baton-implement
description: >
  Executes approved plans faithfully with verification against design intent.
  Use when plan.md contains BATON:GO and the user says "generate todolist" or
  "implement". Requires an approved plan with BATON:GO marker before any source
  code changes.
```

### Content Principles for Baton Skills

1. **Move phase guidance from workflow-full.md into SKILL.md files** -- currently the detailed [RESEARCH], [PLAN], [ANNOTATION], [IMPLEMENT] sections live in workflow-full.md and are "injected by the SessionStart hook." Skills are the native mechanism for this.

2. **Keep cross-phase principles in CLAUDE.md / workflow.md** -- the Mindset, Evidence Standards, Annotation Protocol, and Action Boundaries apply across all phases and should remain always-loaded.

3. **Use Iron Laws for baton's hard gates**:
   ```
   NO SOURCE CODE CHANGES WITHOUT BATON:GO IN PLAN.MD
   NO TODOLIST WITHOUT HUMAN SAYING "GENERATE TODOLIST"
   NO BATON:GO PLACED BY AI -- ONLY THE HUMAN PLACES IT
   ```

4. **Build rationalization tables** for each skill. What excuses will the AI use to skip research? To skip annotation? To implement without BATON:GO?

5. **Use Red Flags lists** for each phase. What thought patterns signal the AI is about to violate baton's principles?

6. **Explain the why for technique guidance** -- baton's research strategy hints, annotation thinking posture, and plan approach analysis benefit from understanding, not just compliance.

7. **Token budget**: Keep each SKILL.md under 300 lines. The workflow-full.md [RESEARCH] section alone is ~65 lines -- well within budget. Move the detailed annotation cycle guidance to a reference file if needed.

### Structural Recommendations

```
.claude/skills/
  baton-research/
    SKILL.md              # Research phase guide (~200 lines)
  baton-plan/
    SKILL.md              # Plan phase guide (~200 lines)
  baton-implement/
    SKILL.md              # Implementation phase guide (~150 lines)
  baton-annotate/
    SKILL.md              # Annotation cycle guide (~150 lines)
```

**Alternative**: A single `baton/SKILL.md` that serves as router + cross-phase principles, with phase-specific reference files. This trades activation precision for simpler structure.

### Differentiation from Superpowers

Baton skills should NOT replicate superpowers. Key differences:

| Aspect | Superpowers | Baton |
|--------|-------------|-------|
| **Philosophy** | Agent-centric: teach AI methodology | Human-centric: shared understanding construction |
| **Gate mechanism** | TodoWrite checklists, self-checks | Human annotation + explicit BATON:GO |
| **Evidence standard** | Test results, code review | file:line citations, verified claims |
| **Feedback loop** | Subagent code review | Human annotation cycle with [Q], [CHANGE], [DEEPER] |
| **Transparency** | Agent self-review | AI surfaces uncertainty, disagrees with evidence |

Baton's unique value is the **human-in-the-loop annotation cycle** and the **evidence standard** that forces the AI to cite file:line for every claim. Skills should reinforce these differentiators, not dilute them with generic methodology.

---

## Self-Review

1. **A skeptic would challenge**: "Do activation rates from the community gist (20% -> 50% -> 90%) actually apply to Claude Code's current matching implementation?" -- The data comes from community testing, not Anthropic's official benchmarks. Activation behavior may have changed. However, Anthropic's own skill-creator acknowledges undertriggering as a known issue (skill-creator/SKILL.md:67), which corroborates the community findings.

2. **Weakest conclusion**: The recommendation to split baton into 3-4 separate skills vs. one router skill. The optimal choice depends on how many other skills are in the user's environment (context budget) and whether the skills compete with each other for activation. This needs testing.

3. **What would change the analysis**: If Claude Code's skill activation mechanism changes (e.g., to embedding-based matching), the description optimization strategies would need revision. Also, if baton is packaged as a plugin (which has its own skill namespace), the activation dynamics would differ from project-level skills.

## Questions for Human Judgment

1. Should baton skills be project-level (`.claude/skills/`) or packaged as a plugin? Plugin skills use a `plugin-name:skill-name` namespace which prevents conflicts but changes how descriptions are matched.

2. The current workflow.md is loaded via `@.baton/workflow.md` in CLAUDE.md -- this means it's always in context. If we move phase guidance to skills, should workflow.md shrink to just cross-phase principles (~2KB) to save the token budget for skill descriptions?

3. Should there be a `baton-annotate` skill separate from `baton-plan` and `baton-research`? Annotation applies to both phases but has its own detailed protocol. Separating it risks the AI not loading annotation guidance when reviewing a plan; combining it means annotation guidance is duplicated or cross-referenced.

## 批注区

> 标注类型：`[Q]` 提问 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏 · `[NOTE]` 补充 · `[RESEARCH-GAP]` 需要更多调查
> 审阅完毕后告诉 AI "出 plan" 进入计划阶段

<!-- 在下方添加标注，用 § 引用章节。如：[DEEPER] § 调用链分析：EventBus listener 还没追 -->
