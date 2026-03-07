# IDE Capability Matrix

As of 2026-03-07. This matrix separates:

- official product capability
- Baton's current installer target
- the bucket Baton should use today

For the full evidence trail, see [Hook Research 2026-03-07](/Users/hex1n/IdeaProjects/baton/research-ide-hooks-2026-03-07.md).

| Product | Official custom hooks | Baton target today | Baton bucket today | Notes |
|---|---|---|---|---|
| Claude Code | Yes | `.claude/` | Full protection | Native hook model with session/tool lifecycle support |
| Factory AI | Yes | `.claude/`-compatible surface | Full protection | Claude-style hook model |
| Cursor IDE | Yes | `.cursor/` | Full protection | Baton `cursor` means IDE integration, not CLI |
| Cursor CLI | Partial only | Not modeled separately | N/A | Official staff says hook parity is incomplete |
| Windsurf | Yes | `.windsurf/` | Full protection | Native hook model |
| Augment | Yes | `.augment/` | Full protection | Native hook model |
| Kiro | Yes | `.amazonq/` shared surface | Hook protection | Official hook model exists, but Baton still targets the shared `.amazonq/` project surface |
| Amazon Q Developer CLI | Yes, different model | Not modeled separately | N/A | Agent hooks exist, but they are not the same model as Kiro |
| GitHub Copilot | Yes | `.github/hooks/` | Full protection | Coding agent / CLI hook model |
| Cline | Yes | `.clinerules/` and `.cline/skills/` | Hook protection | Hook model exists; Baton uses adapter wiring |
| Codex | No custom hooks found | `AGENTS.md` + `.agents/skills/` | Rules guidance | Rules, skills, sandbox, approval controls |
| Zed | No custom hooks found | `.rules` | Rules guidance | Rules + tool permissions + MCP |
| Roo Code | Unverified in current official docs | `.roo/rules/` + skills | Rules guidance | Baton stays conservative until stronger primary evidence appears |

## Current Baton Guidance

1. Treat `Cursor IDE` and `Cursor CLI` as different capability surfaces in docs/research.
2. Treat `Kiro` and `Amazon Q Developer CLI` as different products with different hook models.
3. Keep `Codex` and `Zed` in the rules-guidance bucket.
4. Keep `Roo Code` conservative until Baton has a current official hook integration target.

## Maintenance Rules

1. Update this matrix before changing supported-IDE wording in `README.md`, `setup.sh`, or installer-facing tests.
2. If product capability and Baton installer target differ, describe both explicitly instead of collapsing them into one label.
3. Current implementation scope: Baton's current installer work covers Cursor IDE and the current Kiro `.amazonq` compatibility surface. This iteration does not add a first-class Amazon Q Developer CLI target, does not model Cursor CLI separately, and keeps Roo Code in rules-guidance mode.
