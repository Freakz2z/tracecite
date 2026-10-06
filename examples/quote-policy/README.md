# 显式引号策略与覆盖预算

这是 0.8.0 开发源码样例，尚未包含在正式 0.7.2 包或 Action 标签中。从仓库根目录运行：

```sh
moon run cmd/main check --root examples/quote-policy/project
```

[项目配置](project/tracecite.json)显式选择 skip，仅跳过[文档](project/guide.md)中没有关联来源的两个完整引号；它们作为未检查项保留。
预期退出 0：实际核验一个标题链接和一条有来源的引文；skipped_quotes 为 2，checked_count 为 2，网页与未绑定代码块均为 0。
这两个引号是否是术语需要作者确认，工具不会根据检查通过推断引用意图。

恢复默认复核，或收紧预算：

```sh
moon run cmd/main check --root examples/quote-policy/project --unassociated-quotes review
moon run cmd/main check --root examples/quote-policy/project --max-skipped-quotes 1 --no-strict --preview-baseline --json
```

两条命令均预期退出 2。第一条保留两个 UNASSOCIATED_QUOTE；第二条报告 SKIPPED_QUOTE_LIMIT_EXCEEDED，且 baseline_preview.can_update 为 false。
超过预算时不能写入快照；明确的引文、未闭合引号、未知来源、断链和越界路径仍按原规则检查。

完整八步验证会复制样例到临时目录，检查 init 持久化、配置重用、来源变化与失败保护，不修改原样例：

```sh
moon build --target native
python3 scripts/verify_quote_policy_example.py _build/native/debug/build/cmd/main/main.exe
```

源码包和未来正式包的消费验证也会执行相同八步流程。配置、公共结构迁移与限制见[维护说明](../../docs/maintenance.md#无来源引号策略08-开发版)。
