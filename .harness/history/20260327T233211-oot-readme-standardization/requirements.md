# Requirements: root-readme-standardization

**主题**: 根目录 README 双语维护标准化
**状态**: `approved`
**规模**: `Small`

## 1. 问题

根目录已经有正式英文 README 和正式中文 README，但当前仓库没有机制保证两者持续同步，也没有把“文档入口类变更应按 harness 流程执行”的经验写回治理规则。结果是 README 入口可能再次发生漂移，且未来类似任务仍可能被当成“只是改文档”而绕过 scope / verification 闭环。

## 2. 范围

### 2.1 范围内

- 新增根目录 README 双语自检脚本
- 把双语 README 维护规则写入治理文档
- 让仓库级一致性检查覆盖该脚本
- 视需要在根目录 README 入口处补充维护提示

### 2.2 范围外

- 为所有文档建立中英双版
- 对外部分发这个 README 检查脚本作为通用 harness 能力
- 新增独立 role、state 或复杂文档流水线

## 3. 功能需求

### FR-1 根目录 README 双语自检

- 仓库必须提供一个轻量脚本，能检查 `README.md` 与 `README.zh-CN.md` 是否同时存在
- 该脚本必须检查双向语言链接是否存在
- 该脚本必须检查关键章节是否在中英两份 README 中同时存在
- 该脚本必须检查关键接入术语是否在中英两份 README 中同时存在

### FR-2 文档贡献约定

- 仓库治理文档必须明确：`README.md` 仍是英文主入口，`README.zh-CN.md` 是正式中文副本
- 仓库治理文档必须明确：涉及根目录入口、安装/升级、vendor/override、skill 分发等变化时，需要同一改动里同步更新两份 README
- 仓库治理文档必须明确：根目录入口文档类任务同样应按 harness 流程执行

### FR-3 自检入口整合

- 仓库已有的一致性检查入口必须能够触发 README 双语自检，避免规则只停留在文档里

## 4. 非目标

- 不追求自动翻译 README
- 不要求 README 两份文件逐行一一对齐
- 不要求为贡献规则再维护一份独立的中文 CONTRIBUTING 文档

## 5. 验收标准

### AC-1 自检脚本可直接运行

- `bash spec/bootstrap/check-root-readme-bilingual.sh` 在当前仓库可执行
- 成功时输出明确的 OK / summary
- 失败时对缺失文件、链接、章节或关键术语给出可定位的错误

### AC-2 治理规则已写回仓库

- 至少一个现有治理入口明确写出 README 双语维护规则
- 该规则同时覆盖“英文主入口 + 中文副本”与“文档入口类任务走 harness”两点

### AC-3 仓库主自检可覆盖该规则

- `bash spec/bootstrap/check-consistency.sh` 会调用 README 双语自检

## 6. 约束

- 保持当前根目录 README 双文件布局，不回退成单文件中英混排
- 规则应优先写进已有治理载体，而不是引入更重的流程系统
- 脚本应仅依赖 bash / grep 等基础工具

## 7. 验证意图

- 用新增脚本直接验证根目录 README 双语入口结构
- 用仓库主一致性脚本验证整合生效
- 用 `git diff --check` 确认文档与脚本改动没有格式问题
