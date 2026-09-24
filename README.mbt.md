# TraceCite

TraceCite 是 MoonBit 编写的 Agent 引用证据校验器。它检查回答引用的逐字片段是否出现在对应工具返回内容中，并比较两次运行的来源是否增加、删除或改变。诊断包含输入行号和稳定错误码，可用于本地复现和 CI 门禁。

## 快速运行

安装 [MoonBit 工具链](https://docs.moonbitlang.com/en/stable/tutorial/tour.html)后执行：

```sh
moon run cmd/main fixtures/evidence-old.jsonl --evidence
moon run cmd/main fixtures/evidence-false-quote.jsonl --evidence
moon run cmd/main compare fixtures/evidence-old.jsonl fixtures/evidence-new.jsonl
```

第一条通过；第二条报告 `QUOTE_NOT_IN_SOURCE`；第三条报告 `changed` 来源。成功退出码为 0，校验失败或出现来源变化为 2，参数和读取失败为 1。三个命令都可加 `--json` 获取机器可读报告。

## 实际 Agent 轨迹

仓库包含一次 [Codex CLI 实际运行的去标识化事件](fixtures/codex-cli-events.jsonl)。适配器从命令完成事件读取真实输出，再从最终答复提取 `[source-N]` 引用及其前面的逐字片段：

```sh
python3 adapters/codex_cli.py fixtures/codex-cli-events.jsonl --out /tmp/codex-trace.jsonl
moon run cmd/main /tmp/codex-trace.jsonl --evidence
```

该样例的 `42` 确实出现在被捕获的 `answer=42` 中。适配器以命令文本的 SHA-256 作为来源 URI，以便相同命令跨运行比较；这个 URI 只代表命令身份，不能证明执行环境或文件相同。详见[验证记录](docs/live-validation.md)。

## 通用接口与边界

核心库提供 `validate_jsonl`、`validate_evidence_jsonl` 和 `compare_jsonl`，可在 native、JS、Wasm 目标编译。输入约定见[证据格式](docs/contract.md)。任何能输出工具调用、工具结果和最终回答的 Agent 都可以生成此 JSONL；现有自动适配器覆盖 Codex CLI，其他系统需要按约定导出事件。

逐字匹配不等于语义事实核验，也不保证采集器没有伪造内容；跨运行变化检测依赖稳定来源 URI。普通模式保留旧版 ID 关联校验，输出中的 `verified_citation_count` 明确标示证据匹配数量。

## 开发验证

```sh
moon check --deny-warn
moon test --deny-warn
moon test --target js --deny-warn
moon test --target wasm --deny-warn
sh scripts/smoke.sh
python3 -m unittest discover -s adapters -p 'test_*.py'
```

Apache-2.0。尚未发布到 Mooncakes。
