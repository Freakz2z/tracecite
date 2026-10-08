# 独立 HTML 锚点

此样例适用于 0.8.0 开发源码，尚未包含在正式 0.7.2 中。
[有效引用](project/guide.md)包含 4 条引用；[真实缺失目标](project/broken.md)必须失败；正文见 [source.md](project/source.md)。

在 TraceCite 源码根目录运行：

```sh
moon run cmd/main check guide.md --root examples/html-anchors/project --no-config --strict
moon run cmd/main check broken.md --root examples/html-anchors/project --no-config --strict
```

第一条命令退出 0，第二条退出 2 并报告 ANCHOR_NOT_FOUND。
脚本 scripts/verify_html_anchor_example.py 接受独立 CLI 路径，验证这两个结果；源码包消费验证也会运行。

仅支持单独一行、内容为空的 a 元素，具有非空 id 属性且在同一行闭合。
标签和属性名不区分大小写，ID 值保留大小写和 Unicode；属性值可用单引号、双引号或无引号。
ID 中的 & 必须写成 &amp;。支持 amp、quot、apos、lt、gt 五种 HTML 字符引用；其他实体、数字字符引用、跨行标签、name 属性及其他元素的 ID 尚不支持。
重复 id 属性采用首个值；重复目标以及与标题锚点重名时，采用文档中首个匹配位置。
L 加数字的片段及 region: 前缀继续保留为源码范围选择器。

锚点后隔空行紧接标题时，范围包括该标题及其子章节，直到同级或更高标题；若后面先出现正文，则到下一标题为止。
两种情况都不会跨过下一个受支持的独立 HTML 锚点。选中的原始 Markdown 包含锚点行，不是渲染后的 HTML。
因此重命名显示标题仍能找到固定 ID，但观察到的来源发生变化，仍要求复核基线。

代码块、行内代码、注释、转义标签，带列表或引用前缀的标签，以及其他 HTML 容器内的类似文本不作为受支持的目标。
工具不执行 HTML，也不推测站点专用规则。完整范围与限制见 [维护说明](../../docs/maintenance.md)。

实际动机来自 [openseek 固定版本的语言文档](https://github.com/moonbitlang/openseek/blob/aaa46dc0c06959d13d35c9f2e2e806f6539cee70/share/doc/moonbit/language/packages.md)：其中用独立 HTML ID 定位 default-alias 段落。
本目录文字和回归用例由 TraceCite 编写，没有复制上游正文；这是语法兼容性案例，不代表上游采用或整份上游文档已通过检查。
