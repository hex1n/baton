# Requirements: skill-retrospective-alignment

**Topic**: Align `baton-retrospective` skill with `retrospective.template.md` (6 sections) and add structural validation
**Status**: `complete`
**Sizing**: `Small`

## 1. Problem

`skills/baton-retrospective/SKILL.md` instructs the LLM to write 8 retrospective sections (Metrics / What Worked / What Failed / What Should Be Standardized / Repo-Specific Lessons / Skill Patches / Profile Patches / Follow-up Tasks) across two inconsistent internal blocks (Step 3 prose + Output Template). But `spec/templates/retrospective.template.md` has only 6 sections (Outcome / What Worked / What Failed / Repo-Specific Lessons / Harness Lessons / Standardization Candidates) and has been 6 sections since the harness-spec-v1 protocol was born (commit `08540ca`, 2026-03-26). The skill's 8-dimension instructions are pre-protocol legacy that survived the refactor. Recent tasks have been writing 6-section retrospectives because LLMs follow the template they see in `.harness/retrospective.md`, not the skill's outdated prose. This drift was invisible because `validate-artifact.sh` has no `retrospective` case — retrospective structure has zero enforcement.

## 2. Assumptions

- A1 (Convention, High): Template is authoritative, skill is stale. If wrong → restoring the 8-dimension shape would need to add Metrics/Skill Patches/Profile Patches/Follow-up back to the template. Verified by git archaeology: template born at 6 sections in `08540ca`, never touched since.
- A2 (Testable, High): Metrics/Skill Patches/Profile Patches/Follow-up Tasks are not referenced elsewhere as anchors. If wrong → removing them from the skill breaks some other consumer. Will verify via grep in Verification §V1.
- A3 (Convention, High): `check-lesson-index-consistency.sh` is the right guard location. If wrong → would need a new dedicated checker. Low risk since that script already owns the skill↔template contract domain.

## 3. Scope

### 3.1 In Scope

- Rewrite `skills/baton-retrospective/SKILL.md` Step 3 and Output Template to match the 6-section template structure
- Delete legacy references to Metrics / Skill Patches / Profile Patches / Follow-up Tasks sections
- Update skill `description` to mention dual purpose (close task + feed `knowledge/lessons.md`)
- Add `retrospective` case to `spec/bootstrap/commands/validate-artifact.sh`
- Extend `check-lesson-index-consistency.sh` with a skill↔template section-ordering check

### 3.2 Out of Scope

- Redesigning the 6-section schema itself
- Adding metrics collection or skill-self-improvement in a new form
- Touching other skills, templates, or the extractor regex
- Editing archived retrospectives in `.harness/history/`

## 4. Functional Requirements

### FR-1 Skill Step 3 matches template
The Execution Steps §3 in `baton-retrospective/SKILL.md` enumerates exactly the 6 sections from `retrospective.template.md`, in the same order, with the same titles.

### FR-2 Skill Output Template matches template
The Output Template code block in `baton-retrospective/SKILL.md` contains exactly 6 level-2 headings: Outcome / What Worked / What Failed / Repo-Specific Lessons / Harness Lessons / Standardization Candidates. §4 and §5 retain numbered prefixes (`## 4.` / `## 5.`) because `start-task.sh` extractor and `check-lesson-index-consistency.sh` depend on them.

### FR-3 Skill description reflects dual purpose
The `description:` frontmatter in `baton-retrospective/SKILL.md` mentions both (a) closing the task and (b) feeding `knowledge/lessons.md`.

### FR-4 Validator enforces retrospective structure
`validate-artifact.sh` has a `retrospective` case that fails if any of the 6 required sections is missing.

### FR-5 Consistency check guards skill↔template alignment
`check-lesson-index-consistency.sh` has a new check that extracts the 6 level-2 headings from the skill's output template block and from `retrospective.template.md` and fails if they differ in content or order.

### FR-6 Current retrospectives still validate
Running the new `validate-artifact.sh retrospective` case on the current `.harness/retrospective.md` exits 0 (the existing file already has the 6 sections).

## 5. Non-Goals

- No UI / CLI changes
- No test suite refactoring beyond the added validator case and consistency check
- No schema migration — archived history retrospectives are not re-validated

## 6. Acceptance Criteria

### AC-1 Skill sections match template exactly
```bash
diff <(grep -E '^## ' spec/templates/retrospective.template.md | sed 's/^## //') \
     <(awk '/^```markdown/,/^```$/' skills/baton-retrospective/SKILL.md | grep -E '^## ' | sed 's/^## //')
```
Only permitted diff: §4/§5 numbered prefixes in the skill output (`4. Repo-Specific Lessons` / `5. Harness Lessons`).

### AC-2 Template section count unchanged
`grep -c '^## ' spec/templates/retrospective.template.md` = 6.

### AC-3 Current retro passes new validator
`bash spec/bootstrap/commands/validate-artifact.sh retrospective .harness/retrospective.md` exits 0.

### AC-4 Broken retro fails new validator
Creating a temp copy of a retrospective with any required section removed and running validator exits 1 with the correct error message.

### AC-5 Consistency check clean
`bash spec/bootstrap/commands/check-lesson-index-consistency.sh` exits 0 after the rewrite.

### AC-6 Consistency check catches new drift class
Injecting a heading rename (e.g., "What Worked" → "What Succeeded") into the skill's output template and running the consistency check produces exit 1 with a meaningful error. Restore file afterward.

### AC-7 Skill description signals dual purpose
`grep -E '(close.*task|lessons\.md)' skills/baton-retrospective/SKILL.md | head -5` shows at least one match in the `description:` frontmatter region (lines 1–10).

## 7. Constraints

- MUST preserve `## 4. Repo-Specific Lessons` and `## 5. Harness Lessons` numbered headings in the skill output template block — extractor regex depends on the exact shape
- MUST NOT break any check currently passing in `check-lesson-index-consistency.sh`
- MUST NOT touch `retrospective.template.md` (authoritative, already correct)

## 8. Validation Intent

- **Unit**: run each AC command manually after the rewrite
- **Integration**: on task closure (next start-task.sh run), verify `knowledge/lessons.md` receives this task's §4/§5 — same as the previous two tasks — proving the skill/template/extractor chain still works end-to-end after the rewrite
- **Negative**: AC-4 and AC-6 explicitly inject breakage to prove the new guards fire
