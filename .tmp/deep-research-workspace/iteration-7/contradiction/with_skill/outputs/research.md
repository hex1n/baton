# adapter-cline.sh / adapter-copilot.sh: Documentation vs Code

**Depth**: Standard -- documentation-vs-code consistency check with clear search scope.

## Answer

**Code is correct. `adapter-cline.sh` and `adapter-copilot.sh` have never existed.** They appear only in the research document's *proposed* architecture diagram, not as descriptions of current implementation. Baton currently has exactly **2 adapters**: Cursor and Codex.

---

## Evidence

### 1. What the documentation claims

`docs/research-ide-hooks.md` lines 327-337 contain an architecture diagram under the heading "### Suggested baton architecture":

```
write-lock.sh (core, exit 0/2)
├── Direct use: Claude Code, Factory, Cursor*, Windsurf, Augment, Amazon Q/Kiro
├── Thin adapter layer (~10 lines, translate output format):
│   ├── adapter-cline.sh    → {"cancel":true/false}
│   └── adapter-copilot.sh  → {"permissionDecision":"deny"/"allow"}
├── JS Plugin: OpenCode (standalone, already exists)
└── Fallback:
    ├── Rules injection: Codex (AGENTS.md), Zed (.rules), Roo Code (.roo/rules/)
    └── git pre-commit hook: universal safety net
```

The same document also references `adapter-copilot.sh` in the GitHub Copilot configuration example at lines 227-228:
```json
"bash": ".baton/adapters/adapter-copilot.sh",
"powershell": ".baton/adapters/adapter-copilot.ps1",
```

And `adapter-cursor.sh` in the Cursor configuration example at line 106:
```json
"command": ".baton/adapters/adapter-cursor.sh",
```

These are all **proposed/example** configurations showing how baton *could* integrate with each IDE's hook system. The document is a research survey (dated 2026-03-03/2026-03-05), and the header at line 7 explicitly states: "Current implementation scope (2026-03-09): Baton supports 4 IDEs -- Claude Code, Factory AI, Cursor IDE (core protection via adapter), and Codex (rules guidance). All other IDEs documented below are historical research only and are not supported by the current installer."

### 2. What actually exists in code

Codebase search (`glob **/adapter*`) reveals exactly 2 adapter directories:

| Adapter | Path | Purpose |
|---------|------|---------|
| Cursor | `.baton/adapters/cursor/adapter.sh` | Translates write-lock exit codes to Cursor JSON protocol: `{"decision":"allow"}` / `{"decision":"deny","reason":"..."}` |
| Cursor dispatch | `.baton/adapters/cursor/dispatch.sh` | Full event dispatch for Cursor (maps camelCase events to PascalCase, routes through `dispatch.sh`) |
| Codex | `.baton/adapters/codex/adapter.sh` | Translates Baton hook stderr to Codex stdout protocol for `phase-guide` and `stop-guard` |
| Codex dispatch | `.baton/adapters/codex/dispatch.sh` | Full event dispatch for Codex (SessionStart, Stop) |

No `adapter-cline.sh`, `adapter-copilot.sh`, or any Cline/Copilot-related adapter file exists anywhere in the repository.

- Codebase-wide grep for `adapter-cline|adapter-copilot` returns hits only in `docs/research-ide-hooks.md` and previous eval output files in `.tmp/`. Zero hits in any `.sh`, `.json`, or configuration file.
- `git log --all --oneline -- '**/adapter-cline*' '**/adapter-copilot*'` returns no commits -- these files were never created.

### 3. The naming discrepancy

The research document proposed a flat naming scheme (`adapter-cline.sh`, `adapter-copilot.sh`, `adapter-cursor.sh`). The actual implementation uses a subdirectory structure (`adapters/cursor/adapter.sh`, `adapters/codex/adapter.sh`).

This is confirmed by commit `96334d1` (2026-03-18):
```
refactor: restructure .baton directory -- extract lib/, consolidate adapters
.../{adapter-codex.sh => codex/adapter.sh}
.../{adapter-cursor.sh => cursor/adapter.sh}
```

Before this commit, flat-named files `adapter-cursor.sh` and `adapter-codex.sh` did exist. After the refactor, they became subdirectory-based. The documentation was not updated to reflect this restructuring.

### 4. Current supported IDEs (from ide-capability-matrix.md)

| Tier | IDEs | Adapter |
|------|------|---------|
| Full protection | Claude Code, Factory AI | None needed (native hook support) |
| Core protection | Cursor IDE | `adapters/cursor/adapter.sh` + `dispatch.sh` |
| Rules guidance | Codex | `adapters/codex/adapter.sh` + `dispatch.sh` |

Cline, Copilot, Windsurf, Augment, Kiro, and others are documented in the research as theoretically compatible but have no implementation.

---

## Verdict

| Item | In documentation | In code | Status |
|------|-----------------|---------|--------|
| `adapter-cline.sh` | Proposed in architecture diagram (line 332) | Does not exist | **Unimplemented proposal** |
| `adapter-copilot.sh` | Proposed in architecture diagram (line 333) + config example (line 227) | Does not exist | **Unimplemented proposal** |
| `adapter-cursor.sh` (flat) | Config example (line 106) | Renamed to `adapters/cursor/adapter.sh` in `96334d1` | **Doc stale** |
| `adapter-codex.sh` (flat) | Not directly in research doc | Renamed to `adapters/codex/adapter.sh` in `96334d1` | **Doc stale** (referenced in `ide-capability-matrix.md:33,38`) |

**The code is the source of truth.** The research document mixes current-state descriptions with future proposals without clear visual separation, which causes the confusion. The document's own header (line 7) correctly narrows the scope to 4 IDEs, but the architecture diagram deeper in the document does not carry the same caveat.

---

## Documentation issues found

1. **`docs/research-ide-hooks.md` lines 327-337**: The architecture diagram proposes `adapter-cline.sh` and `adapter-copilot.sh` without marking them as unimplemented. A reader encountering this diagram naturally expects these files to exist.

2. **`docs/research-ide-hooks.md` line 106**: Cursor config example references `.baton/adapters/adapter-cursor.sh` (flat path) -- the actual path is `.baton/adapters/cursor/adapter.sh` (directory structure post-`96334d1`).

3. **`docs/ide-capability-matrix.md` lines 33, 38**: References `adapter-cursor.sh` and `adapter-codex.sh` using the pre-refactor flat naming. Actual paths are `adapters/cursor/adapter.sh` and `adapters/codex/adapter.sh`.

---

## Weakest conclusion

The classification of the architecture diagram as "proposed" rather than "intended to be implemented" rests on context (the document header at line 7, the section title "Suggested baton architecture"). If the original author intended these as planned work items rather than pure research suggestions, the gap would be better characterized as "planned but not yet implemented" rather than "unimplemented proposal." The practical impact is the same either way: the files do not exist in code.
