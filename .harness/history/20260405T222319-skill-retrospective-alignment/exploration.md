# Scoped Map: skill-retrospective-alignment

**Requirement**: 对齐 `baton-retrospective` skill 与 `retrospective.template.md`,消除 skill/template 漂移;给 retrospective.md 加结构校验
**Domain**: baton harness / skills + protocol
**Owner**: `scoped-explorer`
**Status**: `complete`

## 1. Scope

- In scope:
  - Rewrite `skills/baton-retrospective/SKILL.md` Step 3 and output template to match the 6-section structure in `spec/templates/retrospective.template.md` (Outcome, What Worked, What Failed, Repo-Specific Lessons, Harness Lessons, Standardization Candidates)
  - Delete skill references to Metrics, Skill Patches, Profile Patches, Follow-up Tasks sections (not in template, not written by recent tasks, no downstream consumer)
  - Add `retrospective` case to `spec/bootstrap/commands/validate-artifact.sh`
  - Update `baton-retrospective` skill `description` to reflect dual purpose (close task + feed lesson index)
  - Extend `check-lesson-index-consistency.sh` to verify skill Step 3 section ordering matches template ordering
- Out of scope:
  - Redesigning the retrospective schema itself — 6 sections stays 6 sections
  - Adding new metrics collection or skill-self-improvement mechanisms (deferred)
  - Refactoring other skills or artifacts
  - Touching the extractor regex (already correct after previous task)
- Expected write boundary: 3 files edited, 0 files added
  - `skills/baton-retrospective/SKILL.md`
  - `spec/bootstrap/commands/validate-artifact.sh`
  - `spec/bootstrap/commands/check-lesson-index-consistency.sh`

## 2. Entry Point

- Primary: `skills/baton-retrospective/SKILL.md:22-94` (Execution Steps §1–§8) and L118-174 (Output Template block)
- Contract targets: `spec/templates/retrospective.template.md` (6 sections, authoritative since `08540ca`)
- Validator: `spec/bootstrap/commands/validate-artifact.sh` (currently has no `retrospective` case)
- Guard: `spec/bootstrap/commands/check-lesson-index-consistency.sh` (currently only checks §4/§5 heading presence)

## 3. Call Chain

```text
task complete
  → user/orchestrator invokes baton-retrospective skill
  → LLM reads skill Step 3 (currently 8 sections) + output template (currently 8 sections, different order, §4/§5 numbered)
  → LLM writes retrospective.md
  → validate-artifact.sh runs (currently SKIPS retrospective — no case)
  → next start-task.sh → sed extracts §4/§5 → knowledge/lessons.md
```

After fix:

```text
task complete
  → skill Step 3 + output template (6 sections matching template)
  → LLM writes retrospective.md (6 sections)
  → validate-artifact.sh runs retrospective case → blocks on missing sections
  → next start-task.sh → sed extracts §4/§5 → knowledge/lessons.md
```

## 4. Data Flow

- Source: skill prose (LLM instructions) + output template (LLM schema reference)
- Transform: LLM drafts retrospective.md
- Sink: `.harness/retrospective.md`
- Downstream: validator (gate), extractor (lesson compounding)

## 5. Existing Behavior

- `baton-retrospective/SKILL.md` Step 3 enumerates 8 dimensions: Metrics / What Worked / What Failed / What Should Be Standardized / Repo-Specific Lessons / Skill Patches / Profile Patches / Follow-up Tasks
- Output template block inside the skill has DIFFERENT ordering and section numbering from Step 3
- `retrospective.template.md` has been 6 sections since commit `08540ca` (harness-spec-v1 birth, 2026-03-26) — the template was never 8 sections
- Recent tasks (`knowledge-compound-mvp`, `skill-retrospective-review`) wrote retros in the 6-section shape — proving the skill's 8-dimension instructions are being silently ignored by the LLM in practice
- `validate-artifact.sh` runs `return 0` (skip) for `retrospective` — no structural enforcement

## 6. Existing Tests

- None directly on retrospective content
- Indirect: `check-lesson-index-consistency.sh` checks §4/§5 heading regex in the skill only

## 7. Change History

- `08540ca` 2026-03-26: template born at 6 sections (harness-spec-v1 protocol birth)
- `ab071c9` 2026-04-04: i18n removal touched skill (1 insertion, 2 deletions) — not a refactor of the 8-dimension structure
- `884e4ce` 2026-04-04: lesson-index extractor wiring; added §4/§5 numbered headings to output template block, but did NOT touch Step 3 prose. This is when skill prose and output template first went out of sync WITH EACH OTHER.
- **Finding**: the 8-dimension structure is a pre-harness-spec-v1 legacy. It has been stale for the entire life of the current protocol.

## 8. Dependency / Risk Scan

- No integration or infra touched
- No migrations or schema changes
- Does NOT cross business domains
- **Risk R1**: validator case addition might reject existing retrospectives in `.harness/history/` — but validator only runs on *current* `.harness/retrospective.md` at hook time, not on archived ones. Mitigated.
- **Risk R2**: LLM that previously ignored the 8-dimension prose might now notice the new 6-dimension prose and behave differently on this very task's closure. Acceptable — the new prose matches what LLMs were already doing.
- **Risk R3**: consistency check extension might false-positive if skill Step 3 uses prose descriptions rather than exact heading matches. Mitigation: the check should match the exact level-2 headings in the output template block, not the Step 3 prose — simpler and more reliable.

## 9. Change Shape

- This looks like: **surgical content alignment + validator extension**
- Estimated file count: 3 (all edits, no new files)
- Preferred implementation depth: **Low-risk**. Can skip Clarifier, go straight to a compact Architect + Gate 2.

## 10. Open Questions

- None remaining after the git archaeology above — the template is authoritative, the skill is stale, direction is clear.

## 11. Recommendation

- **Proceed**: yes, Low-risk, short architecture pass then Gate 2 then implement
- **Suggested next step**: write compact `architecture.md` (5 change points), Gate 2 approval, implement in one pass, verify with `check-lesson-index-consistency.sh` + a re-run of validator on existing retrospective
- **Uncertainty flags**: none material

## 12. Historical Lessons

> Explorer read `knowledge/lessons.md` before scope definition this time.

- **Relevant prior lessons** (from `knowledge/lessons.md`):
  - `skill-retrospective-review`: "validate-artifact.sh has no case for retrospective" → **this is the task fixing that lesson**; directly in scope
  - `skill-retrospective-review`: "Skills with user-invocable:true whose outputs feed a downstream script are dual-contract (LLM-facing + machine-parseable)" → informs C3 (consistency check extension) and C1 (rewrite must match exact headings the extractor regex looks for)
  - `knowledge-compound-mvp`: "When a skill's output template is the contract for a downstream extractor, updating the template is not enough — the skill prose must explicitly instruct the LLM to write the new section" → load-bearing for this task. The fix must touch Step 3 prose AND the output template block AND the machine-parseable headings, all three in lockstep.
  - `knowledge-compound-mvp`: "Cross-file regex contracts need a static checker" → directly motivates C3 (extend consistency check)
- **Lessons explicitly not applicable**:
  - BSD sed BRE syntax — no sed work in this task
  - "Silent protocol-layer bugs need observability at write boundary" — not a write-boundary bug this time, it's a prose-contract bug
