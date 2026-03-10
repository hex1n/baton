Baton 核心契约审计清单。这不是泛泛 checklist，而是面向你这个项目当前阶段的“先打硬核心协议”的清单。

先给结论

这轮审计的目标不是“找更多问题”，而是只做一件事：

确认 Baton 的核心行为到底是什么，并让文档、测试、实现三者重新一致。

你现在最需要的不是更多功能，而是把下面四类问题一次性清掉：
•	哪些行为是 Baton 明确承诺的
•	哪些承诺已经漂移
•	哪些地方语义不清
•	哪些地方会在不同宿主下 silently break

⸻

一、审计目标

建议把这轮任务正式命名为：

Baton Core Contract Audit

输出物固定为 3 份：

1）核心契约清单

定义 Baton 当前“必须稳定”的行为，不讨论愿景，只讨论真实承诺。

2）差异矩阵

逐项标记：
•	一致
•	文档过时
•	测试过时
•	实现缺失
•	契约不明确

3）修复优先级

只分三档：
•	P0：会导致错误执行、越权写入、阶段误判
•	P1：会导致用户理解错误、安装行为不一致
•	P2：命名、文案、非关键体验问题

⸻

二、建议先锁定的最小稳定面

这一段最重要。
如果你不先定义“什么必须稳定”，审计会无限膨胀。

我建议 Baton 当前只锁 5 个核心能力：

1. 阶段识别

系统必须能稳定判断当前处于：
•	research
•	plan
•	annotation
•	awaiting todo / implement ready
•	implement
•	archive

2. 写保护

未批准前，源码写入必须被阻断；非源码或允许文件必须按规则放行。

3. 批准门槛

BATON:GO 的语义必须唯一且不可歧义。

4. 注释闭环

annotation / feedback loop 的输入输出、退出条件、回到 plan 的条件必须明确。

5. implement 前置条件

什么时候允许生成 todolist，什么时候允许真正进入 implement，必须一致。

这 5 项之外，先别扩。

⸻

三、核心契约审计清单

下面是你可以直接用的审计项。

A. 阶段模型审计

目标：确认 Baton 到底有哪些阶段，以及每阶段允许什么、禁止什么。

需要核对的内容
1.	Baton 官方阶段列表是否唯一
2.	各阶段进入条件是否唯一
3.	各阶段退出条件是否唯一
4.	阶段优先级是否明确
5.	多个条件同时满足时，谁覆盖谁
6.	阶段是否由文件状态派生，还是由显式标记驱动
7.	“无状态机”这句话是否和实际实现冲突

必问问题
•	到底有没有隐式状态机
•	annotation 是独立阶段，还是 plan 的子循环
•	awaiting todo 和 implement 是两个阶段还是一个过渡态
•	archive 是历史状态还是活跃阶段

判定标准

如果 README、workflow、skills、hooks、tests 对阶段数、阶段名、优先级有任何一处不一致，就记为 P0 契约不明确。

⸻

B. 写保护契约审计

目标：确认 Baton 最核心的治理能力到底如何工作。

需要核对的内容
1.	哪些文件类型默认放行
2.	哪些文件类型默认阻断
3.	未找到 plan 时行为是什么
4.	未批准 plan 时行为是什么
5.	找不到目标文件时是 fail-open 还是 fail-closed
6.	markdown 永远放行是否是正式承诺
7.	docs、plans、tests、config 是否属于源码保护范围
8.	对新建文件、重命名文件、删除文件是否一致处理
9.	多文件修改时是否逐个判断
10.	不同 IDE / adapter 是否都走同一写锁逻辑

必问问题
•	“源码”的精确定义是什么
•	是否允许先改测试再改实现
•	是否允许改 CI/config
•	write-lock 的边界是 repo policy 还是 Baton protocol

判定标准

凡是会导致未批准就能改核心源码，一律 P0。
凡是不同宿主执行结果不同，一律至少 P1，若会越权则 P0。

⸻

C. BATON:GO 审计

目标：确认批准信号的语义绝对单一。

需要核对的内容
1.	BATON:GO 是否只有一种合法写法
2.	它必须出现在哪个文件
3.	它必须出现在什么位置
4.	允许多个 plan 文件时如何选择
5.	被 archive 的 plan 是否还有效
6.	BATON:GO 只代表“允许实现”，还是也代表“允许生成 todolist”
7.	是否允许 AI 自己写入 BATON:GO
8.	技能、文档、hook 是否都对其语义一致

必问问题
•	BATON:GO 是 approval token，还是 phase transition token
•	“生成 todolist”是否在 GO 前还是 GO 后
•	plan 被修改后，旧的 GO 是否失效

判定标准

只要存在两种解释路径，就算 P0 契约歧义。
因为这个标记是 Baton 最核心的治理边界。

⸻

D. todolist / implement 前置条件审计

目标：把“能实施”这件事定义清楚。

需要核对的内容
1.	什么时候允许生成 todolist
2.	生成 todolist 是否要求先有 GO
3.	implement 是否必须以 todolist 为入口
4.	implement 时是否只能改 approved write set
5.	unexpected discovery 时是否必须停下并回到 plan
6.	implement skill、README、workflow 是否一致
7.	无 todolist 能不能直接写代码

必问问题
•	todolist 是执行计划，还是仅是可选中间产物
•	write set 的来源是 plan、todolist，还是二者结合
•	小改动是否允许跳过 todolist

判定标准

凡是让 implement 入口条件不清晰的，都应记为 P0 或 P1。
因为这会直接影响是否会“偷偷从计划滑到实现”。

⸻

E. annotation 协议审计

目标：确认 Baton 最有特色的人机闭环到底如何运作。

需要核对的内容
1.	annotation 的输入格式是否明确
2.	annotation 的输出格式是否明确
3.	一轮批注结束的判定条件是什么
4.	什么时候继续批注，什么时候回 plan
5.	annotation 是否允许直接触发实现
6.	annotation 中发现新事实后是否强制更新 research / plan
7.	tests 是否覆盖典型 annotation 流程

必问问题
•	annotation 是 review loop，还是需求澄清 loop
•	批注积累到什么程度才算共享理解成立
•	annotation 记录是协议的一部分，还是仅建议保留

判定标准

如果 annotation 只是“文档里写得很好看”，但实现和技能没有一致承诺，那就不是核心机制，只能算方法论描述。这个要明确，不然会误导定位。

⸻

F. shell / runtime 契约审计

目标：清掉最容易潜伏爆炸的工程风险。

需要核对的内容
1.	每个脚本的 shebang 是否真实反映依赖
2.	外部调用是否统一使用 bash 或 sh
3.	是否存在 bashism 在 sh 下执行
4.	macOS / Linux 是否都能跑
5.	tests 的执行方式是否与真实宿主一致
6.	Cursor / Claude / 其他 adapter 是否统一执行方式
7.	setup 生成的 hook 调用命令是否一致

必问问题
•	Baton 官方支持 Bash-only 还是 POSIX sh
•	如果 Bash-only，是否所有调用方都显式用 bash
•	如果要支持 sh，是否已清理所有 bashism

判定标准

任何会导致不同宿主行为不同的问题都至少 P1。
任何会导致 hook 失效、写锁绕过、阶段判断失败的问题都是 P0。

⸻

G. setup / install 契约审计

目标：确认安装器承诺和实际行为一致。

需要核对的内容
1.	默认安装哪些 hook
2.	默认不安装哪些 hook
3.	pre-commit 是否属于当前正式支持面
4.	不同 IDE 安装产物是否一致
5.	卸载 legacy 行为是否与当前文档一致
6.	setup 是否幂等
7.	重复执行 setup 是否破坏用户配置
8.	CLI 参数与 README 是否一致

必问问题
•	Baton 当前是“单一安装入口”还是“多宿主分散安装”
•	setup 是安装协议，还是迁移工具
•	文档承诺的默认行为是否和脚本一致

判定标准

安装行为不一致，会直接损害用户对 Baton 的信任，至少 P1。
如果导致用户误以为已受保护但实际上没装上 hook，就是 P0。

⸻

H. 多宿主一致性审计

目标：确认 Baton 真的是 protocol layer，而不是某个宿主特供技巧。

需要核对的内容
1.	Claude / Cursor 是否拥有相同核心能力
2.	哪些能力是宿主无关的
3.	哪些能力依赖宿主特性
4.	adapter 是否仅做适配，不偷改协议
5.	文档是否明确能力矩阵
6.	tests 是否覆盖宿主差异

必问问题
•	Baton 核心协议是否独立于宿主
•	多宿主之间哪些差异是设计允许的
•	哪些差异会破坏 Baton 的身份认知

判定标准

如果不同宿主导致不同阶段语义、不同批准边界、不同写锁行为，那 Baton 还不能自称稳定的 protocol runtime。

⸻

I. 文档真相源审计

目标：决定到底谁说了算。

需要核对的内容
1.	README 是介绍文档还是规范文档
2.	workflow / workflow-full 哪个是正式协议
3.	skills 是实现提示还是规范组成部分
4.	tests 是否以某一份规范为唯一依据
5.	plans 样例是否只是例子，还是隐式规范
6.	是否存在多个文档同时定义行为

必问问题
•	Baton 的 normative spec 在哪里
•	哪些文档是 authoritative
•	哪些文档只是 explanatory

判定标准

没有唯一真相源，后续所有扩展都会继续漂。这个问题本身就是 P0 级别的架构债。

⸻
