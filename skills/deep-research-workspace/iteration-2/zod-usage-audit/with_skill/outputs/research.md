**Question**: Is zod used for schema validation in this project, and should hand-written type guards be unified with zod?
**Depth**: Standard
**Key finding**: The premise is false -- this project has no TypeScript, no JavaScript, no zod, and no type guards. It is entirely shell scripts and markdown.
**Open questions**: 0

---

## Overview

The question assumes the baton project uses zod for schema validation alongside
hand-written TypeScript type guards. Investigation shows this premise does not
hold: baton is a pure shell-script + markdown project with no JavaScript or
TypeScript anywhere in the codebase.

## Findings

### 1. Project technology stack

Baton is an AI-assisted plan-first development workflow tool. Its codebase
consists entirely of:

- **Bash scripts** (`.sh`) -- CLI entry point, hooks, adapters, tests, setup
- **Markdown** (`.md`) -- constitution, skills, documentation
- **One CMD file** (`hooks/run-hook.cmd`) -- Windows adapter

There are **zero TypeScript files**, **zero JavaScript files**, and **no
`package.json`**.

Evidence:
- `glob **/*.ts` returned 0 results (verified: ran glob)
- `glob **/*.js` returned 0 results (verified: ran glob)
- `glob **/package.json` returned 0 results (verified: ran glob)
- `bin/baton:1` is `#!/usr/bin/env bash` -- pure shell (verified: read bin/baton:1-5)
- `.gitignore` contains no mention of `node_modules`, `dist`, or any JS/TS build artifacts (verified: read .gitignore)
- `hooks/` directory contains 13 `.sh` files, 1 `.cmd` file, 1 `manifest.conf`, and a `lib/` directory (verified: listed hooks/)

### 2. No zod dependency

A project-wide search for `zod` found matches only in the deep-research eval
system itself:

- `skills/deep-research/evals/evals.json` -- defines this eval question
- `skills/deep-research-workspace/iteration-*/zod-usage-audit/` -- eval metadata and prior outputs

A targeted search for `from ['"]zod['"]` (the standard zod import pattern)
returned zero results outside of prior eval outputs. There is no zod import,
no zod schema definition, and no zod dependency anywhere in the project.
(verified: grep for `from ['"]zod['"]` and `require\(['"]zod['"]\)` both returned 0 results in source code)

### 3. No type guards

Searches for TypeScript type guard patterns returned no results in source files:

- `typeof` / `instanceof` in `.sh` files: 0 results (verified: ran grep)
- `type.?guard` (case-insensitive) across entire project: results only in eval metadata files (verified: ran grep)

The shell scripts use standard bash conditionals (`[ -f "$file" ]`, `[ -z "$var" ]`)
for input validation, but these are shell idioms, not TypeScript type guards.

### 4. What validation does exist

Baton validates state through **shell hook scripts** that enforce structural
preconditions at runtime:

| Hook | Purpose |
|------|---------|
| `write-lock.sh` | Checks whether source modifications are authorized |
| `bash-guard.sh` | Validates bash command execution context |
| `quality-gate.sh` | Checks output quality conditions |
| `completion-check.sh` | Validates completion criteria |
| `phase-guide.sh` | Validates phase transition rules |
| `stop-guard.sh` | Prevents unauthorized continuation |

These are procedural shell checks dispatched via `hooks/dispatch.sh`. The concept
of declarative schema validation (what zod provides) does not apply to this
architecture.

## Conclusion

**The question's premise is wrong.** Baton is not a TypeScript/JavaScript
project. It does not use zod, does not have type guards, and has no schema
validation layer to unify. The entire validation approach is shell-based
procedural hooks.

Introducing zod would require adding a Node.js runtime dependency to a project
that currently has zero JavaScript dependencies -- a fundamental architectural
change with no clear benefit for a shell-script tool.

## Self-challenge

The weakest point in this conclusion would be if there were TypeScript/JavaScript
files hidden in an unusual location (e.g., a git submodule, a generated
directory, or files without extensions). I verified against this by searching
for zod imports project-wide (not just in standard directories) and by checking
the `.gitignore` for any JS/TS ecosystem artifacts. Neither search turned up
evidence of a JS/TS layer.

## 批注区
