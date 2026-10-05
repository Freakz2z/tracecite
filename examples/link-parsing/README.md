# 引用式链接与地址解析回归样例

这些修复当前在 main 开发源码中，尚未包含在已发布的 0.7.1 包中。
从源码根目录运行：

```sh
moon run cmd/main check guide.md --root examples/link-parsing/project --no-config --strict --max-skipped-web 0 --max-unbound-snippets 0
```

预期检查 12 条引用，退出 0，零失败、零待复核和零未检查内容。
[文档](project/guide.md)覆盖第一条有效定义优先、Unicode 标签匹配、标点前空格、链接标题、角括号路径、转义括号、逐字引文和绑定片段。
标题中的括号是展示文字，不改变链接目的地；标签 A . 与 A. 指向不同文件。

负向样例使用第一条断开的定义和后面的有效定义：

```sh
moon run cmd/main check broken-first.md --root examples/link-parsing/project --no-config --strict
```

预期退出 2，报告 SOURCE_NOT_FOUND。[断链文档](project/broken-first.md)不会因为后面又定义了相同标签而通过检查。
CLI 集成回归同时断言这种情况下 init 不创建配置或基线，越界地址仍被拒绝。

不支持的引用方式和无法确认意图的引号文本继续进入人工复核，不将它们计为已核验。
