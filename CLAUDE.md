# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

@.baton/constitution.md

## Development

### Testing

- Quick smoke test: `bash tests/test-smoke.sh`
- Full regression: `bash tests/test-full.sh`
- Single test file: `bash tests/test-<name>.sh` (e.g., `bash tests/test-write-lock.sh`)

### Linting

ShellCheck is used in CI. Targets: all `.sh` files under `.baton/hooks/`, `.baton/adapters/`, and `setup.sh`. Run locally: `shellcheck <file>`.

### Platform Notes

- **Windows/Git Bash is slow** (~15s per shell assertion). Use the `timeout` parameter on Bash tool calls for test runs; never use `sleep` + poll loops.
- Hooks on Windows go through `run-hook.cmd` (Git Bash doesn't work in pre-tool hooks on Windows IDE).
- NTFS junctions are the default linking method; falls back to copy-mode if unavailable.

### Key Environment Variables

- `BATON_PLAN` — custom plan filename (default: `plan.md`)
- `BATON_BYPASS=1` — emergency write-lock bypass
- `BATON_HOME` — path to `~/.baton/` (default: `$HOME/.baton`)
- `BATON_IDE` — specify IDEs at install (e.g., `claude,cursor`)

### Architecture

- Pure bash + markdown. Zero compiled dependencies. jq optional (awk fallback).
- Junction-based distribution: `~/.baton/` is the single source; projects reference it via NTFS junctions or symlinks.
- Hook system: `dispatch.sh` reads `manifest.conf` to route events to hook scripts. New hooks need a manifest line + script + IDE registration.
- Adapters in `.baton/adapters/` translate between IDE-specific hook formats (Cursor JSON response protocol, Codex rules-based).
