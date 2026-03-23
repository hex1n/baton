# First-Principles Planner Transcript: Baton Plugin Marketplace

**Depth**: Deep -- multiple viable approaches, "we've always done it this way" energy around junction-based distribution, and the problem sits at the intersection of distribution, discovery, trust, and versioning.

**Input sources**: Conversation context + codebase analysis (setup.sh, junction.sh, phase-guide.sh, manifest.conf, SKILL.md format, constitution.md)

---

## Phase 0: Input Synthesis

**What the user wants**: A plugin marketplace for baton that lets users share and install skills.

**Current state** (verified from codebase):
- Skills are markdown directories containing `SKILL.md` (plus optional supporting files like `review-prompt.md`, templates) ✅ read .baton/skills/*/SKILL.md
- Distribution uses `~/.baton/` as the single source of truth. Projects reference it via NTFS junctions (Windows) or symlinks (Unix). ✅ read junction.sh, setup.sh
- `setup.sh` handles installation: clones baton repo to `~/.baton/`, creates junctions from `~/.baton/.baton/skills/<name>` to project `.<ide>/skills/<name>` ✅ read setup.sh
- `phase-guide.sh` auto-creates missing skill junctions at SessionStart ✅ read phase-guide.sh:51-67
- Skills are discovered by scanning `.<ide>/skills/*/SKILL.md` across `.baton`, `.claude`, `.cursor`, `.agents` directories ✅ read phase-guide.sh:72-83
- Baton is pure bash + markdown, zero compiled dependencies, jq optional ✅ read CLAUDE.md
- Skills have frontmatter (name, description, user-invocable, etc.) ✅ read multiple SKILL.md files
- There is no versioning, dependency management, or registry infrastructure currently

**What they've implied**:
- The current junction model is "local only" -- you get what's in the baton repo, nothing else
- They want a way for the community to create, publish, and consume skills
- This is a significant architectural expansion

**Constraints mentioned**:
- Pure bash + markdown philosophy
- Junction-based distribution is the current mechanism
- No compiled dependencies

---

## Phase 1: Problem Archaeology

### 1.1 -- The Five Whys

**Stated**: "I want to add a plugin marketplace so users can share and install skills."

**Why?** Users can only use skills that ship with baton or that they manually create. There's no way to discover or install third-party skills.

**Why is that a problem?** Baton's value scales with the quality and variety of its skills. A solo maintainer can't produce skills for every workflow. Community contribution is bottlenecked by the absence of a distribution mechanism.

**Why can't users just copy SKILL.md files around?** They technically can, but:
1. No discovery -- how do you find skills that exist?
2. No trust -- how do you know a skill is safe/quality?
3. No versioning -- how do you update a skill?
4. No dependency management -- some skills reference other files
5. No standardized structure -- manual copying is error-prone

**Root**: The real problem is that baton's skill ecosystem is closed-loop. The distribution architecture assumes a single source (the baton repo) and has no mechanism for multiple independent skill authors to publish, discover, and install skills into the same junction-based distribution system.

### 1.2 -- Problem Statement

Baton's skill ecosystem is limited to what ships in the core repo. Users who create useful skills have no standard way to share them, and users who want new capabilities have no way to discover or install third-party skills. This limits baton's value to what one maintainer can produce.

**Solved** = Users can discover skills created by others, install them into their baton environment with a single command, receive updates, and optionally publish their own skills -- all within baton's pure-bash philosophy.

---

## Phase 2: Assumption Audit

### 2.1 -- Surface Assumptions

| # | Assumption | Source | Type |
|---|-----------|--------|------|
| 1 | A "marketplace" implies a centralized registry/server | user's framing | convention |
| 2 | Skills must be distributed via junctions from ~/.baton/ | current architecture | convention |
| 3 | Skills are always single directories with SKILL.md | current architecture | fact |
| 4 | No compiled dependencies allowed | stated constraint | fact (user can override) |
| 5 | Pure bash + markdown is a hard constraint | stated constraint | convention (strong) |
| 6 | Skills need a trust/quality model | inferred | convention |
| 7 | The unit of distribution is a skill directory | current architecture | convention |
| 8 | ~/.baton/ is the single source for all projects | current architecture | convention |
| 9 | Users need a web UI to browse/discover skills | implied by "marketplace" | convention |
| 10 | Versioning requires semver/tags | common industry practice | convention |
| 11 | A registry requires a database or API server | common industry practice | convention |
| 12 | Skills have no inter-skill dependencies | current architecture | fact (currently) |
| 13 | Git is available on all target systems | current architecture (setup.sh uses git clone) | fact |

### 2.2 -- Challenge Each One

**#1 "Marketplace implies centralized registry/server"**
- Type: convention. A marketplace is a discovery + distribution mechanism. Git repos, GitHub topics, or even a curated list in a markdown file can serve as a registry. npm started as just a directory.
- If wrong: we don't need to build/host infrastructure, which dramatically simplifies
- Load-bearing? No. The problem is discovery + install, not "build a server."

**#2 "Skills must be distributed via junctions from ~/.baton/"**
- Type: convention. Junctions are the current mechanism but not the only one. Skills could be installed directly into project directories, or into ~/.baton/community-skills/, or into a separate path.
- If wrong: opens up per-project skill installation without touching ~/.baton/
- Load-bearing? Partially. The phase-guide.sh auto-junction logic assumes .baton/skills/ as the source. But it already scans all IDE skill dirs independently.

**#3 "Skills are always single directories with SKILL.md"**
- Type: fact. ✅ Verified across all skills in the codebase. This is the contract.
- Load-bearing: Yes. This defines the unit of distribution.

**#4 "No compiled dependencies"**
- Type: strong convention. Could use curl, git, tar -- all commonly available.
- Load-bearing: Yes, but the tool chain (bash, git, curl) is already implicitly required.

**#5 "Pure bash + markdown"**
- Type: strong convention / design principle. Breaking this would fundamentally change baton's character.
- Load-bearing: Yes. This rules out Python/Node registry servers, compiled CLIs, etc.

**#8 "~/.baton/ is the single source for all projects"**
- Type: convention. Currently true but not mechanically required. phase-guide.sh scans project-level skill dirs. A skill installed directly into .claude/skills/ would be discovered.
- If wrong: skills could live in multiple locations, with ~/.baton/ being just one source.
- Load-bearing? No. The scan logic already handles multiple sources.

**#9 "Users need a web UI to browse"**
- Type: convention. CLI search + a GitHub-hosted catalog could work. Many developer tools (brew, apt, cargo) are CLI-first.
- Load-bearing? No. CLI-first is more aligned with baton's philosophy.

**#11 "A registry requires a database or API server"**
- Type: convention. A git repo with a manifest file IS a registry. Homebrew's "tap" model proves this.
- If wrong: no infrastructure to host/maintain. Dramatic simplification.
- Load-bearing? No.

### 2.3 -- True Constraints vs Conventions

**True Constraints**:
1. Skills are directories containing SKILL.md (structural contract)
2. Pure bash + markdown, no compiled dependencies (design principle -- user can override but default position)
3. Git is available (already required by setup.sh)
4. Must work on Windows (Git Bash), macOS, and Linux
5. Must not break existing junction-based distribution for core skills
6. Must not require infrastructure that the maintainer has to operate 24/7

**Conventions Worth Breaking**:
1. **"Marketplace = centralized server"** -- use Git repos as the registry, like Homebrew taps
2. **"~/.baton/ is the only source"** -- allow per-project and per-user skill installation from multiple sources
3. **"All skills come from the baton repo"** -- decouple skill authoring from the core repo
4. **"Discovery needs a UI"** -- CLI-first discovery with optional GitHub-based browsing
5. **"Versioning needs semver"** -- git commits/tags ARE versions; no need for a separate versioning layer

---

## Phase 3: Solution Reconstruction

Working with:
- Root problem: closed-loop skill ecosystem, no multi-author distribution
- True constraints: bash+markdown, cross-platform, no hosted infrastructure, git available
- Wider solution space: no server needed, git-as-registry, multi-source skills

### 3.1 -- Solution Categories

#### Category A: Git-as-Registry (Homebrew Tap Model)

**Mechanism**: Skills are published as Git repos (or directories within repos). A "registry" is itself a Git repo containing a catalog (index file mapping skill names to repo URLs). `baton skill install <name>` clones/copies the skill into `~/.baton/community-skills/<name>/` and creates junctions to projects. `baton skill search <keyword>` searches the index.

**Why it might be best**:
- Zero infrastructure. The registry is a Git repo (e.g., `hex1n/baton-skills-index`).
- Familiar model (Homebrew, Vim plugins).
- Versioning is free (git tags/branches).
- Fully bash-implementable.
- Publishing = submitting a PR to add an entry to the index, or self-hosting your own index repo.

**Why it might fail**:
- Discovery is limited to what's in the index (cold start problem).
- No built-in quality/trust signal beyond "it's in the index."
- Git clone per skill could be slow for many small skills.

**Conventions challenged**: No server, no database, no web UI needed.

#### Category B: GitHub API-Based Discovery

**Mechanism**: Skills are published as GitHub repos with a specific topic tag (e.g., `baton-skill`). `baton skill search` uses the GitHub API to find repos with that tag. Installation clones the repo. No separate registry needed.

**Why it might be best**:
- Truly decentralized. No index to maintain.
- Publishing = creating a repo and adding a topic.
- GitHub stars/activity provide organic quality signals.

**Why it might fail**:
- Requires internet + GitHub API access.
- Rate limits on unauthenticated GitHub API (60/hour).
- Tightly coupled to GitHub (not GitLab, Codeberg, etc.).
- Search quality depends on GitHub's topic search.
- Requires curl + JSON parsing (jq or awk fallback).

**Conventions challenged**: No registry at all.

#### Category C: Monorepo Community Skills

**Mechanism**: Community skills live in the baton repo itself, in a `community-skills/` directory. Contribution = PR to the baton repo. Installation = they're already there after setup.

**Why it might be best**:
- Simplest possible model.
- Quality control via PR review.
- Already distributed via the existing junction mechanism.

**Why it might fail**:
- Scales poorly. Baton repo grows with every contribution.
- Bottleneck on maintainer for PR review.
- All-or-nothing: users get every community skill, can't pick.
- Doesn't enable independent skill authors.
- Doesn't solve the "marketplace" aspect at all.

**Conventions challenged**: None (this is the status quo extended).

#### Category D: Hybrid -- Git Index + Direct URL Install

**Mechanism**: Combines A and B. A lightweight index repo provides curated/verified skills. But `baton skill install <git-url>` also works directly for any git repo. The index is a convenience, not a requirement. Users can also add custom index sources ("taps").

**Why it might be best**:
- Best of both worlds: curated discovery + open installation.
- Index repo is optional, not a single point of failure.
- Multiple indexes can coexist (official, community, corporate).
- Direct URL install enables zero-friction publishing.

**Why it might fail**:
- More complex to implement than A alone.
- Multiple indexes could lead to naming conflicts.
- Trust model is weaker for direct URL installs.

**Conventions challenged**: All of category A, plus "one registry" convention.

### 3.2 -- Inversion Test

#### Category A (Git-as-Registry) -- primary candidate:

**What would make this the worst approach?**
- If the cold-start problem never gets solved (index stays empty). Mitigated by seeding with baton's own skills and making publishing trivially easy.
- If users expect a web UI with screenshots, ratings, reviews. Mitigated by keeping expectations CLI-first and optionally generating a static site from the index.

**Opposite approach**: Category B (no index at all, pure API discovery). Merit: eliminates the index maintenance burden. But loses curation and offline capability. **Verdict**: the index is lightweight enough that its benefits outweigh the burden.

**If this fails, what do we learn?** That the baton community is too small for a skill ecosystem, and the problem should be solved by growing the core skill set instead. This is valuable information -- it means marketplace infrastructure was premature.

#### Category D (Hybrid) -- enhanced candidate:

**What would make this worst?** Over-engineering. If 90% of installs are direct URL and nobody uses the index, the index is dead weight. **Mitigated by**: making the index genuinely useful (search, categories, verified badges) and making direct URL the fallback, not the primary path.

### 3.3 -- Recommendation

**Recommended approach: Category D (Hybrid -- Git Index + Direct URL Install)**

Reasoning chain:
- **Root problem** (Phase 1): closed-loop ecosystem needs multi-author distribution
- **True constraint satisfaction** (Phase 2): pure bash, no hosted infrastructure, cross-platform, git-based
- **Convention deliberately broken**: "marketplace = server" -- we use a git repo as registry. "Single source" -- we allow ~/.baton/community-skills/ as a second source alongside ~/.baton/.baton/skills/
- **Primary risk**: over-engineering for a small community. **Mitigation**: implement in layers -- direct URL install first (useful immediately), then index search (useful when there are skills to discover). Each layer delivers standalone value.

The critical design insight from Phase 2 is: **a Git repo IS a database, and git clone IS a package manager**. Baton doesn't need to reinvent package management -- it needs a thin CLI layer over git operations, plus a convention for how skills are published.

---

## Phase 4: Plan Synthesis

(See plan.md for the formatted output)

---

## Self-Check

1. **Did I question the problem, or just the solution?** Yes -- Phase 1 identified that "marketplace" is one solution to the root problem of "closed-loop ecosystem." The plan addresses the root problem, not just the stated solution.

2. **Did I find conventions worth breaking?** Yes -- three significant ones: "marketplace = server," "single source for all skills," and "discovery needs a UI." Each removal widened the solution space.

3. **Am I recommending the first thing I thought of?** No. Four fundamentally different categories were evaluated. Category C (monorepo) was the obvious first thought and was rejected for clear reasons. The hybrid approach emerged from combining the strengths of A and B.

4. **Can the user predict what will happen from reading this plan?** Yes -- the steps describe concrete artifacts (CLI commands, directory structures, file formats) with success criteria.

5. **Would I bet money on this?** On the architecture: yes. On adoption: uncertain -- depends on community size. But the layered implementation means each step delivers value independently, so even partial execution is useful.
