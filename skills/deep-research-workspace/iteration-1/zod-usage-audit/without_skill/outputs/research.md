# Zod Usage Audit: Research Findings

## Summary

The premise of this investigation -- that the project uses zod for schema validation alongside hand-written type guards -- is **incorrect**. The baton project does not use zod, does not contain any TypeScript or JavaScript source code, and has no schema validation or type guard patterns of any kind.

## Evidence

### 1. No TypeScript / JavaScript files exist in the project

A recursive glob for `**/*.{ts,tsx,js,jsx,mjs,cjs}` across the entire repository returned **zero results**. The project contains no files in any JavaScript-family language.

### 2. No package.json, no Node.js dependency management

No `package.json`, `tsconfig.json`, or `node_modules` directory exists anywhere in the repository (excluding `.claude/worktrees` copies). The project has no npm/yarn/pnpm dependency tree, so zod (an npm package) cannot be a dependency.

### 3. No references to zod in any source file

A content search for `zod`, `from 'zod'`, `from "zod"`, and `z.object`/`z.string`/etc. across the entire repository found **zero matches** in any source or configuration file. The only mentions of "zod" appear in:

- `skills/deep-research-workspace/iteration-1/zod-usage-audit/eval_metadata.json` -- the eval definition for this very task
- `skills/deep-research/evals/evals.json` -- the eval registry that references this task

These are eval infrastructure files, not project source code.

### 4. No type guard patterns exist

A search for type guard patterns (`is[A-Z]...()` function signatures, `typeof` checks used as guards) returned **zero matches** across the codebase.

### 5. The project is entirely shell-based

The baton project is an "AI-assisted development shared understanding construction protocol." Its implementation consists of:

- **Shell scripts** (`.sh`): hooks, adapters, setup, install, tests (~80+ files)
- **Markdown** (`.md`): constitution, skills, documentation, task artifacts
- **JSON**: configuration files (`.claude/settings.local.json`, `.codex/hooks.json`)

There is no application code in a typed language. The shell scripts use bash pattern matching and string comparison for their logic, not schema validation libraries.

## Conclusion

**Zod is not used in this project, and the question of unifying zod usage vs. hand-written type guards does not apply.** The entire codebase is shell scripts and markdown -- neither of which can use zod (a TypeScript/JavaScript library).

If the intent was to audit a different project in the same workspace, that project should be specified explicitly. If the intent was to add schema validation to baton's configuration parsing (e.g., validating JSON config files), that would require introducing a new technology stack (Node.js + TypeScript) which would be a significant architectural decision beyond the scope of a usage audit.

## Methodology

| Step | Tool/Approach | What was checked |
|------|---------------|------------------|
| 1 | File glob (`**/*.{ts,tsx,js,jsx,mjs,cjs}`) | Presence of any JS/TS source files |
| 2 | File glob (`**/package.json`) | Presence of Node.js dependency management |
| 3 | Content search for `zod`, `z.object`, `z.string`, etc. | Any reference to zod library |
| 4 | Content search for `is[A-Z]` function patterns, `typeof` guards | Hand-written type guard patterns |
| 5 | Content search for `schema.*valid`, `type.?guard` in `.sh`/`.md` files | Any mention of schema validation concepts |
| 6 | Read `README.md` | Confirm project nature and tech stack |
| 7 | Directory listing of project root | Verify project structure |

All searches were performed against the full repository tree (excluding only `.git`).

## 批注区

(Empty -- no annotations yet.)
