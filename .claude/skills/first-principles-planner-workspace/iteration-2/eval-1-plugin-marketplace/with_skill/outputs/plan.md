# Execution Plan: Baton Skill Marketplace

**Depth**: Deep — this is a "we've always done it this way" situation. Skills distribution has been local-only since inception. The solution space is wide and the constraints need rigorous separation from conventions.

**Input sources**: Codebase exploration of `setup.sh`, `install.sh`, `bin/baton`, `junction.sh`, `phase-guide.sh`, `manifest.conf`, and existing skill structures. User request via conversation.

---

## Phase 1: Problem Archaeology

### 1.1 — The Five Whys

```
Stated: "添加一个插件市场，让用户可以共享和安装 skills"
Why?   → Users create useful skills but can only use them locally
Why?   → The distribution model is junction/copy from ~/.baton/ to project dirs,
         and ~/.baton/ is cloned from a single git repo (hex1n/baton)
Why?   → Skills were designed as part of baton's own governance layer, not as
         independently distributable units
Why?   → The original scope was "enforce plan-first workflow" — skills were
         the mechanism, not the product
Root:    Skills have become a first-class user-facing capability, but the
         distribution infrastructure treats them as implementation details of
         baton itself. Users who create custom skills have no standardized way
         to share them, and users who want new skills have no way to discover them.
```

### 1.2 — Problem Statement

Baton skills are portable markdown units (a directory with SKILL.md), yet there is no mechanism for discovery, installation, or version management of skills beyond the baton-bundled set. Users who create custom skills must manually copy directories. Users who want to find useful community skills have no catalog to search. **Solved** = a user can discover, install, update, and remove third-party skills with a simple CLI command, and a skill author can publish with minimal friction, all without introducing compiled dependencies or breaking the junction-based architecture.

### 1.4 — Assumption Audit

| # | Assumption | Type | If wrong... |
|---|-----------|------|-------------|
| 1 | Skills are always directories with SKILL.md | ✅ fact (verified: every skill in `.baton/skills/` and `.claude/skills/` follows this pattern) | Plan collapses — packaging model would need redesign |
| 2 | Skills need to be in IDE-specific directories (`.claude/skills/`, `.cursor/skills/`, `.agents/skills/`) | ✅ fact (verified: `setup.sh` creates junctions to all three; `phase-guide.sh` scans all four: `.baton`, `.claude`, `.cursor`, `.agents`) | Plan survives — simpler if only one target |
| 3 | A "marketplace" requires a centralized server/registry | **convention** | Plan benefits — simpler approaches exist |
| 4 | Skills must come from a git repo | **convention** | Plan benefits — direct download could work |
| 5 | baton must remain pure bash + markdown, zero compiled deps | ✅ fact (stated design principle, jq is optional with awk fallback) | Plan collapses — would need to allow npm/pip/etc. |
| 6 | Junction-based distribution (single source in `~/.baton/`, projects link to it) must be preserved | ✅ fact for baton-bundled skills, **convention** for third-party | Plan survives — third-party skills could use a different mechanism |
| 7 | Skill versioning matters | **unknown** — skills are currently unversioned markdown files | Plan weakened if ignored (users stuck on broken versions) |
| 8 | Users need a browsable catalog (web UI) | **convention** | Plan survives — CLI-only discovery may suffice initially |

### 1.5 — True Constraints vs. Conventions

**True Constraints:**
- Pure bash + markdown. No compiled deps. jq optional.
- Must work on Windows (Git Bash / NTFS junctions), macOS, Linux.
- Skills are directories with SKILL.md at minimum.
- IDE-specific skill directories must be populated (`.claude/skills/`, `.cursor/skills/`, `.agents/skills/`).
- `atomic_junction` is the linking primitive — battle-tested, handles Windows/Unix/fallback.
- Baton is distributed via `git clone --depth 1` to `~/.baton/`. This repo is the single source of truth for bundled hooks/skills.

**Conventions (candidates for removal or replacement):**
- "All skills come from the baton repo" — third-party skills could come from independent git repos, gists, or a registry.
- "Skills are unversioned" — a `version` field in SKILL.md frontmatter could enable version tracking.
- "Discovery requires knowing the author/repo" — a simple index file (JSON/markdown) could serve as a catalog without a web server.
- "A marketplace needs a backend server" — a git-based registry (like Homebrew taps) avoids server infrastructure entirely.
- "`~/.baton/` is the only skill source" — a separate `~/.baton/plugins/` or `~/.baton/community/` directory could hold third-party skills without polluting the baton source tree.

---

## Phase 2: Solution Reconstruction

### 2.1 — Solution Categories

#### Category A: Git-Based Registry (Homebrew Tap Model)

**Mechanism**: A single git repo acts as the "registry" — contains an `index.json` (or `index.md`) mapping skill names to git repo URLs + metadata. `baton marketplace search` clones/pulls the index. `baton marketplace install <name>` clones the skill repo into `~/.baton/community/<name>/` and creates junctions to project skill dirs. No server needed.

**Why it might be best**: Zero infrastructure cost. Fully offline-capable after initial clone. Git handles versioning naturally (tags/branches). Any user can fork the registry to create a private catalog. Perfectly aligned with baton's git-based distribution model.

**Why it might fail**: Git operations are slow on Windows (~2-5s per clone). Registry becomes a bottleneck if one person controls merges. Discoverability limited to CLI search (no web browse).

**Which conventions does it challenge**: Breaks "all skills from baton repo" and "skills are unversioned." Maintains pure bash.

#### Category B: GitHub API Direct (No Registry)

**Mechanism**: Use GitHub's API (via `curl`) to search repos with a specific topic tag (e.g., `baton-skill`). `baton marketplace search <query>` hits `api.github.com/search/repositories?q=topic:baton-skill+<query>`. Install clones directly. No central registry at all.

**Why it might be best**: Zero maintenance of a registry. Fully decentralized. Skill authors just tag their repo. GitHub handles search, stars, descriptions.

**Why it might fail**: Requires internet for every search. GitHub rate limits (60 req/hr unauthenticated). Ties ecosystem to GitHub exclusively. Search quality depends on GitHub's algo. No curation — anyone can tag a repo.

**Which conventions does it challenge**: Breaks "offline-first" capability. Introduces a runtime dependency on GitHub API availability.

#### Category C: Embedded Registry in Baton Repo

**Mechanism**: Add a `marketplace/` directory to the baton repo itself. `marketplace/index.json` lists community skills with URLs. Bundled with every `~/.baton/` install. Updated on `baton update`. Install still clones from external repos, but the catalog is always local.

**Why it might be best**: Simplest implementation — the registry travels with baton. No additional repos to manage. `baton update` already does `git pull` on `~/.baton/`. Offline search works immediately.

**Why it might fail**: Baton repo becomes a gatekeeper for all skill listings. Index grows stale between updates. Mixes governance code with community content in the same repo.

**Which conventions does it challenge**: Breaks "baton repo is only for baton code." Maintains everything else.

### 2.2 — Inversion Test

**Category A (Git-Based Registry):**
- **Worst case?** Registry repo is abandoned, forks fragment the ecosystem, nobody submits PRs. Mitigated by: automated PR acceptance for valid skill entries (CI validates SKILL.md exists).
- **Opposite approach?** No registry at all (Category B). Merit: simpler. But loses curation and offline capability.
- **If it fails, what do we learn?** That the baton community is too small for a separate registry — in which case fall back to Category C.

**Category C (Embedded Registry):**
- **Worst case?** Baton repo becomes bloated with community submissions, merge conflicts between governance changes and marketplace updates. Mitigated by: the index is a single JSON file, not full skill content.
- **Opposite approach?** Fully decentralized (Category B). Merit: no gatekeeping.
- **If it fails, what do we learn?** That coupling registry and runtime was a mistake — decouple into Category A.

### 2.3 — Recommendation: Category A (Git-Based Registry), bootstrapped with Category C

**Reasoning chain:**

1. **Root problem**: Skills are distributable units with no distribution channel. (Phase 1)
2. **True constraint**: Pure bash, cross-platform, git-based distribution. (Phase 1)
3. **Category A** solves the root problem using the same mechanism baton already uses (git clone + junctions). This is not accidental alignment — it's the same distribution primitive, applied to a new domain.
4. **Convention broken**: "All skills from baton repo." This is acceptable because skills are already structurally independent — they're directories with SKILL.md, no build step, no linking to baton internals.
5. **Bootstrapping with Category C**: Initially ship a `marketplace/index.json` in the baton repo itself. This avoids the cold-start problem (empty registry = zero value). When the ecosystem grows, the index can migrate to a separate repo with zero CLI changes — the CLI reads `index.json` from a configurable URL.
6. **Primary risk**: Windows git clone latency. Mitigation: clone with `--depth 1`, cache index locally, use `git archive` for individual skill downloads when available.

### 2.4 — Dissenting Path

The user asked for a "插件市场" (plugin marketplace), which implies a browsable catalog. If the intent is specifically a web-based marketplace with ratings, downloads, and screenshots:

- **Conditions that would justify it**: 100+ skills in the ecosystem, non-technical users who won't use CLI, monetization intent.
- **If you still want to proceed**: Build the web frontend as a static site generated from `index.json` (GitHub Pages). The CLI plan below remains the backend. The web layer is additive, not architectural.

---

## Phase 3: Plan Synthesis

### Approach

A git-based skill marketplace implemented as:
1. A **registry** (`index.json`) listing skill metadata + source URLs
2. CLI commands (`baton marketplace search|install|remove|publish`) in `bin/baton`
3. A **community skill directory** (`~/.baton/community/`) isolated from bundled skills
4. Junction creation reusing `atomic_junction` to link community skills into projects
5. A **skill manifest** convention (`SKILL.md` frontmatter: `name`, `version`, `description`, `author`, `repository`)

### Steps

| # | Step | Why this order | Effort | Success Criteria |
|---|------|---------------|--------|-----------------|
| 1 | Define skill manifest convention — add `version`, `author`, `repository` fields to SKILL.md frontmatter | Foundation: all subsequent steps depend on being able to identify and version a skill | 2h | Existing baton skills have valid frontmatter; a spec document defines required/optional fields |
| 2 | Create `~/.baton/community/` directory structure and modify `phase-guide.sh` to scan it | Skills installed here must be discoverable by baton's existing skill scan | 3h | `_scan_all_skills()` finds skills in `community/`; SessionStart guidance lists them |
| 3 | Create `marketplace/index.json` schema and seed with 2-3 example entries | The registry format must exist before CLI can consume it | 2h | Valid JSON schema; entries have: name, version, description, author, repository, tags |
| 4 | Implement `baton marketplace search [query]` | Users need discovery before install | 3h | `baton marketplace search research` finds matching skills; works offline from cached index; `baton marketplace search` (no query) lists all |
| 5 | Implement `baton marketplace install <name>` | Core value: one-command skill installation | 4h | `baton marketplace install my-skill` clones repo to `~/.baton/community/my-skill/`, creates junctions in current project's IDE skill dirs; idempotent (re-install updates) |
| 6 | Implement `baton marketplace remove <name>` | Users need to uninstall cleanly | 2h | Removes `~/.baton/community/<name>/`, removes junctions from project; does not touch bundled skills |
| 7 | Implement `baton marketplace list` | Users need to see what's installed | 1h | Lists installed community skills with version and source |
| 8 | Implement `baton marketplace publish` (helper) | Authors need a frictionless publish path | 3h | Validates SKILL.md frontmatter, generates index entry JSON, prints instructions for submitting to registry |
| 9 | Modify `setup.sh` to junction community skills alongside bundled skills | New projects get community skills automatically | 2h | `baton init` in a new project creates junctions for both bundled and community skills |
| 10 | Modify `baton update` to refresh community skills | `baton update` already refreshes bundled skills; community should follow | 2h | `baton update` does `git pull` on each `~/.baton/community/<name>/` repo |
| 11 | Add `baton marketplace update` for selective community updates | Some users want to update only marketplace skills | 1h | Updates all or named community skills |
| 12 | Tests: `tests/test-marketplace.sh` | Regression protection for the new subsystem | 4h | Covers: search, install, remove, list, junction creation, update, idempotency, error cases |

### Priority Table

| Priority | Change | Effort | Risk | Value |
|----------|--------|--------|------|-------|
| P1 | Steps 1-2: Skill manifest + community directory | 5h | Low — additive, no existing behavior changes | High — enables all subsequent work |
| P1 | Steps 3-5: Registry + search + install | 9h | Med — git clone on Windows needs testing | High — core marketplace value |
| P2 | Steps 6-7: Remove + list | 3h | Low — straightforward | Med — completeness |
| P2 | Steps 9-10: setup.sh + update integration | 4h | Med — modifying existing scripts | High — seamless UX |
| P3 | Step 8: Publish helper | 3h | Low | Med — author experience |
| P3 | Steps 11-12: Selective update + tests | 5h | Low | Med — polish + safety net |

### Code Examples

**Step 1 — Skill manifest convention (SKILL.md frontmatter):**

```yaml
---
name: my-awesome-skill
version: 1.0.0
description: >
  Does something useful.
author: username
repository: https://github.com/username/baton-skill-awesome
tags: [research, analysis]
user-invocable: true
---
```

**Step 2 — Community skill scanning (patch to `phase-guide.sh` `_scan_all_skills`):**

```bash
# After existing IDE skill dir scan, also scan community:
_community="${BATON_HOME:-$HOME/.baton}/community"
if [ -d "$_community" ]; then
    for _skill_dir in "$_community"/*/; do
        [ -f "$_skill_dir/SKILL.md" ] || continue
        _name="$(basename "$_skill_dir")"
        case " $_seen " in *" $_name "*) continue ;; esac
        _seen="$_seen $_name"
    done
fi
```

**Step 5 — `baton marketplace install` (core logic in `bin/baton`):**

```bash
marketplace_install() {
    _name="$1"
    _index="$BATON_HOME/marketplace/index.json"
    _community="$BATON_HOME/community"

    # Look up repo URL from index
    _repo="$(jq -r --arg n "$_name" '.skills[] | select(.name == $n) | .repository' "$_index")"
    [ -z "$_repo" ] && { echo "Skill '$_name' not found in marketplace index."; exit 1; }

    # Clone or pull
    _dst="$_community/$_name"
    mkdir -p "$_community"
    if [ -d "$_dst/.git" ]; then
        git -C "$_dst" pull --ff-only 2>/dev/null || echo "⚠ Could not update $_name"
    else
        git clone --depth 1 "$_repo" "$_dst"
    fi

    # Create junctions in current project
    _proj="$(pwd)"
    . "$BATON_HOME/.baton/hooks/lib/junction.sh"
    for _ide_skills in "$_proj/.claude/skills" "$_proj/.cursor/skills" "$_proj/.agents/skills"; do
        [ -d "$_ide_skills" ] || continue
        atomic_junction "$_dst" "$_ide_skills/$_name" 2>/dev/null || true
    done
    echo "✓ Installed $_name"
}
```

**Step 3 — Registry schema (`marketplace/index.json`):**

```json
{
  "version": 1,
  "updated": "2026-03-23",
  "skills": [
    {
      "name": "example-research-helper",
      "version": "1.0.0",
      "description": "Structured research templates for API integration analysis",
      "author": "example-user",
      "repository": "https://github.com/example-user/baton-skill-research-helper",
      "tags": ["research", "api"],
      "min_baton_version": "4.0"
    }
  ]
}
```

### Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| Windows git clone latency (2-5s per skill) | Poor UX on install | High | Use `--depth 1`; batch installs; cache index locally |
| Malicious skills (arbitrary SKILL.md content injected into AI context) | Security — skill could instruct AI to exfiltrate data | Medium | Add a `baton marketplace audit <name>` command that shows SKILL.md content before install; document security model; curated registry requires PR review |
| Registry stale / abandoned | Ecosystem stagnation | Medium | Embed initial index in baton repo; automated CI to validate entries are still reachable |
| Skill name collisions (community skill vs. bundled) | Confusion, broken junctions | Low | Bundled skills use `baton-*` prefix; community skills must not use this prefix; enforce in publish validation |
| jq dependency for JSON parsing | Breaks on systems without jq | Medium | Provide awk/sed fallback for index parsing (consistent with baton's existing pattern) |
| Skill incompatibility across baton versions | Broken skills after baton update | Low (initially) | `min_baton_version` field in index; `baton marketplace install` warns if incompatible |

### Success Criteria

1. A user can run `baton marketplace search research` and see a list of matching community skills
2. A user can run `baton marketplace install <name>` and the skill appears in their project's skill directories, discoverable by phase-guide.sh
3. A skill author can run `baton marketplace publish` and get a validated index entry to submit
4. `baton update` refreshes both bundled and community skills
5. `baton init` in a new project creates junctions for installed community skills
6. All operations work on Windows (Git Bash), macOS, and Linux
7. Zero new compiled dependencies — pure bash throughout

### What We're Deliberately NOT Doing

| Rejected Approach | Why |
|---|---|
| **Web-based marketplace UI** | Premature — no evidence of demand for non-CLI discovery. Can be added later as a static site generated from `index.json` without any architectural change. |
| **npm/pip-style package manager** | Violates pure-bash constraint. Skills are directories, not packages. git clone is the right primitive. |
| **Skill dependencies** (skill A requires skill B) | Complexity not justified yet. Skills are self-contained markdown. If needed later, add a `dependencies` field to frontmatter. |
| **Automatic skill updates on `baton init`** | Dangerous — could break a working project. Updates should be explicit (`baton marketplace update`). |
| **Monetization / paid skills** | Out of scope. If needed, implement at the registry level (private registries), not in the CLI. |
| **Rating / review system** | Requires server infrastructure. Use GitHub stars as a proxy initially. |

## 批注区
