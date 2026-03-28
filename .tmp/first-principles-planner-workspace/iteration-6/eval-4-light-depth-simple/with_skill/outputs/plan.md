# manifest.conf 注释支持

**深度**: Light — 问题明确，解决空间窄，且需要先验证是否真的存在问题。

**输入来源**: baton 代码库（dispatch.sh, manifest.conf, test-dispatch.sh）

---

## TL;DR

manifest.conf **已经支持 `#` 注释**。dispatch.sh 第 38 行的 `case "$_evt" in ''|\#*) continue ;; esac` 会跳过所有以 `#` 开头的行和空行。test-dispatch.sh 中有专门的测试用例（第 159-174 行）验证了这个行为。当前 manifest.conf 的第一行 `# event:matcher:script` 本身就是一个正常工作的注释。

**不需要做任何改动。**

---

## 行动计划

| 优先级 | 改动 | 工作量 | 风险 | 价值 |
|--------|------|--------|------|------|
| — | 无需改动 | 0 | — | — |
| **合计** | | **0** | | |

---

## 关键假设

- **"manifest.conf 需要支持 # 注释"假设注释功能不存在** — 这是一个惯例性假设。实际上功能已在代码中实现。✅ 已验证：dispatch.sh:38 的 case 语句。
- **"# 开头行被正确跳过"** — ✅ 已验证：test-dispatch.sh 第 159-174 行有测试覆盖，测试用例名为 "comments and blanks are skipped"。
- **现有 manifest.conf 的注释行格式兼容** — ✅ 已验证：manifest.conf 第 1 行 `# event:matcher:script` 是一个包含冒号的注释行，IFS=: 分割后 `_evt` 为 `# event`，以 `#` 开头，被正确跳过。

---

## 自检

**这个计划最可能的失败模式是什么？** 用户可能有一个我没理解到的更具体的需求 — 比如行内注释（`SessionStart::phase-guide # 这是注释`）或者对注释格式有特殊要求。当前实现只支持整行注释（行首 `#`），不支持行内注释。如果用户需要的是行内注释，那确实需要修改 dispatch.sh 的解析逻辑，但这会引入新的复杂性（比如 script 名称中如果包含 `#` 怎么办），需要额外评估。

---

## 分析

### 现有实现机制

dispatch.sh 用 `while IFS=: read -r _evt _matcher _script` 逐行读取 manifest.conf，以冒号为分隔符拆分为三个字段。拆分后立即执行：

```bash
case "$_evt" in ''|\#*) continue ;; esac
```

这个 case 语句处理两种情况：
- `''`：空行（包括只有空白的行在 `read` 之后的结果）
- `\#*`：第一个字段以 `#` 开头的行

对于 `# 这是注释` 这样无冒号的行，`read` 把整行赋给 `_evt`，以 `#` 开头，被跳过。对于 `# event:matcher:script` 这样有冒号的行，`_evt` 得到 `# event`，同样以 `#` 开头，被跳过。

### 测试覆盖

test-dispatch.sh 第 159-174 行明确测试了此行为：创建包含注释行和空行的 manifest.conf，验证 hook 正常触发且注释被忽略。测试断言名为 "comments and blanks are skipped"。
