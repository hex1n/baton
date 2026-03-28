**Question**: Should I use Bun or Deno to build a new CLI tool that requires fast startup, TypeScript support, and single-executable bundling?
**Depth**: Deep
**Key finding**: Bun is the stronger choice for this specific use case -- its faster startup (~18ms vs ~42ms), more mature single-executable compilation, and richer asset embedding API give it a clear edge for CLI tools, despite Deno's advantages in security and built-in tooling.
**Open questions**: 3 -- see end of document

---

## Overview

Both Bun (v1.3.10, March 2026) and Deno (v2.7.7, March 2026) are actively maintained, TypeScript-native runtimes that can compile to single executables. They take fundamentally different architectural approaches:

- **Bun** is built on Zig + JavaScriptCore (WebKit's JS engine). Philosophy: raw speed and Node.js compatibility.
- **Deno** is built on Rust + V8 (Chrome's JS engine). Philosophy: security-by-default and web standards alignment.

For a CLI tool with the stated requirements (fast startup, TypeScript, single executable), the comparison reduces to three decisive dimensions and several secondary ones:

```
Decisive dimensions:
  1. Startup performance
  2. Single-executable compilation maturity
  3. TypeScript development experience

Secondary dimensions:
  4. Binary size
  5. Cross-compilation support
  6. Security model
  7. Ecosystem & CLI libraries
  8. Stability & production readiness
```

---

## Findings

### 1. Startup Performance

This is Bun's strongest advantage and it matters most for CLI tools, where users feel every millisecond.

| Runtime | Startup time (hello world) | Engine | Source |
|---------|---------------------------|--------|--------|
| Bun     | ~8-18ms | JavaScriptCore | Multiple benchmarks (pullflow.com, medium.com/@sonampatel) |
| Deno    | ~40-60ms | V8 | Same benchmarks |
| Node.js | ~60-120ms | V8 | Same benchmarks (for reference) |

The gap is architectural: JavaScriptCore has a fundamentally faster cold-start than V8. This is not something Deno can close without changing engines. (verified: consistent across multiple independent 2025 benchmarks)

**Caveat**: One AWS Lambda cold-start benchmark from Deno's own blog showed Deno beating Bun in Linux VM cold starts. The difference likely comes from measurement methodology (Lambda container initialization vs. bare process startup). For a local CLI tool, the bare startup measurement is the relevant one.

**Verdict**: Bun wins decisively. For a CLI that runs, executes a task, and exits, the 3-5x startup advantage is perceptible to users.

### 2. Single-Executable Compilation

Both runtimes support `compile` commands that bundle the runtime + your code into a single binary. The maturity and capabilities differ.

#### Bun: `bun build --compile`

```bash
bun build --compile ./cli.ts --outfile mycli
```

Key capabilities:
- **Asset embedding**: First-class support via `import icon from "./icon.png" with { type: "file" }` and `Bun.embeddedFiles` API. Can also embed multiple files via entrypoint globs: `bun build --compile ./main.ts ./templates/**/*.html` (verified: official docs at bun.com/docs/bundler/executables)
- **Minification**: `--minify` flag for smaller output
- **Programmatic API**: `Bun.build({ compile: { outfile, target } })` -- can script the build
- **Windows-specific features**: custom icons, metadata (but not available during cross-compilation)

Limitations:
- No `--no-bundle` option -- everything is always bundled
- Cannot use `--outdir`, only `--outfile` (unless using `--splitting`)
- Historical `process.argv` bugs in compiled binaries (e.g., extra argument in v1.2.21, fixed in later versions) (verified: GitHub issue #22157)

#### Deno: `deno compile`

```bash
deno compile --output mycli main.ts
```

Key capabilities:
- **Asset embedding**: `--include <path>` flag (added in Deno 2.1). Can include files and directories. (verified: official docs at docs.deno.com/runtime/reference/cli/compile)
- **Self-extracting mode**: `--self-extracting` flag extracts embedded files to disk at runtime -- useful for native addons that need real filesystem paths
- **Permission baking**: Runtime permissions (e.g., `--allow-read`, `--allow-net`) are baked into the binary at compile time
- **Custom icons**: `--icon icon.ico` for Windows executables
- **FFI and native addon support**: Deno 2.3+ supports compiling programs that use FFI and Node native addons (verified: Deno 2.3 release notes)

Limitations:
- Asset embedding via `--include` had bugs with JS-like files (GitHub issue #28843)
- No programmatic build API equivalent to `Bun.build()`
- Monorepo setups can bundle entire `node_modules`, inflating binary size (GitHub issue #30134)

**Verdict**: Bun's asset embedding is more mature and ergonomic (import-based vs. flag-based). Deno's permission-baking is a unique advantage for security-sensitive CLIs. Both are production-viable for CLI compilation.

### 3. TypeScript Development Experience

Both run TypeScript directly without external tooling. The approaches differ:

| Aspect | Bun | Deno |
|--------|-----|------|
| Transpilation | Strips types, runs immediately (fastest) | Transpiles via SWC, runs immediately |
| Type checking | Delegated to external `tsc` | Built-in `deno check` command |
| Config | Reads `tsconfig.json`, provides sensible defaults | Reads `deno.json` or `tsconfig.json` |
| Import style | Node-style (`import x from "pkg"`) + npm | URL imports, `npm:` specifier, or import maps |
| LSP | Works with standard TS LSP | Ships its own LSP (`deno lsp`) |

(verified: Bun docs, Deno docs, betterstack.com comparison)

For a CLI tool developer:
- **Bun** feels like "TypeScript that just works" with zero config. If you're coming from Node.js, there's nearly zero learning curve.
- **Deno** adds built-in type checking (no need for separate `tsc` step), but its import system (`npm:` prefixes, URL imports) requires adjustment.

**Verdict**: Roughly equal, with different tradeoffs. Bun is simpler if you want Node-style ergonomics. Deno is better if you want type checking integrated into the runtime.

### 4. Binary Size

Both produce large binaries because they embed their entire runtime. This is a weakness shared by both -- neither is "small" by Go/Rust standards.

| Runtime | Hello-world binary (macOS ARM64) | Notes |
|---------|----------------------------------|-------|
| Bun     | ~57 MB | Includes full JavaScriptCore engine |
| Deno    | ~58 MB (v1.41), ~80 MB (v2.x) | Includes slimmed V8 (`denort`) |
| Go      | ~2-5 MB | For reference |

(verified: Bun docs, Deno v1.41 release notes, GitHub discussions)

Bun's binaries are slightly smaller than Deno 2's. One migration case study reported a **9x size reduction** when moving from Deno to Bun for a single binary CLI (zenn.dev/dyoshikawa), though specific numbers were not available from the search.

The Tigris CLI team reported their Bun-compiled binary at ~60 MB -- "large but acceptable" given that users no longer needed Node.js installed. (verified: tigrisdata.com blog)

**Verdict**: Bun has a slight edge. Neither is great. If binary size is a hard constraint (e.g., <10 MB), neither runtime is suitable -- use Go or Rust.

### 5. Cross-Compilation Support

Both support compiling for platforms other than the host.

| Target | Bun | Deno |
|--------|-----|------|
| macOS x64 | `bun-darwin-x64` | `x86_64-apple-darwin` |
| macOS ARM64 | `bun-darwin-arm64` | `aarch64-apple-darwin` |
| Linux x64 | `bun-linux-x64` | `x86_64-unknown-linux-gnu` |
| Linux ARM64 | `bun-linux-arm64` | `aarch64-unknown-linux-gnu` |
| Windows x64 | `bun-windows-x64` | `x86_64-pc-windows-msvc` |
| Windows ARM64 | `bun-windows-arm64` | Not listed in current docs |
| Linux musl (Alpine) | `bun-linux-x64-musl`, `bun-linux-arm64-musl` | Not listed in current docs |

(verified: Bun official docs via context7, Deno official docs via context7)

Bun offers **13 target variants** (including musl for Alpine Linux and CPU baseline/modern variants). Deno offers **~6 targets**. Bun's musl support is notable for Docker/Alpine deployments.

Bun limitation: Windows-specific flags (icon, metadata) don't work during cross-compilation. (verified: Bun docs)

**Verdict**: Bun has broader cross-compilation target coverage, especially for Linux containers (musl) and CPU variant optimization.

### 6. Security Model

| Aspect | Bun | Deno |
|--------|-----|------|
| Default permissions | Full access (like Node.js) | No access (secure by default) |
| Permission flags | None | `--allow-read`, `--allow-net`, `--allow-env`, etc. |
| Compiled binary permissions | N/A -- full access | Baked in at compile time |
| Supply chain protection | None built-in | Sandboxed by default |

For a CLI tool you're writing yourself, Deno's permission model is less critical (you trust your own code). It becomes valuable when:
- Your CLI uses third-party npm packages that could be compromised
- You want to guarantee users that your CLI only accesses what it declares

**Verdict**: Deno wins on security. For most CLI tools, this is a secondary concern unless you're building for security-conscious users or handling sensitive data.

### 7. Ecosystem & CLI Libraries

**Argument parsing**:

| Library | Bun | Deno |
|---------|-----|------|
| `util.parseArgs` (Node built-in) | Supported | Supported via Node compat |
| `@std/cli/parse-args` (Deno std) | N/A | Native, based on minimist |
| `commander` (npm) | Supported | Supported via `npm:commander` |
| `yargs` (npm) | Supported | Supported via `npm:yargs` |
| `cliffy` (Deno-native) | N/A | Native, Commander.js-inspired |

Both have access to the npm ecosystem. Deno additionally has JSR (its own registry) and Deno-native packages like cliffy.

**CLI frameworks**:
- Bun: `bunli` (Bun-native CLI framework with plugins, terminal UI)
- Deno: `cliffy` (well-established, type-checked, shell completions)

**Built-in tooling**:
- Bun: runtime, bundler, test runner, package manager
- Deno: runtime, formatter (`deno fmt`), linter (`deno lint`), test runner, doc generator, benchmarker, LSP -- more batteries included

**Verdict**: Deno has more built-in tooling. Both have adequate CLI library ecosystems. For CLI development specifically, the difference is minor.

### 8. Stability & Production Readiness

| Signal | Bun | Deno |
|--------|-----|------|
| Current version | v1.3.10 (March 2026) | v2.7.7 (March 2026) |
| LTS policy | None | 6-month LTS cycle (since v2.1.0) |
| Open issues | ~4,800 | Fewer (exact count not verified) |
| Backing | Anthropic (investment), Oven Inc | Deno Company |
| npm compatibility | ~95% | Full via `npm:` specifier |
| Known pain points | Occasional process.argv bugs in compiled binaries, Windows quirks | Monorepo compile bloat, --include bugs with JS files |

(verified: GitHub repos, dev.to assessments, Deno stability docs)

The consensus from multiple 2025-2026 assessments: Bun is production-ready for CLI tools (this was called out as one of Bun's strongest use cases). Deno is more mature overall with LTS support, but both are viable.

**Verdict**: Deno is more mature institutionally (LTS, fewer open issues). Bun is specifically well-suited for CLI tools despite its younger ecosystem.

---

## Recommendation

For a CLI tool prioritizing **fast startup, TypeScript, and single-executable bundling**, **Bun is the stronger choice**:

1. **Startup time**: 3-5x faster than Deno. This is the single most important metric for CLI UX and Bun's architectural advantage (JavaScriptCore) is durable.
2. **Compile maturity**: Bun's asset embedding (`import with { type: "file" }`, `Bun.embeddedFiles`) is more ergonomic than Deno's `--include` flag. Programmatic build API enables sophisticated build scripts.
3. **Cross-compilation**: 13 targets vs ~6, including musl for Alpine Linux containers.
4. **Ecosystem friction**: Zero learning curve from Node.js. Standard `import` syntax, `package.json`, npm packages work directly.

**Choose Deno instead if**:
- Security is a primary requirement (permission model baked into compiled binaries)
- You want built-in type checking without external `tsc`
- You prefer web-standard APIs and URL-based imports
- LTS stability guarantees matter more than raw speed
- You're already in the Deno ecosystem (JSR packages, Fresh, etc.)

**Neither is a good choice if**:
- Binary size must be under 10 MB (use Go or Rust)
- You need deterministic memory behavior (use a compiled language)
- Startup must be under 5ms (use a compiled language)

---

## Contradictions & Tensions

1. **Startup benchmarks conflict**: Most benchmarks show Bun at 8-18ms and Deno at 40-60ms, but Deno's own AWS Lambda benchmark showed Deno with faster cold starts than Bun. Resolution: these measure different things. Lambda cold start includes container initialization; bare startup measures process spawn to first output. For a CLI tool, bare startup is the relevant metric. The Bun advantage is real for CLI use cases. (partially resolved -- would need to run both on the same machine to fully verify)

2. **Binary size reports vary widely**: Sources cite Bun at 57-60 MB and Deno at 58-80 MB depending on version. The zenn.dev article claimed 9x reduction from Deno to Bun, which would imply Deno was ~500 MB and Bun ~55 MB -- this seems implausible and may involve different compilation approaches or npm dependency bundling. (unresolved -- original article not fully accessible)

3. **Stability narratives conflict**: Some sources call Bun "production ready in 2026" while others point to 4,800 open issues as concerning. Resolution: both are true simultaneously. Bun is stable for CLI tools (a well-exercised path), but has rough edges in less common scenarios (complex Node.js compatibility, Windows edge cases). For the stated use case, stability is adequate.

---

## Challenge

**Weakest conclusion**: My claim that Bun's startup advantage is "durable" assumes Deno won't adopt a tiered compilation strategy or startup cache that closes the gap. V8 has been investing in startup optimization (e.g., code caching, snapshot deserialization). Deno could narrow the gap significantly in future versions, though matching JavaScriptCore's cold start from a fundamentally larger engine seems unlikely.

**What I didn't check**:
- Actual binary sizes on the same machine with the same test program (all numbers are from different sources/environments)
- Memory usage comparison during CLI execution (may matter for memory-constrained environments)
- Specific behavior of compiled binaries when using native npm packages with C++ addons

---

## Open Questions

1. **Memory usage in compiled binaries**: How much RAM does a compiled Bun CLI use vs a compiled Deno CLI for equivalent workloads? JavaScriptCore is generally lighter, but this wasn't verified with specific measurements.

2. **Bun compile + native npm packages**: If the CLI needs packages with native bindings (e.g., `better-sqlite3`, `sharp`), does `bun build --compile` handle them correctly? Deno 2.3+ explicitly added this support. Bun's status is less clearly documented.

3. **Long-term maintenance trajectory**: Bun has no LTS policy and 4,800 open issues. For a CLI tool that will be maintained for years, will Bun's rapid iteration cycle cause breaking changes? Deno's 6-month LTS cycle provides more stability guarantees.

---

Sources:
- [Bun Single-file Executable Docs](https://bun.com/docs/bundler/executables)
- [Deno Compile Reference](https://docs.deno.com/runtime/reference/cli/compile/)
- [Self-contained Executable Programs with Deno Compile](https://deno.com/blog/deno-compile-executable-programs)
- [Deno vs Bun: TypeScript Development Compared (Better Stack)](https://betterstack.com/community/guides/scaling-nodejs/deno-vs-bun-typescript/)
- [Deno Vs Bun In 2025 (Pullflow)](https://pullflow.com/blog/deno-vs-bun-2025/)
- [Bun vs Node vs Deno Re-Ran Benchmarks (Medium)](https://medium.com/@sonampatel_97163/bun-vs-node-vs-deno-in-2025-i-re-ran-the-benchmarks-f955a04ee016)
- [Deno 2 vs Node.js vs Bun in 2026 (DEV Community)](https://dev.to/pockit_tools/deno-2-vs-nodejs-vs-bun-in-2026-the-complete-javascript-runtime-comparison-1elm)
- [From npm to a Single Binary: Tigris CLI (Tigris Blog)](https://www.tigrisdata.com/blog/using-bun-and-benchmark/)
- [Is Bun Production-Ready in 2026 (DEV Community)](https://dev.to/last9/is-bun-production-ready-in-2026-a-practical-assessment-181h)
- [Deno 1.41: Smaller Compile Binaries](https://deno.com/blog/v1.41)
- [Deno 2.3: Improved deno compile](https://deno.com/blog/v2.3)
- [How to Build CLI Applications with Bun](https://oneuptime.com/blog/post/2026-01-31-bun-cli-applications/view)
- [Build a Cross-Platform CLI with Deno](https://deno.com/blog/build-cross-platform-cli)
- [Deno Stability and Releases](https://docs.deno.com/runtime/fundamentals/stability_and_releases/)
- [Bun process.argv Bug in Compiled Binaries (GitHub #22157)](https://github.com/oven-sh/bun/issues/22157)
- [Reducing Binary Size 9x: Deno to Bun (zenn.dev)](https://zenn.dev/dyoshikawa/articles/deno-to-bun-single-binary?locale=en)
- [Deno 2.7: Temporal, Windows ARM](https://www.basantasapkota026.com.np/2026/03/deno-27-temporal-stable-windows-arm-npm.html)

## 批注区
