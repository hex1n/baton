# dispatch.sh 中的 hook 目录是怎么确定的

## 直接回答

`dispatch.sh` 中没有名为 `hook_dir` 的变量。承担"hook 目录"职责的变量是 `_dir`，定义在第 8 行：

```bash
_dir="$(cd "$(dirname "$0")" && pwd)"
```

这是一个经典的 bash 自定位模式：取 `$0`（脚本自身路径）的目录部分，`cd` 进去后 `pwd` 获取绝对路径。也就是说，`_dir` 永远指向 `dispatch.sh` 自己所在的目录。

## 完整调用链

理解 `_dir` 的值需要看 `dispatch.sh` 是怎么被调用的。整个链条分三层：

### 1. IDE 注册层

Claude Code 的 `.claude/settings.json` 注册了各事件的 hook command，例如：

```json
"command": ".baton/hooks/run-hook.cmd PreToolUse"
```

IDE 从项目根目录执行这条命令，所以 `run-hook.cmd` 的路径是相对于项目根的 `.baton/hooks/run-hook.cmd`。

### 2. run-hook.cmd 转发层

`run-hook.cmd` 是一个 polyglot 文件（同时是合法的 cmd batch 和 bash script）：

- **Windows (cmd.exe) 路径**：用 `%~dp0` 获取自身所在目录，存入 `HOOK_DIR`，然后调用 `"%HOOK_DIR%dispatch.sh"`。`%~dp0` 是 cmd 内建的"当前批处理文件所在目录（含尾部反斜杠）"。
- **Unix (bash) 路径**：用 `SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"` 同样获取自身目录，然后 `exec bash "${SCRIPT_DIR}/dispatch.sh" "$@"`。

两个平台的效果相同：`dispatch.sh` 收到的 `$0` 是一个指向 `.baton/hooks/dispatch.sh` 的路径（绝对或相对取决于调用方式，但 `dispatch.sh` 自己会在第 8 行再做一次绝对化）。

### 3. dispatch.sh 自定位

```bash
_dir="$(cd "$(dirname "$0")" && pwd)"
```

无论 `$0` 是绝对路径还是相对路径，这一行都会解析出绝对路径。最终 `_dir` 的典型值为：

```
C:/Users/hexin/IdeaProjects/baton/.baton/hooks
```

（或者如果项目使用了 junction/symlink 分发，可能指向 `~/.baton/hooks`——取决于 `.baton/` 是实体目录还是 junction。）

## _dir 在 dispatch.sh 中的用途

`_dir` 在脚本中有两处使用：

1. **定位 manifest.conf**（第 9 行）：`_manifest="$_dir/manifest.conf"` — manifest 和 dispatch.sh 同目录。
2. **执行 hook 脚本**（第 52 行）：`( . "$_dir/$_script.sh" )` — 通过 manifest 中读取的脚本名拼出完整路径，在子 shell 中 source 执行。

## Junction 对路径的影响

由于 baton 使用 junction 分发架构（`~/.baton/` 是 single source of truth，项目中的 `.baton/` 可能是指向它的 NTFS junction），`_dir` 解析出的路径可能是 junction 的目标路径（即 `~/.baton/hooks`）而非项目内的路径。这在功能上没有区别，因为 hook 脚本通过 `_dir` 相对定位 manifest 和其他 hook 脚本，与项目目录无关。项目目录通过独立的 `BATON_PROJECT_DIR="$(pwd)"` 在第 15 行捕获。

## 总结

| 层级 | 变量 | 取值方式 | 解析到 |
|------|------|----------|--------|
| run-hook.cmd (Windows) | `HOOK_DIR` | `%~dp0` | `.baton\hooks\` |
| run-hook.cmd (Unix) | `SCRIPT_DIR` | `$(cd "$(dirname "$0")" && pwd)` | `.baton/hooks` |
| dispatch.sh | `_dir` | `$(cd "$(dirname "$0")" && pwd)` | `.baton/hooks`（绝对路径） |

三层都用同一个模式——"自身所在目录"——确保无论从哪里调用，hook 目录都能正确解析。
