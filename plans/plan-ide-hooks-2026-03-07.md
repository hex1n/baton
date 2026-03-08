# Plan: Align Baton IDE Capability Modeling With 2026-03-07 Hook Research

## References

- Primary research: `research-ide-hooks-2026-03-07.md:17-79`
- Capability matrix: `docs/ide-capability-matrix.md:11-32`
- Current public-facing support table: `README.md:112-137`
- Current installer capability labels: `setup.sh:280-292`
- Current Kiro/Amazon Q implementation surface: `setup.sh:861-888`
- Current Roo handling: `setup.sh:961-966`

## Problem Statement

The latest research shows Baton's broad direction is mostly correct, but three capability boundaries are still blurred:

1. `Cursor IDE` and `Cursor CLI` do not have the same hook surface. The research confirms IDE hooks exist, while Cursor CLI currently has only partial hook parity (`research-ide-hooks-2026-03-07.md:23-24`, `:46-50`).
2. `Kiro` and `Amazon Q Developer CLI` both support hooks, but they now expose materially different hook models. Baton still routes `kiro` through the shared `.amazonq/` surface (`research-ide-hooks-2026-03-07.md:27-28`, `:52-56`, `setup.sh:861-866`).
3. `Roo Code` remains unverified for current official hook support. Baton is correct to keep it conservative for now (`research-ide-hooks-2026-03-07.md:33`, `:69-73`, `setup.sh:961-966`).

The plan needs to reduce capability drift without breaking current installs or overfitting to uncertain surfaces.

## Constraints

- Baton must not overstate official hook support in user-facing docs or installer prompts. The new matrix is the current source of truth (`docs/ide-capability-matrix.md:11-25`).
- Existing installs that use `cursor`, `kiro`, and `.amazonq/` must keep working. Abrupt target renames would create migration churn (`setup.sh:861-888`).
- `Codex` and `Zed` should remain in the rules-guidance bucket unless stronger primary evidence appears (`research-ide-hooks-2026-03-07.md:31-32`, `:58-67`).
- `Roo Code` should stay conservative until Baton has a current official hook integration target (`docs/ide-capability-matrix.md:25-32`).

## Approaches Considered

### Approach A: Docs-Only Alignment

Update only `README`, research docs, and installer wording; keep the internal target model unchanged.

- Feasibility: `✅`
- Pros:
  - Lowest migration risk
  - Fastest to ship
- Cons:
  - Leaves the `kiro -> .amazonq` conflation in the actual installer
  - Leaves no structured place to encode capability boundaries beyond prose
  - Future feature work can regress back into the same confusion

### Approach B: Staged Capability Alignment

Keep current installer targets working, but introduce a single capability model and progressively separate product surfaces where the research justifies it.

- Feasibility: `✅`
- Pros:
  - Preserves backward compatibility
  - Creates one source of truth for docs, prompts, and installer behavior
  - Lets Baton separate `Kiro` and `Amazon Q Developer CLI` incrementally instead of via a breaking rename
- Cons:
  - Requires touching docs, installer logic, and tests together
  - Adds some temporary duplication while aliases remain supported

### Approach C: Immediate Full Product Split

Immediately split `cursor-ide`, `cursor-cli`, `kiro`, `amazonq`, and potentially `roo` into distinct installer targets.

- Feasibility: `⚠️`
- Pros:
  - Maximum conceptual clarity
- Cons:
  - Not justified by current Baton install surfaces
  - `Roo Code` evidence is still weak
  - Would create avoidable migration and UX complexity before the capability model is stabilized

## Recommendation

Recommend **Approach B: staged capability alignment**.

Reasoning:

- The research is strong enough to justify separating capability semantics for `Cursor IDE` vs `Cursor CLI`, and `Kiro` vs `Amazon Q Developer CLI` (`research-ide-hooks-2026-03-07.md:46-56`).
- The research is **not** strong enough to justify a hook-based Baton integration for `Roo Code` yet (`research-ide-hooks-2026-03-07.md:69-73`).
- Baton already has working installs on the current surfaces. The right move is to add a stable capability layer first, then split installer targets where the current shared surface is clearly misleading.

## Recommended Immediate Scope

If the goal is to improve Baton now with minimal migration risk, the recommended implementation scope is:

1. **Do not add a first-class `amazonq` installer target yet.**
   Keep `kiro` as the user-facing selection and document it as the current `.amazonq/` compatibility surface.
2. **Do not add a separate `cursor-cli` installer target yet.**
   Keep `cursor` meaning `Cursor IDE`, and document Cursor CLI as out-of-scope / partial for now.
3. **Do not promote Roo Code into a hook bucket.**
   Keep `roo` in rules-guidance mode until Baton has a current official hook target to implement against.
4. **Do add a capability-source-of-truth rule plus consistency checks.**
   This is the lowest-risk change that prevents the same drift from recurring.

This gives Baton a clear v1 boundary:

- `cursor` = Cursor IDE
- `kiro` = current `.amazonq/` integration surface
- `amazonq` = documented concept, not yet an installer target
- `roo` = rules-guidance only

Approved scope note for this iteration:

- Do not add new Baton work targeting `Amazon Q Developer CLI`
- Do not add new Baton work targeting `Cursor CLI`
- Do not change `Roo Code` integration beyond keeping its current conservative stance documented

## Proposed Changes

### Phase 1: Establish a Single Capability Source of Truth

Create or adopt one canonical capability table that Baton code and docs should follow.

- Keep `docs/ide-capability-matrix.md` as the authoritative matrix for:
  - official hook support
  - Baton installer target
  - Baton protection bucket
  - uncertainty level
- Add a short maintenance rule in docs: any change to supported IDE behavior must update this matrix first

Why:

- Today the same claim is spread across `README`, `setup.sh`, and historical research docs (`README.md:112-137`, `setup.sh:280-292`, `docs/research-ide-hooks.md:1-8`).
- A single capability source reduces drift between research and product messaging.

### Phase 2: Separate Product Semantics From Installer Aliases

Keep the current CLI flags working, but make the model explicit.

- Keep `cursor` as the installer target, but document and treat it as `Cursor IDE`
- Keep `kiro` as a backward-compatible alias for the current `.amazonq/` integration surface
- Add an explicit `amazonq` concept to docs and capability modeling, even if installer support initially remains aliased or pending
- Keep `roo` in rules-guidance mode until Baton has a verified hook target

Why:

- The research shows `Cursor CLI` should not be implicitly covered by the current `cursor` bucket (`research-ide-hooks-2026-03-07.md:23-24`, `:46-50`).
- The research shows `Kiro` and `Amazon Q Developer CLI` are no longer safely representable as one hook platform (`research-ide-hooks-2026-03-07.md:27-28`, `:52-56`).

### Phase 3: Refactor Installer Terminology and Capability Checks

Adjust `setup.sh` so its UI and internal comments match the matrix.

- Replace vague product summaries with matrix-aligned wording
- Make comments explicitly say when Baton is modeling a shared config surface rather than a true product-equivalent target
- If Baton adds a future `amazonq` installer target, preserve `kiro` as an alias during migration

Why:

- `setup.sh` is user-facing product surface, not just plumbing (`setup.sh:280-292`).
- Current wording already improved, but still encodes the `.amazonq` compromise as implementation detail rather than deliberate compatibility behavior (`setup.sh:861-866`).

### Phase 4: Test the Capability Boundaries Explicitly

Add or tighten tests around the newly clarified semantics.

- Assert `cursor` wording maps to `Cursor IDE`
- Add tests for `kiro` alias behavior if/when `amazonq` becomes a first-class target
- Keep `roo` rules-only tests and make the “hooks unverified” stance explicit in docs/tests
- Add a docs consistency check if feasible: supported-IDE wording in `README` vs capability matrix

Why:

- The risky failure mode here is not code execution; it is documentation and UX drift.
- Tests should catch future regressions back to “Kiro/Amazon Q are the same” or “Cursor means all Cursor surfaces”.

## Impact Scope

Expected files:

- `README.md`
- `setup.sh`
- `docs/ide-capability-matrix.md`
- `docs/research-ide-hooks.md`
- `tests/test-setup.sh`
- `tests/test-multi-ide.sh`

Potential follow-up files if installer targets are split:

- additional docs under `docs/`
- migration notes in `README.md`

## Risks And Mitigations

### Risk 1: Breaking Existing `kiro` / `.amazonq` Installs

- Risk: renaming the target too early could break current projects or user muscle memory
- Mitigation: keep `kiro` as an alias; if `amazonq` is introduced, migrate gradually and preserve `.amazonq/` compatibility first

### Risk 2: Over-modeling Unstable or Under-documented Surfaces

- Risk: introducing `cursor-cli` or `roo` as first-class Baton targets without enough primary evidence
- Mitigation: keep those as documentation distinctions first; do not add installer targets until official integration surfaces are stable

### Risk 3: Capability Drift Between Docs And Installer

- Risk: future changes update `README` or `setup.sh` but not both
- Mitigation: treat `docs/ide-capability-matrix.md` as the required update point and add consistency checks where practical

## Verification Plan

1. Run `sh -n setup.sh`
2. Run `bash tests/test-setup.sh`
3. Run `bash tests/test-multi-ide.sh`
4. Manually verify installer output for:
   - `--choose` menu wording
   - `--ide cursor`
   - `--ide kiro`
   - `--ide codex`
5. Review `README.md` and `docs/ide-capability-matrix.md` side-by-side to confirm the same bucketing
6. If docs consistency checks are added, run them and verify failure messages point to the mismatched source file

## Todo

- [x] 1. Change: add a matrix-first maintenance rule and approved-scope note so future IDE capability updates must start from the canonical matrix and explicitly exclude new `Amazon Q Developer CLI` / `Cursor CLI` / `Roo Code` integration work in this iteration | Files: docs/ide-capability-matrix.md, README.md, docs/research-ide-hooks.md | Verify: manual doc review confirms the same scope/bucketing language appears in all three docs | Deps: none | Artifacts: none
- [x] 2. Change: tighten installer-facing wording so the chooser/help text continues to mean `cursor = Cursor IDE`, `kiro = .amazonq compatibility surface`, and `roo = rules-guidance only`, without implying broader product coverage | Files: setup.sh | Verify: `sh -n setup.sh` and manual review of chooser/help output strings | Deps: #1 | Artifacts: none
- [x] 3. Change: add regression coverage for the clarified semantics in the existing setup tests, including summary wording and current alias expectations, while leaving `Amazon Q Developer CLI`, `Cursor CLI`, and `Roo Code` out of new integration scope | Files: tests/test-setup.sh, tests/test-multi-ide.sh | Verify: `bash tests/test-setup.sh` and `bash tests/test-multi-ide.sh` | Deps: #2 | Artifacts: none
- [x] 4. Change: add an automated docs consistency check so README capability claims stay aligned with the canonical matrix for the currently supported Baton targets | Files: tests/test-ide-capability-consistency.sh | Verify: `bash tests/test-ide-capability-consistency.sh` | Deps: #1 | Artifacts: none
- [x] 5. Change: bootstrap `.agents/skills` and any selected IDE skill directories during Baton self-install so the Baton repo itself can exercise both the Codex fallback path and the native skill directories for other selected IDEs without requiring a second external install target | Files: setup.sh, tests/test-setup.sh | Verify: `bash tests/test-setup.sh` and a real `bash ./setup.sh --ide codex` self-install in this repository | Deps: none | Artifacts: `.agents/skills/baton-{research,plan,implement}/SKILL.md` plus selected IDE skill directories such as `.cursor/skills/` and `.amazonq/skills/`
- [x] 6. Change: auto-merge Baton hooks into existing JSON-based IDE config files so installer support is not limited to fresh installs; preserve user-defined config while appending missing Baton hook entries for Claude, Cursor, Windsurf, Augment, Kiro compatibility surface, and Copilot | Files: setup.sh, tests/test-setup.sh, tests/test-multi-ide.sh | Verify: `bash tests/test-setup.sh`, `bash tests/test-multi-ide.sh`, `bash tests/test-ide-capability-consistency.sh` | Deps: none | Artifacts: merged existing `settings.json` / `hooks.json` / `baton.json` files instead of manual-merge warnings for the covered JSON targets
- [x] 7. Change: bring Cline onto the same install/merge path by wrapping existing `.clinerules/hooks/PreToolUse` and `TaskComplete` scripts instead of ignoring them, preserving the user hook behind a Baton wrapper and restoring it on uninstall; also add a Cline `TaskComplete` JSON adapter so completion checks follow Cline's documented hook protocol | Files: setup.sh, .baton/adapters/adapter-cline-taskcomplete.sh, tests/test-setup.sh, tests/test-multi-ide.sh, tests/test-adapters-v2.sh | Verify: `bash tests/test-setup.sh`, `bash tests/test-multi-ide.sh`, `bash tests/test-adapters-v2.sh` | Deps: none | Artifacts: Baton-managed Cline wrapper hooks plus preserved `.baton-user` backups when pre-existing user hooks are present

## Verification Results

- `sh -n setup.sh` → passed
- `bash tests/test-ide-capability-consistency.sh` → passed (`12/12`)
- `bash tests/test-setup.sh` → passed (`150/150`)
- `bash tests/test-multi-ide.sh` → passed (`54/54`)
- `bash tests/test-adapters-v2.sh` → passed (`12/12`)
- `BATON_SKIP=pre-commit bash ./setup.sh --ide codex` → passed; confirmed self-install now bootstraps `.agents/skills/` in the Baton repo itself

## Decision Points Requiring Human Approval

1. `Recommended default:` keep only the current `kiro -> .amazonq` compatibility target for this iteration. Do you want Baton to introduce a first-class `amazonq` installer target now anyway?
2. `Recommended default:` keep `Cursor CLI` out of Baton installer scope for now and document it separately. Do you want `Cursor CLI` to become a tracked Baton target now anyway?

## Self-Review

- Biggest risk: the `Kiro` / `Amazon Q Developer CLI` split touches both product naming and filesystem/config surface, so it is easy to improve wording without actually improving the model.
- What could make this plan wrong: if Baton intentionally wants to model only repository config surfaces and not products, then a product-level split may be unnecessary.
- Rejected alternative: immediate full product split. I rejected it because the evidence is not equally strong across all products, and the migration cost is higher than the current problem warrants.

## Retrospective

- The lowest-risk improvement was tightening terminology and adding a matrix-backed consistency check before attempting any installer target split.
- The plan was correct to defer `Amazon Q Developer CLI`, `Cursor CLI`, and deeper `Roo Code` integration work; the current repo needed semantics cleanup more than new surfaces.
- The follow-up self-install fix was small but worthwhile: it removes a confusing gap between the documented skill paths and the Baton repo's previous inability to bootstrap them for itself during self-install.
- The next practical gap after capability wording was installer behavior on existing projects; JSON-based hook auto-merge closes a real adoption problem without changing Baton scope claims.
- Cline needed a different solution from the JSON-based IDEs: wrapping and restoring user hook files is more reliable than trying to append text into executable event scripts, and it keeps uninstall reversible.
- If this work continues, the next research-to-implementation step should be deciding whether Baton wants to model products or only repository config surfaces, because that choice determines whether `amazonq` should ever become a first-class installer target.

## Annotation Log

### Round 1

- Initial plan created from `research-ide-hooks-2026-03-07.md` and `docs/ide-capability-matrix.md`
- Added recommended default decisions to reduce approval ambiguity before implementation
- Status: awaiting review

### Round 2

**[NOTE] § 批注区**
"1.可以先不考虑 Amazon Q Developer CLI 和 cursor Cli 还有rooCode"
→ Accepted. This iteration keeps `Amazon Q Developer CLI`, `Cursor CLI`, and new `Roo Code` integration work out of scope, while preserving accurate existing documentation about their current status.
→ Result: accepted

### Round 3

**[CHANGE] § Follow-up implementation scope**
"可以"
→ Accepted as approval for the follow-up change proposed in chat: bootstrap `.agents/skills` during Baton self-install so the current repository can exercise Codex/Baton skill fallback directly.
→ Result: accepted

### Round 4

**[CHANGE] § Follow-up implementation scope**
"不至codex 其他的ide也需要这样"
→ Accepted. The self-install follow-up was broadened so selected non-Codex IDEs also receive their skill directories during Baton self-install, while keeping same-path `.claude/skills` sources safe by skipping self-copies.
→ Result: accepted

### Round 5

**[CHANGE] § Follow-up implementation scope**
"改进 这个问题 还有一个实际问题比矩阵本身更大：对“已存在配置文件”的项目，installer 很多时候不会自动合并，只会提示你手工 merge。也就是说，矩阵说“支持”，不等于跑完 setup.sh 一定真的装齐。"
→ Accepted. Added auto-merge for existing JSON-based IDE hook config files so supported Baton targets are no longer fresh-install-only for the covered config surfaces.
→ Result: accepted

### Round 6

**[CHANGE] § Follow-up implementation scope**
"需要"
→ Accepted. Extended the same “create if missing / preserve and merge if present” installer experience to Cline by wrapping existing hook files, preserving the original user script, and restoring it on uninstall.
→ Result: accepted

## 批注区

> 标注类型：`[Q]` 提问 · `[CHANGE]` 修改 · `[NOTE]` 补充 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏
> 审阅完成后添加 `<!-- BATON:GO -->`，然后告诉 AI "generate todolist"

<!-- 在下方添加标注 -->
[NOTE]
  1.可以先不考虑 Amazon Q Developer CLI 和 cursor Cli 还有rooCode


<!-- BATON:GO --> 
