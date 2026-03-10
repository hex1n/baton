结论

我已经按你的要求，基于实际源码分析了这个项目，忽略了 docs/、plans/ 里的文档内容，只看可执行层：CLI、安装脚本、hooks、适配器、测试、CI。

直接结论：

baton 不是空壳 prompt 项目，它确实是一个有执行层的 AI 编码流程护栏。核心实现集中在：

install.sh

setup.sh

bin/baton

.baton/hooks/*

.baton/adapters/*

tests/*

.github/workflows/ci.yml

它的方向是对的：把 AI 改代码这件事，变成“先研究、再计划、再批准、再实施”的受控流程。

但我也要直接指出：
当前这份代码还达不到“强约束、可放心依赖”的程度。
不是理念有问题，而是实现层存在几处很硬的缺陷，而且其中两处已经会直接破坏它最核心的承诺。

我的总判断：

设计方向：强

工程实现：中等，且有关键缺陷

当前状态更像：有价值的原型 / 早期可用工具

还不像：已经打磨好的高可信治理层

置信度：高
因为这次不是基于 README 猜，而是直接看了实现并跑了测试。

这个项目的真实定位

从代码看，baton 的本质不是 agent framework，也不是多智能体平台。它更准确的定位是：

AI coding workflow guardrail / protocol layer

也就是：

用 write-lock 阻止未授权写代码

用 phase-guide 提示当前阶段

用 setup.sh 把 hooks 注入 Claude / Cursor / Codex

用 skills 把研究、计划、实施分阶段约束

用 bin/baton 提供项目注册、安装、doctor、status

这一点从几个关键文件能直接看出来：

install.sh:12-47 负责全局安装、稀疏 clone、自更新

setup.sh:1021-1106 负责把 baton 注入项目

bin/baton:202-223 提供 CLI 命令面

.baton/hooks/write-lock.sh:87-102 负责真正的写入门禁

.baton/hooks/phase-guide.sh:34-135 负责阶段识别与提示

.github/workflows/ci.yml:39-127 说明作者确实把 hooks / setup / adapter / workflow consistency 当成测试对象

所以这项目不是“只有流程哲学”，它确实有工程实现。

做得对的地方
1. 架构抓住了 AI coding 的真问题

这个项目不是在堆“记忆”“代理编排”“自动化”等花活，而是在解决最真实的问题：

AI 还没看清就开始改

研究和实施混在一起

用户一句反馈，AI 就盲从

改着改着越界

没批准就写代码

这套设计的主轴很明确：
证据、阶段、批准、边界。

这条主轴是对的。

2. 安装 / 升级 / 卸载思路比较成熟

setup.sh 不只是“把文件 copy 进去”，它还处理了：

IDE 检测与选择：setup.sh:1024-1044

旧版本迁移：setup.sh:1046-1053

已有 JSON 配置合并而不是粗暴覆盖：setup.sh:783-801, 806-825, 988-996

卸载时尽量保守，不乱删仍被引用的 .baton/：setup.sh:352-365, 369-430

这是成熟工程意识，不是一次性脚本心态。

3. 测试覆盖面比一般同类项目强

tests/ 里不只是有 happy path，还覆盖了：

write-lock

phase-guide

stop-guard

setup

cli

Cursor adapter

multi-IDE

workflow consistency

新 hooks

从测试种类上看，作者是有“把流程做成系统”的意识的，不只是写几个脚本就算完。

关键问题：现在的实现和它宣称的能力并不完全一致

下面这些不是抽象担忧，是代码和实跑结果里已经出现的问题。

1. write-lock 存在真实绕过漏洞，这是最严重的问题

write-lock.sh 的核心路径判断在这里：

.baton/hooks/write-lock.sh:60-72

问题出在这一段：

它先尝试 cd "$(dirname "$TARGET")" 再拼接 basename：63

当目标是 src/app.ts，但 src/ 目录还不存在时，这个 cd 会失败

结果 TARGET_REAL 会退化成类似 "/app.ts" 这样的绝对路径

然后在 69-72 的“是否在项目目录内”判断里，被当成“项目外文件”

项目外文件被直接 exit 0 放行

也就是说，在没有 plan / 没有 BATON:GO 的情况下，下面这种写入可能被错误允许：

src/app.ts

src/blocked.ts

任何相对路径但父目录尚不存在的目标

这不是猜测，我直接跑了它的现有测试：

tests/test-write-lock.sh 本地结果：28/37 passed，9 failed

失败项里就包括：

“No plan.md → 应该 block src/app.ts，实际被 allowed”

“plan.md exists, no GO → 应该 block src/app.ts，实际被 allowed”

stdin JSON 路径解析场景也有同类失败

这说明 baton 最核心的“没批准不能写源码”承诺，目前在一类很常见路径上是失效的。

这个问题的严重程度：高

因为它破坏的是项目最核心的价值主张。

2. phase-guide.sh 和 bin/baton 都有 /bin/sh 兼容性错误

这两个文件都声明了 #!/bin/sh，但都用了 Bash 风格的字符串替换：

.baton/hooks/phase-guide.sh:25

RESEARCH_NAME="${PLAN_NAME/plan/research}"

bin/baton:155

_rname="${_pname/plan/research}"

这在 Bash 下没问题，但在严格的 /bin/sh 环境下会直接报错 Bad substitution。

我实际复现了：

执行 sh .baton/hooks/phase-guide.sh，直接退出 2，报 Bad substitution

执行 bin/baton 作为真正可执行脚本，status 也会因为同类问题报错

这意味着：

phase-guide 这个 hook 在部分环境下会直接坏掉

baton CLI 的 portability 也被破坏了

更关键的是，这不是边缘文件，而是主路径文件。

对应证据：

.baton/hooks/phase-guide.sh:1-3, 25

bin/baton:1-4, 155

这个问题的严重程度：高

因为它影响主流程，而且是“脚本一运行就炸”的问题，不是小瑕疵。

3. setup.sh 会写入对新 hooks 的引用，但根本没把这些 hooks 安装进去

这是我这次看到的另一个很硬的实现缺口。

Claude 配置里明确注入了这些 hook：

post-write-tracker.sh

subagent-context.sh

completion-check.sh

pre-compact.sh

证据在：

setup.sh:818-824

setup.sh:827-910

但实际安装阶段只安装了这四个脚本：

write-lock.sh

phase-guide.sh

stop-guard.sh

bash-guard.sh

证据在：

setup.sh:1075-1078

也就是说，setup.sh 会生成一个 .claude/settings.json，里面指向 4 个根本不存在的 hook 文件。

我实际跑了 setup.sh 后验证过：

安装后项目里的 .baton/hooks/ 只有：

_common.sh

write-lock.sh

phase-guide.sh

stop-guard.sh

bash-guard.sh

而以下文件是缺失的：

post-write-tracker.sh

subagent-context.sh

completion-check.sh

pre-compact.sh

但它们已经被写进 .claude/settings.json 里了。

这不是理念问题，这是明确的安装缺陷。

严重程度：高

因为这会导致“看起来配置成功，实际运行时缺文件”。

4. doctor 检查不到上面这个缺陷，健康检查是有盲区的

bin/baton doctor 只检查这四个脚本：

write-lock.sh

phase-guide.sh

stop-guard.sh

bash-guard.sh

证据：

bin/baton:65-84

它不会检查：

post-write-tracker.sh

subagent-context.sh

completion-check.sh

pre-compact.sh

所以会出现一种很糟的情况：

setup.sh 已经把缺失 hook 写进 IDE 配置

但 doctor 仍然可能给出“脚本层基本正常”的结论

我实测就是这样：
安装后的项目里缺了 4 个被配置引用的 hook，但 doctor 并不会报这个问题。

这说明它的自检链条还没闭合。

严重程度：中高

因为这会制造“假健康”。

5. Bash 写文件这条绕行路径并没有被真正封死

项目里确实有一个 bash-guard.sh，但它自己就写得很清楚：

.baton/hooks/bash-guard.sh:3-5

这是 advisory only

never blocks, only warns

更关键的是，它目前并没有真正接进 Claude / Cursor 的配置主链路。

Claude 配置注入的是：

phase-guide

write-lock

post-write-tracker

stop-guard

subagent-context

completion-check

pre-compact

证据：

setup.sh:818-824

Cursor 配置注入的是：

phase-guide

adapter-cursor

subagent-context

pre-compact

证据：

setup.sh:992-995

这里都没有 bash-guard。

这意味着什么？

即使不考虑上面“新 hooks 没装进去”的缺陷，单从设计上讲，当前 baton 的强约束主要还是针对 Edit/Write/MultiEdit/CreateFile 这一类文件编辑工具，而不是 Bash 工具里的：

echo > file

tee

sed -i

cp

mv

而这恰恰是 AI 在很多 IDE / CLI 环境里最容易绕过文件编辑 hook 的路径。

所以它现在还不能说自己实现了“全面写保护”。
更准确的说法应该是：

它实现了“编辑工具路径上的主保护”，但对 shell 写入路径仍是明显薄弱。

严重程度：中高

这几个问题叠在一起，说明什么

这说明 baton 现在的状态是：

理念比实现更成熟。

换句话说，它已经很好地回答了“应该怎么约束 AI 编码流程”，但还没有完全做到“这些约束在代码里被可靠执行”。

这不是否定它，而是准确定位它当前阶段：

不是“只能看不能用”的概念项目

也不是“已经可以高信任落地”的稳定系统

更像“方向非常对，但实现层需要一轮硬化”的工程原型

测试体系本身也暴露了一个问题

它有很多测试，这是优点。
但测试和真实执行环境之间有一个错位：

tests/test-cli.sh 里调用 CLI 时用的是：

bash "$BATON_CLI"

而不是直接执行脚本。

这会掩盖 bin/baton 的 /bin/sh 兼容性问题。
也就是说，测试把它当 Bash 脚本跑了，但真实用户可能是按 shebang 走 /bin/sh。

所以当前测试体系不是“没有测试”，而是：

测试很多，但有些关键路径的执行方式和真实运行方式不一致。

我对项目的最终判断
事实

从实际代码看，baton 具备：

全局安装器

项目注入器

hook 体系

Cursor 适配器

CLI

卸载与迁移

测试与 CI

所以它不是“文档驱动幻觉项目”。

推断

它真正想做的是：

AI coding governance / guardrail tooling

而不是 agent 本体。

判断

这个方向很值得做，而且 baton 已经有了不错的骨架。
但当前 master 包里的实现，至少还存在以下不可忽视的问题：

核心门禁 write-lock 有可复现绕过

主路径脚本有 /bin/sh 兼容性错误

setup 会注入缺失 hook

doctor 检不出来这个缺陷

Bash 写路径没有真正封住

所以我不会给它“已经成熟可靠”的评价。

更准确的评价是：

这是一个很有价值、方向正确、工程感不错的 AI 编码护栏项目，但当前实现层还没有把它自己的承诺完全兑现。

我给你的推荐结论

如果你问“这个项目值不值得继续做”，答案是：值得，而且方向对。

如果你问“现在这份实现能不能直接当高信任基建用”，答案是：还不行。

我会建议优先修这 4 件事，顺序不要反：

修 write-lock.sh 的路径归一化逻辑
否则核心门禁名存实亡。

统一 shell 语义
要么所有相关脚本改成 Bash 并显式 #!/usr/bin/env bash，要么去掉 Bashism，真正兼容 /bin/sh。

setup.sh 必须安装所有它注入引用的 hooks
并让 doctor 校验这些 hooks 是否存在。

明确 Bash 写路径策略
要么真正接入 bash-guard，要么明确承认 shell 写入目前不能强约束，别把能力说满。