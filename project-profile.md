# Project Profile: baton

> Harness for AI-assisted software development. Non-Java project — shell scripts + Markdown.

## Build

| Key | Value |
|-----|-------|
| Language | Bash / Markdown |
| Framework | None (CLI harness) |
| Build tool | None |
| Modules | `spec/` (v1 protocol), `v2/` (v2 protocol), `skills/` (v1 skills), `tests/` (shell tests) |
| Compile | N/A |
| Test | `bash tests/test-*.sh` (individual shell test scripts) |
| Run | N/A (harness is invoked as Claude Code skills) |

## Test Infrastructure

| Key | Value |
|-----|-------|
| Framework | Custom shell-based (each `tests/test-*.sh` is self-contained) |
| Pattern | Setup temp dir → run function → assert output → cleanup |
| Assertion | Shell `[[ ]]` / `diff` / `grep` comparisons |

## Conventions

### Directory Structure
```
baton/
├── v2/                    — v2 harness (current)
│   ├── protocol.md        — protocol spec
│   ├── CLAUDE.md          — entry point
│   ├── skills/            — dispatch, planner, builder, verifier
│   └── templates/         — project-profile, brief templates
├── spec/                  — v1 spec (legacy)
├── skills/                — v1 skills (legacy)
├── tests/                 — shell tests for v1
├── .harness/              — task artifacts (v1 format currently)
└── baton-tasks/           — task history
```

### Naming
- Skills: `{name}/SKILL.md` with YAML frontmatter
- Templates: `{name}.template.md`
- Shell scripts: `kebab-case.sh`

## Traps

| File / Pattern | Trap | Mitigation |
|---------------|------|------------|
| `spec/bootstrap/*.sh` | v1 shell scripts — 50+ files, complex interdependencies | Don't modify; v2 replaces these with skill-based approach |
| `.harness/` | Currently has v1 artifacts | v2 will use same directory but different file format |

## Verifier Capability

| Capability | Available | Notes |
|-----------|-----------|-------|
| Compile | N/A | No compiled language |
| Test | ⚠️ Partial | v1 shell tests exist; v2 has no tests yet |
| App startup | N/A | Not a running application |
| DB | N/A | No database |
| **Verifier Mode** | **C** | Static only — code review + script execution |

## Notes

- v2 is a clean redesign; v1 code in `spec/` and `skills/` is legacy
- The project's primary purpose is to govern OTHER projects (Java), but this task is about tooling for baton itself
- Shell scripts written for this project should be POSIX-compatible where possible, targeting zsh/bash on macOS
