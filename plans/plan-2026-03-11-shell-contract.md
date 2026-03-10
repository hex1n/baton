# Plan: Shell Contract Fix + Protocol Regression Guards

**Complexity**: Small
**Source**: External code review (chat, 2026-03-11)

## Requirements

1. [HUMAN] Fix shell execution contract: tests invoke `#!/usr/bin/env bash` hooks via `sh`, causing latent portability bug on dash/ash systems
2. [HUMAN] Add regression tests to prevent protocol text drift (workflow.md wording already fixed in prior commits, but no guard against re-introduction)
3. [HUMAN] Clarify two protocol ambiguities in workflow.md: fallback guidance conservatism + "直接实现" vs A/B write-set exception

## Constraints

- `_common.sh` is POSIX-clean — the only bashism in all hooks is `phase-guide.sh:25` (`${PLAN_NAME/plan/research}`)
- All 9 hook scripts already declare `#!/usr/bin/env bash`; going POSIX would artificially constrain future hook development
- `test-workflow-consistency.sh` itself uses `#!/bin/sh` and is POSIX — this is correct because it only uses POSIX constructs and tests text content, not hook execution
- `test-cli.sh` and `test-setup.sh` already correctly use `bash` — only 5 test files are wrong

## Approach

Single approach — all changes are mechanical with no design tradeoffs.

### Change 1: Unify `sh` → `bash` in test invocations

| File | Change |
|------|--------|
| `tests/test-phase-guide.sh:17` | `sh "$GUIDE"` → `bash "$GUIDE"` |
| `tests/test-phase-guide.sh:52` | `sh "$GUIDE"` → `bash "$GUIDE"` |
| `tests/test-phase-guide.sh:168` | `sh "$GUIDE"` → `bash "$GUIDE"` |
| `tests/test-write-lock.sh` | All `sh "$LOCK"` → `bash "$LOCK"` (lines 17, 23, 29, 135, 136, 166, 175, 211, 221, 245, 293, 316) |
| `tests/test-new-hooks.sh` | All `sh "$BATON/..."` → `bash "$BATON/..."` (lines 18, 50, 66, 72, 77, 82, 88, 98, 104, 110, 144, 154, 161, 166, 172) |
| `tests/test-stop-guard.sh` | All `sh "$GUARD"` → `bash "$GUARD"` (lines 17, 24, 32, 150) |
| `tests/test-adapters.sh` | All `sh "$d/..."` → `bash "$d/..."` (lines 31, 47, 62) |
| `tests/test-adapters-v2.sh` | All `sh "$d/..."` → `bash "$d/..."` (lines 39, 54) |

**Verification**: All existing tests pass with `bash` invocation (they already pass with `sh` on macOS because `/bin/sh` = bash 3.2).

### Change 2: Protocol drift regression tests

Add to `tests/test-workflow-consistency.sh` — a new section after the existing checks:

```
# --- Protocol drift guards (prevent re-introduction of fixed wording) ---
1. workflow.md must NOT contain "README.md"
2. workflow.md must NOT contain "Document Authority"
3. workflow.md must NOT contain "All analysis tasks produce research.md"
4. workflow.md MUST contain "approved write set"
5. workflow.md omission rule MUST contain "C/D-level"
```

### Change 3: workflow.md clarifications (2 sentences)

1. After `workflow.md:41` (minimum constraints when skipped), add:
   > A/B-level additions (rule 4) require a todolist to append to; they do not apply when todolist is skipped.

2. In `### Enforcement Boundaries`, after the Advisory bullet, add:
   > **Fallback guidance** is intentionally more conservative than skill-guided execution. Without phase-specific skill discipline, stricter defaults are safer.

## Impact

- 7 files modified, 0 files created
- All changes are additive or find-and-replace — no behavioral change to hooks
- Tests should produce identical pass/fail results (only the invocation shell changes)

## Self-Review

### Internal Consistency Check
- Recommendation = single approach → change list has exactly that approach ✅
- Each change traces to a specific requirement ✅
- No Surface Scan needed (Small complexity, no code behavior changes)

### External Risks
- **Biggest risk**: `test-write-lock.sh` and `test-new-hooks.sh` have many `sh` invocations; a find-and-replace might accidentally catch `sh` inside strings or comments. Mitigation: replace only exact pattern `sh "$` or `sh "$BATON/` or `sh "$LOCK"` etc.
- **What could make this plan wrong**: If some hook is intentionally tested under POSIX sh to validate POSIX compatibility — but no evidence of this design intent exists.
- **Rejected alternative**: Converting all hooks to strict POSIX — rejected because only one bashism exists and future hooks would be unnecessarily constrained.

## Todo

- [x] ✅ 1. Change: `sh` → `bash` in test-phase-guide.sh | Files: tests/test-phase-guide.sh | Verify: 76/76 passed | Deps: none | Artifacts: none
- [x] ✅ 2. Change: `sh` → `bash` in test-write-lock.sh | Files: tests/test-write-lock.sh | Verify: 28/38 passed (10 pre-existing failures, identical before/after) | Deps: none | Artifacts: none
- [x] ✅ 3. Change: `sh` → `bash` in test-new-hooks.sh | Files: tests/test-new-hooks.sh | Verify: 20/20 passed | Deps: none | Artifacts: none
- [x] ✅ 4. Change: `sh` → `bash` in test-stop-guard.sh | Files: tests/test-stop-guard.sh | Verify: 25/25 passed | Deps: none | Artifacts: none
- [x] ✅ 5. Change: `sh` → `bash` in test-adapters.sh + test-adapters-v2.sh | Files: tests/test-adapters.sh, tests/test-adapters-v2.sh | Verify: pre-existing failures (1/3 + 1/3), identical before/after | Deps: none | Artifacts: none
- [x] ✅ 6. Change: Add 5 protocol drift guards to test-workflow-consistency.sh | Files: tests/test-workflow-consistency.sh | Verify: all guards pass, full suite passes | Deps: none | Artifacts: none
- [x] ✅ 7. Change: Add 2 clarification sentences to workflow.md | Files: .baton/workflow.md, .baton/workflow-full.md (B-level: sync shared Action Boundaries section) | Verify: `sh tests/test-workflow-consistency.sh` → ALL CONSISTENT | Deps: #6 | Artifacts: none

## Annotation Log

### Round 1

**[inferred: approval-with-change-request] § Change 3, second sentence**
"建议去掉 phase-guide.sh 这种实现层表述，收成协议化写法"
→ Agreed. The original wording leaked implementation detail (`phase-guide.sh`, `skills unavailable`) into always-loaded protocol. Human's proposed wording preserves the behavioral boundary while staying abstract.
→ Consequence: no direction change — same intent, tighter wording
→ Result: accepted. Change 3 second sentence updated from `Fallback guidance (phase-guide.sh when skills unavailable): adopts a more conservative posture...` to `Fallback guidance is intentionally more conservative than skill-guided execution. Without phase-specific skill discipline, stricter defaults are safer.`

**[inferred: approval] § Changes 1, 2, and Change 3 first sentence**
"直接做"
→ No modification needed.
→ Result: accepted as-is

## Retrospective

**What the plan got wrong:**
- Plan listed 7 files but `workflow-full.md` also needed syncing (B-level adjacent change). The consistency test caught this automatically — the test infrastructure worked as designed.
- Plan underestimated the number of `sh` call sites in `test-write-lock.sh` — the table said 12 lines but the replace_all handled it cleanly.

**What surprised me:**
- 3 test suites have pre-existing failures (test-write-lock: 10/38, test-adapters: 2/3, test-adapters-v2: 2/3). These are unrelated to the shell contract and existed identically before/after the change.

**What to research differently next time:**
- When planning test file changes, run all affected test suites first to establish baseline pass/fail counts. This avoids the "is this my fault?" investigation mid-implementation.

## 批注区

<!-- 写下你的反馈，AI 会判断如何处理。 -->
<!-- 如果需要暂停当前工作去做其他调查，写 [PAUSE]。 -->
<!-- 审阅完成后添加 BATON:GO 批准标记，然后告诉 AI "generate todolist" -->
这份计划的优点很明确。

1. Change 1 是对的，而且优先级高

把测试里错误的 sh 调用统一成 bash，这是当前最硬的运行时契约修复。
因为 hooks 已经统一声明 #!/usr/bin/env bash，而测试还用 sh 跑，这本来就是错配。你计划里把这点说清楚了，而且说明了为什么不走“全项目收成 POSIX sh”这条路，这个判断正确。 ￼

2. Change 2 也很值

给 tests/test-workflow-consistency.sh 增加 protocol drift guards，这一步我很认同。
你前面已经反复踩过：
•	README.md 被塞回 workflow.md
•	Document Authority 这类元说明重新进入 slim workflow
•	research.md 规则表述漂回旧说法
•	write set / omission wording 再次漂移

这类问题如果不加 guard，后面很容易复发。 ￼

3. Change 3 的方向也对

你要补的两句，不是在扩协议面，而是在把已经存在的真实行为边界写清楚：
•	跳过 todolist 时，A/B 级 write-set 追加不适用
•	fallback guidance 故意偏保守

这两点之前确实都有轻微歧义。把它们写清楚，原则上是好事。 ￼

但你担心的点是成立的

workflow.md 是 always-loaded core protocol，所以任何新增句子都不是“普通文档修改”，而是在改 AI 的常驻上下文。

这意味着评价标准要比普通文档更严。
不是“解释得越完整越好”，而是：

只有那些会直接改变 AI 行为判断、且当前存在真实歧义的内容，才值得进 workflow.md。

按这个标准看，这次计划里的两句新增，我会分开评价。

对 workflow.md 两处新增的具体判断

第一处：关于“直接实现 / skip todolist”与 A/B 例外的关系

计划里的新增句子是：

A/B-level additions (rule 4) require a todolist to append to; they do not apply when todolist is skipped.  ￼

这句我认为值得加。

原因很简单：它在解决一个真实歧义，而且会直接影响 AI 的行为。

当前 workflow.md 里已经同时存在两条规则：
•	skip todolist 时的最小约束
•	implement 阶段允许 A/B 级 write-set 追加

如果不把两者关系说清楚，AI 很容易自然地推断：

“既然直接实现也算 implementation，那我是不是也可以用 A/B 例外？”

所以这句不是解释性噪音，而是真正的行为边界澄清。
它适合进 always-loaded workflow。

第二处：关于 fallback guidance 偏保守

计划里的新增句子是：

Fallback guidance (phase-guide.sh when skills unavailable): adopts a more conservative posture than skill-guided execution. This is intentional — without skill discipline, stricter defaults are safer.  ￼

这句我部分认同，但建议收短。

问题不在内容错，而在它有点偏“实现说明”：
•	提到了 phase-guide.sh
•	提到了 skills unavailable
•	解释了为什么更保守

其中“更保守是故意的”这件事确实值得告诉 AI；
但把 phase-guide.sh 这种实现名词写进 always-loaded workflow，我觉得略重了一点。

更干净的写法应该是协议化，而不是实现化。

我建议收成类似这样：

Fallback guidance is intentionally more conservative than skill-guided execution. Without phase-specific skill discipline, stricter defaults are safer.

这样保留了你真正想表达的边界：
•	fallback 比 skill-guided 更严
•	这是故意设计

但去掉了 phase-guide.sh 这种实现细节。
这更适合 always-loaded 上下文。

会不会影响 AI 常驻上下文质量

事实

这次拟新增到 workflow.md 的内容只有两句，而且都在澄清已有规则边界，不是在引入新概念。 ￼

推断

如果措辞收得干净，它们会让 AI 的行为判断更稳定，而不是增加负担。
真正会污染 always-loaded context 的，不是“多两句”，而是：
•	加入 README / Document Authority 这种文档架构说明
•	加入环境变量、hook 文件名、加载机制等实现细节
•	把本该在 workflow-full.md 的解释层塞进 slim workflow

判断

所以这次不是不能改 workflow.md，而是要遵守一个严格边界：

允许加行为澄清，不允许加文档导航和实现细节。

按这个标准，这次第一句没问题，第二句建议去实现名词化后再加。

我对这份 plan 的具体建议

我建议批准，但改一小处更稳

计划整体可以过。
我只建议你把 Change 3 的第二句改短、改抽象一点。

也就是从：

Fallback guidance (phase-guide.sh when skills unavailable): adopts a more conservative posture than skill-guided execution. This is intentional — without skill discipline, stricter defaults are safer.

收成：

Fallback guidance is intentionally more conservative than skill-guided execution. Without phase-specific skill discipline, stricter defaults are safer.

这样更适合 workflow.md 的职责边界。

其他部分不用再折腾
•	Change 1：直接做
•	Change 2：直接做
•	Change 3 第一条：直接做
•	Change 3 第二条：收一下措辞再做

最终结论

这份计划可以批准。
而且修改 workflow.md 本身不是问题，问题只在于改进去的内容是不是“始终值得让 AI 记住”。

我的结论是：
•	第一条澄清，值得进 workflow.md
•	第二条澄清，也值得进，但建议去掉 phase-guide.sh 这种实现层表述
•	只要守住这个边界，这次修改不会污染 always-loaded context，反而会让它更稳定

<!-- BATON:GO --> 