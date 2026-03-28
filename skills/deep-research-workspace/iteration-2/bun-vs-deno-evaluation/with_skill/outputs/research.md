**Question**: Should I use Bun or Deno for a new CLI tool that needs fast startup, TypeScript support, and single-executable packaging?
**Depth**: Deep
**Key finding**: Bun is the stronger choice for this specific use case -- it wins on startup speed, compiled binary size, and npm ecosystem access; Deno wins on security and built-in tooling completeness but produces significantly larger binaries.
**Open questions**: 3 -- see end of document

---

# Bun vs Deno for a New CLI Tool

## Decision boundary

This investigation determines which runtime (Bun or Deno) to choose for a new
CLI tool project, evaluated against three stated requirements:

1. Fast startup time
2. First-class TypeScript support
3. Convenient single-executable packaging

Secondary factors examined: npm ecosystem compatibility, cross-platform
compilation, binary size, built-in tooling, maturity/stability, and security
model.

---

## Overview

Both Bun and Deno are modern JavaScript/TypeScript runtimes that offer native
TypeScript execution and single-executable compilation. They take fundamentally
different architectural approaches:

```
+------------------+                    +------------------+
|       Bun        |                    |       Deno       |
+------------------+                    +------------------+
| Engine: JSC      |                    | Engine: V8       |
| Language: Zig+C  |                    | Language: Rust   |
| Philosophy:      |                    | Philosophy:      |
|   Speed-first,   |                    |   Security-first,|
|   Node-compat    |                    |   Web-standards  |
| Owner: Anthropic |                    | Owner: Deno Land |
|   (since Dec'25) |                    |   (Ryan Dahl)    |
+------------------+                    +------------------+
```

---

## Findings

### 1. Startup Time

This is the most decisive differentiator for CLI tools, where every invocation
pays the startup cost.

| Runtime | Cold start (hello world) | Engine |
|---------|--------------------------|--------|
| Bun     | ~8-18 ms                 | JavaScriptCore (JSC) |
| Deno    | ~40-60 ms                | V8 |

(verified: multiple benchmark articles -- [Better Stack](https://betterstack.com/community/guides/scaling-nodejs/nodejs-vs-deno-vs-bun/), [DEV Community 2026 benchmarks](https://dev.to/jsgurujobs/bun-vs-deno-vs-nodejs-in-2026-benchmarks-code-and-real-numbers-2l9d), [Medium re-ran benchmarks Jan 2026](https://medium.com/@sonampatel_97163/bun-vs-node-vs-deno-in-2025-i-re-ran-the-benchmarks-f955a04ee016))

**Bun is ~3-4x faster at startup.** This is architectural: JSC prioritizes fast
startup and low memory, while V8 prioritizes peak throughput via JIT
optimization. For a CLI tool that starts, runs, and exits, JSC's tradeoff is
ideal.

Memory usage follows the same pattern: Bun uses 2-3x less memory than Deno for
simple workloads.
(verified: [Better Stack runtime comparison](https://betterstack.com/community/guides/scaling-nodejs/nodejs-vs-deno-vs-bun/))

**Winner: Bun** -- clear and significant advantage.

### 2. TypeScript Support

Both runtimes execute TypeScript natively with zero configuration.

| Dimension | Bun | Deno |
|-----------|-----|------|
| Runs .ts files directly | Yes | Yes |
| tsconfig required | No (optional) | No (optional) |
| Transpiler | Built-in (Zig, very fast) | Built-in (swc-based) |
| Built-in type checking | No -- transpile only, strips types | Yes -- `deno check` runs tsc |
| Decorators | Supported (experimental) | Supported |
| Enums | Supported natively | Supported |
| JSX/TSX | Supported natively | Supported |
| Path mapping | Supported | Supported |

(verified: [Better Stack TypeScript comparison](https://betterstack.com/community/guides/scaling-nodejs/deno-vs-bun-typescript/), [Pullflow 2025 comparison](https://pullflow.com/blog/deno-vs-bun-2025/))

Key difference: **Deno integrates type checking into its workflow** (`deno check`),
while **Bun only transpiles** (strips types for speed). With Bun, you'd use a
separate `tsc --noEmit` step or your editor's language server for type checking.

For a CLI tool where you'll have CI anyway, this difference is minor -- you'll
run type checking in CI regardless of runtime.

**Winner: Tie** -- both excellent, minor philosophical difference.

### 3. Single-Executable Packaging

This is the second most decisive factor. Both support compiling to standalone
executables, but they differ significantly in binary size and optimization.

#### Command comparison

```bash
# Bun
bun build --compile ./cli.ts --outfile mycli

# Deno
deno compile -o mycli ./cli.ts
```

#### Binary size (the critical difference)

| Runtime | Hello world binary (macOS ARM64) | With dependencies |
|---------|----------------------------------|-------------------|
| Bun     | ~57-63 MB                        | Smaller (tree-shaking + minification) |
| Deno    | ~58 MB (v1.41+), ~100+ MB (pre-1.41) | Much larger (no tree-shaking) |

(verified: [Bun docs](https://bun.com/docs/bundler/executables), [Deno 1.41 release notes](https://deno.com/blog/v1.41), [GitHub discussions](https://github.com/denoland/deno/discussions/28536))

**For hello-world, sizes are now comparable (~58-63 MB).** But the real
difference emerges with actual projects that have dependencies:

A real-world case study (Rulesync CLI migration from Deno to Bun) showed a
**9x reduction in binary size** after switching to Bun. The reason:
(verified: [Zenn article by dyoshikawa](https://zenn.dev/dyoshikawa/articles/deno-to-bun-single-binary?locale=en))

- **Bun's `--compile`** runs its bundler first: tree-shaking removes unused
  code, minification shrinks the rest, then embeds the result.
- **Deno's `compile`** embeds source code and npm packages as-is, including
  unused packages from the lock file and even `@types/*` packages.

This is a significant architectural difference. Deno currently has no
tree-shaking or minification in its compile pipeline.

#### Cross-compilation targets

| Target | Bun | Deno |
|--------|-----|------|
| macOS x64 | `bun-darwin-x64` | `x86_64-apple-darwin` |
| macOS ARM64 | `bun-darwin-arm64` | `aarch64-apple-darwin` |
| Linux x64 | `bun-linux-x64` | `x86_64-unknown-linux-gnu` |
| Linux ARM64 | `bun-linux-arm64` | `aarch64-unknown-linux-gnu` |
| Linux x64 musl (Alpine) | `bun-linux-x64-musl` | Not supported |
| Linux ARM64 musl | `bun-linux-arm64-musl` | Not supported |
| Windows x64 | `bun-windows-x64` | `x86_64-pc-windows-msvc` |
| Windows ARM64 | `bun-windows-arm64` | `aarch64-pc-windows-msvc` (Deno 2.7+) |
| CPU baseline variants | Yes (multiple per platform) | No |

(verified: [Bun docs](https://bun.com/docs/bundler/executables), [Deno compile docs](https://docs.deno.com/runtime/reference/cli/compile/), [Deno 2.7 release](https://deno.com/blog/v2.7))

Bun has **13 targets** including musl (Alpine Linux) variants and CPU baseline
options. Deno has **6 targets** (5 original + Windows ARM64 added in Deno 2.7,
Feb 2026). Notably, Deno lacks musl/Alpine support for compiled binaries.

#### Asset embedding

| Feature | Bun | Deno |
|---------|-----|------|
| Embed individual files | Yes | Yes (`--include`) |
| Embed directories | Beta (has known bugs) | Yes (`--include <dir>`) |
| Glob patterns for embedding | Broken (known issue) | N/A (use --include) |
| Self-extracting mode | No | Yes (`--self-extracting` in 2.7+) |

(verified: [Bun GitHub issues #5445, #23852](https://github.com/oven-sh/bun/issues/23852), [Deno 2.1 blog](https://deno.com/blog/v2.1))

Bun's directory/asset embedding is less mature and has documented bugs. Deno's
`--include` flag and new `--self-extracting` mode are more reliable for
embedding assets.

#### Build speed

The Rulesync migration showed Bun compiles for 5 platforms in ~4 seconds vs
Deno's ~78 seconds -- a **~20x speedup**.
(verified: [Zenn article by dyoshikawa](https://zenn.dev/dyoshikawa/articles/deno-to-bun-single-binary?locale=en))

**Winner: Bun** -- smaller binaries with dependencies (due to tree-shaking),
more cross-compilation targets, much faster builds. Deno has better asset
embedding and the self-extracting feature.

### 4. npm Ecosystem Compatibility

| Dimension | Bun | Deno |
|-----------|-----|------|
| npm package support | Near 100% Node.js compat | Supports npm: specifiers, ~good compat |
| Package manager | `bun install` (very fast) | `deno add`, `deno install` |
| node_modules | Uses by default | Optional (global cache or node_modules) |
| package.json | Full support | Full support (Deno 2+) |
| Import maps | Supported | Native (import_map.json / deno.json) |
| Popular CLI libs (commander, chalk, inquirer) | Work natively | Work via npm: specifier |

(verified: [Bun Node.js compat docs](https://bun.com/docs/runtime/nodejs-compat), [Deno Node/npm compat docs](https://docs.deno.com/runtime/fundamentals/node/))

Both work well with npm packages. Bun's approach is "any npm package that works
in Node should work in Bun" (incompatibility is treated as a bug). Deno 2's npm
compatibility is good and improving but occasionally hits edge cases with
packages that use obscure Node.js APIs.

For CLI development, the common libraries (commander, yargs, chalk, inquirer,
ora, etc.) work on both runtimes.

**Winner: Bun** -- slightly more seamless npm compatibility, faster package
installation.

### 5. Built-in Tooling

| Tool | Bun | Deno |
|------|-----|------|
| Package manager | `bun install` | `deno install` / `deno add` |
| Test runner | `bun test` (Jest-compatible) | `deno test` |
| Formatter | `bun fmt` | `deno fmt` |
| Linter | `bun lint` | `deno lint` |
| Bundler | `bun build` | `deno bundle` (deprecated, use esbuild) |
| Type checker | No (use tsc separately) | `deno check` |
| Documentation generator | No | `deno doc` |
| Task runner | `bun run` | `deno task` |
| REPL | `bun repl` | `deno` |
| Coverage | Via test runner | `deno test --coverage` |
| Benchmarking | No built-in | `deno bench` |

(verified: [Deno all-in-one tooling docs](https://docs.deno.com/examples/all-in-one_tooling/), [Bun homepage](https://bun.com/))

Deno's toolchain is more complete out of the box, especially with `deno check`
(type checking), `deno doc` (documentation), and `deno bench` (benchmarking).
Bun recently added `bun fmt` and `bun lint` but its toolchain is newer.

**Winner: Deno** -- more mature and complete built-in toolchain.

### 6. Security Model

| Aspect | Bun | Deno |
|--------|-----|------|
| Default permissions | Full access (like Node.js) | No I/O access by default |
| Permission flags | None | `--allow-read`, `--allow-write`, `--allow-net`, etc. |
| Permissions in compiled binary | N/A | Baked in at compile time |
| Permission sets (deno.json) | N/A | Yes (Deno 2.5+) |

(verified: [Deno security docs](https://docs.deno.com/runtime/fundamentals/security/))

Deno's permission model is genuinely useful for CLI tools that users download
and run: the binary can be locked down to only the specific filesystem paths
and network endpoints it needs. This is a meaningful security advantage when
distributing CLI tools to others.

For a personal/internal tool where you trust the code, this matters less.

**Winner: Deno** -- significant security advantage for distributed CLI tools.

### 7. Maturity and Stability

| Dimension | Bun | Deno |
|-----------|-----|------|
| Current version | v1.3.5 (Jan 2026) | v2.7 (Feb 2026) |
| 1.0 release | Sep 2023 | Late 2018 (1.0 in May 2020) |
| Owner/backer | Anthropic (acquired Dec 2025) | Deno Land (Ryan Dahl) |
| License | MIT | MIT |
| Open issues | ~4,700 | Fewer |
| LTS support | No formal LTS | Yes (starting v2.1.0) |
| Release cadence | Frequent (weekly patches) | Regular (~monthly minors) |

(verified: [Bun endoflife.date](https://endoflife.date/bun), [Deno endoflife.date](https://endoflife.date/deno), [Anthropic acquisition announcement](https://bun.com/blog/bun-joins-anthropic))

Deno is more mature (longer track record, formal LTS). Bun is newer but has
strong financial backing from Anthropic and a very active development pace.
Bun's higher issue count (~4.7k vs Node's ~1.7k) reflects its younger
codebase.

The Anthropic acquisition is a double-edged signal: it ensures Bun's survival
and funding, but also means Bun's roadmap may prioritize Anthropic's needs
(AI coding tools) over general-purpose CLI use cases. So far, Bun remains
MIT-licensed and open-source.
(verified: [Bun blog - joining Anthropic](https://bun.com/blog/bun-joins-anthropic), [Anthropic announcement](https://www.anthropic.com/news/anthropic-acquires-bun-as-claude-code-reaches-usd1b-milestone))

**Winner: Deno** -- more mature, has LTS, longer track record.

---

## Synthesis: Decision Matrix

| Criterion | Weight (for CLI tool) | Bun | Deno | Winner |
|-----------|-----------------------|-----|------|--------|
| Startup time | HIGH | ~8-18ms | ~40-60ms | **Bun** |
| TypeScript support | HIGH | Excellent (transpile only) | Excellent (+ type checking) | Tie |
| Single-exe binary size | HIGH | ~57-63 MB (hello world), much smaller with deps | ~58 MB (hello world), much larger with deps | **Bun** |
| Cross-compilation targets | MEDIUM | 13 targets (incl. musl) | 6 targets | **Bun** |
| Build speed | MEDIUM | ~4s for 5 platforms | ~78s for 5 platforms | **Bun** |
| npm compatibility | MEDIUM | Near 100% | Good, improving | **Bun** |
| Built-in tooling | MEDIUM | Good (recently added fmt/lint) | Excellent (complete suite) | **Deno** |
| Security model | LOW-MEDIUM* | None (full access) | Granular permissions | **Deno** |
| Asset embedding | LOW | Beta, has bugs | Mature, + self-extracting | **Deno** |
| Maturity/LTS | LOW-MEDIUM | No LTS, 2.5yr track record | LTS available, 6yr track record | **Deno** |

\* Security weight depends on distribution model: LOW for internal tools, HIGH
for publicly distributed tools.

---

## Recommendation

**For this use case (fast startup + TypeScript + single executable), choose Bun.**

The three stated requirements map directly to Bun's strengths:

1. **Fast startup**: Bun is 3-4x faster than Deno at cold start. For a CLI tool
   invoked repeatedly, this is the single most noticeable difference to end users.

2. **TypeScript support**: Both are excellent. Tie.

3. **Single-executable packaging**: Bun produces smaller binaries for real-world
   projects (tree-shaking + minification), supports more targets (13 vs 6,
   including Alpine Linux), and builds ~20x faster.

### When to choose Deno instead

- **Security is paramount**: if you're distributing a CLI tool to untrusted
  environments and want to restrict what the binary can access, Deno's
  permission model (baked into the compiled binary) is a genuine advantage
  that Bun cannot match.

- **You need reliable asset embedding**: Deno's `--include` and
  `--self-extracting` are more mature than Bun's directory embedding, which
  has documented bugs.

- **You need LTS guarantees**: Deno offers formal LTS; Bun does not.

- **You want integrated type checking**: Deno's `deno check` is convenient
  if you don't want to set up a separate tsc step.

### Concrete getting-started with Bun

```bash
# Initialize project
mkdir my-cli && cd my-cli
bun init

# Write your CLI in TypeScript
# (use commander, yargs, or @clack/prompts for argument parsing)

# Run during development
bun run cli.ts --help

# Test
bun test

# Compile for current platform
bun build --compile ./cli.ts --outfile my-cli

# Cross-compile for all major platforms
bun build --compile --target=bun-darwin-arm64 ./cli.ts --outfile dist/my-cli-macos-arm64
bun build --compile --target=bun-darwin-x64 ./cli.ts --outfile dist/my-cli-macos-x64
bun build --compile --target=bun-linux-x64 ./cli.ts --outfile dist/my-cli-linux-x64
bun build --compile --target=bun-linux-arm64 ./cli.ts --outfile dist/my-cli-linux-arm64
bun build --compile --target=bun-windows-x64 ./cli.ts --outfile dist/my-cli-windows-x64.exe
```

---

## Challenge (self-critique)

**Weakest conclusion**: The binary size comparison for real-world projects relies
heavily on a single migration case study (Rulesync, Deno to Bun). The 9x
difference is dramatic but may not generalize to all dependency profiles. A CLI
tool with few dependencies might see comparable sizes from both runtimes.

**What would disprove the recommendation**: If Deno adds tree-shaking and
minification to its compile pipeline (which is technically feasible), the binary
size advantage largely disappears, leaving startup time as the main
differentiator. Additionally, if the CLI tool requires complex asset embedding
(templates, data files), Bun's current bugs in this area could be a blocker.

**What I didn't verify at runtime**: All performance numbers come from published
benchmarks and articles, not from running the runtimes myself. Actual numbers
on your specific hardware and with your specific dependencies may vary.

---

## Open questions

1. **Bun asset embedding reliability**: If your CLI needs to embed template files
   or data directories, test Bun's `--compile` with your specific asset structure
   early. The documented bugs with glob patterns and directory embedding may
   require workarounds. (Relevant issue: [oven-sh/bun#23852](https://github.com/oven-sh/bun/issues/23852))

2. **Deno tree-shaking roadmap**: Is Deno planning to add bundler optimization
   to `deno compile`? If so, the binary size gap could close. Worth checking
   Deno's roadmap before committing if binary size is the deciding factor.

3. **Anthropic acquisition long-term effects**: Bun's roadmap priorities under
   Anthropic ownership are not yet clear beyond AI tooling. For a CLI tool
   unrelated to AI, monitor whether general-purpose improvements continue at
   the same pace.

---

## Sources

- [Bun single-file executable docs](https://bun.com/docs/bundler/executables)
- [Deno compile reference](https://docs.deno.com/runtime/reference/cli/compile/)
- [Better Stack: Deno vs Bun TypeScript comparison](https://betterstack.com/community/guides/scaling-nodejs/deno-vs-bun-typescript/)
- [Better Stack: Node.js vs Deno vs Bun runtime comparison](https://betterstack.com/community/guides/scaling-nodejs/nodejs-vs-deno-vs-bun/)
- [Pullflow: Deno vs Bun in 2025](https://pullflow.com/blog/deno-vs-bun-2025/)
- [DEV Community: Bun vs Deno vs Node.js in 2026 benchmarks](https://dev.to/jsgurujobs/bun-vs-deno-vs-nodejs-in-2026-benchmarks-code-and-real-numbers-2l9d)
- [DEV Community: Deno 2 vs Node.js vs Bun in 2026 complete comparison](https://dev.to/pockit_tools/deno-2-vs-nodejs-vs-bun-in-2026-the-complete-javascript-runtime-comparison-1elm)
- [Zenn: Reducing binary size by 9x migrating from Deno to Bun](https://zenn.dev/dyoshikawa/articles/deno-to-bun-single-binary?locale=en)
- [Deno 1.41: smaller compile binaries](https://deno.com/blog/v1.41)
- [Deno 2.7 release notes](https://deno.com/blog/v2.7)
- [Deno: self-contained executable programs](https://deno.com/blog/deno-compile-executable-programs)
- [Deno security and permissions docs](https://docs.deno.com/runtime/fundamentals/security/)
- [Bun joins Anthropic announcement](https://bun.com/blog/bun-joins-anthropic)
- [Anthropic acquires Bun announcement](https://www.anthropic.com/news/anthropic-acquires-bun-as-claude-code-reaches-usd1b-milestone)
- [Deno Node.js and npm compatibility](https://docs.deno.com/runtime/fundamentals/node/)
- [Bun Node.js compatibility](https://bun.com/docs/runtime/nodejs-compat)
- [Deno all-in-one tooling](https://docs.deno.com/examples/all-in-one_tooling/)
- [Medium: Bun vs Node vs Deno re-ran benchmarks Jan 2026](https://medium.com/@sonampatel_97163/bun-vs-node-vs-deno-in-2025-i-re-ran-the-benchmarks-f955a04ee016)

## 批注区

(Reserved for annotations)
