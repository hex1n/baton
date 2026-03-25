# gstack 深度分析报告

> 分析日期: 2026-03-22
> 项目版本: 0.3.3 (package.json) / v0.9.4.1 (CHANGELOG latest)
> 作者: Garry Tan (YC President & CEO)
> 许可: MIT
> 安装位置: `~/.agents/skills/gstack/`

---

## 目录

1. [项目概述](#1-项目概述)
2. [架构设计哲学](#2-架构设计哲学)
3. [Browse 无头浏览器子系统](#3-browse-无头浏览器子系统)
4. [全部 21 个 Skills 详解](#4-全部-21-个-skills-详解)
5. [CLI 脚本与工具链](#5-cli-脚本与工具链)
6. [测试基础设施](#6-测试基础设施)
7. [配置与状态管理](#7-配置与状态管理)
8. [遥测与分析系统](#8-遥测与分析系统)
9. [构建系统与 CI/CD](#9-构建系统与-cicd)
10. [跨平台支持](#10-跨平台支持)
11. [安全模型](#11-安全模型)
12. [设计模式与惯例](#12-设计模式与惯例)
13. [Token 消耗分析](#13-token-消耗分析)
14. [与 Baton 对比](#14-与-baton-对比)

---

## 1. 项目概述

### 定位

gstack 是 Garry Tan 的开源 AI 工程工作流系统。它将 Claude Code 变成一个虚拟工程团队——CEO、工程经理、设计师、偏执审查者、QA 负责人、发布工程师。15 个专家角色 + 6 个工具，全部是 slash 命令，全部是 Markdown，全部免费。

### 核心数据

| 指标 | 值 |
|------|-----|
| Skills 数量 | 21 个 |
| 源码文件 | ~50 个 TypeScript + ~15 个 Shell 脚本 |
| Browse 二进制 | ~58MB 编译后单文件 |
| 运行时依赖 | 仅 playwright + diff |
| 支持平台 | Claude Code, Codex CLI, Gemini CLI |
| 安装时间 | ~30 秒 |

### 宣称效果

- 60 天内 600,000+ 行生产代码
- 每天 10,000-20,000 行可用 LOC（兼职）
- 2026 年 1,237+ contributions

### Sprint 结构

```
Think → Plan → Build → Review → Test → Ship → Reflect
  │        │       │        │       │       │       │
  ▼        ▼       ▼        ▼       ▼       ▼       ▼
office   plan-*   code    review    qa     ship    retro
hours    reviews          codex   qa-only        doc-release
```

每个 skill 输出喂给下一个。`/office-hours` 写设计文档，下游 skills 读取。

---

## 2. 架构设计哲学

### 分层设计

```
┌────────────────────────────────────────────────────────┐
│  用户 (Claude Code / Codex / Gemini) + /skills         │
├────────────────────────────────────────────────────────┤
│  SKILL.md 文件 (从 .tmpl 模板自动生成)                  │
│  - 21 个专家角色 + 6 个安全工具                         │
├────────────────────────────────────────────────────────┤
│  $B (browse CLI 命令)                                  │
│  - 编译后单文件 (58MB, 即时启动)                        │
│  - 纯文本输入/输出, HTTP POST 到 localhost              │
├────────────────────────────────────────────────────────┤
│  HTTP Server (Bun 守护进程, 持久化)                     │
│  - 分发: READ | WRITE | META 命令                      │
│  - Ref 映射: @e/@c 元素寻址                            │
│  - 环形缓冲: console, network, dialog                  │
├────────────────────────────────────────────────────────┤
│  Playwright API                                        │
│  - 无障碍树快照 (Accessibility Tree)                    │
│  - Locator 系统 (无 DOM 注入)                          │
├────────────────────────────────────────────────────────┤
│  Chromium (headless, 持久化)                           │
│  - 守护模式: cookies, localStorage 跨命令保持           │
│  - 30 分钟空闲关闭, 自动重启                            │
└────────────────────────────────────────────────────────┘
```

### 六大设计原则

1. **结构化角色 > 通用代理** — 21 个专家角色而非一个万能助手
2. **持久状态 > 无状态** — 浏览器守护进程，cookie/tab/状态跨命令保持
3. **Token 效率 > 抽象层** — 纯文本 CLI 每次调用 0 token 开销 (vs MCP 1500-2000)
4. **自动化 > 手动** — SKILL.md 从代码自动生成，`/ship` 自动触发 `/document-release`
5. **结构化并行** — 10-15 个 sprint 同时运行，流程本身保证正确性
6. **人在回路中** — `/careful` 警告破坏性操作，`/handoff` 切换到可见 Chrome

### Token 效率对比

| 工具 | 首次启动 | 后续命令 | Token 开销/次 |
|------|---------|---------|--------------|
| Chrome MCP | ~5s | ~2-5s | ~2000 tokens |
| Playwright MCP | ~3s | ~1-3s | ~1500 tokens |
| **gstack browse** | ~3s | **~100-200ms** | **0 tokens** |

20 次命令会话: gstack 0 token 协议开销, MCP 烧掉 30,000-40,000 token。

### 为什么选择 CLI 而非 MCP

- 无 JSON schema 膨胀
- 无 WebSocket 连接脆弱性
- 纯文本 stdout (0 token 开销)
- 可用标准 shell 工具调试

### 为什么选择 Bun

- 编译后单文件 (~58MB): 无需 `node_modules`
- 原生 SQLite: cookie 解密无需 native addon
- 原生 TypeScript: 开发时 `bun run server.ts` 无需编译
- 内置 HTTP 服务: `Bun.serve()` 比 Express/Fastify 更简单

---

## 3. Browse 无头浏览器子系统

### 目录结构

```
browse/
├── src/
│   ├── cli.ts              (12KB) CLI 客户端: 服务启动/健康检查/命令分发
│   ├── server.ts           (14KB) Bun HTTP 守护进程
│   ├── browser-manager.ts  (21KB) Chromium 生命周期/tab 管理/状态保存
│   ├── commands.ts         (8.2KB) 命令注册表 (单一事实源)
│   ├── snapshot.ts         (15KB) 无障碍树生成/ref 分配/@e/@c 系统
│   ├── read-commands.ts    (12KB) 只读命令: text/html/links/forms/console
│   ├── write-commands.ts   (13KB) 写入命令: click/fill/type/upload
│   ├── meta-commands.ts    (9.9KB) Tab/chain/handoff/截图/diff
│   ├── cookie-import-browser.ts (16KB) 多浏览器 cookie 解密
│   ├── cookie-picker-ui.ts (17KB) Cookie 域选择器 HTML/CSS/JS
│   ├── cookie-picker-routes.ts (208行) Cookie picker HTTP 路由
│   ├── url-validation.ts   (2.3KB) 安全 URL scheme 检查
│   ├── platform.ts         (634B) 跨平台常量
│   ├── config.ts           (4.7KB) .gstack 配置文件 I/O
│   ├── buffers.ts          (4.3KB) 环形缓冲区
│   └── find-browse.ts      (62行) 二进制文件定位
├── dist/
│   ├── browse              编译后 CLI 二进制
│   ├── find-browse         辅助二进制
│   ├── server-node.mjs     Node.js 回退 (Windows)
│   ├── bun-polyfill.cjs    Bun API 兼容层
│   └── .version            Git commit hash
├── bin/
│   ├── find-browse         Bash 查找脚本
│   └── remote-slug         项目标识提取
├── scripts/
│   └── build-node-server.sh  Node.js 回退构建
└── test/                     测试 + fixtures
```

### 启动流程

```
用户运行: browse goto https://example.com

1. cli.ts main() 解析参数
2. ensureServer() 读取 ~/.gstack/browse.json
3. 如果状态缺失或 PID 已死:
   ├─ macOS/Linux: spawn `bun run browse/src/server.ts`
   └─ Windows: spawn `node browse/dist/server-node.mjs`
4. server.ts 启动:
   ├─ 随机端口 10000-60000
   ├─ HTTP 服务: /health, /command, /cookie-picker/*
   ├─ Chromium 启动 via BrowserManager.launch()
   ├─ 生成 UUID auth token
   ├─ 原子写入状态文件: {pid, port, token, startedAt, binaryVersion}
   ├─ 启动环形缓冲 (console, network, dialog)
   └─ 启动空闲定时器 (30 分钟)
5. cli.ts sendCommand() POST 命令到服务器
6. server.ts 分发到 handleReadCommand/handleWriteCommand/handleMetaCommand
7. cli.ts 打印响应到 stdout
```

### 命令分类 (~50 个)

| 类别 | 命令 | 说明 |
|------|------|------|
| **导航** | goto, back, forward, reload, url | 页面导航 |
| **读取** | text, html, links, forms, accessibility | 页面内容提取 |
| **快照** | snapshot [-i] [-c] [-d N] [-s sel] [-D] [-a] [-o] [-C] | 无障碍树快照 |
| **交互** | click, fill, select, hover, type, press, scroll, wait, upload | 页面操作 |
| **检查** | js, eval, css, attrs, is, console, network, dialog, cookies, storage, perf | 状态检查 |
| **视觉** | screenshot, pdf, responsive, diff | 视觉输出 |
| **对话框** | dialog-accept, dialog-dismiss | 浏览器对话框 |
| **Tab** | tabs, tab, newtab, closetab | 多标签管理 |
| **Cookie** | cookie-import, cookie-import-browser | Cookie 导入 |
| **交接** | handoff, resume | 人机交接 (CAPTCHA/MFA) |
| **元命令** | chain, status, restart, stop, health | 服务器控制 |

### 快照系统 (Ref 系统)

这是 gstack 最独特的设计之一:

```
1. page.locator('body').ariaSnapshot() → YAML 无障碍树:
   - button "Submit"
   - link "Help": /help
   - heading "Title" [level=1]

2. 两遍 ref 分配:
   Pass 1: 统计 role+name 对 (用于消歧)
   Pass 2: 分配 @e1, @e2, ... 使用 getByRole(role, {name})

3. 构建 Map<string, RefEntry> (Locator + role + name)

4. 后续命令 `click @e3` 通过 map 解析为 Playwright Locator
```

**快照标志:**

| 标志 | 说明 |
|------|------|
| `-i` | 仅交互元素 |
| `-c` | 紧凑模式 (无空节点) |
| `-d N` | 深度限制 |
| `-s sel` | CSS 选择器范围 |
| `-D` | Diff 模式 (与基线对比) |
| `-a` | 标注截图 (红色覆盖 + 标签) |
| `-o path` | 输出路径 |
| `-C` | cursor:pointer 元素扫描 (@c refs) |

### 环形缓冲架构

```typescript
class CircularBuffer<T> {
  private entries: (T | undefined)[] = Array(50000);
  private head = 0;
  private totalAdded = 0;
  push(entry: T): void { /* O(1) */ }
  toArray(): T[] { /* 按插入顺序返回 */ }
}
```

三个模块级缓冲:
- **consoleBuffer** — {timestamp, level, text}
- **networkBuffer** — {method, url, status, duration, size}
- **dialogBuffer** — {timestamp, type, message, action, response}

每秒异步刷新到磁盘 JSONL，CLI 查询读取内存缓冲。

### Cookie 导入系统

```
cookie-import-browser.ts 解密流程:
1. findInstalledBrowsers() — 检测 Comet/Chrome/Arc/Brave/Edge (macOS)
2. listDomains(profile) — 查询 Chromium SQLite (复制到 /tmp 避免锁)
3. importCookies(profile, domains):
   Keychain 查找 "Chrome Safe Storage" → key
   PBKDF2(key, salt, 1003 iter, sha1) → derived key
   AES-128-CBC.decrypt(encryptedValue, derived key) → plaintext
   PKCS7.unpad() → cookie value
   Chromium epoch → Unix seconds
4. 返回 cookie 数组
```

### 版本不匹配自动重启

```
构建时: git rev-parse HEAD → browse/dist/.version
启动时: server 写入 binaryVersion 到状态文件
每次 CLI 调用: 读取 .version → 对比服务器版本
不匹配: kill + restart → 永不出现"陈旧二进制"问题
```

---

## 4. 全部 21 个 Skills 详解

### 4.1 /office-hours — YC 办公时间

**版本:** 1.0.0 | **触发:** "brainstorm", "ideas", "what should we build"

**两种模式:**
- **Startup 模式** — 6 个强制问题:
  1. Demand Reality (需求现实)
  2. Status Quo (现状)
  3. Desperate Specificity (绝望的具体性)
  4. Narrowest Wedge (最窄切入点)
  5. Observation & Surprise (观察与惊喜)
  6. Future-Fit (未来适配)
- **Builder 模式** — 设计思维头脑风暴 (副项目/黑客松/学习/开源)

**输出:** DESIGN.md 作为每个功能的设计文档，喂给 /plan-* 审查技能

---

### 4.2 /plan-ceo-review — CEO/创始人战略审查

**版本:** 1.0.0 | **触发:** "CEO review", "think bigger", "rethink this"

**四种模式:**
1. **SCOPE EXPANSION** — 10x 思维，柏拉图理想型
2. **SELECTIVE EXPANSION** — 保持范围 + 精选扩展
3. **HOLD SCOPE** — 不增不减，最大严谨
4. **SCOPE REDUCTION** — 无情裁剪到必须发布的核心

**Step 0: 核弹级范围挑战**
- 0A: 前提挑战 (这是正确的问题吗？)
- 0B: 现有代码复用 (子问题映射到现有代码)
- 0C: 梦想状态映射 (12 个月理想状态)
- 0C-bis: 实施替代方案 (2-3 种方法对比)
- 0D: 模式特定分析

**16 个认知模式:** 分类本能、偏执扫描、反转反射、聚焦即减法、人优先排序、速度校准、代理怀疑论、叙事连贯性、时间深度、创始人模式偏见、战时意识、勇气积累、意志力即策略、杠杆执念、层级即服务、边界情况偏执

---

### 4.3 /plan-eng-review — 工程经理架构审查

**版本:** 1.0.0 | **触发:** "architecture review", "engineering review"

**流程:**
1. 预检: git log, git diff stat, TODO/FIXME grep
2. 设计文档检查: 无则建议 /office-hours
3. Step 0: 范围挑战
   - 现有代码解决了哪些子问题？
   - 最小变更集是什么？
   - 复杂度检查: 8+ 文件或 2+ 新类 = 代码异味
4. Step 0.5: 可选 Codex 计划审查
5. 四个审查维度 (每个问题独立 AskUserQuestion):
   - **架构** — 系统设计/依赖/数据流/扩展/安全
   - **代码质量** — 组织/DRY/错误处理/边界情况
   - **测试** — 新 UX/flow/codepath 需要测试图
   - **性能** — N+1 查询/内存/缓存/慢路径

**工程偏好:** DRY、充分测试、"工程化到位"、深思 > 速度、显式 > 巧妙、最小 diff、可观测性必须、非原子部署

**12 个认知模式:** 状态诊断、爆炸半径本能、默认无聊、增量 > 革命、系统 > 英雄、可逆性偏好、失败即信息、组织结构即架构、DX 即产品质量、本质 vs 偶然复杂度、两周臭味测试、胶水工作意识

**输出:** 测试计划到 `~/.gstack/projects/{slug}/` + review log

---

### 4.4 /plan-design-review — 设计师之眼计划审查

**版本:** 2.0.0 | **触发:** "design review plan", "check UX"

**七个审查维度 (每个 0-10 评分):**
1. **信息架构** — 层次结构、ASCII 图、约束崇拜
2. **交互状态覆盖** — loading/empty/error/success/partial 状态
3. **用户旅程与情感弧** — 故事板、时间视野设计
4. **AI 垃圾风险** — 检测紫色渐变/气泡边框/通用素材
5. **设计系统对齐** — DESIGN.md token/组件
6. **响应式与无障碍** — mobile/tablet/desktop、键盘导航、ARIA
7. **未解决设计决策** — 决策表 + 延迟影响

**8 个设计原则:** 空状态即功能、每屏有层次、具体性 > 氛围、边界情况即体验、AI 垃圾是敌人、响应式是有意设计、无障碍必须、默认减法

---

### 4.5 /design-consultation — 设计系统创建

**版本:** 1.0.0 | **触发:** "design system", "create branding"

**6 个阶段:**
1. Phase 0: 预检 (现有 DESIGN.md、产品上下文)
2. Phase 1: 产品上下文收集
3. Phase 2: 研究 (WebSearch + browse 视觉调研)
4. Phase 3: 完整提案 (SAFE/RISK 分解)
5. Phase 4: 深入 (字体/颜色/美学/布局/间距/动效)
6. Phase 5: 字体 & 颜色预览页 (自包含 HTML)
7. Phase 6: 写入 DESIGN.md

**美学方向 (10 种):** Brutally Minimal / Maximalist Chaos / Retro-Futuristic / Luxury-Refined / Playful-Toy-like / Editorial-Magazine / Brutalist-Raw / Art Deco / Organic-Natural / Industrial-Utilitarian

**字体黑名单:** Papyrus, Comic Sans, Lobster, Impact, Jokerman
**过度使用警告:** Inter, Roboto, Arial, Helvetica, Open Sans, Lato, Montserrat, Poppins

---

### 4.6 /review — 预合并 PR 审查

**版本:** 1.0.0 | **触发:** "code review", "before merge"

**两遍审查:**
- **CRITICAL** — SQL 安全、LLM 信任边界、竞态条件、陈旧数据、认证绕过
- **INFORMATIONAL** — 可维护性、测试覆盖、性能、安全信号

每个发现包含: 上下文、证据、建议修复、置信度

**依赖:** Greptile API (代码分析) + /codex (跨模型验证)

---

### 4.7 /codex — OpenAI Codex CLI 封装

**版本:** 1.0.0 | **触发:** "codex review", "second opinion", "adversarial review"

**三种模式:**
1. **Review** — 独立 diff 审查: `codex review --base <base>` → PASS/FAIL
   - FAIL: 输出包含 [P1] 标记
   - PASS: 仅 [P2] 或无发现
2. **Challenge** — 对抗模式: 查找边界情况/竞态/安全漏洞/资源泄漏
3. **Consult** — 会话连续性 Q&A: `codex exec` + JSONL 推理轨迹

**关键设计:** 跨模型比较 — 如果 /review 和 /codex 同时运行，对比发现
**自递归保护:** gstack 在 Codex 内运行时，Codex 审查步骤被剥离 (防止无限循环)

---

### 4.8 /investigate — 系统化根因调试

**版本:** 1.0.0 | **触发:** "debug", "why is this failing"

**铁律: "没有根因调查就没有修复"**

**五个阶段:**
1. **根因调查** — 复现、隔离故障、日志分析
2. **模式分析** — 孤立问题还是系统性？
3. **假设测试** — 提出因果假设，验证
4. **实施** — 根因确认后修复
5. **验证** — 重新测试 + 检查邻近区域回归

**范围锁定:** 调试期间限制编辑到受影响模块
**失败边界:** 同一方法失败 ≥2 次 → 升级

---

### 4.9 /qa — 系统化 QA + 自动修复

**版本:** 1.0.0 | **触发:** "test the app", "QA and fix bugs"

**三个层级:**
- **Quick** — 首页 + 5 个导航目标
- **Standard** — 完整应用
- **Exhaustive** — 深度多页面

**流程:** 测试 → 发现 bug → 修复 → 重测 → 报告

**每页检查清单:** 视觉、交互、表单、导航、状态、控制台、响应式
**健康评分:** 控制台 15% + 链接 10% + 各类别 75%

**依赖:** /browse (无头 Chromium)

---

### 4.10 /qa-only — 仅报告 QA

**版本:** 1.0.0 | **触发:** "QA report", "test but don't fix"

与 /qa 相同流程但**永不修复**。产出结构化报告 + 健康评分 + 截图 + 复现步骤。

**四种模式:** Diff-aware (特性分支) / Full (URL 驱动) / Quick (30 秒冒烟) / Regression (baseline.json 对比)

---

### 4.11 /design-review — 设计师 QA (实时站点)

**版本:** 1.0.0 | **触发:** "design review", "visual check", "UX audit"

**四种模式:**
- Full (5-8 页): 完整视觉审计
- Quick (首页 + 2 关键页): 快速冒烟
- Deep (10-15 页): 穷尽深度审查
- Diff-aware: 仅变更屏幕

**检查模式:** 视觉不一致、间距问题、层次问题、AI 垃圾模式 (紫色渐变/气泡边框/通用素材)、空状态/加载状态/错误状态、响应式布局、对比度和无障碍

**迭代修复:** 发现问题 → 修改源码 → 原子提交 → 重新验证 (before/after 截图)

---

### 4.12 /ship — 完全自动化发布

**版本:** 1.0.0 | **触发:** "ship", "deploy", "ready to go"

**流程 (默认非交互):**
1. 检测 base 分支
2. 合并 (fast-forward 或常规)
3. 运行测试 (失败 = 回滚)
4. 审查 diff (gstack-review)
5. 版本号递增 (semver)
6. 更新 CHANGELOG
7. 提交变更
8. 推送到远程
9. 创建 PR

**Review Readiness Dashboard:** 追踪 Eng/CEO/Design/Codex 审查状态

---

### 4.13 /document-release — 发布后文档更新

**版本:** 1.0.0 | **触发:** "update docs", "post-ship docs"

**流程:**
1. 读取所有项目文档 (README, ARCHITECTURE, CONTRIBUTING, CLAUDE.md)
2. 与合并 diff 交叉引用
3. 逐文件审计: 是否仍准确？是否提到新代码？
4. 按需更新每个文档
5. 提交变更

运行在代码合并**之后** (不是之前)。

---

### 4.14 /retro — 周回顾

**版本:** 1.0.0 | **触发:** "retrospective", "weekly review"

**流程:**
1. 分析提交历史 (最近 30 个 commit)
2. 每人排行榜 (commits, contributions, PRs)
3. 贡献分析: insertions, deletions, 测试 LOC 比例
4. 热点分析: 最常变更文件、模式
5. 指标: 提交速度、贡献者多样性、测试比例趋势

持久化历史追踪 (跨周趋势)。关注速度和代码健康，不是指责。

---

### 4.15 /browse — 快速无头浏览器

**版本:** 1.1.0 | **详见第 3 节**

核心特性: ~100ms 命令延迟、持久化 cookies/tabs、快照 + diff、人机交接

---

### 4.16 /setup-browser-cookies — Cookie 导入

**版本:** 1.0.0 | **触发:** "import cookies", "login to site"

**流程:**
1. 定位 browse 二进制
2. 打开 cookie 选择器: `$B cookie-import-browser`
3. 自动检测: Comet/Chrome/Arc/Brave/Edge
4. 交互式 UI 选择域名
5. 验证: `$B cookies`

首次导入触发 macOS Keychain 对话框。

---

### 4.17 /careful — 破坏性命令守卫

**版本:** 0.1.0 | **触发:** "safety mode", "be careful"

**PreToolUse Hook** 检测模式:
- `rm -rf/-r/--recursive`
- `DROP TABLE/DATABASE`
- `TRUNCATE`
- `git push --force`
- `git reset --hard`
- `git checkout .`
- `kubectl delete`
- `docker rm -f`

**安全例外** (不警告): rm -rf node_modules/.next/dist/__pycache__/.cache/build/.turbo/coverage

返回 `permissionDecision: "ask"` + 警告消息。

---

### 4.18 /freeze — 编辑范围锁定

**版本:** 0.1.0 | **触发:** "lock edits", "restrict to directory"

**流程:**
1. AskUserQuestion 获取目录路径
2. 解析为绝对路径 + 添加尾部斜杠
3. 保存到 `~/.gstack/freeze-dir.txt`

**PreToolUse Hook** 匹配 Edit/Write → 路径不在 freeze 目录内则 `permissionDecision: "deny"`

---

### 4.19 /guard — 全安全模式

**版本:** 0.1.0 | **触发:** "guard mode", "maximum safety"

= /careful + /freeze 的组合。同时提供破坏性命令警告 + 目录编辑限制。

---

### 4.20 /unfreeze — 清除编辑限制

**版本:** 0.1.0 | **触发:** "unfreeze", "unlock edits"

删除 `~/.gstack/freeze-dir.txt`。Hook 保留但变为 no-op。

---

### 4.21 /gstack-upgrade — 版本管理

**版本:** 1.1.0 | **触发:** "upgrade gstack"

**流程:**
1. 检查 auto_upgrade 配置
2. 检测安装类型 (global-git/local-git/vendored/vendored-global)
3. 保存旧版本
4. 升级 (git fetch/reset 或 clone/move)
5. 同步本地 vendored 副本
6. 写入 `~/.gstack/just-upgraded-from` 标记
7. 读取 CHANGELOG.md 总结 5-7 要点

**Snooze 状态:** 指数退避 24h → 48h → 1 week

---

## 5. CLI 脚本与工具链

### bin/ 目录

| 脚本 | 用途 |
|------|------|
| `gstack-telemetry-log` | 追加遥测事件 (JSONL) |
| `gstack-telemetry-sync` | 后台 Supabase 上传 (限速 5 分钟) |
| `gstack-analytics` | 本地使用分析仪表盘 |
| `gstack-community-dashboard` | 远程社区指标 |
| `gstack-config` | YAML 键值存储 (get/set/list) |
| `gstack-slug` | 项目标识提取 (owner-repo) |
| `gstack-diff-scope` | 变更影响分类 (FRONTEND/BACKEND/...) |
| `gstack-review-log` | 审查结果原子追加 |
| `gstack-review-read` | 审查历史读取 |
| `gstack-update-check` | 版本检查 (智能缓存 + snooze) |
| `dev-setup` | 开发模式 (符号链接本地 checkout) |
| `dev-teardown` | 退出开发模式 |

### Skill 内 bin/ 脚本

| 脚本 | 所属 Skill | 用途 |
|------|-----------|------|
| `check-careful.sh` | /careful | PreToolUse 破坏性命令检测 |
| `check-freeze.sh` | /freeze | PreToolUse 编辑边界检查 |

### 遥测三层级

| 层级 | 写入本地 | 发送远程 | installation_id |
|------|---------|---------|-----------------|
| **off** | 否 | 否 | — |
| **anonymous** | 是 | 是 (剥离 ID) | null |
| **community** | 是 | 是 | SHA-256 hash |

### gstack-update-check 智能缓存

| 结果 | 缓存 TTL |
|------|---------|
| UP_TO_DATE | 60 分钟 |
| UPGRADE_AVAILABLE | 720 分钟 |

Snooze 级别: 24h → 48h → 7d (指数退避)

---

## 6. 测试基础设施

### 三层测试策略

| 层级 | 命令 | 成本 | 时间 | 内容 |
|------|------|------|------|------|
| **Tier 1 (Free)** | `bun test` | $0 | <2s | Skill 验证 + gen-skill-docs 质量 |
| **Tier 2 (Paid)** | `bun run test:evals` | ~$4 | ~20min | E2E via `claude -p` + diff-based |
| **Tier 3 (Paid)** | `bun run test:evals` | ~$0.15 | — | LLM-as-judge 质量评分 |

### 测试文件

| 文件 | 测试内容 |
|------|---------|
| `telemetry.test.ts` | 隐私层级/字段屏蔽/Supabase 同步 |
| `analytics.test.ts` | JSONL 解析/时间窗口/技能聚合 |
| `hook-scripts.test.ts` | Freeze 边界/Careful 模式检测 |
| `skill-parser.test.ts` | Browse 命令提取/快照标志验证 |
| `skill-validation.test.ts` | SKILL.md 结构完整性 |
| `skill-llm-eval.test.ts` | LLM-as-judge 质量评分 |
| `skill-e2e.test.ts` | Claude -p 端到端 |
| `gemini-e2e.test.ts` | Gemini CLI 互操作 |
| `touchfiles.test.ts` | Diff-based 测试选择 |

### Diff-Based 测试选择

通过 touchfiles 系统实现: 每个 E2E 测试声明其 TOUCHFILES glob 模式，仅运行受变更文件影响的测试。

---

## 7. 配置与状态管理

### 配置文件

| 文件 | 用途 |
|------|------|
| `~/.gstack/config.yaml` | 用户配置 (telemetry/proactive/codex_reviews/auto_upgrade) |
| `~/.gstack/browse.json` | 浏览器守护进程状态 (PID/port/token) |
| `~/.gstack/sessions/{PPID}` | 会话追踪 (2 小时 TTL) |
| `~/.gstack/analytics/skill-usage.jsonl` | 本地使用日志 |
| `~/.gstack/freeze-dir.txt` | Freeze 边界 |
| `~/.gstack/just-upgraded-from` | 升级标记 |
| `~/.gstack/.completeness-intro-seen` | 完整性介绍标记 |
| `~/.gstack/.telemetry-prompted` | 遥测同意标记 |

### 项目级状态

```
~/.gstack/projects/{SLUG}/
├── state.json                         浏览器状态
├── buffers-YYYY-MM-DD.jsonl          日志缓冲
├── ceo-plans/{date}-{feature}.md     CEO 审查计划
├── {user}-{branch}-test-plan-*.md    测试计划
├── *-design-*.md                     设计文档
├── {branch}-reviews.jsonl            审查日志
└── contributor-logs/*.md             贡献者反馈
```

---

## 8. 遥测与分析系统

### 设计原则

- **默认关闭** (首次安装不发送数据)
- **用户主动选择** (首次运行提示)
- **从不发送:** 代码、文件路径、仓库名、分支名、提示词

### 数据流

```
Skill 执行
  ↓ gstack-telemetry-log
追加到 ~/.gstack/analytics/skill-usage.jsonl
  ↓ 后台触发 gstack-telemetry-sync
检查 .last-sync-time (5 分钟最小间隔)
  ↓ 读取 .last-sync-line 游标
批量 HTTP POST 到 Supabase (最多 100 条/请求)
  ↓ 剥离本地字段 (_repo_slug, _branch)
  ↓ anonymous 层级额外剥离 installation_id
更新游标 → 完成
```

### 事件签名

```json
{
  "v": 1,
  "ts": "2026-03-22T10:00:00Z",
  "event_type": "skill_usage",
  "skill": "review",
  "session_id": "abc123",
  "gstack_version": "0.3.3",
  "os": "darwin",
  "arch": "arm64",
  "duration_s": 45,
  "outcome": "success",
  "error_class": null,
  "used_browse": true,
  "sessions": 3,
  "installation_id": "sha256...",
  "_repo_slug": "owner-repo",    // 本地字段，不上传
  "_branch": "main"              // 本地字段，不上传
}
```

---

## 9. 构建系统与 CI/CD

### 构建流程

```bash
bun run build
  → bun run gen:skill-docs              # 生成 Claude host skills
  → bun run gen:skill-docs --host codex # 生成 Codex host skills
  → bun build --compile browse/src/cli.ts --outfile browse/dist/browse
  → bun build --compile browse/src/find-browse.ts --outfile browse/dist/find-browse
  → bash browse/scripts/build-node-server.sh  # Windows Node.js 回退
  → git rev-parse HEAD > browse/dist/.version  # 嵌入版本 hash
```

### GitHub CI

`.github/workflows/skill-docs.yml`:
- 触发: push + pull_request
- 验证 Claude host SKILL.md 新鲜度
- 验证 Codex host SKILL.md 新鲜度
- 生成文件与 Git 状态不匹配则构建失败

### 依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| playwright | ^1.58.2 | 浏览器自动化 (运行时) |
| diff | ^7.0.0 | 快照 diff (运行时) |
| @anthropic-ai/sdk | ^0.78.0 | Claude API (仅开发/评估) |

---

## 10. 跨平台支持

### 多主机适配

| 主机 | 安装路径 | SKILL.md 路径 |
|------|---------|-------------|
| Claude Code | `~/.claude/skills/gstack/` | 主 SKILL.md |
| Codex | `~/.codex/skills/gstack/` | `.agents/skills/gstack-*/SKILL.md` |
| Gemini CLI | `.agents/skills/gstack/` | 同 Codex |

### Windows 支持 (v0.9.3.0+)

- Bun 服务端回退到 Node.js (Bun 在 Windows 上无法控制 Playwright Chromium)
- `browse/scripts/build-node-server.sh` 转译为 `server-node.mjs`
- `bun-polyfill.cjs` 提供 Bun.serve()/Bun.spawn() 等 API 兼容
- 15 秒启动超时 (vs Unix 8 秒)
- Cookie 解密仅 macOS (Keychain)

---

## 11. 安全模型

### 浏览器安全

- **Localhost 绑定** — 不是 `0.0.0.0`
- **Bearer Token 认证** — UUID, 状态文件 mode 0o600
- **Keychain 审批** — macOS Keychain UI 对话框
- **进程内解密** — cookie 值从不存储明文
- **硬编码浏览器注册表** — 无 shell 注入
- **URL 验证** — 阻止 `javascript:` scheme + 云元数据端点 (169.254.169.254)
- **路径验证** — 输出文件限制在 TEMP_DIR 和 cwd 内

### 编辑安全

- `/careful` — 破坏性命令警告 (PreToolUse hook)
- `/freeze` — 目录编辑锁 (PreToolUse hook)
- `/guard` — 两者组合

### 隐私安全

- 遥测默认关闭
- 从不发送代码/路径/提示词
- 本地字段在上传前剥离
- Supabase insert-only RLS

---

## 12. 设计模式与惯例

### 所有 Skill 共享的 Preamble

每个 skill 启动时运行:

```bash
# 版本升级检查
gstack-update-check

# 会话管理
mkdir -p ~/.gstack/sessions
touch ~/.gstack/sessions/$PPID
find ~/.gstack/sessions -mmin +120 -delete

# 配置
gstack-config get gstack_contributor
gstack-config get proactive

# 遥测
gstack-telemetry-log --skill --duration --outcome

# 完整性介绍 (一次性)
# 遥测同意 (一次性)
```

### AskUserQuestion 四部分格式

1. **Re-ground:** 项目、分支、当前任务
2. **Simplify:** 16 岁能懂的简明英语
3. **Recommend:** 包含 Completeness: X/10
4. **Options:** 字母选项 A/B/C + 人力/CC 工时对比

### 完整性原则 ("Boil the Lake")

AI 辅助编码让完整性的边际成本接近零。

| 任务类型 | 人工 | CC+gstack | 压缩比 |
|---------|------|-----------|--------|
| 模板/脚手架 | 2 天 | 15 分钟 | 100x |
| 测试编写 | 1 天 | 15 分钟 | 50x |
| 功能实现 | 1 周 | 30 分钟 | 30x |
| Bug 修复 + 回归 | 4 小时 | 15 分钟 | 20x |
| 架构/设计 | 2 天 | 4 小时 | 5x |
| 研究/探索 | 1 天 | 3 小时 | 3x |

### 完成状态协议

所有 skill 使用统一状态:
- **DONE** — 成功完成，提供证据
- **DONE_WITH_CONCERNS** — 完成但有问题
- **BLOCKED** — 无法继续，说明原因
- **NEEDS_CONTEXT** — 缺少信息

升级阈值: 同一假设 3 次失败或安全不确定

### 关键设计模式

1. **Fire-and-Forget 异步** — 遥测同步从不阻塞 skill 执行
2. **游标恢复** — 同步失败不丢事件，游标保留待重试
3. **隐私 by Design** — 遥测层级内置，本地字段传输前剥离
4. **崩溃恢复** — .pending 标记在下次会话启动时清理
5. **速率限制** — 5 分钟最小同步间隔防止 Supabase 洪水
6. **优雅降级** — 缺少配置/认证不崩溃，功能降级
7. **原子更新** — 审查日志原子写入防止损坏
8. **Hook 安全** — 破坏性操作在执行前验证
9. **Diff-Based 选择** — 仅运行受影响测试
10. **智能缓存** — 版本检查根据结果使用不同 TTL

---

## 13. Token 消耗分析

### 每次对话的固定开销

gstack 的 token 消耗主要来自:

1. **Skill 列表注入** — 每次对话 system-reminder 中注入所有 21 个 skill 描述 (~3000-5000 tokens)
2. **SKILL.md 加载** — 每次调用 skill 时加载完整 SKILL.md 到 context (~2000-8000 tokens/skill)
3. **Preamble 执行** — 每个 skill 的版本检查 + 配置读取 (~500 tokens)
4. **Browse 命令输出** — 快照/截图等输出 (~500-2000 tokens/次)

### 对比 (单次会话)

| 场景 | 原生 Claude Code | + gstack |
|------|----------------|---------|
| 空闲 (仅 skill 列表) | 0 | ~4000 tokens |
| 使用 1 个 skill | 0 | ~6000-12000 tokens |
| 完整 sprint | 0 | ~30,000-50,000 tokens |
| Browse 20 次命令 | N/A | 0 (CLI 无 token 开销) |

Browse 子系统是**唯一没有 token 开销**的部分，因为它通过 shell 而非 MCP 协议通信。

---

## 14. 与 Baton 对比

### 功能覆盖矩阵

| 能力 | Baton | gstack | 优势方 |
|------|-------|--------|--------|
| 计划/设计 | baton-plan | plan-ceo/eng/design-review + office-hours | gstack (多视角) |
| 研究 | baton-research (模板化) | 无专门 skill | Baton |
| 实施 | baton-implement | superpowers:executing-plans | 平手 |
| 调试 | baton-debug | /investigate | 平手 |
| 审查 | baton-review (对抗式) | /review + /codex (跨模型) | gstack (跨模型) |
| QA | 无 | /qa + /qa-only + /browse | gstack |
| 发布 | 无 | /ship + /document-release | gstack |
| 回顾 | 无 | /retro | gstack |
| 设计 | 无 | /design-consultation + /design-review | gstack |
| 安全守卫 | write-lock + stop-guard + failure-tracker | /careful + /freeze + /guard | 平手 |
| 治理门控 | BATON:GO + 状态机 + constitution | 无 (流程非强制) | Baton |
| 证据标记 | ✅/❓ 系统 | 无 | Baton |
| 并行代理 | baton-subagent | superpowers:dispatching-parallel-agents | 平手 |

### 核心差异

| 维度 | Baton | gstack |
|------|-------|--------|
| **设计哲学** | 治理优先 (invariants, gates) | 工作流优先 (roles, sprint) |
| **强制方式** | Hook 强制 + Constitution | Skill 建议 (可关闭) |
| **Token 开销** | 中等 (hooks + skills) | 较高 (21 skill 列表 + preamble) |
| **浏览器** | 无 | 完整无头 Chromium |
| **跨模型** | 无 | Codex CLI 集成 |
| **覆盖范围** | 研究→实施 (4 阶段) | 构思→回顾 (全生命周期) |

---

## 附录: 文件清单

### 核心文件

```
~/.agents/skills/gstack/
├── ARCHITECTURE.md          (21KB) 系统设计文档
├── AGENTS.md                (2.6KB) 角色 & 构建命令
├── BROWSER.md               (17KB) 浏览器技术参考
├── README.md                (200行) 愿景 & 用户指南
├── CHANGELOG.md             (67KB) 完整版本历史
├── CLAUDE.md                (11KB) 开发命令 & 惯例
├── CONTRIBUTING.md          (15KB) 贡献者指南
├── package.json             (54行) 依赖 & 脚本
├── LICENSE                  MIT
├── setup                    安装脚本
└── conductor.json           并行工作区配置
```

### Skills (21 个)

```
browse/         careful/        codex/          design-consultation/
design-review/  document-release/ freeze/       gstack-upgrade/
guard/          investigate/    office-hours/   plan-ceo-review/
plan-design-review/ plan-eng-review/ qa/        qa-only/
retro/          review/         setup-browser-cookies/
ship/           unfreeze/
```

### Browse 源码 (16 个文件)

```
browse/src/
├── browser-manager.ts  cli.ts          commands.ts
├── config.ts           buffers.ts      cookie-import-browser.ts
├── cookie-picker-routes.ts  cookie-picker-ui.ts  find-browse.ts
├── meta-commands.ts    platform.ts     read-commands.ts
├── server.ts           snapshot.ts     url-validation.ts
└── write-commands.ts
```

### CLI 脚本 (12 个)

```
bin/
├── dev-setup           dev-teardown      gstack-analytics
├── gstack-community-dashboard  gstack-config  gstack-diff-scope
├── gstack-review-log   gstack-review-read gstack-slug
├── gstack-telemetry-log gstack-telemetry-sync gstack-update-check
```
