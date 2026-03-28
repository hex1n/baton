# Execution Plan: Baton Skill Marketplace

**Planning depth**: Deep -- multiple viable approaches, convention-heavy problem space, significant architectural expansion.

**Input sources**: User request (conversation) + codebase analysis (setup.sh, junction.sh, phase-guide.sh, manifest.conf, SKILL.md files, constitution.md)

---

## Problem

Baton's skill ecosystem is closed-loop: skills can only come from the core baton repo and are distributed via a single-source junction mechanism from `~/.baton/`. Users who create useful skills have no standard way to share them, and users who want new capabilities have no way to discover or install third-party skills. This limits baton's ecosystem value to what one maintainer can produce.

Solved = users can discover, install, update, and publish skills from multiple independent authors, using a CLI workflow that fits baton's pure-bash philosophy.

## Key Insight

**A Git repo IS a registry, and `git clone` IS a package manager.** The assumption that a "marketplace" requires a hosted server, database, or web application is a convention, not a constraint. Baton already depends on git (`setup.sh` clones via git). The entire marketplace can be built as a thin bash CLI layer over git operations + a catalog file in a git repo. No infrastructure to host or maintain.

Second insight: **`~/.baton/` as the single skill source is a convention, not a requirement.** `phase-guide.sh` already scans all IDE skill directories independently (`.baton/skills/`, `.claude/skills/`, `.cursor/skills/`, `.agents/skills/`). Community skills can live in a separate location (`~/.baton/community-skills/`) and be junctioned to projects alongside core skills, without changing the discovery mechanism.

## Approach

**Hybrid Git Index + Direct URL Install** -- a layered architecture where each layer delivers standalone value:

1. **Layer 1 (direct install)**: `baton skill install <git-url>` clones a skill repo into `~/.baton/community-skills/<name>/` and creates junctions to the current project. Immediately useful, no registry needed.

2. **Layer 2 (index search)**: An index git repo (e.g., `hex1n/baton-skill-index`) contains a catalog file mapping skill names to git URLs, descriptions, and metadata. `baton skill search <keyword>` searches this catalog. Publishing = PR to add an entry.

3. **Layer 3 (multi-index)**: Users can add custom index sources ("taps") for corporate or community indexes. `baton skill tap add <index-url>`.

## Steps

### Step 1: Define the Skill Package Convention -- why this comes first: everything else depends on the contract

Establish what a "publishable skill" looks like. This is the API contract between authors and the install system.

**Deliverables**:
- A skill package is a git repo (or subdirectory of a git repo) containing:
  - `SKILL.md` with standard frontmatter (name, description, version, author, license)
  - Optional supporting files (templates, review prompts, etc.)
  - Optional `skill.conf` with metadata the index needs (categories, tags, baton-version-min)
- Add `version` and `author` to the SKILL.md frontmatter spec
- Document the convention in a `docs/skill-authoring.md`

**Success criteria**: An existing baton skill (e.g., `baton-research`) passes the convention validation, demonstrating backward compatibility.

**Dependencies**: None.

### Step 2: Build `baton skill` CLI -- why second: this is the core user interface

Create a bash CLI entry point for skill management operations.

**Deliverables**:
- `baton` CLI wrapper (or extend existing mechanisms) supporting:
  - `baton skill install <git-url> [--name <name>]` -- clone to `~/.baton/community-skills/<name>/`, create junctions
  - `baton skill remove <name>` -- remove junctions + source
  - `baton skill list` -- show installed community skills with source info
  - `baton skill update [<name>|--all]` -- git pull in community skill dirs
  - `baton skill link <name>` -- (re)create junctions for a skill in the current project
- Implementation in `~/.baton/bin/baton` or `.baton/cli/skill.sh`
- Uses `junction.sh`'s `atomic_junction()` for cross-platform linking

**Success criteria**: `baton skill install https://github.com/someone/my-skill.git` results in the skill appearing in `baton skill list` and being usable in the current project via `/<skill-name>`.

**Dependencies**: Step 1 (package convention).

### Step 3: Integrate community skills into setup.sh and phase-guide.sh -- why third: makes installed skills persistent across sessions

Modify the existing distribution machinery to handle community skills.

**Deliverables**:
- `setup.sh` gains a `create_community_skill_junctions()` function that mirrors `create_skill_junctions()` but sources from `~/.baton/community-skills/`
- `phase-guide.sh` auto-junction logic (lines 51-67) extended to also scan `~/.baton/community-skills/` for skills to auto-link
- `.gitignore` generation updated to include community skill junction paths
- Community skills are discovered by the existing `_scan_all_skills()` -- no changes needed there since it scans IDE skill dirs, not the source

**Success criteria**: After running `baton skill install <url>` in project A, running `bash setup.sh` in project B also makes the skill available. `phase-guide.sh` auto-creates junctions for community skills at SessionStart.

**Dependencies**: Step 2 (CLI creates the community-skills directory structure).

### Step 4: Build the skill index -- why fourth: useful only after install mechanism works

Create the registry as a git repo with a searchable catalog.

**Deliverables**:
- Git repo `baton-skill-index` containing:
  - `index.tsv` or `index.conf`: one line per skill with fields: `name`, `git-url`, `description`, `author`, `tags`, `baton-version-min`
  - `README.md` with contribution instructions (how to add your skill)
  - CI validation: check that each listed repo exists and contains valid SKILL.md
- `baton skill search <keyword>` searches the local cached copy of the index
  - First run: `git clone --depth 1` the index repo to `~/.baton/cache/skill-index/`
  - Subsequent: `git pull --ff-only` if cache is older than 24h
  - Search: grep through `index.tsv` matching keyword against name, description, tags
- `baton skill install <name>` (without URL) resolves name via index, then delegates to URL install

**Success criteria**: `baton skill search "debug"` returns matching skills from the index. `baton skill install cool-debugger` resolves from the index and installs.

**Dependencies**: Step 2 (CLI), external: create and seed the index repo.

### Step 5: Add multi-index support ("taps") -- why fifth: extends the model for corporate/community use

Allow users to register additional index sources.

**Deliverables**:
- `baton skill tap add <index-git-url> [--name <tap-name>]` -- clones index to `~/.baton/cache/taps/<name>/`
- `baton skill tap remove <tap-name>`
- `baton skill tap list`
- Search and name resolution scan all taps (official + custom)
- Tap config stored in `~/.baton/config/taps.conf`

**Success criteria**: A corporate team can host their own skill index at an internal git URL, `baton skill tap add` it, and `baton skill search` returns skills from both the official and corporate indexes.

**Dependencies**: Step 4 (index mechanism).

### Step 6: Publish workflow -- why last: only meaningful once the ecosystem exists

Make it trivial for skill authors to publish.

**Deliverables**:
- `baton skill publish` -- validates the current directory against the skill package convention, outputs the line to add to an index, optionally opens a PR against the official index
- `baton skill validate` -- checks SKILL.md frontmatter, required fields, file structure
- Template: `baton skill new <name>` -- scaffolds a new skill directory with SKILL.md template

**Success criteria**: A skill author can run `baton skill new my-skill`, edit it, and run `baton skill publish` to submit to the index.

**Dependencies**: Steps 1, 4.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| Cold-start: index is empty, no skills to discover | Low adoption | High (initially) | Seed index with existing baton skills + extract any reusable skills from the core repo. Layer 1 (direct URL install) works without the index. |
| Security: malicious SKILL.md could inject prompt attacks | AI behavior compromise | Medium | Skills are markdown (no code execution). SKILL.md is loaded as context, same as any project file. Document the trust model: install = trust. Official index has review process. |
| Naming conflicts: two skills with the same name in different taps | Install confusion | Medium | Namespace by tap: `baton skill install tap-name/skill-name`. Official index has unique-name requirement. |
| Complexity creep: CLI grows beyond bash's comfort zone | Maintenance burden | Medium | Keep each subcommand in a separate script file. If complexity exceeds bash's strengths, that's a signal to consider a compiled CLI (future, not now). |
| Cross-platform junction issues with community skills | Install failures on some platforms | Low | Already solved: `junction.sh` handles Windows/macOS/Linux with fallback to copy. Community skills use the same mechanism. |
| Git dependency: users without git can't install | Broken for some users | Very Low | Git is already required by setup.sh. Document this as a hard dependency. |

## Success Criteria

1. A user can install a third-party skill from a git URL with one command and use it immediately
2. A user can search for skills by keyword and install by name
3. Installed skills persist across projects (via setup.sh) and sessions (via phase-guide.sh auto-junction)
4. A skill author can publish a skill by creating a git repo and submitting to the index
5. The entire system is implemented in bash + markdown with no new compiled dependencies
6. Existing baton installations are unaffected (backward compatible)

## What We're Deliberately NOT Doing

| Rejected Approach | Why |
|---|---|
| **Hosted server/API** | Violates pure-bash philosophy, requires ongoing infrastructure, single point of failure. Git repos provide equivalent functionality with zero operational burden. |
| **Web UI for browsing** | Premature. CLI-first matches baton's audience. A static site can be generated from the index later if needed -- but it's a nice-to-have, not a requirement. |
| **Monorepo community skills** | Doesn't scale. Bottlenecks on maintainer. All-or-nothing installation. Doesn't enable independent authors. |
| **npm/pip-style version resolution** | Over-engineering. Skills are markdown with no code dependencies. Git tags provide version pinning when needed. Complex dependency resolution is solving a problem that doesn't exist yet. |
| **Ratings/reviews system** | Requires server-side state. Start with GitHub stars as the organic quality signal. Add curated "featured" skills to the index later. |
| **Automatic skill updates** | Dangerous -- a skill update could change AI behavior unexpectedly. Updates should be explicit (`baton skill update`), never silent. |

---

## 批注区
