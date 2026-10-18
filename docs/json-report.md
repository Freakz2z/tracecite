# 文档检查 JSON 接入契约

适用 TraceCite 0.7.0 及后续版本的 check/init --json；其他 trace、verify-*、compare 命令使用各自格式。
机器格式见 [JSON Schema](../schemas/document-check-v1.schema.json)，真实输出样例见 [report.json](../examples/integration/report.json)。

```sh
tracecite check --json > report.json
```

保留 check 的退出码；读取报告不会代替 CI 判定。退出 0 表示按当前规则通过，退出 2 表示未通过或没有可检查引用。
参数、配置或路径范围错误退出 1，错误写入 stderr，可能没有 JSON 报告；调用方需同时处理进程退出码和输出是否存在。

0.9.0 开发线在报告前复查本地输入，发现变化时增加 unavailable/CHECK_INPUT_CHANGED 条目，归入 source_unavailable，阻止可写候选与保存。保存阶段还会在输出报告后重新验证；此时发生输入变化或目标基线并发更新，进程退出 2，stderr 提供 CHECK_INPUT_CHANGED 或 SNAPSHOT_CONFLICT。JSON 表示扫描结果，failed_count=0 不保证基线已保存，必须保留进程退出码。临时预约占用等写入错误仍退出 1。
快照写入失败也可能在输出报告后返回 1，不应仅凭报告中的计数判定整个命令成功。

## 版本与兼容性

- schema_version 是整数，目前为 1；tool_version 为生成报告的 TraceCite 版本。
- 0.6.x 报告没有这两个字段；原有计数、items、review、baseline_preview 保留。现有按旧字段读取的消费方可继续使用。
- 同一 schema 可增加字段、诊断代码、kind、status 或 category 值。调用方应忽略未知字段，将未知状态或分类保留为待复核。
- 已有字段类型或含义的不兼容变化需要提升 schema_version；不支持的版本应明确拒绝或交给另一个解析器。
- None 对应的可选字段省略；不输出 null。字段顺序不构成契约。
- 可读 message 会改进或调整措辞，机器逻辑应读取 code/category/status，避免按 message 文本匹配。
- 项目配置 version 和快照 version 是各自独立的版本标识，不等同于报告 schema_version。

## 顶层字段

| 字段 | 含义 |
| --- | --- |
| schema_version / tool_version | 报告契约版本及工具版本 |
| document_count | 扫描的 Markdown 文档数量 |
| checked_count | 尝试独立检查的引用数量，包括失败；不含跳过网页、跳过引号和解析警告 |
| failed_count | error、unavailable、mismatch、changed 项数量 |
| warning_count | warning 项数量；严格模式下这些项也使检查失败 |
| skipped_count | 离线模式未回源的网页引用数量，不含跳过引号 |
| skipped_quotes | 0.8.0新增：显式跳过的无来源完整引号数量；旧报告缺省视为 0 |
| unassociated_quotes | 0.8.0新增：本次生效的 review 或 skip 策略；旧报告为 review |
| unbound_snippets | 没有 source= 的代码块数量，不计为已检查 |
| online | 本次是否启用网页回源 |
| items | 完整逐项结果，包含成功、失败、警告和跳过项 |
| review | --review 的来源分组；未启用时为空数组，locations 使用同一条目结构 |
| baseline_preview | 仅 --preview-baseline 存在；只读变化清单与可选候选快照 |

一条引用可对应失败或待复核诊断，覆盖超限还会增加合成诊断，不能假设 items 长度等于 checked_count。
不同检查范围也会改变数量；计数不是总体准确率或采用收益。
0.8.0 新增字段仍使用 schema_version=1；原有 skipped_count 语义保持网页计数。UNASSOCIATED_QUOTE_SKIPPED 为 skipped/not_checked，SKIPPED_QUOTE_LIMIT_EXCEEDED 为 error/coverage。预算超限会阻止基线写入，即使关闭严格模式。

## 条目字段与分类

每条 item 必含 document、line、source、kind、status、code、message、category。
line 为文档内从 1 起算的行号；document 为工作区相对路径；没有明确来源的诊断 source 可为空。
expected、actual、previous 是可选的有界展示文本，不代替完整来源。
0.8.0中，status=changed 的 previous/actual 成对定位首个变化附近，每侧至多 1600 个 Unicode 字符，并用省略号标记遗漏内容；它们不是完整 diff。review.locations 采用同一展示文本。baseline_preview.changes 的 previous/current 和候选 snapshot 仍保存完整观察值，不能用精简展示文本重建基线。


0.9.0 开发线增加可选 change_analysis：来源变化或有旧观察值的片段失配时，包含结构化行差异；review.locations 复用相同信息。schema_version 仍为 1，旧读取器可以忽略这个字段，原有计数和 previous/actual 含义不变。

change_analysis.algorithm 为 bounded_lcs_lines_v1，coordinate_system 为 observed_source_1_based。hunks 提供 previous_start_line / current_start_line（从 1 起）及各侧行数、文本；零行数表示插入或删除位置，位置可以在末行之后。坐标属于保存/当前观察文本，不是完整源文件的绝对行号。文本保留换行和 CRLF 身份。

complete=true 时 added_lines、removed_lines、total_hunks 为完整计算结果。display_truncated 独立表示编辑块或文本展示被省略；每个块的 text_truncated 标记自身文本省略。complete=false 时 reason 为 input_limit、line_limit 或 cell_limit，编辑数量缺省，不能当作零；原有来源变化或片段失配仍失败。完整证据继续由快照及 baseline_preview.changes 保存，差异块不能在展示截断时重建原始证据。预算及验证方法见 [工程说明](engineering-depth.md)。

| category | 处理含义 |
| --- | --- |
| verified | 当前来源与引用匹配 |
| source_unavailable | 来源未成功回读；先解决 URL、网络、权限、响应类型或文件路径问题 |
| content_mismatch | 来源已读取，但引文、片段或选择的标题/范围不匹配 |
| source_changed | 当前引用仍匹配，但来源上下文与旧基线不同，需要维护者复核 |
| needs_review | 新引用、未关联来源、未支持引用方式等需要人工复核 |
| not_checked | 未检查的网页引用或显式跳过的引号，不能视为匹配 |
| coverage | 未检查数量超过项目预算 |
| invalid_document | 文档不可读或结构解析失败 |

## 网页失败的解释

HTTP_STATUS_403/404/429/5xx 表示服务返回了对应状态；REQUEST_TIMEOUT 表示 20 秒内未完成，
HTTP_REQUEST_FAILED 表示尚未收到可用响应，可能涉及 DNS、TLS、网络或代理。
代理、重定向、超出 2 MiB、非支持内容类型及不可解析响应分别保留原诊断代码，并给出具体处理说明。
失败均归类为 source_unavailable，不证明引文本身有误；解决回源问题后再检查内容。

## 消费样例

示例读取器使用 Python 3 标准库，汇总分类、未检查数量与未知项：

```sh
python3 examples/integration/read_report.py examples/integration/report.json
```

它拒绝非对象报告和未知契约版本；未知状态、分类或错误类型的条目会出现在 unknown_items_need_review，避免消费脚本直接崩溃。这是展示用读取器，不是完整 JSON Schema 校验器，
也不替代原命令退出码。完整结构校验可使用支持 JSON Schema 2020-12 的验证库。
[读取器源码](../examples/integration/read_report.py)和 [契约边界测试](../scripts/test_report_contract.py)可供接入方参考。

预览的 can_update 表示当前扫描范围的可检查引用通过，未检查内容符合预算；未检查数量仍见顶层字段。
维护者仍需决定是否接受来源变化，新增或变化仍可返回退出码 2。
只读候选 snapshot 在不完整检查时省略，不能将没有候选解释为删除全部条目。
部分范围的预览仍使用整份快照替换语义，复核 scanned_documents 和 removed_count 后再决定是否更新基线。
