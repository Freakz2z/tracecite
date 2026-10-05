# MoonBit 库接入样例

project 是一个独立 MoonBit 模块，通过 Mooncakes 导入 Freakz2z/tracecite@0.7.1。
CLI 与 HTTP 模块不在导入范围，样例可编译到 native、JS、Wasm。

0.7.1 已正式发布，从本仓库根目录执行：

```sh
cd examples/library/project
moon update
moon run . --target native
moon run . --target js
moon run . --target wasm
```

三个目标输出相同：references=1、before_matches=true、after_matches=false，changes 含一条 changed，
previous 为 timeout = 20，current 为 timeout = 30。这说明来源变化后原文档片段需要维护。
样例使用内嵌的受控文本，调用方需自行读取文件或网页，并决定是否接受变化。

查看 [完整代码](project/main.mbt)与 [消费项目配置](project/moon.mod)。公开 API 无新增依赖，
与 0.6.1 一致；当前例子重点展示 parse_document、document_excerpt_matches 和 compare_document_snapshots。

开发验证从根目录执行 python3 scripts/verify_library_example.py；它复制到临时目录并设置本地 workspace，
不改变分发样例的注册表依赖。发布后执行 python3 scripts/verify_library_example.py --registry，
不使用本地覆盖，验证真实注册表版本。正式发布验证在源码 ZIP 解包后及注册表消费阶段都运行这份样例。

## CLI 与 CI 接入

在待维护项目根目录安装 CLI 并创建共享配置：

```sh
moon install Freakz2z/tracecite/cmd/tracecite@0.7.1
tracecite init 'docs/**/*.md' --max-skipped-web 0 --max-unbound-snippets 0
tracecite check
```

提交生成的 tracecite.json 和 .tracecite-docs.json。零覆盖预算适用于完全离线且所有代码块均绑定来源的范围；
实际项目可在人工复核后设定允许数量。init 拒绝来源不匹配、待复核或没有可检查引用的范围。

将 [CI 模板](../../templates/document-check.yml)复制到项目的 .github/workflows/document-check.yml：

```yaml source=../../templates/document-check.yml
name: Check documentation
on: [push, pull_request]
permissions:
  contents: read
jobs:
  documents:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: Freakz2z/tracecite@v0.7.1
```

Action 不需要重复填写 paths、strict、online 或 baseline，它会读取同一份项目配置。
项目需要网络来源时在配置中显式开启 online；已有配置仍可通过 Action 输入覆盖。

复现全流程：从 TraceCite 根目录执行 python3 scripts/onboarding_demo.py --out _build/onboarding-new。
八步包括 init、本地检查、Action 检查脚本、来源变化、同一脚本同样失败、人工修复后的只读预览、
复核后更新基线及最终恢复。输出目录必须不存在；每步报告和回执会保留。
这是新项目的受控接入验证，不代表外部团队采用。
