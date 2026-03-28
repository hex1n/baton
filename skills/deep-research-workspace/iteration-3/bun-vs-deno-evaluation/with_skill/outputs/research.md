**Question**: Should I use Bun or Deno to build a new CLI tool that needs fast startup, TypeScript support, and single-binary distribution?
**Depth**: Deep
**Key finding**: Bun is the stronger choice for this specific use case — it wins on startup speed, binary size, and has proven CLI distribution at scale (Claude Code); Deno wins on security model and developer tooling completeness, but those advantages matter less for a CLI tool scenario.
**Open questions**: 3 — see end of document

---

# Bun vs Deno for CLI Tool Development

## Overview

Both Bun and Deno are modern JavaScript/TypeScript runtimes that natively support TypeScript and can compile to single-binary executables. However, they are optimized for different things: Bun prioritizes raw speed and Node.js compatibility; Deno prioritizes security, standards compliance, and developer tooling completeness. For a CLI tool with the stated requirements (fast startup, TypeScript, single binary), these different priorities produce meaningful differences.

```
                   Bun                              Deno
            +-----------------+              +-----------------+
  Engine:   | JavaScriptCore  |    Engine:   |       V8        |
            | (Safari/WebKit) |              |    (Chrome)     |
            +-----------------+              +-----------------+
  Language: |      Zig        |    Language: |      Rust       |
            +-----------------+              +-----------------+
  Owner:    |   Anthropic     |    Owner:    |   Deno Company  |
            | (acq. Dec 2025) |              | ($30.9M raised) |
            +-----------------+              +-----------------+
  Version:  |    v1.3.11      |    Version:  |     v2.7.7      |
            +-----------------+              +-----------------+
```

## Findings

### 1. Startup Time

This is the most straightforward dimension and the one with the clearest winner.

| Runtime | Startup Time (benchmark) | Engine | Source |
|---------|-------------------------|--------|--------|
| Bun | ~18ms | JavaScriptCore | (verified: web search, multiple benchmark articles from 2025) |
| Deno | ~42ms | V8 | (verified: web search, multiple benchmark articles from 2025) |

Bun is roughly 2x faster at cold startup. This comes from JavaScriptCore's architecture, which is optimized for fast startup (Safari needs this for web pages), while V8 is optimized for peak throughput after warmup.

For a CLI tool that runs and exits quickly, startup time dominates the user experience. An 18ms startup feels instant; 42ms also feels instant for most use cases but the gap compounds when your CLI is invoked repeatedly (e.g., in scripts, watch mode, or shell pipelines).

**Nuance**: In AWS Lambda cold-start benchmarks, Deno actually beats Bun (verified: Deno blog on Lambda cold start benchmarks). The inversion happens because Lambda cold starts include dependency resolution and initialization patterns that favor Deno's module system. For a compiled single-binary CLI, this Lambda advantage is irrelevant — the binary has everything bundled.

**Verdict**: Bun wins on startup. The margin matters for CLI tools.

### 2. TypeScript Support

Both runtimes execute TypeScript directly without a build step. The differences are in implementation approach:

| Dimension | Bun | Deno |
|-----------|-----|------|
| Execution | Native transpiler (Zig) strips types, runs via JSC | SWC (Rust) strips types, runs via V8 |
| Type checking | Not built-in; relies on external `tsc` | Built-in `deno check` (bundles TypeScript compiler) |
| Config required | Zero config | Zero config |
| JSX/TSX | Native support, no config | Native support, no config |
| Decorators | TC39 standard decorators supported (verified: Bun v1.3.10 blog) | Supported |

Both are excellent for TypeScript CLI development. The key difference: Deno includes a built-in type checker (`deno check`), while Bun requires running `tsc` separately for type checking. For a CLI project, this is a minor convenience difference — you'll likely have `tsc` in your dev workflow regardless.

**Verdict**: Tie. Both provide first-class TypeScript support. Deno has a slight edge in tooling completeness (built-in type checker, formatter, linter), but it doesn't materially affect the CLI development experience.

### 3. Single-Binary Compilation

This is the dimension with the most significant practical differences.

#### Binary Size

| Runtime | Hello World Binary (macOS ARM64) | Source |
|---------|----------------------------------|--------|
| Bun | ~57 MB | (verified: web search, multiple sources including GitHub issues) |
| Deno | ~80 MB (Deno 2.x) | (verified: web search, Deno blog and community discussions) |

Both produce large binaries because they embed the entire runtime. Bun's binaries are consistently smaller.

A real-world migration story is striking: one developer reported a **9x size reduction** switching from `deno compile` to `bun build --compile` for the same application (verified: zenn.dev article "Reducing Single Binary Size by 9x: Migrating from Deno to Bun"). The 9x factor comes from Deno's compile not performing tree-shaking or minification — it embeds source code and all npm packages as-is. Bun applies bundling and `--minify` to the output, stripping unused code.

For a production CLI tool like Claude Code (Anthropic's CLI), the Bun-compiled binary is ~100MB (verified: frr.dev blog post on Claude Code native build). This is a substantial application with many dependencies — for simpler CLI tools, expect 50-60MB.

#### Cross-Compilation Targets

| Target | Bun | Deno |
|--------|-----|------|
| Linux x64 | Yes | Yes |
| Linux ARM64 | Yes | No (not listed in official targets) |
| macOS x64 | Not listed separately (Intel Macs) | Yes |
| macOS ARM64 | Yes | Yes |
| Windows x64 | Yes | Yes |
| Windows ARM64 | No | Yes (added in Deno 2.7, Feb 2026) |

Both support the major targets. Bun has Linux ARM64 which Deno lacks; Deno has Windows ARM64 which Bun lacks. Choose based on your distribution targets.

#### Compilation Features

| Feature | Bun | Deno |
|---------|-----|------|
| Embedded files/assets | Yes (`Bun.embeddedFiles`) | Yes (`--include` flag) |
| Minification | Yes (`--minify` flag) | No native minification |
| Tree-shaking | Yes (bundler does this) | No (embeds source as-is) |
| Code signing | Not documented | Supported on Windows (icons too) |
| Sourcemaps | Supported (`--compile` + sourcemaps in v1.3.10) | Not documented for compile |

**Verdict**: Bun wins on binary compilation. Smaller binaries, better optimization (minification + tree-shaking), and proven at massive scale (Claude Code ships as a Bun single-binary to millions of users).

### 4. Ecosystem & npm Compatibility

| Dimension | Bun | Deno |
|-----------|-----|------|
| npm package support | High — drop-in for most packages | Full — `npm:` specifiers, package.json, node_modules (since Deno 2) |
| Node.js API coverage | ~98% of test suite on macOS/Linux (verified: Bun blog) | Extensive, actively improving (verified: Deno docs) |
| Native addons (N-API) | Partial — 34% native dependency compatibility rate reported (verified: dev.to article) | Supported (Node-API native addons) |
| Package manager | Built-in (`bun install`, 25x faster than npm claimed) | Built-in (`deno install`, 15-90% faster than npm claimed) |
| CLI libraries (Commander, Yargs) | Work via npm compat | Work via `npm:` specifiers |

For CLI development specifically, the key question is: do the npm packages you need work? Commander.js and Yargs (the two most popular CLI frameworks) work on both runtimes. For common CLI dependencies (chalk, ora, inquirer, etc.), both runtimes have good compatibility.

Deno additionally has its own standard library with CLI utilities like `@std/cli/parse-args` for argument parsing, which means you can build a CLI without any npm dependencies at all (verified: Deno docs).

**Verdict**: Rough tie. Bun has broader Node.js compatibility out of the box; Deno has a richer standard library that reduces dependency on npm. For CLI tools, both ecosystems have what you need.

### 5. Developer Experience for CLI Development

| Dimension | Bun | Deno |
|-----------|-----|------|
| Built-in test runner | Yes | Yes |
| Built-in formatter | No (use Prettier) | Yes (`deno fmt`) |
| Built-in linter | No (use ESLint) | Yes (`deno lint`) |
| Watch mode | Yes (`--watch`) | Yes (`--watch`) |
| REPL | Yes (native, added recently) | Yes |
| Standard library | Minimal | Comprehensive (audited, versioned) |
| Security model | None (full access by default) | Permission-based (explicit `--allow-*` flags) |

Deno's built-in toolchain (formatter, linter, test runner, type checker) means fewer dev dependencies. For a CLI tool, this reduces setup friction. Bun requires setting up Prettier + ESLint separately, which is standard but adds config files.

Deno's permission model is theoretically valuable for a CLI tool — you can restrict what the compiled binary can access. In practice, most CLI tools need broad permissions (file system, network, environment variables), so you'll often end up with `--allow-all` or a long list of flags. When compiling with `deno compile`, permissions are baked into the binary.

**Verdict**: Deno has a more complete built-in toolchain. This matters for developer ergonomics but doesn't affect the end-user CLI experience.

### 6. Platform Support & Stability

| Dimension | Bun | Deno |
|-----------|-----|------|
| macOS | Stable | Stable |
| Linux | Stable | Stable |
| Windows | Supported since v1.1; x64 only; 98% test pass rate | Stable; x64 + ARM64 (v2.7+) |
| Open issues (GitHub) | ~4,800 (verified: GitHub issues page) | Fewer (more mature issue triage) |
| LTS program | No formal LTS | Yes — 6-month backport cycle (verified: Deno docs) |
| Maturity | v1.3.x (GA since Sep 2023) | v2.7.x (GA v1.0 since 2020, v2.0 since Oct 2024) |

Deno is more mature and has stronger production stability signals (LTS program, longer track record, fewer open issues proportionally). Bun is moving fast but carries more risk of encountering edge-case bugs, especially on Windows.

**Verdict**: Deno wins on stability and maturity. Bun wins on momentum (Anthropic backing, rapid development).

### 7. Governance & Long-Term Viability

| Dimension | Bun | Deno |
|-----------|-----|------|
| Owner | Anthropic (acquired Dec 2025) | Deno Company (independent, $30.9M raised from Sequoia et al.) |
| License | MIT | MIT |
| Business model | Powers Claude Code and Anthropic's AI products | Deno Deploy (cloud hosting) + JSR (package registry) |
| Open governance | MIT licensed, corporate-driven | JSR has independent governance board; Deno itself is company-driven |

Bun's acquisition by Anthropic is a double-edged sword:
- **Upside**: massive resources, proven production usage (Claude Code at $1B run-rate revenue), strong incentive to keep Bun excellent for CLI/binary distribution.
- **Downside**: Bun's roadmap is now tied to Anthropic's needs. If Anthropic's priorities diverge from general-purpose CLI tool development, community features could lag.

Deno's independence means its roadmap is driven by the broader developer community and Deno Deploy business, but $30.9M in funding is modest compared to Anthropic's resources.

**Verdict**: Both have credible long-term viability. Bun has more resources but less independence; Deno has more independence but fewer resources.

## Comparison Summary

| Criterion | Bun | Deno | Weight for CLI |
|-----------|-----|------|----------------|
| Startup time | **Win** (~18ms) | ~42ms | High |
| TypeScript | Tie | Tie | Medium (both excellent) |
| Binary size | **Win** (~57MB, with tree-shaking) | ~80MB (no tree-shaking) | High |
| Binary optimization | **Win** (minify, tree-shake, embed) | Basic (embed only) | High |
| Cross-compilation | Tie (different targets) | Tie (different targets) | Medium |
| npm compatibility | Slight edge | Good (since Deno 2) | Medium |
| Built-in toolchain | Basic | **Win** (fmt, lint, check, test) | Low (dev-time only) |
| Security model | None | **Win** (permissions) | Low (most CLIs need full access) |
| Stability/maturity | Good | **Win** (LTS, longer track record) | Medium |
| Proven at scale for CLI | **Win** (Claude Code) | No comparable example | High |

## Recommendation

**Use Bun** for this project.

The three stated requirements — fast startup, TypeScript support, single-binary distribution — all favor Bun:

1. **Fast startup**: Bun is ~2x faster at cold start. For a CLI tool, this is the most user-facing performance metric.
2. **TypeScript**: Both are excellent; no differentiator.
3. **Single binary**: Bun produces smaller binaries (potentially much smaller for apps with many npm dependencies), applies tree-shaking and minification, and has been proven at massive scale with Claude Code's distribution to millions of users.

**When to choose Deno instead**:
- If your CLI needs to run on Windows ARM64 (Deno supports it; Bun doesn't).
- If the security permission model is important to your users (e.g., a CLI that processes untrusted plugins).
- If you strongly prefer zero-config linting/formatting/testing without setting up additional tools.
- If you want an LTS release cadence for long-term maintenance predictability.

**Assumptions this recommendation rests on**:
- The CLI targets macOS, Linux, and/or Windows x64 (not Windows ARM).
- Binary size between 50-100MB is acceptable for your distribution model.
- You're comfortable with Bun's current maturity level (~4,800 open issues, no LTS program).
- Your npm dependencies are in the well-supported majority (not native addons with low compat rates).

## Contradictions & Tensions

1. **Startup benchmarks vary by methodology.** The 18ms vs 42ms numbers come from synthetic benchmarks. In AWS Lambda cold starts, Deno actually beats Bun. The key question is: which benchmark matches your workload? For a compiled single-binary CLI that runs locally, the synthetic startup benchmark is the relevant one. But if your CLI will also run in serverless environments, test both.

2. **Binary size: 9x claim vs baseline comparison.** The 9x size reduction from Deno to Bun was reported for a specific application with many npm dependencies. For a hello-world, the ratio is closer to 1.4x (57MB vs 80MB). The gap widens with more dependencies because Deno doesn't tree-shake. Your actual ratio depends on your dependency graph.

3. **"4,800 open issues" vs "production-proven."** Bun has many open issues AND powers a billion-dollar product (Claude Code). These aren't contradictory — Claude Code exercises specific code paths heavily, while the long tail of Node.js API compatibility creates many issues. The risk is that your CLI hits a code path that Claude Code doesn't.

## Challenge

**Weakest conclusion**: The startup time advantage (18ms vs 42ms) is from 2025 benchmark articles, not from tests I ran. Both numbers are below human perception threshold (~100ms), so the practical difference for a typical interactive CLI invocation may be negligible. The advantage becomes real only for repeated rapid invocations (scripts, pipelines, watch mode). If your CLI is invoked once per user action (not in a tight loop), this advantage is less decisive than I've weighted it.

**Most important thing I didn't check**: I didn't verify the actual npm packages you plan to use work correctly with Bun's `--compile`. Some packages with native bindings or dynamic `require()` calls fail in compiled binaries. Before committing to Bun, test your actual dependency set with `bun build --compile` early in development.

## Open Questions

1. **What are your target platforms?** If Windows ARM64 is required, Deno is the only option. If Linux ARM64 is required, Bun is the only option.

2. **What npm packages will you use?** Test Commander/Yargs + your specific dependencies with `bun build --compile` before committing. Some packages that work fine at runtime fail when bundled into a compiled binary (dynamic imports, native addons, etc.).

3. **Is 50-100MB binary size acceptable?** Both runtimes produce large binaries. If you need sub-10MB binaries, neither runtime is appropriate — consider Go or Rust for the CLI instead.

---

Sources:
- [Bun Single-file Executable Docs](https://bun.com/docs/bundler/executables)
- [Deno Compile Docs](https://docs.deno.com/runtime/reference/cli/compile/)
- [Deno vs Bun in 2025 (Pullflow)](https://pullflow.com/blog/deno-vs-bun-2025/)
- [Bun vs Node vs Deno Benchmarks Re-ran (Medium, Jan 2026)](https://medium.com/@sonampatel_97163/bun-vs-node-vs-deno-in-2025-i-re-ran-the-benchmarks-f955a04ee016)
- [Reducing Single Binary Size by 9x: Deno to Bun (Zenn)](https://zenn.dev/dyoshikawa/articles/deno-to-bun-single-binary?locale=en)
- [Claude Code Native Build: 100MB Binary (frr.dev)](https://www.frr.dev/posts/claude-code-native-build-bun/)
- [Anthropic Acquires Bun (Anthropic)](https://www.anthropic.com/news/anthropic-acquires-bun-as-claude-code-reaches-usd1b-milestone)
- [Bun Joins Anthropic (Bun Blog)](https://bun.com/blog/bun-joins-anthropic)
- [Deno TypeScript Support Docs](https://docs.deno.com/runtime/fundamentals/typescript/)
- [Deno Security and Permissions](https://docs.deno.com/runtime/fundamentals/security/)
- [Deno 2.7 Release (Windows ARM, Temporal)](https://deno.com/blog/v2.7)
- [Deno Stability and Releases](https://docs.deno.com/runtime/fundamentals/stability_and_releases/)
- [Bun Compatibility in 2026 (DEV Community)](https://dev.to/alexcloudstar/bun-compatibility-in-2026-what-actually-works-what-does-not-and-when-to-switch-23eb)
- [Bun v1.3.10 Blog](https://bun.com/blog/bun-v1.3.10)
- [Node and npm Compatibility in Deno](https://docs.deno.com/runtime/fundamentals/node/)
- [AWS Lambda Cold Start Benchmarks (Deno Blog)](https://deno.com/blog/aws-lambda-coldstart-benchmarks)
- [Tigris CLI: From npm to Single Binary with Bun](https://www.tigrisdata.com/blog/using-bun-and-benchmark/)
- [Deno Company Funding (Crunchbase)](https://www.crunchbase.com/organization/deno-b57a)
- [Reports of Deno's Demise Greatly Exaggerated (Deno Blog)](https://deno.com/blog/greatly-exaggerated)
