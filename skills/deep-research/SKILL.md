---
name: deep-research
description: >
  Systematic investigation of code, APIs, docs, or any technical question.
  Use when you need to understand how something works before deciding what
  to do. Trigger this skill whenever the user asks to "调研", "research",
  "investigate", "figure out why", "trace", "compare", or "evaluate" something
  across multiple files or sources. Specifically covers: cross-module behavior
  tracing, architecture understanding, API and ecosystem research, tradeoff
  analysis between approaches (e.g., "should we use X or Y"), resolving
  conflicting information, git archaeology ("why was this changed", "when did
  this break"), technology upgrade evaluation ("is it worth upgrading to vN"),
  codebase audits ("where do we use X", "why are there two approaches"),
  confirming or disproving suspected bugs across multiple files, and building
  evidence-backed mental models of unfamiliar systems. This skill investigates
  and produces understanding, not implementations or reviews. For single-file
  questions, just read the file directly. When in doubt about whether this
  skill applies, use it — the calibration step will determine the right depth.
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

### 1. Calibrate the question. Decide the depth.

**Before investigating, check whether the question has a clear decision
boundary.** "How does the auth middleware work?" is clear. "Research the
auth system" is not — research *what about it*, for *what decision*?

If the decision boundary is unclear, define it — not by listing topics to
cover (that's scope expansion), but by naming the decision: "This
investigation will determine [what] so that [who] can decide [what action]."
If you can't name a decision-maker or action, the question is too broad —
narrow it before proceeding, don't expand into "cover everything."
If a prior conversation or task context already makes this obvious, skip it.

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

**Convergence checkpoint (Standard/Deep):** After 3 rounds of the loop
above, pause and assess: are you converging (each round narrows uncertainty)
or diverging (each round opens new questions)? If diverging — or if you've
spent 2+ rounds without materially changing your conclusion — surface what
you have so far and ask the human whether to continue, narrow scope, or
stop. The goal is to prevent runaway investigation, not to impose a hard
cap: if you're clearly converging, keep going. But if you catch yourself
thinking "just one more thing," that's the signal to checkpoint. For Deep
depth, the threshold extends to 5 rounds before mandatory checkpoint.

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
| How does technology X work? | Official docs first (use structured doc tools if available, otherwise fetch docs by URL). |
| Which library/tool should we use? | Define evaluation criteria → search for candidates → read official docs for each → check adoption signals (package registry downloads, GitHub activity, release cadence). |
| What's the state of technology X? | Package registry, GitHub repo (issues, releases, contributors), official roadmap, community forums. Adoption ≠ quality — check both. |

These are starting points, not exclusive sources. Cross-reference codebase
evidence with external docs when the question touches both.

**External research tips:**
- **Source hierarchy depends on the question.** For "what API does X expose?": official docs > source code. For "what does X actually do?": source code > docs (docs describe intent; code describes reality). Blog posts are leads, not evidence.
- **Discovery vs. targeted fetch.** Use broad search when you don't know *where* the answer lives ("what libraries support X?", "how do others solve Y?"). Use direct URL fetch when you have a specific page to read. Use structured documentation tools (library doc fetchers, API reference tools) when available — they return versioned, indexed content that's more reliable than raw web fetches.
- **Version mismatch is a silent killer.** Before citing external docs, check which version the project actually uses (package.json, go.mod, requirements.txt, etc.). If the docs version doesn't match the project version, note the discrepancy — don't silently apply v3 docs to a v2 codebase.
- **Cross-validate external claims.** A single external source is a lead. Two independent sources agreeing is stronger but still not verified. When possible, confirm external claims against the actual codebase or a runnable test.
- **Multi-source synthesis**: state which claims come from which source. Don't merge codebase evidence and external docs into ambiguous prose.
- **For technology evaluations**: don't just compare feature lists. Check: (1) Does the project's actual use case match the tool's sweet spot? (2) What's the maintenance trajectory — growing, stable, or declining? (3) What do migration/adoption stories from similar projects say? Feature parity on paper often hides major differences in practice.

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
- `✅ verified` or `(verified: ...)` — **only** for claims you confirmed
  during this investigation by reading a file, fetching a URL, or running a
  command. "Verified" means "I saw the source text with my own eyes in this
  session." If you didn't fetch it now, you can't mark it verified — period.
- `❓ unverified` — for claims you believe are true but didn't confirm in
  this session. This includes anything from training data, memory, or
  inference. Common examples: version numbers you didn't check, company
  news you didn't fetch, performance figures you didn't benchmark.
- Don't mark obvious facts. Mark claims that someone might question.
- In evidence markers, reference the **source** (official docs, file path,
  URL), not the **tool** you used to reach it. Write
  `(verified: Bun official docs)` not `(verified: via some-internal-tool)`.
  The reader cares where the fact came from, not which tool fetched it.

**Trace to primary sources.** A blog post is a lead, not evidence. Official
docs are evidence. Source code is evidence. "I remember" is not evidence.

**External factual claims require fetched sources.** Claims about the
external world — company acquisitions, funding rounds, version numbers,
release dates, organizational changes — are especially hallucination-prone.
Before writing any such claim as verified, ask: "Did I actually fetch a
page that states this, or do I just believe it?" If you didn't fetch it,
either (a) fetch a primary source now, or (b) mark it
`❓ recalled, not verified — could not confirm from a fetched source`.
Never mark an external factual claim as verified based on training data
alone, no matter how confident you feel — confidence is not evidence.

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

### 4. Source audit (Standard/Deep with external claims).

If your investigation includes claims about the external world (company
news, version numbers, performance benchmarks, release dates, funding,
acquisitions), add a source audit before finalizing. This is a structural
defense — it makes every external claim auditable in one place.

Append a table at the end of your findings:

```
## Source Audit
| Claim | Source | How obtained |
|-------|--------|-------------|
| Bun starts in ~18ms | bun.sh/docs/cli/run | Fetched in this session |
| DuckDB 1.0 released 2024 | Recalled from training data | ❓ Not fetched |
```

Rules:
- **"Fetched in this session"** = you read a URL, file, or command output
  that explicitly states this claim. You can point to the source.
- **"Recalled from training data"** = you believe this is true but didn't
  fetch a source. Mark with ❓.
- If a claim is important to your conclusion and you only have "recalled,"
  try to fetch a source now. If you can't, keep it as ❓ and note it.

This table is not busywork — it's a reviewer's shortcut. One glance tells
them which claims to trust and which to spot-check. Skip this step only
if your investigation has zero external factual claims (pure codebase work).

### 5. Challenge yourself.

For **Standard/Deep**: before finalizing, name your weakest conclusion or
the most important thing you didn't check. One honest sentence is enough —
"I didn't verify whether X holds at runtime" or "This assumes Y, which I
couldn't confirm." If you can't find a gap, that's a red flag — look harder.

For **Quick**: skip this unless the answer depends on an assumption you
didn't verify, in which case flag it inline.

## Example: Cross-Module Behavior Trace

> **Question**: "Why does the webhook retry logic sometimes send duplicate
> events to downstream consumers?"

**Calibration**: The question implies a production behavior — the decision
boundary is whether to change the retry mechanism. → **Standard** depth
(cross-module, but not a design decision yet).

**Investigation** (abbreviated):

1. *Most important unknown*: where does the retry logic live?
   - `grep -r "retry" src/webhooks/` → found `retry-queue.ts:34` and `delivery.ts:78`
   - ✅ `retry-queue.ts:34`: exponential backoff with `maxRetries: 3`
   - ✅ `delivery.ts:78`: separate retry via `setTimeout` — **this is a second retry path**

2. *Changed question*: are both retry paths active simultaneously?
   - ✅ `git blame delivery.ts:78` → added 2024-11 by PR #412 "hotfix: retry on timeout"
   - ✅ `git blame retry-queue.ts:34` → original implementation from 2023-06
   - **Contradiction**: PR #412's description says "replaces the queue-based retry" but the queue code was never removed ❓ (no delete in the diff)

3. *Resolution*: read the PR #412 diff → confirmed: only added `setTimeout` retry, did not touch `retry-queue.ts`. Both paths fire on timeout errors.

**Answer**: Duplicate events occur because two independent retry mechanisms
both trigger on timeout: the original queue (`retry-queue.ts:34`) and a
hotfix bypass (`delivery.ts:78`). The hotfix was intended to replace the
queue but never removed it. Fix: remove the `setTimeout` retry in
`delivery.ts` or deregister timeout errors from the queue.

**Open question**: ❓ Are there downstream consumers that depend on the
faster `setTimeout` retry timing? Need to check consumer SLAs before
removing it.

## Example: Technology Evaluation

> **Question**: "Should we use SQLite or DuckDB for our analytics
> dashboard's local data layer?"

**Calibration**: Decision boundary is clear — pick one for the local data
layer. Two candidates, multiple evaluation dimensions. → **Standard** depth.

**Investigation** (abbreviated):

1. *Most important unknown*: what query patterns does the dashboard use?
   - ✅ Read `src/queries/` — mostly analytical aggregations (GROUP BY,
     window functions), some point lookups for config
   - This favors columnar (DuckDB) but need to check write patterns too

2. *Second unknown*: what's the write pattern?
   - ✅ Read `src/ingest/` — batch inserts every 5 min, no concurrent writes
   - Batch-friendly — both handle this fine

3. *External research*: how do they compare on analytical queries?
   - ✅ Fetched DuckDB official benchmarks page — 10-100x faster than SQLite
     on analytical queries (❓ vendor benchmark — may be cherry-picked)
   - ✅ Fetched SQLite docs on columnar extensions — no native columnar mode
   - ❓ Recalled that DuckDB can read Parquet natively — did not verify in
     this session

4. *Adoption check*:
   - ✅ Fetched npm registry — `duckdb` ~50k weekly downloads, `better-sqlite3`
     ~800k. SQLite ecosystem is far more mature.
   - ✅ Fetched DuckDB GitHub — active development, but v1.0 released only
     recently. API stability less proven than SQLite.

**Answer**: DuckDB for the primary query path (analytical aggregations
are the dominant pattern, and the 10-100x advantage is decisive). Keep
SQLite for config storage (point lookups, well-understood, tiny footprint).

**Weakest conclusion**: The DuckDB benchmark advantage comes from vendor
benchmarks — independent confirmation on our actual query shapes would
strengthen the recommendation.

---

## Anti-Patterns

These are the failure modes this skill exists to prevent:

| Anti-pattern | What to do instead |
|-------------|-------------------|
| **Claims without evidence** ("I checked" / "should be fine") | Show the receipt: file:line, command output, doc URL |
| **False verification** (marking recalled claims as `verified`) | `verified` means you fetched/read the source in this session. If you didn't fetch it, it's `❓ unverified` — no matter how confident you are. This is worse than no marker because it actively misleads the reader. |
| **Only positive evidence** (confirming what you expected) | Actively search for disproving evidence before concluding |
| **Smoothing over contradictions** (merging disagreements into vague prose) | Name both claims, state the difference, explain why it matters |
| **Template filling** (writing sections because the template has them, not because the answer needs them) | Write what the question needs, not what a template expects |
| **Premature convergence** ("this is obviously how it works") | If it's obvious, the counterexample check takes 30 seconds. Do it. |
| **Investigating past the point of relevance** (chasing details that won't change the answer) | Ask: "would knowing this change my conclusion?" If no, stop and note it as an open question. |

## Saving Research

When the investigation is substantial enough to save (Standard or Deep depth):

- Save to a location appropriate for the project (e.g., `docs/research-<topic>.md`
  or a project-specific research directory).
- Start the document with a brief header so the next investigator can assess
  relevance without reading the full document:
  ```
  **Question**: [the specific question this investigation answers]
  **Depth**: Standard | Deep
  **Key finding**: [one-sentence answer]
  **Open questions**: [count] — see end of document
  ```
- If there are unresolved questions, list them at the end so the next
  investigator knows where to pick up.

For Quick depth, the answer usually lives in the chat — no file needed
unless the user asks for one.
