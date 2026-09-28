# 普通 Markdown 报告试验（2026-09-28）

为检验真实输入成本，先确定三个技术写作任务，再让 Codex CLI 0.149.0（`gpt-5.6-sol`）一次性生成 Markdown 报告。任务分别涉及 MoonBit 发布、GitHub Actions 工作流和 Python 打包；提示只要求引用官方网页的 4–6 条短英文原文，并在附近放普通 Markdown 来源链接，**没有指定 TraceCite 的引用块格式或预设错误**。原始输出分别保存在 [MoonBit](moonbit-publish.md)、[GitHub Actions](github-actions.md) 和 [Python 打包](python-packaging.md)。

| 阶段 | 结果 |
| --- | --- |
| `0.2.0` 直接检查三份原稿 | 0/16 条被解析，三份均报 `NO_REPORT_CITATIONS` |
| 加入行内引文解析后的首次检查 | GitHub 5/5、MoonBit 4/5、Python 5/5；MoonBit 另有 1 条未提取 |
| 修复同句后置链接与 HTML 行内代码空格后 | 三份原稿分别 5/5、6/6、5/5，合计 16/16；输入准备为 0 次人工转写 |

MoonBit 首次不匹配的引文实际上存在于[官方 Workspace 文档](https://docs.moonbitlang.com/en/latest/toolchain/moon/workspace.html#work-at-workspace-root)：HTML 将行内代码与右括号分成节点，文本提取产生额外空格。修正标准化后通过；它是工具误报，不计为模型错引。另一条引文的来源链接隔着几字解释文字，原解析器未提取，随后补上同句链接关联。

最终复测三份报告，`check-report` 依次用约 5.78、2.52、0.74 秒（单次本机观测，随网络变化）。三份原稿都没有发现需要修正的逐字引文，**真实报告改稿数为 0**。这些结果证明工具不再要求用户重写普通 Markdown 引用，也不能证明自然错引发现率、语义正确性或实际节省的人工审核时间。受控错引的失败路径另见[公开样例](../inline-report.md)和 `fixtures/inline-report-wrong-quote.md`。

复测命令（从仓库根目录运行）：

```sh
moon run cmd/main check-report examples/field-trial/github-actions.md
moon run cmd/main check-report examples/field-trial/moonbit-publish.md
moon run cmd/main check-report examples/field-trial/python-packaging.md
```
