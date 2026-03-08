# IDE Hook Support Research (2026-03-07)

## Scope

Re-check which Baton-supported IDEs currently support hooks, using:

- Current Baton assumptions in [setup.sh](/Users/hex1n/IdeaProjects/baton/setup.sh#L280) and [README.md](/Users/hex1n/IdeaProjects/baton/README.md#L112)
- Current official product documentation or official product channels as of 2026-03-07

## Tool Inventory

- `rg` / `sed` on local repo: used to inspect current Baton assumptions and config paths
- `Context7`: used to query official-style doc mirrors for Claude Code hooks, GitHub Copilot hooks, and Zed rules/tool permissions
- Official web docs search/open: used for current hook support claims
- No source-code changes performed during research

## Summary Matrix

| IDE | Baton current assumption | Official finding | Assessment |
|---|---|---|---|
| Claude Code | `native hooks + skills` ([setup.sh](/Users/hex1n/IdeaProjects/baton/setup.sh#L282), [README.md](/Users/hex1n/IdeaProjects/baton/README.md#L114)) | Anthropic officially documents `hooks` in `.claude/settings.json`, including `PreToolUse`, `PostToolUse`, `SessionStart`, `Stop`, etc. Source: https://docs.anthropic.com/en/docs/claude-code/hooks | `✅ confirmed` |
| Factory AI | `Claude-style hooks + skills` ([setup.sh](/Users/hex1n/IdeaProjects/baton/setup.sh#L283), [README.md](/Users/hex1n/IdeaProjects/baton/README.md#L115)) | Factory officially documents Droid hooks with `PreToolUse`, `PostToolUse`, `SessionStart`, `SessionEnd`, `Stop`, `SubagentStop`, `PreCompact`, etc. Sources: https://docs.factory.ai/cli/configuration/hooks-guide , https://docs.factory.ai/reference/hooks-reference | `✅ confirmed` |
| Cursor IDE | `adapter + session hooks` ([setup.sh](/Users/hex1n/IdeaProjects/baton/setup.sh#L284), [README.md](/Users/hex1n/IdeaProjects/baton/README.md#L116)) | Cursor official product pages/changelog confirm hooks exist in the IDE. Sources: https://cursor.com/blog/enterprise/ , https://cursor.com/changelog/1-7/ | `✅ hooks exist` |
| Cursor CLI | not modeled separately in Baton | Official Cursor staff says CLI hook support is currently partial: only `beforeShellExecution` and `afterShellExecution`; full parity is still in development. Source: https://forum.cursor.com/t/cursor-cli-doesnt-send-all-events-defined-in-hooks/148316/7 | `⚠ partial only` |
| Windsurf | `native hooks + skills` ([setup.sh](/Users/hex1n/IdeaProjects/baton/setup.sh#L285), [README.md](/Users/hex1n/IdeaProjects/baton/README.md#L117)) | Windsurf officially documents Cascade Hooks with workspace/user/system config, pre/post events, and blocking via exit code `2`. Source: https://docs.windsurf.com/windsurf/cascade/hooks | `✅ confirmed` |
| Augment | `hooks + skills` ([setup.sh](/Users/hex1n/IdeaProjects/baton/setup.sh#L287), [README.md](/Users/hex1n/IdeaProjects/baton/README.md#L118)) | Augment officially documents hooks in `settings.json`, including `PreToolUse`, `PostToolUse`, `SessionStart`, `SessionEnd`, `Stop`. Source: https://docs.augmentcode.com/cli/hooks | `✅ confirmed` |
| Kiro IDE / CLI | Baton currently maps this through `.amazonq` and labels it `hook protection via .amazonq + skills` ([setup.sh](/Users/hex1n/IdeaProjects/baton/setup.sh#L288), [README.md](/Users/hex1n/IdeaProjects/baton/README.md#L119)) | Kiro officially documents hooks, contextual hooks, pre/post tool hooks, task hooks, and hook packaging in powers. Sources: https://kiro.dev/docs/cli/hooks , https://kiro.dev/changelog/ide/0-8/ , https://kiro.dev/changelog/ide/0-9/ , https://kiro.dev/changelog/ide/0-10/ | `✅ confirmed, richer than Baton assumes` |
| Amazon Q Developer CLI | Baton currently collapses this together with Kiro ([README.md](/Users/hex1n/IdeaProjects/baton/README.md#L119)) | AWS officially documents agent hooks for `agentSpawn` and `userPromptSubmit`; older context hooks are deprecated. Sources: https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/command-line-custom-agents-configuration.html , https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/command-line-context-hooks.html | `✅ confirmed, but different hook model` |
| GitHub Copilot coding agent / CLI | `adapter + workflow.md + skills` ([setup.sh](/Users/hex1n/IdeaProjects/baton/setup.sh#L289), [README.md](/Users/hex1n/IdeaProjects/baton/README.md#L120)) | GitHub officially documents hooks for Copilot coding agent and Copilot CLI, stored at `.github/hooks/*.json`, with session/tool lifecycle events. Source: https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-hooks | `✅ confirmed` |
| Cline | `completion checks + skills` ([setup.sh](/Users/hex1n/IdeaProjects/baton/setup.sh#L286), [README.md](/Users/hex1n/IdeaProjects/baton/README.md#L121)) | Cline officially documents hooks broadly, including `TaskStart`, `TaskResume`, `TaskComplete`, `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `PreCompact`; CLI hooks are supported on macOS/Linux. Sources: https://docs.cline.bot/customization/hooks , https://docs.cline.bot/features/hooks/hook-reference | `✅ confirmed` |
| Codex | `AGENTS.md + .agents/skills` and `no hooks` ([setup.sh](/Users/hex1n/IdeaProjects/baton/setup.sh#L290), [README.md](/Users/hex1n/IdeaProjects/baton/README.md#L123)) | OpenAI official materials currently emphasize `AGENTS.md`, Skills, sandbox/approval controls, and rules. I did not find an official custom hook mechanism. Sources: https://openai.com/index/introducing-codex/ , https://openai.com/codex , https://openai.com/index/introducing-the-codex-app/ | `✅ no custom hooks found` |
| Zed | `rules only` ([setup.sh](/Users/hex1n/IdeaProjects/baton/setup.sh#L291), [README.md](/Users/hex1n/IdeaProjects/baton/README.md#L124)) | Zed officially documents `.rules` plus tool permissions and MCP support, but not a custom hook execution system. Sources: https://zed.dev/docs/ai/rules , https://zed.dev/docs/ai/agent-settings , https://zed.dev/docs/ai/mcp | `✅ no custom hooks found` |
| Roo Code | `rules via .roo/rules + skills` ([setup.sh](/Users/hex1n/IdeaProjects/baton/setup.sh#L292), [README.md](/Users/hex1n/IdeaProjects/baton/README.md#L122)) | Current official Roo docs and repo prominently document modes, auto-approve, MCP, and docs, but I did not find a current official hook system page comparable to Cline/Windsurf/Kiro. Sources: https://docs.roocode.com/ , https://github.com/RooCodeInc/Roo-Code | `❓ no current official hook docs found` |

## Key Findings

### 1. Baton is correct about these having real hook systems

- Claude Code
- Factory AI
- Windsurf
- Augment
- GitHub Copilot coding agent / CLI
- Cline

### 2. Cursor does support hooks, but Baton should distinguish IDE vs CLI

- Cursor IDE clearly has hooks from official product material.
- Cursor CLI still has only partial hook parity according to Cursor staff.
- Baton currently treats `cursor` as a single bucket. That is workable for the IDE integration, but inaccurate if the project wants to reason about Cursor CLI separately.

### 3. `Kiro` and `Amazon Q Developer CLI` should no longer be treated as the same thing

- Official Kiro docs now show a broad hook system with multiple trigger families and ongoing hook feature expansion.
- Official Amazon Q Developer CLI docs show agent hooks, but the model is different: `agentSpawn` and `userPromptSubmit`, with older context hooks deprecated.
- Baton currently maps `kiro` to `.amazonq/...` and describes it as one combined target. That is now a conceptual mismatch.

### 4. Codex and Zed still do not show a custom hook system in official docs

- Codex: official control mechanisms are rules, skills, sandboxing, and approval controls, not hooks.
- Zed: official control mechanisms are rules, tool permissions, and MCP, not hooks.

### 4b. Context7 spot-check agrees with the same split

- Context7 for `Claude Code` returned hook config and event docs for `PreToolUse`, `Stop`, and hook JSON structure, which supports the "real hooks" classification.
- Context7 for `GitHub Docs` returned Copilot coding agent / CLI hook docs showing `.github/hooks/*.json`, `sessionStart`, `preToolUse`, `postToolUse`, and synchronous blocking behavior.
- Context7 for `Zed` returned tool permissions and external agent settings, but did not surface a custom hook script system. That supports keeping Zed in the rules/permissions bucket.

### 5. Roo Code remains the least certain case

- I found no current official Roo hook documentation.
- Official materials I found emphasize custom modes, auto-approve, MCP, and docs/repo customization instead.
- Baton's current conservative stance (`rules + skills`, not hooks) remains the safest default unless stronger primary evidence appears.

## Counterexample Sweep

- Counterexample to "Cursor supports full hooks everywhere": false. Cursor CLI is still partial, even though Cursor IDE hooks exist.
- Counterexample to "Amazon Q / Kiro is one hook platform": false. Official docs now describe different systems.
- Counterexample to "all VS Code-derived IDEs support hooks the same way": false. Cline, Windsurf, Kiro, Cursor, and Roo diverge materially.

## Recommended Baton Impact

1. Split `kiro` from `amazonq` in capability modeling.
2. Split `cursor-ide` vs `cursor-cli` in docs/research, even if setup keeps one `cursor` installer path.
3. Keep `codex` and `zed` in rules-guidance bucket.
4. Keep `roo` conservative until a primary Roo hook spec appears.

## Self-Review

- Weakest conclusion: Roo Code. This is based on absence of official hook documentation I could find, not on an explicit official "no hooks" statement.
- Most likely stale assumption in Baton: conflating Kiro with Amazon Q Developer CLI.
- What would change this research: a current official Cursor hook reference page, or a current official Roo hook reference page.

## Questions for Human Judgment

- Does Baton want to model products by brand name (`Kiro`, `Amazon Q`) or by concrete runtime/config surface (`.kiro`, `.amazonq`)?
- Does Baton care about Cursor CLI separately from Cursor IDE, or is the product-level abstraction good enough?

## 批注区

> 标注类型：`[Q]` 提问 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏 · `[NOTE]` 补充 · `[RESEARCH-GAP]` 需要更多调查
> 审阅完毕后告诉 AI "出 plan" 进入计划阶段

<!-- 在下方添加标注 -->
