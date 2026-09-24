# Codex CLI 实际轨迹验证（2026-09-23；2026-09-24 重新校验）

在只含 `facts.txt` 的临时目录中，以只读模式运行 `codex exec --json --ephemeral`。Codex CLI 0.149.0 实际执行 `cat facts.txt`，事件流包含命令的 `item.started` 和 `item.completed`，最终答复为 `42 [source-1]`。测试没有修改工作区文件。

公开的 [CLI 事件样例](../fixtures/codex-cli-events.jsonl)从该次运行截取并去标识化：替换会话和事件 ID，删除无关的提示性事件及用量数据；保留命令执行状态、输出和最终答复。[导出的轨迹](../fixtures/codex-cli-trace.jsonl)现在包含命令输出原文和从最终答复提取的引用片段，因此只能用于无敏感内容的公开样例。

```sh
python3 adapters/codex_cli.py fixtures/codex-cli-events.jsonl --out /tmp/codex-trace.jsonl
moon run cmd/main /tmp/codex-trace.jsonl --evidence
```

重新校验结果：`PASS`，3 个事件、1 次工具调用、1 个来源、1 条引用，`1/1 matched citations`。`42` 是捕获输出 `answer=42` 的逐字子串。把回答改为 `99 [source-1]` 会触发 `QUOTE_NOT_IN_SOURCE`；把引用改成 `source-99` 会触发 `UNKNOWN_SOURCE`。

为了演示跨运行比较，仓库另有两份明确标注为**合成**的轨迹：[旧运行](../fixtures/evidence-old.jsonl)与[新运行](../fixtures/evidence-new.jsonl)。两者来源 URI 相同，捕获内容从 `value=42` 变为 `value=43`。执行 `moon run cmd/main compare fixtures/evidence-old.jsonl fixtures/evidence-new.jsonl` 得到一个 `changed` 事件，退出码为 2。这不是第二次真实 Codex 运行。

这里的证据结论止于事件流：逐字匹配不判断语义蕴含，适配器的捕获过程也仍是可信边界。
