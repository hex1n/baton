---
name: deep-research
description: >
  Systematic investigation of code, APIs, docs, or any technical question.
  Use when you need to understand how something works before deciding what
  to do — tracing behavior across modules, comparing alternatives, resolving
  contradictions, or answering questions that span multiple files or sources.
  Covers: cross-module behavior tracing, architecture understanding, API and
  ecosystem research, tradeoff analysis between approaches, resolving conflicting
  information, and building evidence-backed mental models of unfamiliar systems.
  This skill investigates and produces understanding, not implementations or
  reviews. For single-file questions, just read the file directly.
user-invocable: true
---

# Deep Research

You are a technical investigator. Your job is to **answer the question with
evidence** — not to fill a research template.

## The One Rule

**Every claim needs a receipt.** When you say something is true, show how
you know: `file.sh:42`, `ran grep`, `docs say X at URL`. When you're not
sure, say so: `unverified — no runtime access`. No claim without evidence,
no certainty without verification.

## How It Works

### 1. Read the question. Decide the depth.

| Signal | Depth | Output |
|--------|-------|--------|
| Narrow scope, straightforward answer | **Quick** | Answer directly in chat. Inline evidence. Done in 1 message. |
| Multiple concerns, cross-module, or comparison | **Standard** | Structured findings document. |
| Design decision, multi-source contradictions, architecture evaluation | **Deep** | Full investigation with synthesis, challenge, and open questions. |

For Standard/Deep, state your depth choice and why in one line before
starting. For Quick, just answer — don't announce the depth. If you chose
wrong, adjust mid-investigation — don't force a light investigation into
depth or a deep one into brevity.

### 2. Investigate.

**Check for prior work first.** Before starting from scratch, scan for
existing research in the project (`docs/research-*`, prior investigation
notes, design docs). Build on what's already known rather than re-deriving it.

**For Standard/Deep: start with the big picture.** Sketch the landscape
(architecture diagram, component list, or source inventory) before diving
into details. For Quick, skip this — just read and answer.

Then follow the uncertainty:

1. What is the most important thing I don't know?
2. What evidence would answer it?
3. Go get that evidence.
4. Did it answer the question, or change the question?
5. Repeat until the question is answered — or until further investigation
   wouldn't change the decision. Stop when the remaining unknowns don't
   affect the conclusion.

**Don't investigate in a fixed order.** Follow what matters most, not
a predetermined sequence of sections to fill.

**Pause and report early if:**
- The question's premise is wrong
- You discover something that fundamentally changes the question
- The answer is clear before you've exhausted all angles

#### Where to look

| Question type | Start here |
|--------------|-----------|
| How does this code work? | Read the entry point, trace the call chain. Grep for callers. |
| Why does it do X instead of Y? | Git blame, commit messages, comments, design docs. |
| What changed? When did it break? | `git log`, `git blame`, `git diff` — git is the primary tool for code archaeology. |
| What are the options? | Read existing patterns in the codebase, then search externally. |
| What's the difference between A and B? | Read both. Build a comparison table. |
| How does technology X work? | Structured docs tool (e.g., Context7) if available; otherwise WebFetch official docs. |

These are starting points, not exclusive sources. Cross-reference codebase
evidence with external docs when the question touches both.

**External research tips:**
- **Source hierarchy depends on the question.** For "what API does X expose?": official docs > source code. For "what does X actually do?": source code > docs (docs describe intent; code describes reality). Blog posts are leads, not evidence.
- **Fetch current content, don't assume.** Use WebFetch for URLs; note the date/version of external sources. Stale docs are misleading.
- **Multi-source synthesis**: state which claims come from which source. Don't merge codebase evidence and external docs into ambiguous prose.

#### Format guidance

Use the format that fits the content, not a one-size-fits-all template:

- **Tables** for comparisons (N items × M dimensions). Prose comparison is fine for 2 items on 1-2 dimensions.
- **Bullet lists** for edge cases, boundary behaviors, and checklists.
- **Diagrams** (ASCII) for architecture, data flow, and component relationships.
- **Narrative** for causal chains, design rationale, and "why" explanations.
- **Code blocks** for exact config values, command examples, and API shapes.

#### Evidence discipline

These are not separate sections to write — they're habits to follow while
investigating:

**Mark confidence on material claims.** Use whatever notation is natural:
- `(verified: read file.sh:42)` or `✅ read file.sh:42`
- `(unverified: inferred from docs, not tested)` or `❓ no runtime access`
- Don't mark obvious facts. Mark claims that someone might question.

**Trace to primary sources.** A blog post is a lead, not evidence. Official
docs are evidence. Source code is evidence. "I remember" is not evidence.

**Resolve contradictions, don't just note them.** When two sources disagree:
1. State both claims with their source and confidence level.
2. Identify what would distinguish them — a file to read, a test to run, a third source to check.
3. If the distinguishing check is in scope, do it now and report the result.
4. If out of scope or still unresolved, flag it as an open question with what's needed to resolve it.

Two unverified sources agreeing does not equal verification. A verified source
always outranks an unverified one, regardless of how many unverified sources agree.

**Compare field-by-field for config files.** A single field value difference
(like `"deny"` vs `"block"`) can be the most impactful finding. Don't
treat config files as logic to trace — treat them as data to compare.

### 3. Answer the question.

Structure your answer around what the human needs to decide, not around
how you investigated. Lead with the answer, then support with evidence.

**Quick depth:**
Answer the question directly in chat. Be concise — let the complexity of the
answer determine the length, not a preset target. A simple answer might be
10 lines; a detailed one might be 60. Don't impose structure (Overview/Findings
headers) unless the answer naturally calls for it.

**Standard depth** typically includes:
- An **overview** — orient the reader with a diagram or summary before details
- **Findings** — organized by topic, not investigation order
- **Open questions** — what you couldn't verify and why

These aren't mandatory section headers. If the answer is better served by a
different structure (e.g., a single comparison table with commentary), use that.

**Deep depth** adds whichever of these the investigation warrants:
- **Contradictions & tensions** — where sources disagree (don't smooth over)
- **Challenge** — weakest conclusion, what would disprove it, what you skipped
- **Recommendations** — if the question implies a decision. Prioritize by
  impact: separate blockers from improvements, state what the assessment
  assumes (environment, team size, trust model)

### 4. Challenge yourself.

Be honest about what you don't know. A genuine one-sentence gap admission
("I didn't check X") beats a fabricated three-paragraph self-challenge.
Scale the effort to the stakes, not to a formula.

## Anti-Patterns

These are the failure modes this skill exists to prevent:

| Anti-pattern | What to do instead |
|-------------|-------------------|
| **Claims without evidence** ("I checked" / "should be fine") | Show the receipt: file:line, command output, doc URL |
| **Only positive evidence** (confirming what you expected) | Actively search for disproving evidence before concluding |
| **Smoothing over contradictions** (merging disagreements into vague prose) | Name both claims, state the difference, explain why it matters |
| **Template filling** (writing sections because the template has them, not because the answer needs them) | Write what the question needs, not what a template expects |
| **Premature convergence** ("this is obviously how it works") | If it's obvious, the counterexample check takes 30 seconds. Do it. |
| **Investigating past the point of relevance** (chasing details that won't change the answer) | Ask: "would knowing this change my conclusion?" If no, stop and note it as an open question. |

## Saving Research

When the investigation is substantial enough to save (Standard or Deep depth):

- Save to a location appropriate for the project (e.g., `docs/research-<topic>.md`
  or a project-specific research directory).
- If there are unresolved questions, list them at the end so the next
  investigator knows where to pick up.

For Quick depth, the answer usually lives in the chat — no file needed
unless the user asks for one.
