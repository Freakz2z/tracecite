# 真实回源与 Agent 轨迹验证

最后验证：2026-09-28。

## HTTP/HTTPS 网页回源

使用 IANA 的[示例域名说明页](https://www.iana.org/help/example-domains)，轻量笔记中的引用为：

> example.com and example.org are maintained for documentation purposes.

执行 `moon run cmd/main verify-notes fixtures/simple-citation.md --json`，结果为 `source_count=1`、`citation_count=1`、`matched_count=1`，退出码 0。使用包含相同 URL、捕获片段和引用的 [`web-source-trace.jsonl`](../fixtures/web-source-trace.jsonl) 执行 `moon run cmd/main verify-urls fixtures/web-source-trace.jsonl --json`，结果同样为 `1/1 matched`、退出码 0。这两项都由新实现的 MoonBit HTTP 客户端实际请求网页并通过 HTML 解析器提取文本。

## 两次真实 Codex CLI 运行

使用 Codex CLI 0.149.0 和 `gpt-5.6-sol`，在只读沙箱中运行两次。两次都实际执行 `cat fixtures/codex-live-run-source.txt`，然后按工具输出给出逐字引用；两次事件流各包含一个成功命令和一条最终回答。

第一次测试来源内容为 `The archive release date is 2026-10-01.`，回答为 `The archive release date is 2026-10-01. [source-1]`。更新同一路径的测试文件后，第二次来源内容为 `The archive release date is 2026-10-04.`，回答也引用新日期。这些日期是专门构造的测试值，不代表现实项目的发布计划。事件流经过脱敏，分别保存在[第一次事件](../fixtures/codex-two-run-before-events.jsonl)和[第二次事件](../fixtures/codex-two-run-after-events.jsonl)；适配器导出的[旧轨迹](../fixtures/codex-two-run-before.jsonl)与[新轨迹](../fixtures/codex-two-run-after.jsonl)保留相同 URI：`file:fixtures/codex-live-run-source.txt`。

本地验证命令：

```sh
python3 adapters/codex_cli.py fixtures/codex-two-run-before-events.jsonl --bind source-1=fixtures/codex-live-run-source.txt --out /tmp/tracecite-before.jsonl
python3 adapters/codex_cli.py fixtures/codex-two-run-after-events.jsonl --bind source-1=fixtures/codex-live-run-source.txt --out /tmp/tracecite-after.jsonl
moon run cmd/main /tmp/tracecite-before.jsonl --evidence
moon run cmd/main /tmp/tracecite-after.jsonl --evidence
moon run cmd/main compare /tmp/tracecite-before.jsonl /tmp/tracecite-after.jsonl
moon run cmd/main verify-files fixtures/codex-two-run-after.jsonl
```

两份轨迹都通过证据校验（各 3 个事件、1 次调用、1 条引用，`1/1 matched`）。比较结果为 `1 source changes; 0 unchanged`，来源报告为 `changed`；第二次轨迹的文件回读也通过。

样例数据是刻意构造的无敏感内容，来源变化由开发者在两次 Agent 调用之间写入。它证明了真实 Agent 事件可被适配器采集，并能围绕真实运行的来源变化做核对；它不代表外部用户采用率，也不证明语义事实正确。完整功能边界见[输入约定](contract.md)。
