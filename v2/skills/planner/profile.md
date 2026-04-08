# Planner Guide: Profile Generation

> Use this file when Dispatcher invokes Planner with `profile` or when `project-profile.md` does not yet exist.

## Profile Generation

Scan the project and output `project-profile.md`. Run once per project, then keep it human-owned.

### Step 1: Scan build system

```
Find: build config file (pom.xml, build.gradle, package.json, Cargo.toml, go.mod, Makefile, etc.)
Extract: language version, framework version, dependencies, modules, plugins
```

### Step 2: Scan project structure

```
Glob: source directories (sample top-level packages/modules)
Identify: directory convention, layering pattern, entry points
```

### Step 3: Scan test infrastructure

```
Glob: test files (sample 3-5 tests)
Read: identify test framework, base class/helpers, data setup pattern, mock strategy
Try: compile/check command, then test command (verify build works)
```

### Step 4: Scan conventions

```
Read: 2-3 entry point files (controllers, handlers, routes, CLI commands)
Read: 2-3 business logic files (services, use cases, domain logic)
Read: error handling pattern (global handler, middleware, etc.)
Read: configuration files (profiles, env vars, feature flags)
```

### Step 5: Identify traps

```
Grep: TODO, FIXME, HACK, XXX
Identify: large files (>200 lines in a single function/method)
Check: known framework pitfalls relevant to this project's stack
```

### Step 6: Output `project-profile.md`

Use `v2/templates/project-profile.template.md`. Capture build commands, conventions, traps, verifier capability, and project-specific verification checks in a way later rounds can reuse directly.
