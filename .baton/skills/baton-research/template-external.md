# Template: External Research

Use this template when evidence type = **external-primary**.

Cognitive progression: What am I looking for? → Where is trustworthy information? → Which sources deserve depth? → What does each source say? → Does it apply to us? → What does it mean?

---

```markdown
# Research: [topic]

## Frame

- **Question**: What exactly is being investigated? (Frame as behavior or outcome — not mechanism or assumed solution)
- **Why**: What later decision does this support?
- **Scope**: What's in scope?
- **Out of scope**: What is explicitly excluded?
- **Target context**: Our specific constraints (version, platform, use case) — used for applicability assessment throughout
- **Known constraints**: Known constraints (repo, platform, tooling)
- **System goal being served**: What outcome this research enables
- **Claimed framing from human/docs**: The framing as stated
- **What must be validated before accepting that framing**: Assumptions to verify

## Orient

- **Domain familiarity**: none / partial / deep
  - If none/partial → complete Source Landscape before reading any sources
  - If deep → state existing understanding + known authoritative sources, proceed to targeted investigation
- **Evidence type**: external-primary
- **Strategy**: Given my familiarity, how will I organize this investigation?

## Source Landscape

> Required. Complete this BEFORE reading any sources.
> Goal: the reader knows what authoritative sources exist, which ones were selected, and why.

**1. What are the authoritative sources for this domain?**

| Source | Type | URL/Location | Currency | Why authoritative |
|--------|------|-------------|----------|-------------------|
| ... | official docs / source code / spec / peer-reviewed / community | ... | date/version | ... |

Type hierarchy (strongest → weakest):
1. Official documentation + version match confirmed
2. Official source code / reference implementation
3. Peer-reviewed / widely-cited technical analysis
4. Well-maintained community resources (with recency check)
5. Blog posts, tutorials, AI-generated summaries — leads for finding primary sources, not evidence

**2. Coverage assessment**
- Is our question adequately covered by authoritative sources?
- Which aspects lack authoritative sources and require secondary sources?
- What known information gaps exist?

**3. Source selection**
Which sources will I read in depth? Why these?
(Selection criteria: relevance to question, authority, currency. Depth > breadth)

**Pass criteria**: The reader can judge: "If this research missed important information, what source was most likely not covered?"

## Investigation Methods

What evidence acquisition methods were used? What did each return? Why sufficient?
(Require ≥2 independent methods, independence level ≥ moderate)

| Method | What it returned | Independence level |
|--------|-----------------|-------------------|
| ... | ... | strong / moderate / weak |

## Source Evaluations

> Every source actually used must be evaluated here.

### [Source N]: [name]
- **Type**: primary (official docs, source code, spec) / secondary (blog, tutorial, summary)
- **Currency**: Publication/update date. Does it match our target version?
- **Key claims**: What are this source's core assertions?
- **Verification**: Can these claims be verified with stronger evidence? (verified → ✅, not verified → ❓)
- **Applicability**: Does it apply to our Target context? What limitations?
- **Trust level**: high / medium / low + rationale

Quality gates per source:
- **Currency**: date/version match?
- **Authority**: primary or secondary?
- **Verification**: checkable against source code or runtime?
- **Applicability**: matches our version, platform, use case?

## Investigation

Organize by topic/dimension (NOT by source). For each topic:

### [Topic N]: [name]
- **Question**: What does this topic need to answer?
- **Findings**: Synthesized findings from multiple sources (cite source for each finding)
- **Primary source support**: At least one primary source supports this? ✅ / ❓
- **Cross-source consistency**: Do sources agree? If not → record conflicts explicitly
- **Applicability to our context**: Do these findings hold in our Target context?

Hard rule: Each finding that depends on external evidence must cite ≥1 primary source.
Findings supported only by secondary sources are marked ❓ with explicit note.

## Cross-Source Synthesis

> Required when multiple sources were used.

- Where do sources agree?
- Where do sources contradict? (specify which source says what)
- How are contradictions resolved? (stronger evidence wins, or unresolved?)

## Counterexample Sweep

> Active search required. "Found no contradictions" only passes if you name: the specific source or document section checked, what opposing viewpoint or failure case you searched for, and that you specifically went looking.
> ❌ Passive: "no evidence found contradicting this conclusion"
> ✅ Active: name which sources you searched for disagreement, what failure mode you looked for, and what a contradiction would look like

- **Leading interpretation**: What is the current most likely conclusion?
- **Disproving evidence sought**: What specific evidence would disprove it?
- **What was checked**: Which sources, docs, or search terms? What failure case or opposing view would falsify it?
- **Result**: disproving evidence found / not found (confirmed active search) / insufficient search
- **Effect on confidence**: How does this change confidence in the conclusion?

## Self-Challenge

> Shallow answers ("no other alternatives" / "all assumptions verified") signal self-challenge was not genuine — fix before presenting.

**Q1: Weakest conclusion** (required format — fill in all four fields):
- **Conclusion**: [exact claim as stated in conclusions]
- **Why weakest**: [specific gap in evidence making you least confident]
- **Falsification condition**: If [specific, observable thing] were true or present, this conclusion would be wrong
- **Checked for it**: [what you specifically searched, and what you found]

**Q2: What did I NOT investigate that I should have?**
[Specific omissions — not "nothing"]

**Q3: What assumptions did I make without verifying?**
[Specific unverified assumptions — not "all verified"]

## Review

Dispatch baton-review via Agent tool (context isolation) using `./review-prompt-external.md`.
Fallback: self-review using that checklist.

1. Record findings below.
2. Per finding: accept with fix / reject with evidence / keep as ❓
3. Re-review if materially rewritten.
4. Circuit breaker: 3 cycles without passing → escalate to human.

**Review findings:**
(record here, process per Annotation Protocol)

## One-Sentence Summary

> If you can't say it in one sentence, your understanding isn't clear enough.

"In the context of [question], investigating [scope], I found [key finding],
with [confidence level] confidence, accepting [key uncertainty]."

## Final Conclusions

Mark superseded conclusions: `→ Revised in [section]`

Each conclusion must include:
- **Confidence**: high / medium / low + one-sentence rationale
- **Primary source**: At least one primary source citation (if none → mark ❓ + explain why)
- **Applicability**: Assessment under our Target context
- **Verification path**: How to verify this conclusion (what experiment, API call, or comparison would confirm or disprove it)
- **Uncertainty**: what remains unverified
- **Plan implication**: actionable / watchlist / judgment-needed / blocked

## Questions for Human Judgment

**Blocks plan** — must be answered before entering plan phase:

**Can wait for implementation** — plan can proceed, decide during implementation:

**Out of scope but related** — recorded but does not block:

**Open unknowns** — classified by blocking severity:
- [unknown]: blocks plan / does not block plan

**Chat requirements captured** — informal requirements from conversation not yet formally documented:
- `Human requirement (chat): ...`

> Append content of `.baton/annotation-template.md`
```

---

## For mixed research (external-primary with codebase component)

If the investigation also requires codebase analysis, add after Source Landscape:

```markdown
## Codebase Context

Brief system baseline for the codebase component of this investigation.
Every answer must cite evidence ✅ (read file:line).

1. **Relevant modules**: Which parts of the codebase does this investigation touch?
2. **Current implementation**: How does the codebase currently handle the topic being researched?
3. **Integration points**: Where would external findings need to connect with existing code?
```
