**Question**: Should I use Bun or Deno to build a new CLI tool that needs fast startup, TypeScript support, and single-binary distribution?
**Depth**: Deep
**Key finding**: Bun is the stronger choice for this specific use case -- its startup speed advantage is decisive for CLI tools, and its compilation pipeline is battle-tested at scale (Claude Code ships as a Bun single-file executable to millions of users).
**Open questions**: 3 -- see end of document

---

# Bun vs Deno for a CLI Tool: Deep Investigation

## Recommendation

**Use Bun.** For a CLI tool where fast startup, TypeScript, and single-binary distribution are the primary requirements, Bun's advantages are structural, not marginal:

1. **Startup time** -- Bun's JavaScriptCore engine starts in ~10-18ms vs Deno's ~40ms on V8. For a CLI tool that users invoke repeatedly, this 2-4x difference is perceptible.
2. **Proven at scale** -- Claude Code (Anthropic's billion-dollar-ARR CLI product) ships as a `bun build --compile` binary to millions of developers across macOS, Linux, and Windows. This is the strongest possible validation of the compilation pipeline for CLI distribution.
3. **Corporate backing** -- Anthropic acquired Bun (Oven) in December 2025. The runtime is now funded by one of the largest AI companies, with a direct business incentive to keep it working for CLI distribution.

Deno is a strong runtime with better security defaults and more complete built-in tooling, but those advantages matter less for a CLI tool you control end-to-end.

---

## Detailed Comparison

### 1. Startup Time

| Metric | Bun | Deno |
|--------|-----|------|
| Cold start (hello world) | ~10-18ms | ~40-42ms |
| Engine | JavaScriptCore (faster init) | V8 (slower init, faster peak throughput) |
| Bytecode caching | `--bytecode` flag at compile time | V8 code cache (5-240% improvement) |

Bun's startup advantage comes from JavaScriptCore's architecture, which initializes faster than V8. For long-running servers this difference is negligible, but for CLI tools invoked hundreds of times per day, the difference between 10ms and 40ms is the difference between "instant" and "noticeable."

(verified: Bun official docs describe JavaScriptCore startup advantage; benchmark numbers from multiple independent sources including pullflow.com comparison and Medium re-run benchmarks from Jan 2026)

**Caveat**: One benchmark showed Bun at ~10ms vs Node at 4ms for a specific micro-test, suggesting results vary by workload. AWS Lambda cold start benchmarks showed Deno winning in that specific environment. Startup time is workload-dependent, but for local CLI invocation, Bun consistently leads.

### 2. TypeScript Support

| Feature | Bun | Deno |
|---------|-----|------|
| Native execution of .ts | Yes | Yes |
| Type checking at runtime | No (strips types, transpile only) | No by default (`deno run` skips checking) |
| Built-in type checker | No -- requires `tsc --noEmit` separately | Yes -- `deno check` subcommand |
| Transpiler engine | Custom Zig-based (esbuild architecture) | swc-based |
| tsconfig required | Optional (sensible defaults) | Optional (sensible defaults, strict mode) |
| JSX/TSX support | Native | Native |

Both runtimes execute TypeScript directly without configuration. The practical difference: Deno ships a `deno check` command that can type-check your code without a separate `tsc` install, while Bun requires you to run `tsc --noEmit` yourself.

For a CLI tool project, this distinction is minor -- you'll have `tsc` in your dev dependencies regardless for CI/CD. Neither runtime type-checks at execution time by default.

(verified: Bun official TypeScript docs confirm transpile-only approach; Deno official docs confirm `deno check` subcommand and default skip-checking behavior of `deno run`)

### 3. Single-Binary Compilation

This is the most critical dimension for the user's requirements. Both runtimes support compiling to standalone executables.

| Feature | Bun (`bun build --compile`) | Deno (`deno compile`) |
|---------|----------------------------|----------------------|
| Binary size (hello world, macOS ARM) | ~57MB | ~58MB |
| Cross-compilation | Yes (`--target` flag) | Yes (`--target` flag, all targets from any host) |
| Asset embedding | Yes (`with { type: "file" }`, `Bun.embeddedFiles`) | Yes (`--include` flag, virtual filesystem) |
| npm package support in binary | Yes (bundled at compile time) | Yes (since Deno 1.34, improved in Deno 2+) |
| Bytecode pre-compilation | Yes (`--bytecode` flag) | Yes (V8 code cache) |
| Code signing / custom icons | Limited (Windows flags not available in cross-compile) | Yes (since Deno 2) |
| FFI / native addons in binary | Limited | Yes (since Deno 2.3) |
| Self-extracting mode | No | Yes (`--self-extracting` flag) |

**Binary sizes are comparable** -- both produce ~57-60MB binaries for a hello world. This is because both embed their full runtime (JavaScriptCore for Bun, V8 + Deno runtime for Deno). For a real CLI tool with dependencies, expect 60-100MB.

**Cross-compilation**: Deno claims support for all targets from any host platform. Bun supports cross-compilation but has documented limitations -- Windows-specific flags don't work in cross-compile mode, and users may encounter "Illegal instruction" errors on certain x64 targets if they don't use the baseline variant.

**Asset embedding**: Both support embedding files. Bun uses import attributes (`with { type: "file" }`) and glob patterns. Deno uses the `--include` flag. Deno 2.1 overhauled its infrastructure for this, and Deno 2.4 added `--unstable-raw-imports` for direct text/bytes imports. Both approaches work, but Bun's approach is more code-level (import-based) while Deno's is more CLI-level (flag-based).

**Real-world validation**: Claude Code ships as a `bun build --compile` binary (~100MB) to millions of users across all three major platforms. This is the largest known deployment of a Bun-compiled CLI binary. No equivalent scale deployment exists for `deno compile`.

(verified: Bun blog "Bun is joining Anthropic"; Claude Code Native Build analysis on frr.dev; Bun official docs on executables; Deno official docs on compile)

### 4. Ecosystem and Libraries for CLI Development

| Concern | Bun | Deno |
|---------|-----|------|
| Argument parsing | `util.parseArgs` (Node compat), commander, yargs, meow, Clerc | `@std/flags` (standard library), cliffy |
| npm compatibility | Full (package.json, node_modules) | Since Deno 2 (npm: specifiers, node_modules support) |
| Standard library | Relies on npm ecosystem | Audited standard library (`@std/*`) |
| Package manager | Built-in (`bun install`, 25x faster than npm claimed) | Built-in (uses deno.json or package.json) |

For CLI tool development, both have access to the full npm ecosystem. Bun's npm compatibility is more seamless since it was designed for drop-in Node.js replacement. Deno 2 significantly improved npm compatibility, but edge cases may still exist.

Cliffy is the standout CLI framework for Deno -- TypeScript-first, with built-in command framework, prompts, tables, and ANSI utilities. It now also supports Bun and Node. For Bun, you'd typically use commander or yargs from the npm ecosystem.

### 5. Security Model

| Aspect | Bun | Deno |
|--------|-----|------|
| Default permissions | Full access (like Node.js) | No access (secure by default) |
| Granular permissions | No built-in model | Yes (`--allow-read`, `--allow-net`, etc.) |
| Permissions in compiled binary | N/A | Yes (baked into binary at compile time) |

Deno's permission model is a genuine advantage for security-sensitive applications. Permissions are baked into compiled binaries, meaning you can distribute a CLI tool that can only access what you explicitly allow.

For a CLI tool you're building and distributing yourself, this matters less -- you control the code and trust it. But if your CLI will be used in enterprise environments where security auditing matters, Deno's explicit permission model is a differentiator.

### 6. Platform Support and Stability

| Aspect | Bun | Deno |
|--------|-----|------|
| Current version | v1.3.10 (March 18, 2026) | v2.6+ (late 2025 / early 2026) |
| Open issues (GitHub) | ~4,900 | Fewer (more mature codebase) |
| Corporate backing | Anthropic (acquired Dec 2025) | Deno Land Inc ($30.9M total funding, Series A 2022) |
| Windows support | Improving, ARM64 added in v1.3.10 | Mature |
| Release cadence | Very frequent (weekly patches) | Regular (~6-week minor releases) |

**Bun's stability concern**: 4,900 open GitHub issues is a red flag that multiple commenters have raised. The pace of feature development has outrun stability in some areas, particularly on Windows. However, Anthropic's acquisition creates strong incentive to stabilize -- Claude Code's revenue depends on Bun working reliably.

**Deno's funding concern**: $30.9M total funding with the last known round in 2022 (Series A). The team is 11-50 people. This is adequate for open-source development but considerably less financial runway than Anthropic-backed Bun. However, Deno has been consistently shipping quality releases and has a strong track record of stability.

### 7. Developer Experience for CLI Tools

**Bun advantages:**
- Fastest `bun install` for dependency management during development
- Native bundler integrated -- no separate webpack/esbuild config needed
- `bun test` built-in for testing
- Familiar Node.js APIs reduce learning curve

**Deno advantages:**
- `deno fmt`, `deno lint`, `deno test`, `deno check` -- complete toolchain with zero config
- `deno.json` replaces package.json, tsconfig.json, and .eslintrc in one file
- URL-based imports (optional) eliminate dependency management entirely
- `deno doc` generates documentation from JSDoc comments
- `deno audit` (v2.6) for dependency security scanning

Deno provides a more cohesive, batteries-included developer experience. Bun provides a faster, more Node-compatible experience.

---

## Contradictions and Tensions

1. **Startup benchmarks vary by methodology.** Multiple sources cite Bun at ~18ms and Deno at ~42ms for cold start, but one AWS Lambda benchmark showed Deno winning on cold starts. The likely explanation: local execution favors Bun (JavaScriptCore init advantage), while containerized/Lambda environments may have different characteristics. For local CLI tools, the local benchmarks are more relevant.

2. **Binary size claims are inconsistent.** Bun binary sizes range from 51MB to 100MB across sources; Deno from 58MB to 80MB. The variation comes from different versions, platforms, and what's included. The reality: both produce binaries in the same order of magnitude (~60-100MB for real applications), and neither has a decisive advantage here.

3. **"Bun is unstable" vs "Claude Code runs on Bun."** Multiple articles express concern about Bun's 4.9k open issues and production readiness. Yet Claude Code -- a billion-dollar product -- ships on Bun. The resolution: Bun's instability is real but concentrated in edge cases (Windows, specific Node.js compat APIs). For a CLI tool's core path (startup, TypeScript execution, compilation), the critical path is well-tested by Claude Code's usage.

---

## Challenge: Weakest Conclusion

My weakest conclusion is the startup time comparison. I did not run benchmarks myself, and the cited numbers (10-18ms vs 40ms) come from third-party blog posts and comparison articles, not controlled experiments on identical hardware. The 2-4x advantage is directionally correct (JavaScriptCore vs V8 initialization is a well-understood architectural difference), but the specific millisecond figures could be different on the user's machine and workload. If startup time is truly the deciding factor, the user should benchmark their actual CLI entry point on both runtimes before committing.

The second weakness: I did not verify Deno's latest version number or check whether any post-2.6 release addressed compilation size. My Deno version information may be slightly stale.

---

## Open Questions

1. **What's the user's target platform mix?** If Windows is a primary target, Deno's more mature Windows support may outweigh Bun's startup advantage. Bun's Windows support has improved (ARM64 added in v1.3.10) but still has more reported issues.

2. **How large is the dependency tree?** Both runtimes produce ~60MB baseline binaries. With heavy npm dependencies, binary size could grow significantly. If distribution size is a hard constraint (e.g., <20MB), neither runtime works out-of-the-box -- you'd need to consider Go, Rust, or similar compiled languages instead.

3. **Will the CLI need native addons or FFI?** Deno 2.3 added FFI and Node native addon support in compiled binaries. Bun's support for this is more limited. If the CLI needs to call native libraries, this could be a differentiator.

---

## Source Audit

| Claim | Source | How obtained |
|-------|--------|-------------|
| Bun startup ~10-18ms, Deno ~40-42ms | Multiple comparison articles (pullflow.com, Medium re-run benchmarks Jan 2026, DEV Community) | Fetched via web search in this session |
| Bun compiled binary ~57MB (hello world, darwin-arm64) | Bun GitHub issue #5854, multiple articles | Fetched via web search in this session |
| Deno compiled binary ~58MB (hello world, Mac ARM, v1.41) | Deno official blog v1.41 | Fetched via web search in this session |
| Anthropic acquired Bun December 2025 | bun.com/blog/bun-joins-anthropic, anthropic.com/news | Fetched via web search in this session |
| Claude Code ships as bun build --compile binary | Bun blog, frr.dev analysis, Jarred Sumner on X | Fetched via web search in this session |
| Claude Code reached $1B ARR November 2025 | anthropic.com/news | Fetched via web search in this session |
| Deno total funding $30.9M, Series A June 2022 | Tracxn, PitchBook, Crunchbase search results | Fetched via web search in this session |
| Deno team size 11-50 | Tracxn profile | Fetched via web search in this session |
| Bun v1.3.10 released March 18, 2026 | Web search results referencing GitHub releases | Fetched via web search in this session |
| Bun has ~4,900 open GitHub issues | GitHub issue #27664 discussion | Fetched via web search in this session |
| Deno 2.6 includes tsgo (Go-based type checker) | Deno blog v2.6 | Fetched via web search in this session |
| Deno 2.3 added FFI/native addon support in compile | Deno blog v2.3 | Fetched via web search in this session |
| Deno 2.1 added asset embedding in compile | Deno blog v2.1 | Fetched via web search in this session |
| Bun's --bytecode flag for faster compiled startup | Bun official docs on executables | Fetched via web search in this session |
| V8 code cache gives 5-240% startup improvement | Deno blog / official docs | Fetched via web search in this session |
| AWS Lambda benchmark showed Deno winning cold starts | Deno blog (vendor benchmark) | Fetched via web search in this session |
| JavaScriptCore initializes faster than V8 | Multiple independent articles, architectural fact | Fetched via web search (multiple sources confirm) |
| Cliffy supports Bun, Deno, and Node | cliffy GitHub repo description | Fetched via web search in this session |
| Bun npm install 25x faster than npm | Multiple comparison articles | Fetched via web search in this session; vendor claim, not independently verified |

## 批注区
