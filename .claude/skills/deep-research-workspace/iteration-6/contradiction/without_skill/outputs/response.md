# adapter-cline.sh / adapter-copilot.sh: Documentation vs Code

## The Contradiction

**Documentation claim** (`docs/research-ide-hooks.md`, lines 328-337): The "suggested baton architecture" diagram shows two adapter files that translate output formats for B-class protocol IDEs:

```
├── 薄适配层（~10行，翻译输出格式）：
│   ├── adapter-cline.sh    → {"cancel":true/false}
│   └── adapter-copilot.sh  → {"permissionDecision":"deny"/"allow"}
```

**Code reality**: Neither `adapter-cline.sh` nor `adapter-copilot.sh` exists anywhere in the codebase. A global search for these filenames returns zero hits outside of `docs/research-ide-hooks.md` itself.

## What Actually Exists

The adapters directory (`.baton/adapters/`) contains exactly **two** adapter subdirectories:

| Path | Files | Purpose |
|------|-------|---------|
| `.baton/adapters/cursor/` | `adapter.sh`, `dispatch.sh` | Translates dispatch.sh exit codes to Cursor's JSON protocol (`{"decision":"allow"}` / `{"decision":"block"}`) |
| `.baton/adapters/codex/` | `adapter.sh`, `dispatch.sh` | Routes SessionStart/Stop events through dispatch.sh; translates stderr to stdout for Codex's context injection protocol |

The installer (`setup.sh`, line 18) declares exactly four supported IDEs:

```
SUPPORTED_IDES="claude codex cursor factory"
```

Claude Code and Factory AI use the core hooks directly (no adapter needed -- same protocol). Cursor and Codex each have dedicated adapter subdirectories.

The document header itself (line 7) confirms this explicitly:

> Current implementation scope (2026-03-09): Baton supports 4 IDEs -- Claude Code, Factory AI, Cursor IDE (core protection via adapter), and Codex (rules guidance). All other IDEs documented below are historical research only and are not supported by the current installer.

## Verdict: Code Is Authoritative; the Diagram Is a Stale Design Proposal

The architecture diagram on lines 328-337 is a **pre-implementation design suggestion** from the original research document (dated 2026-03-03/05). It describes what *could* be built, not what *was* built. The section is even titled "建议的 baton 架构" ("Suggested baton architecture").

The actual implementation took a different path:

1. **Cline and Copilot were never implemented.** Neither IDE made it into `SUPPORTED_IDES`, and no adapter code was written for them.
2. **Cursor's adapter exists but under a different name and structure.** The diagram proposed `adapter-cursor.sh` (flat file); the implementation uses `adapters/cursor/adapter.sh` + `adapters/cursor/dispatch.sh` (subdirectory with dispatch pattern).
3. **Codex got an adapter the diagram didn't predict.** The diagram placed Codex in "直接使用" (direct use), but the implementation needed a dedicated adapter because Codex's protocol requires stdin closure and stderr-to-stdout redirection.

## Summary

| Item | Document Says | Code Shows |
|------|--------------|------------|
| `adapter-cline.sh` | Listed in diagram | Does not exist |
| `adapter-copilot.sh` | Listed in diagram | Does not exist |
| `adapter-cursor.sh` (flat) | Listed in diagram | Actually `.baton/adapters/cursor/adapter.sh` + `dispatch.sh` |
| Codex adapter | Not in diagram (listed under "直接使用") | Actually `.baton/adapters/codex/adapter.sh` + `dispatch.sh` |
| Supported IDEs | Diagram implies 8+ IDEs possible | `setup.sh` supports exactly 4: claude, codex, cursor, factory |

**The code is the source of truth.** The diagram in the research doc is a design proposal that was partially implemented with structural changes. Cline and Copilot adapters were never built. If the doc is meant to reflect current state, the architecture diagram should be updated -- or more clearly labeled as aspirational/future work.
