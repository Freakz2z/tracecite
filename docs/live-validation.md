# Codex CLI 实际轨迹验证（2026-09-23）

在只含 `facts.txt` 的临时目录中，以只读模式运行 `codex exec --json --ephemeral`。Codex CLI 0.149.0 实际执行了读取文件的命令，事件流包含同一命令的 `item.started` 和 `item.completed`，最终答复为 `42 [source-1]`。测试没有修改工作区文件。

公开的 [CLI 事件样例](../fixtures/codex-cli-events.jsonl)从该次运行截取并去标识化：替换会话和事件 ID，删除无关的提示性事件及用量数据；保留命令执行状态、输出和最终答复。[导出的 TraceCite 轨迹](../fixtures/codex-cli-trace.jsonl)只保留来源 ID 与工具调用的关系，不包含命令输出或答复正文。

```sh
python3 adapters/codex_cli.py fixtures/codex-cli-events.jsonl --out /tmp/codex-trace.jsonl
moon run cmd/main /tmp/codex-trace.jsonl
```

结果为 `PASS`：3 个事件、1 次工具调用、1 个来源、1 条带引用的回答。将回答引用改为不存在的 `source-99` 后，校验器会报告 `UNKNOWN_SOURCE`，退出码为 2。

这是一次实际 Agent 命令调用到引用输出的结构验证。TraceCite 不会自动判断任意来源内容是否充分支持回答；本例中的 `42` 可以直接对照公开的 [`facts.txt`](../fixtures/facts.txt) 检查。
