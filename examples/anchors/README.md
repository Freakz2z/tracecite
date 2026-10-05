# 多语言标题锚点最小样例

TraceCite 0.7.1 修复了非 ASCII 标题的小写转换：带重音的拉丁字母、希腊语、西里尔字母和补充平面字母的有效链接，不再因为标题仍含大写字母而误报。

从源码根目录执行：

```sh
moon run cmd/main check guide.md --root examples/anchors/project --no-config --strict --max-skipped-web 0 --max-unbound-snippets 0
```

预期 LOCAL_OK、12 条引用、零失败、零待复核和零未检查内容。
独立包或安装后的 CLI 对应 tracecite check guide.md --root examples/anchors/project --no-config --strict。
[检查文档](project/guide.md)引用[来源标题](project/source.md)，同时覆盖 ATX、Setext、重复标题和已有数字后缀的冲突。

| 来源标题 | 锚点 |
| --- | --- |
| État CAFÉ | état-café |
| ÜBER Straße | über-straße |
| ΟΣ | ος |
| ΟΣΑ | οσα |
| İSTANBUL | i̇stanbul |
| ПРИВЕТ | привет |
| 𐐀𐐁 | 𐐨𐐩 |

规则使用 Unicode 15.0.0 默认小写转换，不采用特定语言环境。希腊语 Sigma 根据上下文生成 σ 或词尾 ς；İ 展开为 i 和 U+0307 组合点。大小写转换不是去掉重音或 Unicode 规范化：é 与 e 加组合重音仍是不同锚点，Straße 不会变成 strasse。

[预期锚点记录](expected-anchors.json)保存了独立参考实现 github-slugger 2.0.0 的结果、下载摘要与 Node 版本。输入标题由本项目编写，参考代码只用于开发核对，不随 TraceCite 分发；记录不等于 GitHub 网站渲染验证或外部采用。

[版本对比记录](comparison.json)使用已发布、摘要核对后的 0.7.0 Linux 独立包检查同一份样例：12 条链接中 11 条失败。0.7.1 开发版检查 12 条全部通过；重复标题对应的具体正文由 portable 回归单独断言，避免仅验证链接存在。

[生成脚本](../../scripts/generate_unicode_case.py)可使用 Python 的 Unicode 15.0.0 数据库和已保留的上游属性数据离线核对：

```sh
python3 scripts/generate_unicode_case.py --check
```

实际缺失的锚点仍报 ANCHOR_NOT_FOUND；非 ASCII 标题所选区域的来源变化仍进入基线复核。
自定义 HTML ID、站点特有规则和完整 Markdown 行内排版解析继续按[维护指南的范围](../../docs/maintenance.md#链接与标题)人工确认。
