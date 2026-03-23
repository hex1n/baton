# Plan: Baton Skill Marketplace

## Sizing: Large

**Reason**: New subsystem (registry protocol, CLI commands, network I/O, cross-platform distribution) with multi-step verification — requires design-level validation (test scenarios, multi-env, manual judgment).

---

## Problem Statement

Users cannot share or install third-party skills. Skills live in `.baton/skills/` and are distributed via junction/symlink to project IDE directories, but there is no mechanism to:
1. Discover skills others have published
2. Install a skill from a remote source into `~/.baton/`
3. Publish a skill from a local project
4. Manage installed third-party skills (list, update, remove)

## Design Constraints

- **Pure bash + markdown. Zero compiled dependencies.** No Node, Python, or Go runtimes. jq optional with awk fallback.
- **Junction-based distribution must be preserved.** Third-party skills install into `~/.baton/skills/` and flow to projects via the existing junction mechanism in `phase-guide.sh` and `setup.sh`.
- **Cross-platform.** Windows (Git Bash + NTFS junctions), macOS, Linux.
- **Git-native.** GitHub is the primary skill host. No custom server infrastructure needed for v1.

---

## Architecture Decision: Git Repos as Skill Packages

Each skill is a git repository (or a subdirectory within a repo) containing a `SKILL.md` and optional supporting files. The marketplace is a curated registry file (JSON or plain text) hosted in the baton repo itself, mapping skill names to git URLs.

**Why git repos, not tarballs or a custom server:**
- Users already have git (baton requires it for `install.sh` / `baton update`)
- Familiar contribution model (fork, PR to registry)
- Version pinning via git tags/commits
- No server infrastructure to maintain
- Aligns with "zero compiled dependencies" constraint

**Registry format**: A single `registry.json` file in the baton repo at `.baton/marketplace/registry.json`. JSON because baton already has jq-or-awk parsing throughout. Each entry:

```json
{
  "skills": {
    "skill-name": {
      "repo": "https://github.com/user/baton-skill-example.git",
      "path": ".",
      "description": "One-line description",
      "author": "github-username",
      "tags": ["research", "testing"],
      "min-baton-version": "4.0"
    }
  }
}
```

- `path`: subdirectory within the repo containing SKILL.md (default `.` = repo root is the skill)
- Community can submit PRs to add entries to the registry

---

## Approach

### Phase 1: Skill Package Convention

Define the contract for a publishable skill.

**Deliverables:**
- Document the skill package spec (what constitutes a valid installable skill)
- Validation function: `skill_validate <dir>` — checks SKILL.md exists, frontmatter is parseable, no absolute paths, etc.

**Spec:**
- A skill package is a directory containing at minimum `SKILL.md`
- Optional: `review-prompt.md`, `template-*.md`, workspace dirs, supporting scripts
- SKILL.md frontmatter must include `name:` and `description:` fields
- A `skill.json` manifest (optional) can declare dependencies, compatible baton versions, and post-install hooks

**Files:**
- `.baton/marketplace/skill-spec.md` — human-readable spec
- `.baton/hooks/lib/skill-validate.sh` — validation library (sourced, not executed)

### Phase 2: Registry & Index

**Deliverables:**
- Registry file format and initial seed
- `registry_fetch` / `registry_search` functions
- Local cache at `~/.baton/marketplace/cache/registry.json`

**Design:**
- Registry lives at `https://raw.githubusercontent.com/hex1n/baton/master/.baton/marketplace/registry.json`
- `registry_fetch`: curl/wget download to local cache, with staleness check (re-fetch if >24h old)
- `registry_search <query>`: grep/awk against cached registry, match on name/description/tags
- Fallback: if no network, use stale cache with warning

**Files:**
- `.baton/marketplace/registry.json` — the canonical registry (committed to repo)
- `.baton/hooks/lib/marketplace.sh` — registry fetch/search/parse functions

### Phase 3: CLI Commands (`baton skill`)

Extend `bin/baton` with a `skill` subcommand tree:

| Command | Description |
|---------|-------------|
| `baton skill search <query>` | Search registry by name/tag/description |
| `baton skill install <name>` | Install skill from registry (git clone to `~/.baton/skills/<name>/`) |
| `baton skill install <git-url>` | Install skill directly from URL (bypass registry) |
| `baton skill remove <name>` | Remove installed third-party skill |
| `baton skill list` | List installed skills (built-in vs. third-party) |
| `baton skill info <name>` | Show skill metadata |
| `baton skill update [name]` | Update one or all third-party skills (git pull) |
| `baton skill publish` | Validate local skill + generate registry entry for PR submission |

**Implementation details:**

- **Install flow:**
  1. Resolve name to git URL (via registry) or accept raw URL
  2. `git clone --depth 1` to `~/.baton/marketplace/packages/<name>/`
  3. Validate cloned skill (`skill_validate`)
  4. If `path` is not `.`, extract subdirectory
  5. Create junction/symlink from `~/.baton/marketplace/packages/<name>/[path]` to `~/.baton/skills/<name>/`
  6. Existing junction mechanism in `phase-guide.sh` auto-distributes to project IDE dirs on next session

- **Remove flow:**
  1. Remove junction from `~/.baton/skills/<name>/`
  2. Remove cloned source from `~/.baton/marketplace/packages/<name>/`
  3. Note: project-level junctions become dangling — next `baton init` or session cleans up

- **Distinction: built-in vs. third-party:**
  - Built-in skills: directories directly in `.baton/skills/` that are part of the baton repo (tracked by git)
  - Third-party skills: junctions in `.baton/skills/` pointing to `~/.baton/marketplace/packages/`
  - `baton skill list` shows provenance (built-in / marketplace / manual)

- **Update flow:**
  - `git -C ~/.baton/marketplace/packages/<name> pull --ff-only`
  - Junctions mean projects see changes immediately (no re-init needed)

**Files:**
- `bin/baton` — extend with `skill` case
- `.baton/hooks/lib/marketplace.sh` — core logic (sourced by CLI)

### Phase 4: Conflict & Safety

**Namespace collisions:**
- Third-party skills must not use the `baton-` prefix (reserved for built-in skills)
- Install rejects if name collides with existing built-in skill
- Install warns if name collides with already-installed third-party skill (offer `--force`)

**Security considerations:**
- Skills are markdown/bash — they execute as part of the AI agent's context, not as arbitrary code on the user's machine
- SKILL.md is loaded by the AI; supporting `.sh` scripts could be sourced by hooks
- v1: trust model is "review before install" (same as installing any git repo)
- v1: no sandboxing beyond what the IDE provides
- Registry PRs are reviewed by maintainer (curated, not open)
- Display a warning on install: "This skill will be loaded by your AI agent. Review the contents before use."

**Version pinning:**
- Default: install latest (HEAD of default branch)
- `baton skill install <name>@<tag>` — checkout specific tag after clone
- Store installed version in `~/.baton/marketplace/installed.json`:
  ```json
  {
    "skill-name": {
      "repo": "https://...",
      "ref": "v1.2.0",
      "installed": "2026-03-23T10:00:00Z"
    }
  }
  ```

### Phase 5: Integration with Existing Systems

**`phase-guide.sh` changes:**
- Current: auto-junctions only `baton-*` skills from `.baton/skills/` to IDE dirs
- Change: junction ALL directories in `.baton/skills/` (not just `baton-*` prefix)
- This means third-party skills installed to `~/.baton/skills/<name>/` automatically appear in project IDE skill directories

**`setup.sh` changes:**
- `create_skill_junctions()` currently iterates `$BATON_SKILL_NAMES` (computed from `.baton/skills/*/`)
- No change needed — it already discovers all skills dynamically via `compute_skill_names()`
- Verify: `_scan_all_skills()` in phase-guide.sh already scans all `*/` under skill dirs, not just `baton-*`

**`baton doctor` changes:**
- Add third-party skill health check (junction integrity, source repo accessible)
- Distinguish built-in vs. third-party in output

**`baton update` changes:**
- Add `--skills` flag to also update third-party skills
- Or: `baton skill update` is the canonical command, `baton update` only updates baton core

### Phase 6: Documentation & Onboarding

- README section: "Skill Marketplace"
- `baton skill --help` comprehensive usage
- Contributing guide for skill authors: how to structure, test, and submit to registry
- Template repo: `baton-skill-template` on GitHub (separate repo, out of scope for this plan)

---

## Execution Order

```
Phase 1 (skill-spec + validation)
  → Phase 2 (registry format + fetch/search)
    → Phase 3 (CLI commands — install/remove/list/search)
      → Phase 4 (conflict resolution + safety)
        → Phase 5 (integration — phase-guide.sh, doctor, update)
          → Phase 6 (docs)
```

Phases 1-2 can be developed and tested independently. Phase 3 depends on both. Phase 4 is mostly logic within Phase 3 but separated for clarity. Phase 5 is surgical modifications to existing files. Phase 6 is last.

---

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Skill hosting | Git repos | Users already have git; familiar PR model; no infra cost |
| Registry | Single JSON in baton repo | Simple, version-controlled, PR-based curation |
| Package storage | `~/.baton/marketplace/packages/` | Separates third-party from built-in; clean uninstall |
| Distribution to projects | Existing junction mechanism | Zero new infrastructure; skills appear automatically |
| Namespace | `baton-` prefix reserved | Prevents collisions; clear built-in vs. community signal |
| Trust model | Review-before-install + curated registry | Matches risk level (markdown/prompts, not executables) |
| Version pinning | Git tags, stored in installed.json | Simple, git-native, no semver parser needed |

---

## Write Set

| File | Action | Phase |
|------|--------|-------|
| `.baton/marketplace/registry.json` | Create | 2 |
| `.baton/marketplace/skill-spec.md` | Create | 1 |
| `.baton/hooks/lib/skill-validate.sh` | Create | 1 |
| `.baton/hooks/lib/marketplace.sh` | Create | 2-3 |
| `bin/baton` | Modify | 3 |
| `.baton/hooks/phase-guide.sh` | Modify | 5 |
| `setup.sh` | Modify (if needed) | 5 |
| `README.md` | Modify | 6 |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Git clone is slow on Windows | Poor install UX | `--depth 1` by default; cache cloned repos |
| No network → install fails | Expected | Clear error message; cached registry for search |
| Malicious skill in registry | AI agent loads hostile prompts | Curated registry with maintainer review; install warning |
| Junction limits on some NTFS configs | Skills not visible in project | Existing fallback to copy-mode in `junction.sh` |
| Namespace squatting | Third-party claims common names | First-come in registry; maintainer review gate |
| Skill depends on specific baton version | Breaks on old installs | `min-baton-version` field in registry; warn on install |

---

## Verification Strategy

- **Unit**: `tests/test-marketplace.sh` — skill validation, registry parsing, install/remove lifecycle
- **Integration**: Install a test skill from a real git repo, verify it appears in project IDE dirs via junction
- **Cross-platform**: Test on Windows (Git Bash) and Unix (CI)
- **Edge cases**: No network, name collision, invalid SKILL.md, `baton-` prefix rejection, version pinning
- **Manual**: End-to-end flow — search → install → use in Claude Code → remove

---

## Open Questions (for human decision)

1. **Registry hosting**: Should the registry be in the main baton repo (simpler) or a separate `baton-registry` repo (cleaner separation)?
2. **Skill naming**: Should third-party skills follow a namespaced convention like `@author/skill-name` or just flat `skill-name`?
3. **Auto-update**: Should `baton update` auto-update third-party skills, or require explicit `baton skill update`?
4. **Workspace isolation**: Should third-party skill workspaces be isolated from baton's own workspace directories?

---

## 批注区
