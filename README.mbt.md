<p align="center">
  <img src="./assets/readme/hero.svg" width="100%" alt="TraceCite 用 MoonBit 核对 Agent 引用：IANA 网页引用匹配 1/1，两次 Codex CLI 运行的同一来源发生变化">
</p>

# TraceCite

**用 MoonBit 核对 AI Agent 的逐字引文，并发现来源内容何时改变。** TraceCite 从 Markdown 报告中提取引文和链接，独立回访来源，指出不匹配的报告行号；也能检查本地文件和比较两次 Agent 运行的来源。

## 背景及痛点

AI 生成的报告常附有链接，但链接能打开，不代表引号里的文字真出现在该页面。编辑者逐条打开网页、查找原文既费时，也容易漏掉改写过的引文。报告交付后，来源内容还可能变化，旧引文需要重新复核。

这不是只存在于受控样例中的问题。在一份[独立公开资料的固定取样](docs/external-audit.md)中，TraceCite 识别了全部 10 条引文并提示 3 条需复核；人工确认 **2 条不是来源中的连续原文**。另 1 条来自无法可靠提取正文的 X 页面，不能判为错引。只修正前两条，本地副本的匹配数便从 **7/10** 升至 **9/10**。

## 面向场景

- **报告合并或发布前**：作者提交带引文和网页链接的 Markdown 报告；CI 回源检查识别到的逐字引文，失败时定位到报告行，作者修订引文或来源后重跑。
- **本地资料被 Agent 引用时**：把工具调用与引用导出为 JSONL；审核者运行 `verify-files` 回读当前文件，发现轨迹记录与文件内容不一致的来源。
- **模型、提示词或知识库更新后**：保存更新前后的运行轨迹并执行 `compare`；团队按新增、删除或改变的来源 URI 定位需要重新审阅的回答。

## 解决方案

`check-report` 直接识别普通 Markdown 中“逐字引文＋附近的来源链接”，也支持显式“原文＋来源”引用块。它按 URL 去重访问 HTTP/HTTPS 来源，提取 HTML 可见文本，核对引文并输出行号、JSON 结果和适合 CI 的退出码。`verify-urls`、`verify-files` 与 `compare` 则处理需要保留调用链或跨运行记录的 JSONL。完整格式见[输入约定](docs/contract.md)。

三份预先确定主题的 Codex CLI 报告，在旧版中有 **0/16** 条普通行内引文能直接解析；现在无需转写报告即可核验 **16/16** 条。[原稿与试验记录](examples/field-trial/README.md)可复查。这三份报告没有自然错引或实际改稿；工具只证明逐字引文出现在检查时的来源中，不判断整句主张是否正确。

## 快速开始

项目要求 `moonc >= 0.10.14`。macOS/Linux 可用 [MoonBit 官方安装脚本](https://docs.moonbitlang.com/en/stable/tutorial/tour.html#installation)安装；Windows 安装方式见同一文档。

```sh
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
```

安装后重新打开终端，让 `moon` 和 `moonc` 进入 `PATH`，再获取仓库并安装依赖：

```sh
git clone https://github.com/Freakz2z/tracecite.git
cd tracecite
moon update
moonc -v
```

普通 Markdown 中，逐字引文后的来源链接即可被检查。下面的报告不需要专用标记、JSONL 或适配器：

```markdown
IANA explains that “example.com and example.org are maintained for documentation purposes.” ([IANA](https://www.iana.org/help/example-domains))
```

也可以把原文和来源写成相邻的引用块；行内代码反引号会作为排版符号处理。

```markdown
> 原文：“example.com and example.org are maintained for documentation purposes.”
> 来源：[IANA example domains](https://www.iana.org/help/example-domains)
```

在仓库根目录运行：

```sh
moon run cmd/main check-report examples/inline-report.md
moon run cmd/main check-report examples/report.md
```

失败时命令指出报告行号并返回退出码 2，可以作为 PR 的 CI 门禁。[故意写错的行内引用](fixtures/inline-report-wrong-quote.md)展示失败路径。完整输入约定见[格式说明](docs/contract.md)。

在其他 GitHub 仓库中，只需添加一个 CI 步骤（仓库先由 `actions/checkout` 检出）：

```yaml
- uses: Freakz2z/tracecite@v0.4.0
  with:
    report: reports/research.md
```

这一 Action 会安装 MoonBit、编译 TraceCite 并核对报告，失败时让 CI 标红。建议为工作流设置 `permissions: contents: read`，不要向检查步骤提供密钥。

下面是仓库样例的实际输出。第一个命令重新请求 [IANA 示例域名页面](https://www.iana.org/help/example-domains)；第二个命令比较两次 Codex CLI 轨迹，其中测试文件的内容由开发者刻意修改：

```text
$ moon run cmd/main check-report examples/inline-report.md
PASS: 1/1 quotes appear in 1 live web source
  examples/inline-report.md:3 PASS https://www.iana.org/help/example-domains

$ moon run cmd/main compare fixtures/codex-two-run-before.jsonl fixtures/codex-two-run-after.jsonl
1 source changes; 0 unchanged
  [changed] file:fixtures/codex-live-run-source.txt
```

来源变化是刻意构造的测试值；第二个命令返回退出码 2，便于 CI 标记需要重审的回答。[脱敏事件与复现过程](docs/live-validation.md)可查。

## 单条引用也可用三行笔记

不方便修改原报告时，可单独写一条 `claim + quote + URL` 记录：

```text
claim: IANA lists example.com and example.org as documentation examples.
quote: example.com and example.org are maintained for documentation purposes.
url: https://www.iana.org/help/example-domains
```

```sh
moon run cmd/main verify-notes fixtures/simple-citation.md
```

把这三行保存为自己的笔记文件后，传给 `verify-notes` 即可；多条记录用空行或 `---` 分隔。两个命令都支持 `--json` 输出。[完整输入约定](docs/contract.md)。

## 已有 Agent 轨迹怎么接入

- **网页来源**：`verify-urls <trace.jsonl>` 先核对轨迹中的调用、来源和引用，再重新请求 URL，检查当前页面是否仍含引用片段。
- **本地文件**：`verify-files <trace.jsonl>` 回读 `file:` 来源，发现捕获内容与当前文件不一致。
- **两次运行**：`compare <before.jsonl> <after.jsonl>` 按稳定来源 URI 报告新增、删除和内容变化。

仓库提供 [Codex CLI 适配器](adapters/codex_cli.py)及其[真实运行样例](docs/live-validation.md)。其他 Agent 可以生成同一 [JSONL 约定](docs/contract.md)；MoonBit 核心库支持 native、JS 和 Wasm，联网 CLI 在 native 目标运行。

根目录的 MoonBit 文件实现解析、证据验证与来源比较；`cmd/main/` 提供联网命令行，`adapters/` 是可选的 Codex CLI 导出器，`fixtures/` 保留可复现样例。

## 校验边界

TraceCite 确认的是**引用片段在检查时出现在独立读取的来源中**。引号字形差异会归一化；明确写出省略号时，要求省略号两侧的较长片段按顺序出现。它不判断整条 claim 的语义真假，也不能证明网页在 Agent 原始运行时的内容。动态页面或图片中的引文可能无法由可见文本提取器验证；跨运行比较需要稳定来源 URI。

HTTP 回源只接受默认端口的 HTTP/HTTPS URL，最多跟随五次重定向；单个来源限制为 20 秒和 2 MiB。当前网络库在连接时重新解析域名，因而不适合作为处理攻击者可控 URL 的服务端网络隔离层。地址筛选与内容类型规则见[输入约定](docs/contract.md)。

## 开发与许可

```sh
moon info
moon fmt
moon check --deny-warn
moon build --deny-warn
moon test --deny-warn
moon test --target js --deny-warn
moon test --target wasm --deny-warn
sh scripts/smoke.sh
python3 -m unittest discover -s adapters -p 'test_*.py'
```

项目使用 [Apache-2.0 许可证](LICENSE)，HTML 解析依赖 `bobzhang/html_parser`（Apache-2.0）。模块发布在 [Mooncakes：Freakz2z/tracecite](https://mooncakes.io/docs/Freakz2z/tracecite)。
