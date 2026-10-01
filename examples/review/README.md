# 0.6.0 维护复核演示

这是一个受控、离线、可复现的开发样例，验证通配符自动发现新文档、Setext 标题、
同一来源的影响汇总、只读基线预览，以及覆盖要求阻止不完整的基线更新。
它不提供真实团队采用率或节约工时结论。

在源码根目录运行：

```sh
python3 scripts/maintenance_review_demo.py
```

演示复制 [样例项目](project/docs/guide.md) 到新的临时目录，运行 14 步 CLI 调用。
每一步保留 JSON 报告，初始基线与最终项目保留在输出目录，receipt.json 记录结果。
CI 和源码/独立包解包验证都运行这个演示。

手动复现时，先复制 project 到一个新目录，然后在该目录运行源码构建或安装的 0.6.0 CLI：

```sh
tracecite init 'docs/**/*.md' --exclude 'docs/drafts/**' --max-skipped-web 0 --max-unbound-snippets 0
tracecite check
tracecite check --review
tracecite check --preview-baseline --json
```

`*`、`?` 不跨越目录分隔符，`**` 必须是完整目录段，可以匹配零层目录。
给命令行模式加引号，避免 shell 提前展开。任何通配符扫描目标在排除后未匹配文档时都会报错。

来源或引用变化时，检查和预览可返回退出码 2；baseline_preview.can_update 表示
独立来源检查与覆盖要求是否允许生成候选。预览不会写文件。
人工复核完成后，再执行 `tracecite check --snapshot .tracecite-docs.json`，最后重新检查。
删除文档会在预览中列出删除条目；缩小扫描范围也会列出范围外旧条目，应一并复核。

安装与开发状态见 [README](../../README.mbt.md)，完整配置见 [维护指南](../../docs/maintenance.md)。
