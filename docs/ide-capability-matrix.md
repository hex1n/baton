# IDE Capability Matrix

As of 2026-03-09. Baton supports 4 IDEs.

| Product | Official custom hooks | Baton target today | Baton bucket today | Notes |
|---|---|---|---|---|
| Claude Code | Yes | `.claude/` | Full protection | Native hook model with session/tool lifecycle support (7 hooks) |
| Factory AI | Yes | `.claude/`-compatible surface | Full protection | Claude-style hook model |
| Cursor IDE | Yes | `.cursor/` | Full protection | Baton `cursor` means IDE integration, not CLI |
| Codex | No custom hooks found | Generated `AGENTS.md` + generated `.agents/skills/` | Rules guidance | Rules, skills, sandbox, approval controls |

## Maintenance Rules

1. Update this matrix before changing supported-IDE wording in `README.md`, `setup.sh`, or installer-facing tests.
2. If product capability and Baton installer target differ, describe both explicitly instead of collapsing them into one label.
