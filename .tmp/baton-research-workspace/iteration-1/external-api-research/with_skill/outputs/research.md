# Research: Hook Events Across Claude Code, Cursor, and Codex

## Frame

- **Question**: What hook lifecycle events are available across Claude Code, Cursor, and Codex CLI, and how do their capabilities compare for governance enforcement?
- **Why**: Baton needs to decide which hook events to rely on for its core governance system (write-lock, bash-guard, phase-guide, etc.). The choice determines portability across AI coding tools and which governance guarantees can be enforced at the hook level vs. requiring alternative mechanisms.
- **Scope**: Hook event names, handler types, matcher capabilities, blocking behavior, and configuration schemas across Claude Code, Cursor, and Codex CLI.
- **Out of scope**: MCP protocol comparison, IDE editor features unrelated to hooks, pricing, performance benchmarks.
- **Target context**: Baton governance system running on Windows (Git Bash), currently implemented for Claude Code with events defined in `.baton/hooks/manifest.conf`.
- **Known constraints**: Baton currently uses Claude Code hooks exclusively. Manifest uses: SessionStart, PreToolUse, PostToolUse, PostToolUseFailure, SubagentStart, Stop, TaskCompleted, PreCompact.
- **System goal being served**: Determine whether baton's governance hooks can be portable across tools, and which events form a reliable cross-tool foundation.
- **Claimed framing from human/docs**: The human frames this as a comparison to decide which events baton "should rely on" -- implying a selection/prioritization decision.
- **What must be validated before accepting that framing**: (1) That these three tools actually have comparable hook systems. (2) That event semantics are similar enough across tools to meaningfully compare. (3) That portability is achievable vs. requiring per-tool adapters.

## Orient

- **Domain familiarity**: partial -- deep familiarity with Claude Code hooks (baton uses them), no direct experience with Cursor or Codex hook systems.
- **Evidence type**: external-primary (official documentation + changelogs)
- **Strategy**: Fetch official documentation for all three tools. Build a complete event inventory per tool. Compare semantics, matchers, handler types, and blocking capabilities. Assess which baton governance hooks have equivalents across tools.

## Source Landscape

**1. Authoritative sources for this domain:**

| Source | Type | URL/Location | Currency | Why authoritative |
|--------|------|-------------|----------|-------------------|
| Claude Code Hooks Reference | official docs | https://code.claude.com/docs/en/hooks | March 2026 | Anthropic's official reference |
| Cursor Hooks Docs | official docs | https://cursor.com/docs/hooks | 2025-2026 | Cursor's official reference |
| Codex CLI Changelog | official docs | https://developers.openai.com/codex/changelog | March 2026 | OpenAI's official changelog |
| Codex GitHub Discussion #2150 | community + maintainer | https://github.com/openai/codex/discussions/2150 | March 2026 | Direct maintainer statements |
| Codex GitHub Issue #2109 | community + maintainer | https://github.com/openai/codex/issues/2109 | 2025-2026 | Feature request with 515+ upvotes |
| GitButler Cursor Hooks Deep Dive | secondary (blog) | https://blog.gitbutler.com/cursor-hooks-deep-dive | 2025 | Detailed practical analysis |
| Baton manifest.conf | source code | .baton/hooks/manifest.conf | current | Shows which events baton actually uses |

**2. Coverage assessment**
- Claude Code: excellent -- official docs list all 22+ events with full schema.
- Cursor: good -- official docs list 18-20 events with schema.
- Codex: limited -- only changelog entries and GitHub discussions. No dedicated hooks documentation page exists on the official developer site. The feature is experimental.

**3. Source selection**
- Primary depth: Claude Code official docs, Cursor official docs, Codex changelog.
- Supporting: GitButler blog (practical Cursor limitations), Codex GitHub issues (roadmap signals).

## Investigation Methods

| Method | What it returned | Independence level |
|--------|-----------------|-------------------|
| Official documentation (WebFetch on docs pages) | Complete event lists for Claude Code and Cursor; partial for Codex | strong (primary sources) |
| Changelog review (Codex) | Timeline of hook additions: v0.114.0 SessionStart+Stop, v0.115.0 UserPromptSubmit | moderate (primary source, different angle) |
| Community/maintainer statements (GitHub) | Codex hooks are experimental, community requesting Claude Code schema compatibility | moderate (maintainer statements corroborate changelog) |

## Source Evaluations

### Source 1: Claude Code Hooks Reference
- **Type**: primary (official docs)
- **Currency**: March 2026, matches current release
- **Key claims**: 22+ lifecycle events, 4 handler types (command, http, prompt, agent), regex matchers, blocking via exit code 2
- **Verification**: ✅ fetched page directly, cross-referenced with baton's working manifest.conf
- **Applicability**: Direct -- baton already runs on this platform
- **Trust level**: high -- official, version-current, verified against working implementation

### Source 2: Cursor Hooks Docs
- **Type**: primary (official docs)
- **Currency**: 2025-2026, current version
- **Key claims**: 18-20 lifecycle events, 2 handler types (command, prompt), matchers by tool/command, blocking via exit code 2 or permission JSON
- **Verification**: ✅ fetched page directly; ❓ not tested in practice
- **Applicability**: Potential target platform for baton portability
- **Trust level**: high -- official documentation

### Source 3: Codex CLI Changelog
- **Type**: primary (official docs)
- **Currency**: March 19, 2026 (v0.116.0)
- **Key claims**: Only 3 hook events exist (SessionStart, Stop, UserPromptSubmit), experimental, command-type only
- **Verification**: ✅ fetched changelog directly
- **Applicability**: Severely limited -- most baton governance hooks have no Codex equivalent
- **Trust level**: high for what exists -- but feature is explicitly experimental

### Source 4: GitButler Blog (Cursor Deep Dive)
- **Type**: secondary (technical blog)
- **Currency**: 2025
- **Key claims**: Only beforeShellExecution and beforeMCPExecution support blocking JSON responses; beforeSubmitPrompt and afterFileEdit are "informational only"
- **Verification**: ❓ not independently verified against Cursor docs (Cursor official docs list more events than this blog covers, suggesting the blog may describe an earlier version)
- **Applicability**: Useful practical caveat about Cursor blocking limitations
- **Trust level**: medium -- well-researched but may be outdated

## Codebase Context

Brief system baseline for the codebase component of this investigation.

1. **Relevant modules**: `.baton/hooks/manifest.conf`, `.baton/hooks/dispatch.sh`, `.baton/hooks/phase-guide.sh`
2. **Current implementation**: Baton uses Claude Code hooks exclusively. Manifest maps 8 distinct events to 10 hook scripts. ✅ read manifest.conf
3. **Integration points**: Any cross-tool support would need to map manifest.conf events to equivalent events on other platforms, or implement an adapter layer.

**Current baton hook usage** (from manifest.conf):

| Event | Matcher | Hook Script | Governance Function |
|-------|---------|-------------|-------------------|
| SessionStart | (all) | phase-guide | Dynamic phase extraction, auto-junction |
| PreToolUse | Write,Edit,MultiEdit,CreateFile,NotebookEdit | write-lock | Block unauthorized file modifications |
| PreToolUse | Bash | bash-guard | Guard against dangerous shell commands |
| PostToolUse | Write,Edit,MultiEdit,CreateFile,NotebookEdit | post-write-tracker | Track file modifications |
| PostToolUse | Write,Edit,MultiEdit,CreateFile,NotebookEdit | quality-gate | Enforce quality on written files |
| SubagentStart | (all) | subagent-context | Inject context into subagents |
| Stop | (all) | stop-guard | Validate state at turn end |
| TaskCompleted | (all) | completion-check | Verify completion criteria |
| PostToolUseFailure | (all) | failure-tracker | Track tool failures |
| PreCompact | (all) | pre-compact | Preserve critical context before compaction |

## Investigation

### Topic 1: Event Inventory Comparison

- **Question**: Which hook events exist across all three tools, and which are tool-specific?

**Complete Event Comparison Table:**

| Event Category | Claude Code | Cursor | Codex CLI |
|---------------|-------------|--------|-----------|
| **Session lifecycle** | | | |
| Session start | SessionStart | sessionStart | SessionStart |
| Session end | SessionEnd | sessionEnd | -- |
| **User input** | | | |
| Prompt submitted | UserPromptSubmit | beforeSubmitPrompt | UserPromptSubmit |
| **Tool lifecycle** | | | |
| Before tool use | PreToolUse | preToolUse | -- |
| After tool use (success) | PostToolUse | postToolUse | -- |
| After tool use (failure) | PostToolUseFailure | postToolUseFailure | -- |
| Permission request | PermissionRequest | -- | -- |
| **Specific tool events** | | | |
| Before shell execution | (via PreToolUse matcher=Bash) | beforeShellExecution | -- |
| After shell execution | (via PostToolUse matcher=Bash) | afterShellExecution | -- |
| Before MCP execution | (via PreToolUse matcher=mcp__*) | beforeMCPExecution | -- |
| After MCP execution | (via PostToolUse matcher=mcp__*) | afterMCPExecution | -- |
| Before file read | (via PreToolUse matcher=Read) | beforeReadFile | -- |
| After file edit | (via PostToolUse matcher=Edit/Write) | afterFileEdit | -- |
| **Subagent lifecycle** | | | |
| Subagent start | SubagentStart | subagentStart | -- |
| Subagent stop | SubagentStop | subagentStop | -- |
| **Turn/stop** | | | |
| Agent stop | Stop | stop | Stop |
| Stop on failure | StopFailure | -- | -- |
| After agent response | -- | afterAgentResponse | -- |
| After agent thought | -- | afterAgentThought | -- |
| **Task** | | | |
| Task completed | TaskCompleted | -- | -- |
| Teammate idle | TeammateIdle | -- | -- |
| **Context management** | | | |
| Pre-compaction | PreCompact | preCompact | -- |
| Post-compaction | PostCompact | -- | -- |
| Instructions loaded | InstructionsLoaded | -- | -- |
| Config change | ConfigChange | -- | -- |
| **Worktree** | | | |
| Worktree create | WorktreeCreate | -- | -- |
| Worktree remove | WorktreeRemove | -- | -- |
| **Elicitation (MCP)** | | | |
| Elicitation | Elicitation | -- | -- |
| Elicitation result | ElicitationResult | -- | -- |
| **Tab completions** | | | |
| Before tab file read | -- | beforeTabFileRead | -- |
| After tab file edit | -- | afterTabFileEdit | -- |
| **Notification** | | | |
| Notification | Notification | -- | -- |

- **Primary source support**: ✅ Claude Code official docs, ✅ Cursor official docs, ✅ Codex changelog
- **Cross-source consistency**: Sources agree on their own event lists. No contradictions found within each tool's documentation.
- **Applicability to our context**: Direct -- this is the core data needed for the decision.

### Topic 2: Handler Types and Blocking Capabilities

- **Question**: Can hooks block agent actions across all three tools?

| Capability | Claude Code | Cursor | Codex CLI |
|-----------|-------------|--------|-----------|
| **Handler types** | command, http, prompt, agent | command, prompt | command |
| **Blocking mechanism** | Exit code 2 = block; JSON decision field | Exit code 2 = block; permission JSON | ❓ unclear -- experimental |
| **Fail-open vs fail-closed** | Fail-open (non-2 exit = non-blocking error) | Configurable via `failClosed` option | ❓ not documented |
| **Matcher support** | Regex on tool names, event subtypes | String/pattern on tool names, commands | ❓ not documented |
| **Async hooks** | Yes (`async: true`) | No | No |
| **Agent hooks (subagent verification)** | Yes | No | No |
| **HTTP hooks** | Yes | No | No |
| **Prompt (LLM) hooks** | Yes (with model selection) | Yes (with model selection) | No |
| **Feedback to agent** | Yes (systemMessage, reason) | Yes (reason in JSON) | ❓ not documented |
| **Timeout configuration** | Yes (per handler type defaults) | Yes | Yes |

- **Primary source support**: ✅ Claude Code docs, ✅ Cursor docs, ✅ Codex changelog (limited)
- **Key finding**: Claude Code has the richest handler type system (4 types). Cursor is close (2 types) with a useful `failClosed` option Claude Code lacks. Codex only supports command hooks.

### Topic 3: Baton Governance Hook Portability

- **Question**: Which of baton's 8 governance events have equivalents on other platforms?

| Baton Hook | Claude Code | Cursor Equivalent | Codex Equivalent | Portability |
|-----------|-------------|-------------------|------------------|-------------|
| SessionStart (phase-guide) | SessionStart | sessionStart | SessionStart | **High** -- all three |
| PreToolUse:Write,Edit... (write-lock) | PreToolUse | preToolUse or afterFileEdit | -- | **Medium** -- Claude+Cursor only |
| PreToolUse:Bash (bash-guard) | PreToolUse | beforeShellExecution | -- | **Medium** -- Claude+Cursor only |
| PostToolUse:Write,Edit... (post-write-tracker) | PostToolUse | postToolUse or afterFileEdit | -- | **Medium** -- Claude+Cursor only |
| PostToolUse:Write,Edit... (quality-gate) | PostToolUse | postToolUse or afterFileEdit | -- | **Medium** -- Claude+Cursor only |
| SubagentStart (subagent-context) | SubagentStart | subagentStart | -- | **Medium** -- Claude+Cursor only |
| Stop (stop-guard) | Stop | stop | Stop | **High** -- all three |
| TaskCompleted (completion-check) | TaskCompleted | -- | -- | **Low** -- Claude Code only |
| PostToolUseFailure (failure-tracker) | PostToolUseFailure | postToolUseFailure | -- | **Medium** -- Claude+Cursor only |
| PreCompact (pre-compact) | PreCompact | preCompact | -- | **Medium** -- Claude+Cursor only |

- **Primary source support**: ✅ derived from cross-referencing all three official sources
- **Key finding**: Only 2 of baton's 10 hook registrations (SessionStart, Stop) are portable across all three tools. 8 of 10 are portable to Cursor. TaskCompleted is Claude Code exclusive.

### Topic 4: Semantic Differences in "Equivalent" Events

- **Question**: Do events with similar names actually behave the same way across tools?

**Critical differences identified:**

1. **PreToolUse vs. Cursor's split events**: Claude Code uses one PreToolUse event with matchers to distinguish tool types (Bash, Write, Edit, mcp__*). Cursor splits into separate events: beforeShellExecution, beforeMCPExecution, beforeReadFile, preToolUse. ❓ Whether Cursor's `preToolUse` fires for ALL tools or only specific ones needs verification.

2. **Blocking behavior asymmetry in Cursor**: Per the GitButler analysis, `beforeSubmitPrompt` and `afterFileEdit` in Cursor are "informational only" -- they cannot block or communicate back to the agent. ❓ This may have changed since the blog was written. If still true, baton's `quality-gate` (which needs PostToolUse blocking feedback) would not work via `afterFileEdit`.

3. **SessionStart matchers**: Claude Code's SessionStart distinguishes `startup`, `resume`, `clear`, `compact`. Cursor's `sessionStart` has no documented sub-matchers. Codex's SessionStart appears to have no matchers. This matters for phase-guide, which may need to behave differently on resume vs. fresh start.

4. **Stop vs. afterAgentResponse**: Cursor has both `stop` (agent loop ends) and `afterAgentResponse` (after each assistant message). Claude Code's `Stop` fires when the agent finishes responding. The semantic alignment is close but not identical.

- **Primary source support**: ✅ Claude Code docs (matchers documented), ✅ Cursor docs (separate events documented), ❓ GitButler blog (blocking limitation claim -- may be outdated)

## Cross-Source Synthesis

- **Where sources agree**: All three tools support at minimum SessionStart and Stop events. All three use hooks.json as configuration. All three use command-type hooks with stdin JSON / exit code pattern.
- **Where sources contradict**: The GitButler blog (2025) describes Cursor as having only 6 events, while Cursor's official docs list 18-20. Resolution: official docs are more current; the blog likely described an earlier beta version. ✅ Official docs win.
- **Unresolved**: Whether Cursor's `afterFileEdit` can actually block (GitButler says no, but Cursor may have updated this). ❓

## Counterexample Sweep

- **Leading interpretation**: Baton should anchor its core governance on the Claude Code + Cursor shared event set (PreToolUse, PostToolUse, SessionStart, Stop, SubagentStart, PreCompact), and treat Codex as unsupported until its hooks mature.
- **Disproving evidence sought**: (1) Is there a tool other than these three that baton should consider? (2) Is Codex's hook system more mature than the changelog suggests? (3) Are there Claude Code events baton uses that are actually unstable/deprecated?
- **What was checked**:
  - Searched Codex changelog through v0.116.0 (March 19, 2026) for any PreToolUse/PostToolUse equivalent. Found: none. Only SessionStart, Stop, UserPromptSubmit exist. ✅
  - Checked Claude Code docs for any deprecation warnings on events baton uses. Found: none -- all events appear stable. ✅
  - Searched for other AI coding tools with hook systems (Windsurf, Aider, Continue). Did not find mature hook systems comparable to Claude Code/Cursor in initial search. ❓ Not exhaustively verified -- other tools may have hook systems not captured here.
- **Effect on confidence**: High confidence that Claude Code + Cursor is the right anchor. Medium confidence that no other tool should be considered (incomplete search).

## Self-Challenge

**Q1: Weakest conclusion** (required format):
- **Conclusion**: "Cursor's preToolUse, postToolUse, and postToolUseFailure are semantically equivalent to Claude Code's PreToolUse, PostToolUse, PostToolUseFailure and can serve the same governance functions."
- **Why weakest**: Cursor splits tool events into separate granular events (beforeShellExecution, beforeMCPExecution, afterFileEdit) in addition to generic preToolUse/postToolUse. I did not verify whether Cursor's generic preToolUse fires for ALL tool types or only a subset. If it only fires for some tools, baton would need to register multiple Cursor-specific events instead of one PreToolUse with matchers.
- **Falsification condition**: If Cursor's `preToolUse` does NOT fire for shell commands (because `beforeShellExecution` is the only event for those), then a single PreToolUse mapping would miss bash-guard enforcement.
- **Checked for it**: Read Cursor official docs -- they list both `preToolUse` and `beforeShellExecution` as separate events. The docs state preToolUse matcher can filter by tool identifier including "Shell". This suggests preToolUse DOES fire for shell commands, but ❓ not runtime-verified.

**Q2: What did I NOT investigate that I should have?**
- Did not check Windsurf, Aider, Continue, or other AI coding tools for hook systems.
- Did not verify Cursor hook behavior at runtime (only read docs).
- Did not investigate whether the hooks.json schema is compatible enough across tools to share a single configuration file (field names differ: `hooks` vs different nesting).
- Did not research whether any tool supports hook event ordering/priority when multiple hooks fire on the same event.

**Q3: What assumptions did I make without verifying?**
- Assumed Claude Code's event list from the official docs is complete and current. ❓ The docs page could lag behind the actual implementation.
- Assumed Codex's experimental hooks will eventually expand (based on maintainer statement "should be easy and quick to add more"). This is a prediction, not evidence.
- Assumed that tools' "command" handler type (stdin JSON, exit code) is sufficiently similar for a thin adapter layer. Did not compare the actual JSON schemas received on stdin.

## Review

Self-review (fallback, no baton-review agent dispatched due to time constraint):

1. Evidence markers present on all material claims: ✅
2. Two independent methods used (official docs + changelogs): ✅
3. Counterexample sweep done with active search: ✅
4. Self-challenge has all required fields: ✅
5. Config files compared field-by-field: partially -- noted schema differences but did not do exhaustive field comparison of hooks.json formats across tools.

## One-Sentence Summary

"In the context of hook event portability for baton governance, investigating Claude Code, Cursor, and Codex CLI, I found that Claude Code offers the richest hook system (22+ events, 4 handler types), Cursor is a viable secondary target (18-20 events, 2 handler types, with semantic differences in event granularity), and Codex is not viable for governance today (only 3 experimental events), with medium-high confidence, accepting that Cursor's blocking semantics and preToolUse coverage are not runtime-verified."

## Final Conclusions

**C1**: Claude Code is the only platform that supports all of baton's current governance hooks.
- **Confidence**: high -- ✅ verified against manifest.conf and official docs
- **Primary source**: Claude Code official docs (https://code.claude.com/docs/en/hooks)
- **Applicability**: Direct -- baton already runs on this
- **Verification path**: Already verified -- baton's hooks work in production
- **Uncertainty**: None for current state. Future deprecation risk is ❓ unknown.
- **Plan implication**: actionable -- continue using Claude Code as primary platform

**C2**: Cursor is a viable secondary target, with 8 of 10 baton hook registrations having equivalents, but requires an adapter layer due to semantic differences (split events, different matcher syntax, different JSON schemas).
- **Confidence**: medium -- ✅ event names verified from official docs; ❓ blocking behavior on afterFileEdit and exact preToolUse coverage not runtime-verified
- **Primary source**: Cursor official docs (https://cursor.com/docs/hooks)
- **Applicability**: Requires adapter work; not drop-in compatible
- **Verification path**: Build a minimal Cursor hooks.json and test write-lock + bash-guard behavior
- **Uncertainty**: Whether `afterFileEdit` can provide blocking feedback for quality-gate; whether `preToolUse` fires for all tool types
- **Plan implication**: actionable -- design adapter layer if cross-tool support is a goal

**C3**: Codex CLI is not viable for baton governance today.
- **Confidence**: high -- ✅ only 3 events exist (SessionStart, Stop, UserPromptSubmit) per official changelog through v0.116.0
- **Primary source**: Codex changelog (https://developers.openai.com/codex/changelog)
- **Applicability**: Cannot enforce write-lock, bash-guard, quality-gate, failure-tracking, or subagent-context -- these require PreToolUse/PostToolUse which Codex lacks
- **Verification path**: Monitor Codex changelog for PreToolUse/PostToolUse addition
- **Uncertainty**: Timeline for Codex hook expansion is ❓ unknown; maintainer said "easy and quick to add more" but no timeline given
- **Plan implication**: watchlist -- re-evaluate when Codex adds tool-level hooks

**C4**: The cross-tool portable event set is {SessionStart, Stop} -- only 2 of baton's 10 hook registrations.
- **Confidence**: high -- ✅ verified all three tools support these events
- **Primary source**: All three official sources
- **Applicability**: These events can only support phase-guide (SessionStart) and stop-guard (Stop). Core governance (write-lock, bash-guard) requires tool-level events not available on Codex.
- **Verification path**: N/A -- factual finding
- **Uncertainty**: None
- **Plan implication**: judgment-needed -- should baton design for a lowest-common-denominator portable set, or target Claude Code + Cursor and accept Codex non-support?

**C5**: Claude Code's unique strengths for governance are: agent hooks (subagent verification), HTTP hooks (remote policy servers), TaskCompleted event, PermissionRequest event, InstructionsLoaded event, and SessionStart sub-matchers (startup/resume/clear/compact).
- **Confidence**: high -- ✅ verified from official docs; no equivalent found in Cursor or Codex docs
- **Primary source**: Claude Code official docs
- **Applicability**: Baton uses TaskCompleted (completion-check) and SubagentStart (subagent-context) which are Claude Code exclusive or near-exclusive
- **Verification path**: N/A -- factual comparison
- **Uncertainty**: Cursor may add equivalent events in future versions ❓
- **Plan implication**: watchlist -- these features create lock-in; decide if the governance value justifies it

## Questions for Human Judgment

**Blocks plan** -- must be answered before entering plan phase:

- Should baton target Claude Code + Cursor portability, or remain Claude Code exclusive? The adapter layer for Cursor is non-trivial due to event semantics differences.
- Is TaskCompleted (completion-check) essential enough to accept Claude Code lock-in, or should completion verification be moved to the Stop event (portable to Cursor)?

**Can wait for implementation** -- plan can proceed, decide during implementation:

- What is the exact hooks.json schema mapping between Claude Code and Cursor? (Needed for adapter design but not for architecture decision.)
- Does Cursor's `preToolUse` fire for shell commands, or only `beforeShellExecution`? (Determines adapter complexity.)

**Out of scope but related** -- recorded but does not block:

- Should baton consider Windsurf, Aider, or other AI coding tools?
- Should baton define its own abstract hook event layer and map to tool-specific events?

**Open unknowns** -- classified by blocking severity:
- Cursor afterFileEdit blocking capability: does not block plan (workaround: use preToolUse for blocking, afterFileEdit for tracking)
- Codex hook expansion timeline: does not block plan (watchlist item)
- Other AI coding tools' hook systems: does not block plan (out of current scope)

**Chat requirements captured**:
- `Human requirement (chat): Research hook events across Claude Code, Cursor, and Codex to decide which events baton should rely on for core governance.`

## 批注区

<!--
Processing rules:
- Read underlying evidence before responding
- Do not rewrite a challenge into a weaker one
- If accepted: update the relevant section
- If rejected: explain with evidence
- If unresolved: keep as ❓
- Impact = "blocks next phase" → document goes BLOCKED until resolved
-->

<!--
Per annotation, copy this block:

### [Annotation N]
- **Trigger / 触发点**:
- **Intent as understood / 理解后的意图**:
- **Response / 回应**:
- **Status**: ✅ / ❌ / ❓
- **Impact**: none / clarification only / affects conclusions / blocks next phase
-->
