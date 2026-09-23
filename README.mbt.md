# TraceCite

用 MoonBit 检查 AI Agent 回答里的来源引用，能否沿着同一次运行的 **回答 → 来源 → 工具结果 → 工具调用** 找回去。输入是 JSONL，输出是带行号和稳定错误码的诊断，适合在本地或 CI 中离线运行。

## 解决的问题

Agent 可能引用一个没有出现在检索结果中的来源，也可能把失败工具调用返回的来源当成有效证据。TraceCite 检查记录之间的结构关系，并给出可以复现的错误位置。

这是一项**来源链完整性检查**：它不联网，不读取被引用的网页，也不判断来源内容是否真的支持回答中的主张。输入记录本身的真实性仍由生成记录的应用负责。

## 快速运行

安装 [MoonBit 工具链](https://docs.moonbitlang.com/en/stable/tutorial/tour.html)后，在仓库根目录执行：

```sh
moon run cmd/main fixtures/valid.jsonl
moon run cmd/main fixtures/unknown-source.jsonl
moon run cmd/main fixtures/unknown-source.jsonl --json
```

第一条返回 `PASS` 和退出码 `0`。第二条返回 `UNKNOWN_SOURCE`、输入行号和退出码 `2`。文件无法读取或参数错误时退出码为 `1`。`--json` 会输出来源记录、声明引用边和诊断，方便别的工具消费。

```text
FAIL demo: 1 diagnostics
  line 3 [UNKNOWN_SOURCE] claim 1 cites unknown source: doc-404
```

## 输入格式与范围

一个文件代表一次运行，每行是 `tool_call`、`tool_result` 或最终 `answer` 事件。回答的引用使用结构化的 `claims[].source_ids`；首版不尝试从自然语言里猜测引用。完整字段、规则和三个使用场景见 [JSONL v1 约定](docs/contract.md)，命令行样例见 [fixtures](fixtures/README.md)。

校验器目前覆盖：JSON 格式与必填字段、跨运行混入、重复调用或来源 ID、孤立或重复结果、缺失结果、失败结果附带来源、未知引用，以及最终回答之后继续出现工具事件。对重复来源 ID 保留首次来源记录，不让后续记录悄悄改写引用指向。

MoonBit 核心入口为 `validate_jsonl(input : String) -> Report`。`Report` 包含 `sources`、`citations` 和 `diagnostics`；命令行只负责读取文件和输出结果。核心库可在 native、JS 和 Wasm 目标编译运行，文件 CLI 使用 native 目标。

## 开发与验证

```sh
moon check --deny-warn
moon test --deny-warn
moon test --target js --deny-warn
moon test --target wasm --deny-warn
sh scripts/smoke.sh
```

当前仓库提供合成样例和自动化测试。尚未接入真实 Agent 的轨迹导出，也尚未发布到 Mooncakes；这些会在适配器和实际案例验证完成后处理。

## License

Apache-2.0.
