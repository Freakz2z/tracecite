# TraceCite

**用 MoonBit 检查 Markdown 文档引用是否仍然有效：本地文件、标题、源码片段，以及网页引文。** 保存一次引用快照后，来源改变会定位到需要重新审阅的文档行。

这是 0.5.0 开发版的文档；公开的 `v0.4.0` 不包含新的 `check` 入口。当前从包含此改动的源码 checkout 运行即可。

## 背景及痛点

代码和配置持续更新，README 中复制的片段却容易留在旧版本；文件迁移或标题改名后，文档里的相对路径和锚点也可能失效。报告引用的网页仍能打开，原文或上下文却已经改变。维护者需要知道具体哪份文档、哪一行需要复核。

TraceCite 将这些引用视为文档的依赖。它直接读取 Markdown 和引用来源，不需要模型 API、Agent 事件导出、数据库或常驻服务。本地检查默认离线；用户明确添加 `--online` 才访问网页。根目录的 [模块配置](moon.mod)只声明异步 I/O 与 HTML 解析两个外部 MoonBit 库。

## 面向场景

- **源码或配置更新后**：检查绑定了来源的文档代码块，发现复制片段与当前文件不一致。
- **整理仓库文档时**：检查相对路径、Markdown 标题、指定行范围与命名区域，定位失效引用。
- **报告发布前或再次使用时**：检查网页逐字引文，并比较上次独立读取的引用上下文。
- **PR 合并前**：用退出码和 GitHub 文件行号诊断，把需要更新的文档交给作者复核。

## 解决方案

一个入口：`tracecite check`。可以检查一个文件、一个目录或多个路径。它支持普通行内链接和引用式链接；来源路径相对文档所在目录解析。

代码片段只需在代码围栏上标一次 `source=路径`。下面这段是本项目真实的模块配置，检查 README 时会直接核对 [moon.mod](moon.mod)：

```text source=moon.mod
preferred_target = "native"
```

片段按完整行比较，保留引号、标点和缩进；只统一 Windows/Unix 换行。默认在整个来源文件中寻找片段，因此来源前面增加几行不会使引用失效。

## 快速开始

需要 `moonc >= 0.10.14`。安装方式见 [MoonBit 官方教程](https://docs.moonbitlang.com/en/stable/tutorial/tour.html#installation)。在当前源码 checkout 中执行：

```sh
moon update
moon run cmd/main check README.mbt.md docs/maintenance.md --strict
```

检查自己的仓库时，`--root` 指定仓库根目录，后面的扫描路径相对这个根目录：

```sh
moon run cmd/main check docs README.md --root /path/to/your/repository --strict
```

本地引用不会访问网络。需要检查网页引文时：

```sh
moon run cmd/main check examples/inline-report.md --online --strict
```

也可以构建本机独立可执行文件。运行它时不需要 MoonBit、Python 或 Node：

```sh
bash scripts/package.sh
./_build/native/release/build/cmd/main/main.exe check README.mbt.md --strict
```

打包脚本在 `dist/` 生成压缩包。GitHub 的 [打包工作流](.github/workflows/binaries.yml)会在手动触发或推送版本标签时构建 Linux/macOS 包；当前不代表这些新版本产物已经公开发布。

## 保存与复核引用快照

首次独立读取来源后保存快照；之后比较同一份文档，无需运行 Agent 或准备 JSONL：

```sh
moon run cmd/main check README.mbt.md docs/maintenance.md --snapshot .tracecite-docs.json
moon run cmd/main check README.mbt.md docs/maintenance.md --baseline .tracecite-docs.json --strict
```

快照使用相对文档路径，不把本机绝对路径写入记录。移动文档中的段落不会改变引用身份。引用内容不匹配或引用区域改变时会失败，并显示文档片段、候选来源片段或前后观察值。新增引用需要复核；检查通过后，用不带 `--baseline` 的 `--snapshot` 命令接受新的基线。

失败或存在未能核查的引用时不写快照，也不会自动覆盖旧基线。离线快照只覆盖实际检查过的本地引用；网页引文需要在保存和复查时都使用 `--online`。

## GitHub Action

本仓库使用当前 checkout 的 Action 检查自身文档。此改动发布到仓库后，其他项目可指定包含该功能的提交：

```yaml
- uses: actions/checkout@v5
- uses: Freakz2z/tracecite@main
  with:
    path: docs
    strict: 'true'
    baseline: .tracecite-docs.json
```

正式使用应固定到审核过的提交 SHA。`online` 默认为 `false`；`exclude` 支持每行一个根目录相对路径。Action 安装并编译 MoonBit，在调用方仓库中解析引用，并产生文件行号诊断。旧的 `report:` 输入仍兼容，并启用联网检查。

## 覆盖范围与边界

- 普通本地链接检查文件或目录是否存在。带片段的链接支持 ATX Markdown 标题、`#L10-L20` 和 `#region:name`；后者使用来源文件里的 `ANCHOR: name` / `ANCHOR_END: name` 注释。
- 行内引文支持中文弯双引号与英文直双引号；多行或关联不明确的引文使用显式原文、来源块。详细语法见 [维护指南](docs/maintenance.md)。
- 没有 `source=` 的代码块不运行，也不会假装已经核查：它们计入覆盖摘要。未关联的引文、无法解析的来源会提示复核，`--strict` 让这些提示导致失败。
- 默认输出 `LOCAL_OK` 只表示本地检查通过，并列出跳过的网页引用。整个输入没有任何可检查引用时返回失败。
- 网页引文只能确认检查时可提取的原文是否存在。图片、动态页面、登录墙可能需要人工核查；工具不判断论断的语义真假。来源变化表示需要复核，不表示文档一定错误。
- 来源解析限制在 `--root` 中，包括符号链接的真实目标；本地正文和网页请求各限制 2 MiB。网页回源还限制默认端口、重定向、公开地址与 20 秒超时，完整行为见 [输入约定](docs/contract.md#http-回源行为)。

## 验证与开发

当前检查的是可执行能力，不能据此宣称用户采用率或节省了多少审核工时。既有网页引文的 [第三方资料审计](docs/external-audit.md)和 [普通报告试验](examples/field-trial/README.md)保留了样本、结果与局限；新文档维护流程由临时仓库集成测试覆盖。

```sh
moon info
moon fmt
moon check --deny-warn
moon test --deny-warn
moon test --target js --deny-warn
moon test --target wasm --deny-warn
python3 scripts/test_document_cli.py
python3 -m unittest discover -s adapters -p 'test_*.py'
sh scripts/smoke.sh
```

Python 仅用于开发测试和可选的旧 Agent 适配器。原来的 JSONL 校验、`verify-files`、`verify-urls`、`verify-notes`、`check-report` 和 `compare` 仍可使用，见 [兼容接口](docs/contract.md)。

项目以 MoonBit 为主要实现语言，核心库可用于 native、JS 和 Wasm；文件与联网 CLI 使用 native。使用 [Apache-2.0 许可证](LICENSE)，HTML 解析依赖 `bobzhang/html_parser`（Apache-2.0）。已有发布包见 [Mooncakes](https://mooncakes.io/docs/Freakz2z/tracecite)；0.5.0 发布状态请以平台为准。
