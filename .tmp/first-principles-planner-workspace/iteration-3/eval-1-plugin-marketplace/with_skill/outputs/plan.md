# Execution Plan: Baton Plugin Marketplace

**Depth**: Deep -- This is a "we've always done it this way" situation. Skills distribution via junction is a convention inherited from the single-maintainer era. The marketplace concept challenges the entire distribution model, so the assumption audit is central.

**Input sources**: Codebase exploration of `setup.sh`, `junction.sh`, `phase-guide.sh`, `dispatch.sh`, `manifest.conf`, `bin/baton`, `install.sh`, skill directory structures (`.baton/skills/`, `.claude/skills/`).

## TL;DR

The real problem is not "how to build a marketplace" -- it's that baton's skill distribution is a closed loop: skills propagate only through the baton git repo, and there's no mechanism for independent authoring, discovery, or versioning. A marketplace is one solution category; the root problem is **skill portability**. The recommended approach is a git-native registry (a curated index file + `baton skill install <repo>#<skill>` CLI) that clones skill repos into `~/.baton/skills/community/` and junctions them alongside built-in skills. This preserves baton's "pure bash + markdown, zero compiled dependencies" constraint while enabling sharing with minimal new infrastructure.

## Action Plan

| Priority | Step | Effort | Success Criteria |
|----------|------|--------|------------------|
| P1 | Define skill packaging spec (SKILL.md frontmatter + directory conventions) | 2h | Any skill directory with valid SKILL.md is installable without modification |
| P2 | Implement `baton skill install <source>` CLI command | 4h | `baton skill install https://github.com/user/my-skill.git` clones into `~/.baton/skills/community/<name>/` and junctions to current project |
| P3 | Implement `baton skill list` and `baton skill remove` | 2h | Users can see installed skills (built-in vs community) and cleanly remove community skills |
| P4 | Create registry index (curated list of known skills) | 2h | `baton skill search <keyword>` returns matches from index; `baton skill install <shortname>` resolves to git URL |
| P5 | Add skill validation hook (lint on install) | 2h | Malformed skills (missing SKILL.md, invalid frontmatter) are rejected with clear error |
| P6 | Versioning support (git tags/branches) | 3h | `baton skill install repo#v1.2` or `repo#branch` pins to specific version; `baton skill update` pulls latest |
| P7 | Publishing workflow (`baton skill publish`) | 3h | Submits a PR to the registry index repo with skill metadata |

### P1: Skill Packaging Spec

A skill is already well-defined in baton: a directory containing `SKILL.md` with YAML frontmatter. The packaging spec formalizes this and adds optional fields for marketplace use.

```markdown
# Required (already exists):
---
name: my-skill
description: >
  What this skill does...
user-invocable: true
---

# New optional fields for marketplace:
---
name: my-skill
description: ...
user-invocable: true
version: 1.0.0              # semver, derived from git tag if absent
author: github-username
license: MIT
tags: [research, planning]
min-baton-version: 4.0       # compatibility gate
---
```

**Key design choice**: The extra fields are optional. Every existing skill is already valid. No migration needed.

**Files**: No new files. This is a convention documented in a README or the spec itself.

### P2: `baton skill install <source>`

Extend `bin/baton` with a `skill` subcommand. The install flow:

```bash
# Usage:
baton skill install https://github.com/user/cool-skill.git
baton skill install cool-skill                  # shortname, resolved via registry
baton skill install ./path/to/local/skill       # local directory

# Mechanism:
# 1. Clone/copy into ~/.baton/skills/community/<name>/
# 2. Validate SKILL.md exists and has required frontmatter
# 3. Junction into current project's IDE skill dirs (reuse existing create_skill_junctions logic)
# 4. Record in ~/.baton/skills/community/installed.list (name|source|version|date)
```

The critical insight: baton already has all the junction machinery in `junction.sh` and `setup.sh:create_skill_junctions()`. The install command is a thin wrapper that:
1. Resolves the source (git URL, shortname, or local path)
2. Puts the skill directory in the right place
3. Calls the existing junction logic

```bash
# In bin/baton, add to the case statement:
skill)
    shift
    _subcmd="${1:-help}"; shift || true
    case "$_subcmd" in
        install)  . "$BATON_HOME/scripts/skill-install.sh" "$@" ;;
        remove)   . "$BATON_HOME/scripts/skill-remove.sh" "$@" ;;
        list)     . "$BATON_HOME/scripts/skill-list.sh" "$@" ;;
        search)   . "$BATON_HOME/scripts/skill-search.sh" "$@" ;;
        update)   . "$BATON_HOME/scripts/skill-update.sh" "$@" ;;
        publish)  . "$BATON_HOME/scripts/skill-publish.sh" "$@" ;;
        *)        echo "Usage: baton skill {install|remove|list|search|update|publish}" ;;
    esac
    ;;
```

```bash
# scripts/skill-install.sh (core logic sketch):
_source="$1"
_version="${2:-}"  # optional: tag, branch, or commit

# Resolve source
case "$_source" in
    http*|git@*)  _type="git" ;;
    */*)          _type="local" ;;
    *)            _type="registry"; _source="$(_resolve_from_registry "$_source")" ;;
esac

# Determine skill name from source
_name="$(basename "$_source" .git)"

# Clone or copy
_dest="$BATON_HOME/skills/community/$_name"
if [ "$_type" = "git" ]; then
    git clone --depth 1 ${_version:+--branch "$_version"} "$_source" "$_dest"
elif [ "$_type" = "local" ]; then
    cp -r "$_source" "$_dest"
fi

# Validate
if [ ! -f "$_dest/SKILL.md" ]; then
    rm -rf "$_dest"
    echo "Error: No SKILL.md found. Not a valid baton skill."
    exit 1
fi

# Junction to current project (reuse existing logic)
. "$BATON_HOME/.baton/hooks/lib/junction.sh"
for _ide_skills in .claude/skills .cursor/skills .agents/skills; do
    [ -d "$_ide_skills" ] || continue
    atomic_junction "$_dest" "$_ide_skills/$_name"
done

# Record
echo "$_name|$_source|${_version:-latest}|$(date +%Y-%m-%d)" >> "$BATON_HOME/skills/community/installed.list"
```

### P3: `baton skill list` / `baton skill remove`

```bash
# skill-list.sh:
echo "Built-in skills:"
for d in "$BATON_HOME/.baton/skills"/*/; do
    [ -f "$d/SKILL.md" ] || continue
    printf "  %-25s (built-in)\n" "$(basename "$d")"
done
echo ""
echo "Community skills:"
if [ -f "$BATON_HOME/skills/community/installed.list" ]; then
    while IFS='|' read -r name source version date; do
        printf "  %-25s %s  [%s]\n" "$name" "$version" "$source"
    done < "$BATON_HOME/skills/community/installed.list"
else
    echo "  (none)"
fi
```

```bash
# skill-remove.sh:
_name="$1"
_dest="$BATON_HOME/skills/community/$_name"
# Remove junctions from current project
for _ide_skills in .claude/skills .cursor/skills .agents/skills; do
    rm -rf "$_ide_skills/$_name" 2>/dev/null
done
# Remove source
rm -rf "$_dest"
# Remove from installed.list
sed -i "/^${_name}|/d" "$BATON_HOME/skills/community/installed.list"
```

### P4: Registry Index

A single `registry.json` (or `registry.tsv` for jq-optional compatibility) hosted in the baton repo itself or a separate `baton-registry` repo:

```
# ~/.baton/registry.tsv (or fetched from github)
# name | git_url | description | tags | min_baton_version
first-principles-planner|https://github.com/hex1n/baton-skill-fpp.git|Strategic planning from first principles|planning,strategy|4.0
deep-research|https://github.com/hex1n/baton-skill-dr.git|Multi-source deep research|research,analysis|4.0
```

**Why TSV over JSON**: baton's design principle is "jq optional (awk fallback)." TSV is trivially parseable with awk/cut, consistent with the existing architecture.

`baton skill search` greps this file. `baton skill install <shortname>` looks up the git URL here.

**Registry update**: `baton skill update --registry` fetches the latest registry.tsv from the upstream URL (curl/wget).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| Malicious skills (arbitrary bash in SKILL.md hooks) | High -- skills can influence AI behavior | Low -- skills are markdown, not executable code | Skills are markdown prompts, not bash scripts. They influence AI behavior but don't execute code directly. Document this distinction. For hooks (if skills ever include them), add a sandboxing/review step. |
| Name collisions (community skill has same name as built-in) | Medium -- junction overwrite | Medium | Namespace community skills: `community/<name>` in junction path, or prefix community skills in the IDE skills dir. Built-in skills always win. |
| Version drift (installed skill diverges from upstream) | Low -- user confusion | High | `installed.list` records source + version. `baton skill update` does a `git pull` in the cloned dir. `baton doctor` checks for stale community skills. |
| Windows compatibility (git clone in Git Bash) | Medium -- broken install on Windows | Low -- git clone works in Git Bash | Use existing baton patterns (cygpath, junction fallback). Test on Windows. |
| Registry goes stale | Low -- outdated skill list | Medium | Registry is a simple file in a git repo -- PRs keep it alive. Local cache with TTL. |

## What We're Deliberately NOT Doing

1. **Not building a web UI or server-side marketplace.** Baton is pure bash + markdown with zero compiled dependencies. A web marketplace would violate this constraint and add operational complexity disproportionate to the user base. The registry file IS the marketplace.

2. **Not using npm/pip/brew-style package managers.** These are compiled dependencies. Baton's distribution model (git clone + junction) is already a package manager -- we're extending it, not replacing it.

3. **Not adding authentication or access control.** Skills are git repos. Git handles auth. Private skills = private repos. No need for a separate auth layer.

4. **Not supporting skill dependencies (skill A requires skill B).** This adds significant complexity (dependency resolution, version compatibility) for a problem that doesn't exist yet. Skills are self-contained markdown. If a skill references another, document it; don't enforce it mechanically.

5. **Not building an auto-update daemon.** `baton skill update` is explicit and user-initiated. Background updates to governance-critical prompts would violate baton's explicit-authorization principle.

## Self-Check

1. **Did I question the problem, or just the solution?**
   Yes. The stated problem was "add a plugin marketplace." Phase 1 analysis identified that the root problem is skill portability (closed distribution loop), not marketplace infrastructure. This shifted the solution from "build a marketplace" to "make skills installable from any source" -- the registry is a convenience layer on top, not the core mechanism.

2. **Did I find any conventions worth breaking?**
   Yes. The convention that all skills live in `.baton/skills/` (the baton source repo) is the core convention being broken. Community skills live in `~/.baton/skills/community/`, separating provenance. The convention that `setup.sh` is the only skill installer is also broken -- `baton skill install` becomes a parallel path. The convention that skills have no version metadata is broken by adding optional frontmatter fields.

3. **Am I recommending the first thing I thought of?**
   No. The first instinct for "plugin marketplace" is a web platform (like VS Code marketplace). Phase 2 analysis considered and rejected this in favor of a git-native approach. Also considered: (a) a centralized monorepo of community skills (rejected: doesn't scale, single point of control), (b) an npm-style package.json approach (rejected: adds compiled dependency), (c) git submodules (rejected: poor UX, complex state management). The git-clone-to-local-dir approach was the third category considered.

4. **Can the user predict what will happen from reading this plan?**
   Yes. Each step specifies the files to create/modify, the CLI commands that will exist, and concrete code sketches for the mechanisms. The user can trace from `baton skill install foo` through to the junction creation.

5. **Would I bet money on this?**
   Yes, with one caveat: P4 (registry) might need iteration on the curation model. A fully open registry can accumulate low-quality skills; a fully curated one bottlenecks on the maintainer. The initial approach (PRs to a registry file) is deliberately simple and can evolve. The weakest link is the registry governance, not the technical mechanism.

---

## Analysis (supporting reasoning)

### Problem Archaeology

#### Five Whys

**Stated**: "I want to add a plugin marketplace so users can share and install skills."

**Why a marketplace?** Users can't currently share skills. If someone writes a useful skill, others can't use it without manually copying files.

**Why can't they share?** Skills are distributed exclusively through the baton git repo. The only installation path is `setup.sh`, which junctions from `~/.baton/.baton/skills/` (which is a clone of the baton repo) into project directories. There's no mechanism to add skills from external sources.

**Why only through the baton repo?** This was a natural design for a single-maintainer project. All skills are authored by the same person, so the repo IS the distribution channel. This is a convention, not a constraint.

**Why does this matter now?** Baton's skill architecture is generic -- any SKILL.md in the right directory works. The format is IDE-agnostic (works across Claude, Cursor, Codex). This makes skills inherently portable, but the distribution model doesn't reflect this. The architecture is ready for sharing; the plumbing isn't.

**Root**: The skill format is portable but the distribution model is not. Skills are locked into a single-source (baton repo) pipeline despite having no technical reason to be.

#### Problem Statement

Baton skills are self-contained markdown artifacts that work across IDEs, but they can only be distributed through the baton git repository. Users who create useful skills have no mechanism to share them, and users who discover useful skills elsewhere have no mechanism to install them into baton's junction-based distribution. This creates a closed ecosystem where skill diversity is limited to one maintainer's output.

**Solved** = A user can install a skill from any git repo (or local path) with a single command, the skill is junctioned into their project like built-in skills, and they can discover available skills through a searchable index. No new runtime dependencies beyond git and bash.

#### Assumption Audit

| # | Assumption | Type | If wrong... |
|---|-----------|------|-------------|
| 1 | Skills must live in `~/.baton/.baton/skills/` | **Convention** -- this is just where `setup.sh` looks. Junction source can be any directory. | Plan survives -- we add a second source directory (`~/.baton/skills/community/`) |
| 2 | Skills are always distributed via the baton repo | **Convention** -- inherited from single-maintainer model. Skills are just directories with SKILL.md. | Plan survives -- this is the convention being broken |
| 3 | `setup.sh` is the only installer | **Convention** -- `baton init` calls `setup.sh`, but junction creation is a simple bash function. Any script can call `atomic_junction`. | Plan survives -- `baton skill install` reuses `junction.sh` directly |
| 4 | A marketplace requires a web server or database | **Convention from other ecosystems** (npm, VS Code). Not a true constraint. | Plan survives -- the registry is a flat file in a git repo |
| 5 | Pure bash + markdown, zero compiled dependencies | **True constraint** -- core architectural principle ✅ verified from CLAUDE.md and codebase inspection. Every tool is bash/awk/sed. jq is optional with awk fallback. | Plan collapses if violated -- all tooling must be bash |
| 6 | Junction-based distribution (NTFS junctions / symlinks / copy fallback) | **True constraint** -- this is how baton gets skills into IDE-specific directories ✅ verified from `junction.sh`, `setup.sh`, `phase-guide.sh`. | Plan must work within this model |
| 7 | Skills have no version metadata | **Convention** -- SKILL.md frontmatter has `name`, `description`, `user-invocable`. No `version` field exists. Adding one is backward-compatible. | Plan survives -- optional field |
| 8 | `phase-guide.sh` auto-junctions skills from `.baton/skills/baton-*` | **Fact** ✅ verified at lines 51-67 of `phase-guide.sh`. Only `baton-*` prefixed skills are auto-junctioned at SessionStart. | Plan must decide: extend the glob or use a different mechanism for community skills. Decision: extend `phase-guide.sh` to also scan `community/`. |

#### True Constraints vs Conventions

**True Constraints** (cannot change):
- Pure bash + markdown, zero compiled dependencies
- Junction/symlink/copy distribution model
- Skills are directories containing SKILL.md
- Must work on Windows (Git Bash), Linux, macOS
- `bin/baton` is the CLI entry point
- git is available (baton itself is distributed via git)

**Conventions** (can change):
- Skills only come from the baton repo --> can come from any git repo
- `setup.sh` is the only skill installer --> `baton skill install` is a parallel path
- No version metadata in SKILL.md --> add optional fields
- `phase-guide.sh` only auto-junctions `baton-*` prefixed skills --> extend to community skills
- No skill discovery mechanism --> add registry index
- Skills have no provenance tracking --> add `installed.list`

### Solution Reconstruction

#### Solution Categories

**Category A: Git-native registry (recommended)**
- **Mechanism**: Skills are git repos. A registry file (TSV) maps shortnames to git URLs. `baton skill install` clones repos into `~/.baton/skills/community/` and junctions them. CLI commands for install/remove/list/search/update.
- **Why it might be best**: Zero new dependencies. Leverages existing git + junction infrastructure. Registry is a simple file, not a service. Fits baton's architectural principles perfectly.
- **Why it might fail**: Registry curation requires maintainer effort. No rating/review system. Discovery limited to text search.
- **Conventions challenged**: Single-source distribution. Skills-only-from-baton-repo.

**Category B: Web marketplace (npm/VS Code style)**
- **Mechanism**: Server-side registry with web UI, API endpoints, search, ratings, downloads. CLI talks to HTTP API.
- **Why it might be best**: Rich discovery. Social proof (ratings, downloads). Familiar UX.
- **Why it might fail**: Requires server infrastructure (violates zero-dependency constraint). Operational burden disproportionate to user base. Authentication complexity. Would be the only non-bash component in baton.
- **Conventions challenged**: Zero-dependency architecture (this challenges a TRUE CONSTRAINT, not a convention).

**Category C: Monorepo (community contributions via PR)**
- **Mechanism**: Single `baton-community-skills` repo. Contributors submit PRs to add skills. Users install by cloning/updating this repo.
- **Why it might be best**: Simple. Centralized quality control. Single `git pull` updates everything.
- **Why it might fail**: Bottleneck on PR review. Doesn't scale. Contributors lose ownership. Forces one repo's conventions on all authors.
- **Conventions challenged**: None significant -- it's the same single-source model with a bigger source.

**Category D: Git submodules**
- **Mechanism**: Skills as git submodules in the baton repo or a community repo.
- **Why it might be best**: Built-in git feature. Version pinning for free.
- **Why it might fail**: Submodules have notoriously bad UX. Require `git submodule update --init`. Break on shallow clones. State management is complex.
- **Conventions challenged**: None -- same model, worse ergonomics.

#### Inversion Tests

**Category A (git-native registry) -- inversion:**
- **Worst approach if**: baton had thousands of users who expect search, ratings, and one-click install. But baton is a niche governance framework for power users. CLI-native is appropriate.
- **Opposite approach**: Fully centralized, web-hosted marketplace with no git involvement. Merit: better discovery UX. But violates core constraint.
- **If it fails, we learn**: The registry file doesn't scale past ~100 skills, or users need richer discovery. Migration path: the registry file format can be consumed by a web frontend later without changing the CLI.

#### Recommendation Chain

1. **Root problem** (Phase 1): Skill distribution is a closed loop tied to the baton repo.
2. **True constraints**: Pure bash, junction-based, git-available, cross-platform.
3. **Category A** satisfies all true constraints by using git (already required) as the transport and a flat file as the registry (parseable with awk, no jq required).
4. **Convention broken**: Skills can come from anywhere, not just the baton repo. This is acceptable because the skill format was always portable -- only the distribution wasn't.
5. **Primary risk**: Registry curation. Mitigated by starting with a curated list (maintainer-approved PRs) and evolving the model as the community grows.
6. **Dissenting path**: If you still want a web marketplace, the registry TSV can serve as the backend data source for a future web UI. The CLI and data model proposed here are compatible with a web layer on top. Build the plumbing first.
