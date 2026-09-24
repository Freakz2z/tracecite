# TraceCite JSONL 证据约定

一个 UTF-8 JSONL 文件记录一次 Agent 运行。每行一个事件，按观察顺序排列；未知字段允许保留。`run_id` 在文件内一致，`call_id` 与来源 `id` 在运行内唯一。

```jsonl
{"type":"tool_call","run_id":"r1","call_id":"c1","tool":"read"}
{"type":"tool_result","run_id":"r1","call_id":"c1","ok":true,"sources":[{"id":"s1","uri":"file:///example/report.txt","content":"value=42\n"}]}
{"type":"answer","run_id":"r1","claims":[{"text":"The value is 42.","citations":[{"source_id":"s1","quote":"value=42"}]}]}
```

- `tool_call`：必需 `call_id`、`tool`。
- `tool_result`：必需 `call_id`、布尔值 `ok`；`sources[]` 每项必需 `id`、`uri`，证据模式还必需非空 `content`，即观察到的工具输出原文或其中作为来源的原文。失败结果不能提供来源。
- `answer`：每次运行恰好一个。`claims[]` 每项必需 `text`；证据模式要求至少一条 claim，且每条 claim 至少一条 `citations[]`，每项必需 `source_id` 和非空 `quote`。校验器要求 `quote` 是对应来源 `content` 的**逐字子串**，不做大小写或空白归一化。
- 旧格式 `source_ids[]` 仍可用普通模式检查 ID 关系；证据模式会报 `MISSING_QUOTE`，缺少 `content` 还会报 `MISSING_SOURCE_CONTENT`。报告的 `verified_citation_count` 和每条引用的 `evidence_status` 区分两种结果。

`moon run cmd/main trace.jsonl --evidence` 是证据模式。`compare old.jsonl new.jsonl` 要求两个输入都通过证据模式，再按稳定 `uri` 比较逐字内容，报告 `added`、`removed`、`changed`；内容变更退出码为 2。相同 URI 在单次运行中重复会报 `DUPLICATE_URI`，避免跨运行比较歧义。输出报告不会回显来源 `content` 或 `quote`。

`verify-files trace.jsonl` 先执行证据模式，再读取每个 `file:相对路径` 或 `file:///绝对路径` 来源指定的当前文件，与轨迹中的完整 `content` 逐字比较。非文件 URI 报 `UNSUPPORTED_SOURCE_URI`；文件缺失或内容不一致分别报 `SOURCE_UNAVAILABLE`、`SOURCE_FILE_MISMATCH`。相对路径基于执行命令时的工作目录，不解析 URI 百分号转义。

## 能力边界

匹配成功只证明所引片段出现在**采集到的工具返回内容**中；本地文件复核还能证明该内容与**校验时**的文件一致。它不证明来源网页真实、文件在历史采集时的状态，或整条主张在语义上受到支持。未作独立文件复核时，适配器或事件流若伪造输出，离线校验器无法识别。跨运行比较依赖两次运行的来源 URI 表示同一来源；若 URI 变了，会报告添加与删除。把含有敏感内容的轨迹公开前，应先脱敏或使用无敏感数据的运行样例。
