# TraceCite 成果与验收说明

整理日期：2026-10-10（北京时间）。本说明依据 Git 历史中的申报稿技术目标重建成果对照，
正式提交的申报书仍以申报人保存的版本为准。它提供可检查的证据，不代替组委会的最终验收判断。

## 九项验收清单

本节逐项对应组委会提供的验收指南。九项要求均已有可复核的交付材料。当前交付依据 0.8.0 固定源码提交
`072ba161100a788d577ed2023c9c35383248f696` 及该标签的 CI、打包与实际注册表消费验证。
验收记录在发布后补入 main，不修改已发布包与版本标签。

| 序号 | 验收要求 | 交付与复核方式 |
| --- | --- | --- |
| 1 | MoonBit 为主要实现语言，moonc ≥ 0.10.14 | 核心库、文件与网页 I/O、CLI 均为 MoonBit；Python/shell 用于开发测试与打包。CI 实际使用 moonc v0.10.14+7d59c7ec9，并检查最低版本。 |
| 2 | GitHub 仓库公开可访问，提交清晰 | Freakz2z/tracecite 为 public 仓库，main 保留功能、修复、发布与验收的提交；CHANGELOG.md 列出版本里程碑，docs/releases/ 记录各版本固定提交。 |
| 3 | 结构清晰，实现声明的核心功能 | 根包为 portable 解析/校验/比较逻辑；cli/ 为 native 文件和 HTTP 实现；cmd/main 与 cmd/tracecite 共用实现。回源核验、追溯、变化比较和文档维护都有可执行入口。 |
| 4 | README 包含目标、安装、用法、示例并可复现 | README.mbt.md 为主说明，README.md 指向它；包含源码启动、Mooncakes 库/CLI 安装、独立包、配置、Action、边界和维护演示。 |
| 5 | CI 覆盖检查、构建、测试 | .github/workflows/ci.yml 执行最低版本检查、moon check、三目标构建和测试、CLI/适配器/打包测试、实例运行及源码 ZIP 消费验证。 |
| 6 | 至少一个可运行示例 | examples/maintenance/project 提供离线最小项目，下面的一条命令可直接检查；acceptance_demo.py 提供 13 步维护闭环。 |
| 7 | 测试覆盖核心路径 | native 125 项、JS/Wasm 各 110 项；CLI 集成 75 项、JSON 契约 8 项、适配器 6 项、许可打包 9 项、发布保护 15 项。正常路径与失败保护对应关系见下表。 |
| 8 | 发布到 mooncakes.io | 已发布 Freakz2z/tracecite@0.8.0；库和 cmd/tracecite 均通过实际注册表安装验证。发布提交、源码摘要与安装命令见后文和发布指南。 |
| 9 | OSI 开源许可证与上游合规 | 项目采用 Apache-2.0；moon.mod 元数据一致。THIRD_PARTY_NOTICES.md 和 third_party/ 保留依赖、移植来源与 SDK 许可；native 包完整附带 LICENSE/NOTICE 和构建清单，缺项会停止。 |

此前验收材料提交 `4c459edcfc0dd66ee80f59e0936048e9fae0c0d4` 的 [常规 CI](https://github.com/Freakz2z/tracecite/actions/runs/36699193496)
和 [Linux/macOS 独立包验证](https://github.com/Freakz2z/tracecite/actions/runs/36699193906)
均成功。Apache-2.0 为 [OSI 认可的许可证](https://opensource.org/license/apache-2-0)。

最小离线示例：在源码根目录执行 `moon update` 后运行：

```sh
moon run cmd/main check guide.md --root examples/maintenance/project --no-config --strict
```

预期退出码为 0，输出 LOCAL_OK，检查本地标题链接、绑定配置片段和逐字引文。
CLI 从样例根目录读取真实来源，不需要模型或网页服务。CI 同样运行这条命令。

| 核心路径 | 正常路径与失败保护 | 自动化测试位置 |
| --- | --- | --- |
| Agent 证据追溯 | 成功调用与来源关联；未知来源、失败调用、缺失结果、混合 run、重复事件拒绝 | tracecite_wbtest.mbt |
| 引文与来源匹配 | 逐字引用、排版引号、省略号片段；伪造引文、伪造工具捕获内容拒绝 | tracecite_wbtest.mbt、scripts/smoke.sh |
| 跨运行变化比较 | 相同 URI 的来源内容变化输出 changed，保留前后证据 | tracecite_wbtest.mbt、adapters/test_codex_cli.py |
| Markdown 文档与报告 | 源码片段、链接、引文、标题/行/区域；围栏、注释、HTML 和引文关联边界 | document_wbtest.mbt、report_wbtest.mbt |
| 项目配置与维护 | init/check 本地与 CI 复用；非法配置、空范围、覆盖现有文件、错误快照拒绝 | project_wbtest.mbt、scripts/test_document_cli.py |
| 文件与工作区边界 | 文件回读、引用移动、锚点失效；越界路径与符号链接、无可检查引用拒绝 | scripts/test_document_cli.py、scripts/smoke.sh |
| 网页与代理 | HTML/charset/重定向/代理解析；非公开地址、带凭证或异常端口来源拒绝 | cli/remote_wbtest.mbt、cli/proxy_wbtest.mbt、scripts/smoke.sh |
| 发布与许可完整性 | 全新消费项目、CLI 安装、native 解包案例；遗漏 NOTICE、摘要改变、旧文件混入、重复版本和错位标签拒绝 | scripts/verify_release_package.py、scripts/test_native_package.py、scripts/test_release.py、scripts/verify_native_package.py |

## 工程深度补充（0.9.0 开发线）

组委会关于基础匹配与关联之外工程职责的意见，作为持续迭代目标记录。新增有界来源行差异引擎，并将独立回源、观察范围、差异计算及基线状态控制分别对应到源码与可执行案例。职责、依赖归属、预算和边界见 [工程说明](engineering-depth.md)，复现步骤见 [演示](../examples/engineering/README.md)。

本轮属于开发增强，正式版本仍为 0.8.0；现有基本交付清单与组委会对工程深度的进一步判断分别保留，后者不由测试数量或版本号推定。

## 申报方向与当前产品

历史申报稿的方向为 **AI Agent 引用回源验证与来源变化检测**：独立读取网页或本地文件，
核实回答中引用的片段是否出现在当前来源中；比较两次来源，定位需要重新审阅的证据。
轻量笔记是基础输入，JSONL 来源轨迹与 Codex 适配器是可选接入方式。

这些能力仍然保留。0.5.0 增加 Markdown 文档维护、源码片段、引用快照和项目配置，
让同一核验能力可以直接用于 Agent 输出的报告和团队 README，无需先导出 Agent 事件。
来源变化需要人工判断影响，TraceCite 不负责判断论断语义真假。

| 技术目标 | 当前交付 | 可检查证据 |
| --- | --- | --- |
| 轻量引用输入与独立网页回源 | 三行笔记、普通报告、verify-notes / verify-urls / check-report | [输入约定](contract.md)、[回源实现](../cli/remote.mbt)、[实际 IANA 检查](live-validation.md) |
| 本地文件回读，识别捕获内容与当前来源不一致 | verify-files、来源快照匹配；工作区边界与符号链接检查 | [CLI](../cli/main.mbt)、[来源匹配](../snapshot.mbt)、[旧入口冒烟测试](../scripts/smoke.sh) |
| 来源追溯与结构化事件关联 | validate_jsonl / validate_evidence_jsonl，调用与来源关联诊断 | [证据校验实现](../validate.mbt)、[JSONL 测试](../tracecite_wbtest.mbt) |
| 两次运行间发现来源增删与变化 | compare_jsonl / compare；稳定 URI 对比 | [变化比较实现](../compare.mbt)、[两次实际 Codex 运行](live-validation.md) |
| Agent 接入示例 | 可选 Codex CLI 事件适配器，脱敏事件与轨迹夹具 | [适配器](../adapters/codex_cli.py)、[适配器测试](../adapters/test_codex_cli.py) |
| 可交付的 MoonBit 工具与开源包 | portable 核心库、native CLI、Mooncakes 包、GitHub Action | [公开 API](../pkg.generated.mbti)、[发布与消费验证](publishing.md)、[CI](../.github/workflows/ci.yml) |
| 降低团队重复核验的门槛 | init / check；一份配置供本地和 CI 使用，定位文档行与变化上下文 | [维护指南](maintenance.md)、[CLI 集成测试](../scripts/test_document_cli.py)、[维护闭环演示](../examples/maintenance/README.md) |

## 可复现验收

在固定的源码提交中安装 MoonBit（moonc ≥ 0.10.14）和 Python 3 后执行：

```sh
moon update
moon check --deny-warn
moon test --deny-warn
moon test --target js --deny-warn
moon test --target wasm --deny-warn
python3 scripts/test_document_cli.py
python3 -m unittest discover -s adapters -p 'test_*.py'
sh scripts/smoke.sh
moon run cmd/main check
python3 scripts/acceptance_demo.py
bash scripts/release.sh --package-only
bash scripts/package.sh
```

前三个测试目标覆盖 portable 核心，native 另包含文件、HTTP 与代理测试。
CLI 集成测试覆盖配置、init、来源边界、快照保护以及 Action 的真实调用。
发布验证会解包源码 ZIP、安装 CLI，并用全新消费项目测试 native、JS、Wasm 公开 API。
独立包验证会核对许可清单和 SHA-256，再用解包后的二进制跑维护案例。
下载依赖和旧网页回源冒烟测试需要网络；13 步维护演示本身离线运行。

截至 0.5.0 发布提交的基准为 native **79/79**、JS 与 Wasm 各 **66/66**、
CLI 集成 **34** 项、适配器 **6** 项。数字对应固定提交，后续新增测试以当前 CI 为准。

| 证据类别 | 已有记录 | 能说明的结论与限制 |
| --- | --- | --- |
| 受控维护案例 | 13 次真实 CLI 调用；JSON 报告、初始基线、最终项目与 receipt.json | 验证来源变化 → 失败定位 → 修复 → 复核更新基线 → 恢复通过，不能推出自然错误率或节约工时 |
| 实际 Agent 接入 | 两次真实 Codex CLI 运行的脱敏事件，来源文件由开发者刻意修改 | 证明事件采集与来源变化比较，不代表真实用户工作流采用率 |
| 普通报告试验 | [三份普通技术报告](../examples/field-trial/README.md)，16 条引用 | 改善自然 Markdown 输入覆盖；当时没有发现需要修订的实际引文 |
| 独立公开资料审计 | [固定外部仓库的前 10 条样本](external-audit.md)，7/10 → 本地修订后 9/10 | 两条可核实的逐字引文修订建议；一条动态来源仍待人工复核。样本小，网页会变化，不构成总体错误率 |

[维护演示](../examples/maintenance/README.md)会保留每一步的退出码与报告；CI 上传
tracecite-acceptance-evidence。测试异常时已有报告也保留。案例中的接受来源变化步骤是
显式模拟人工复核，产品不会自动替维护者接受变化。

## 0.6.0 功能与开发验证

0.6.0 已正式发布；开发阶段证据与正式交付记录分别保存。
新能力包括通配符自动发现、覆盖数量要求、Setext 标题、来源影响集中复核和只读基线预览。
原来的项目配置、Action 入口和快照更新方式继续兼容。

新增 [14 步离线复核演示](../examples/review/README.md)验证新增文档、来源变化、多文档影响归并、
覆盖超限阻止候选/写入、修复绑定、删除文档与最终恢复。它保留逐步 JSON 报告，不替代真实项目采用数据。
正式发布回归测试为 native 89 项、JS/Wasm 各 76 项、CLI 集成 50 项；
便携 API 消费样例扩展为每目标 4 项，发布与独立包检查同时跑原 13 步和新 14 步演示。
相应源码见 maintenance_v060_wbtest.mbt、scripts/test_document_cli.py 和 scripts/maintenance_review_demo.py；
已推送的实现提交为 `d5baa31f16811953f4bc9cf9376575d6baa51b34`；
[常规 CI](https://github.com/Freakz2z/tracecite/actions/runs/36886731368) 和
[Linux/macOS 独立包工作流](https://github.com/Freakz2z/tracecite/actions/runs/36886730284) 均成功。
本地源码 ZIP 解包消费与 Linux 独立包验证也通过；[开发验证记录](releases/0.6.0-development.json) 明确保留开发状态，
不将候选包或本地消费推定为 0.6.0 注册表正式发布。

## 0.6.1 兼容性修复验证

版本针对真实仓库验证暴露的标点锚点、脚注识别和仓库根路径问题，公开 MoonBit 接口未变化。
正式发布回归为 native 94 项、JS/Wasm 各 81 项、CLI 55 项、许可打包 8 项；
实际注册表消费样例扩展为每目标 5 项。源码解包和独立包验证新增兼容性样例。
[最小样例](../examples/compatibility/README.md) 一条命令可运行；
[真实案例复查](field-validation.md) 保留修复前后结果，未检查内容继续明确计数。

## 0.7.0 生态接入验证

独立 MoonBit 消费项目在 native、JS、Wasm 分别构建、运行并通过 1 项样例测试；输出一致。
核心回归 native 96 项、JS/Wasm 各 81 项、CLI 59 项，JSON 消费契约边界 5 项。
公开 MoonBit API 与配置结构未变化；CLI 文档报告新增版本及分类，兼容性说明见 [JSON 契约](json-report.md)。
[库与 CI 接入样例](../examples/library/README.md) 提供可运行项目、最小工作流及八步受控新项目演示。
Action 的检查脚本在本地验证两次，本仓库 CI 同时运行完整 composite Action；这不表示外部仓库采用。
网页错误保留诊断代码并解释回源失败，不将网络或内容类型问题推定为引文错误。
开发验证与正式注册表消费分别执行，发布结果见固定标签与交付回执。

## 0.7.1 多语言文档兼容性验证

默认小写转换修复多语言标题锚点，覆盖 Sigma 上下文、İ 展开、组合字符与补充平面字母。
核心回归 native 103 项、JS/Wasm 各 88 项，CLI 62 项；公开 API 没有结构变化。
[12 条链接样例](../examples/anchors/README.md)由固定参考实现独立核对，正式 0.7.0 Linux 包有 11 条失败，0.7.1 注册表 CLI 与独立包全部通过。重复编号、具体选中正文、真实缺失锚点和来源变化均有正反回归。
两个固定真实仓库仍保留 async 的两条真实断链及未检查、待复核项；该受控样例不代表外部采用。

## 0.7.2 引用解析交付验证

三目标核心测试为 native 112 项、JS/Wasm 各 97 项，CLI 集成 66 项；公开 API 与报告结构保持不变。
[正反样例](../examples/link-parsing/README.md)要求 12 条有效引用全部通过，重复定义的第一条来源缺失时退出 2 并报告 SOURCE_NOT_FOUND。
源码 ZIP 解包安装、真实注册表安装和独立包使用同一个验证入口，核对实际来源、引用类型、覆盖统计和退出码；不会只验证命令是否启动。
正式发布身份与消费结果见下节，历史记录保持不变。

## 发布身份与复核方式

### 0.8.0

已发布 Freakz2z/tracecite@0.8.0，[GitHub Release](https://github.com/Freakz2z/tracecite/releases/tag/v0.8.0) 提供九项资产。
固定提交为 `072ba161100a788d577ed2023c9c35383248f696`，原始注册表 ZIP SHA-256 为
`db445cd240114f2e643e9fb153b5a740790f7fe14902df489169d2cf1dd97296`。
[标签 CI](https://github.com/Freakz2z/tracecite/actions/runs/38024164266)、
[Linux/macOS 打包](https://github.com/Freakz2z/tracecite/actions/runs/38024164241)、
[原始 ZIP 与注册表消费](https://github.com/Freakz2z/tracecite/actions/runs/38024322180) 全部通过。
三个目标各 10 项公共 API 消费测试及独立库样例通过；安装后的 CLI 跑通八步引号策略、四条 HTML 锚点引用与缺失目标负例，以及 13 步、14 步维护和八步接入流程。
两个平台包的固定提交、摘要和完整许可载荷均已核对；下载的 Linux 包在不含 MoonBit 的 PATH 下再次通过正反样例及六步纯 CLI 接入。
显式跳过的引号仍单独计数并受预算约束，来源变化与缺失目标仍失败；完整快照保留，报告只精简展示上下文。
发布标签的离线自检覆盖 187 条引用，另有 64 个网页和 57 个未绑定代码块未检查。发布后的 main 新增两个交付记录引用和四个 CI/Release 链接，网页预算按实际数量更新为 68，仍全部计入未检查内容。
完整身份与实际检查结果见 [0.8.0 交付记录](releases/0.8.0.json)。原有版本标签和发布包保持不变。

### 0.7.2

已发布 Freakz2z/tracecite@0.7.2，[GitHub Release](https://github.com/Freakz2z/tracecite/releases/tag/v0.7.2) 提供九项资产。
固定提交为 `24c4c627d07fc4f48221b4080afcb4793099d49d`，原始注册表 ZIP SHA-256 为
`5666d6a09e3ff0361c0e8cf46bfa914cac20fea2b6420b7b8fdcf07c5f3dd38f`。
[标签 CI](https://github.com/Freakz2z/tracecite/actions/runs/37277643826)、
[Linux/macOS 打包](https://github.com/Freakz2z/tracecite/actions/runs/37277643771)、
[原始 ZIP 与注册表消费](https://github.com/Freakz2z/tracecite/actions/runs/37277954189) 全部成功。
三个目标各 7 项公共 API 消费测试及独立库样例通过；安装后的 CLI 跑通多语言锚点、12 条解析引用、断链负例和 13 步、14 步、八步维护接入。
下载的 Linux 包在不含 MoonBit 的 PATH 下再次通过正反样例、维护和六步纯 CLI 接入；两个平台包的固定提交、摘要及完整许可载荷均已核对。
完整身份与实际检查结果见 [0.7.2 交付记录](releases/0.7.2.json)。

### 0.7.1

已发布 Freakz2z/tracecite@0.7.1，[GitHub Release](https://github.com/Freakz2z/tracecite/releases/tag/v0.7.1) 提供九项资产。
固定提交为 `65a47a8c4cfdb1d78c07b4e1712794281a5a8c25`，源码 ZIP SHA-256 为
`7c84abe14126a8b8ec59d2ba66d54bc75d8e772603788f2810cd3fec631c726f`。
[标签 CI](https://github.com/Freakz2z/tracecite/actions/runs/37262876665)、
[Linux/macOS 打包](https://github.com/Freakz2z/tracecite/actions/runs/37262876826)、
[原始 ZIP 与注册表消费](https://github.com/Freakz2z/tracecite/actions/runs/37263121185) 全部通过。
真实注册表消费为三个目标各 6 项公共 API 测试、独立库样例、12 条多语言锚点与 13 步、14 步、八步维护接入。下载的 Linux 包也在不含 MoonBit 的 PATH 下通过维护与六步纯 CLI 接入。
完整身份、摘要与实际锚点结果见 [0.7.1 交付记录](releases/0.7.1.json)。

### 0.7.0

已发布 Freakz2z/tracecite@0.7.0，[GitHub Release](https://github.com/Freakz2z/tracecite/releases/tag/v0.7.0) 提供九项资产。
固定提交为 `62b103d80fcfda1101eb190272154d5684122d60`，源码 ZIP SHA-256 为
`8bdc5026bad57fa367f9ef4aff5b830002ff200382738e1d2f05919165d14172`。
[标签 CI](https://github.com/Freakz2z/tracecite/actions/runs/37195970553)、
[Linux/macOS 打包](https://github.com/Freakz2z/tracecite/actions/runs/37195970571)、
[原始 ZIP 与注册表消费](https://github.com/Freakz2z/tracecite/actions/runs/37196223403) 全部通过。
独立库样例在真实注册表消费时三个目标各 1 项测试通过，运行输出相同；公开 API 消费各 5 项通过。
实际安装的 CLI 运行 13 步、14 步维护及八步接入流程，下载的 Linux 包额外运行六步纯 CLI 接入通过。
成功、失败及基线预览报告已用 JSON Schema 2020-12 验证；该外部验证库仅用于开发复核，不是 CLI 运行依赖。
完整身份、摘要和三个目标的样例输出见 [0.7.0 交付记录](releases/0.7.0.json)。

### 0.6.1

已发布 Freakz2z/tracecite@0.6.1，[GitHub Release](https://github.com/Freakz2z/tracecite/releases/tag/v0.6.1) 提供九项资产。
固定提交为 `3aeda81a77bbd9509971edbcaf4c8f942ea63b17`，源码 ZIP SHA-256 为
`e8b40fdd66dadf9baea8565ba6d9e3d0d9cefe1eb9f5046ad6560b4ad5cfada0`。
[标签 CI](https://github.com/Freakz2z/tracecite/actions/runs/37193635311)、
[Linux/macOS 打包](https://github.com/Freakz2z/tracecite/actions/runs/37193635306)、
[原始源码 ZIP 与注册表消费验证](https://github.com/Freakz2z/tracecite/actions/runs/37193770901) 全部通过。
真实注册表消费为三个目标各 5 项 API 测试；安装 CLI 后兼容性样例、13 步和 14 步维护流程均通过。
下载的 Linux 包复现两个固定真实案例，来源诊断与源码 CLI 一致；8 项许可打包测试包含 Unicode 许可缺失保护。
完整身份、摘要与回执见 [0.6.1 交付记录](releases/0.6.1.json)。

### 0.6.0

已发布 Freakz2z/tracecite@0.6.0，[GitHub Release](https://github.com/Freakz2z/tracecite/releases/tag/v0.6.0) 提供九项资产。
固定提交为 `cf041cfd057f791190dfff2c177c4383633f5bd3`，源码 ZIP SHA-256 为
`64835fb0565b0d17d4db7f2f2dd6541841a24e357cc9f33fcc366f3d3d438d53`。
[标签 CI](https://github.com/Freakz2z/tracecite/actions/runs/37185522286)、
[Linux/macOS 打包](https://github.com/Freakz2z/tracecite/actions/runs/37185522287)、
[原始注册表 ZIP 与实际消费验证](https://github.com/Freakz2z/tracecite/actions/runs/37185636878) 全部通过。
真实注册表消费为 native/JS/Wasm 各 4 项 API 测试；安装 CLI 后原 13 步和新增 14 步维护演示全部通过。
下载的 Linux Release 包再次运行两套演示通过，源码资产摘要与注册表一致。
完整机器可读证据见 [0.6.0 交付记录](releases/0.6.0.json)。

新增 [真实仓库首轮验证](field-validation.md) 检查 async 与 moon 的固定提交，记录真实断链与工具兼容性问题，
不将本地评估表述为上游采用或长期收益。

### 0.5.1

已发布 **Freakz2z/tracecite@0.5.1**，固定标签 v0.5.1 对应源码提交
[d4090a5ffa8fb1fdf01fe48a6b27801f72753683](https://github.com/Freakz2z/tracecite/commit/d4090a5ffa8fb1fdf01fe48a6b27801f72753683)。
[标签 CI](https://github.com/Freakz2z/tracecite/actions/runs/36871509146)、
[Linux/macOS 独立包验证](https://github.com/Freakz2z/tracecite/actions/runs/36871509316) 和
[原始源码包与注册表消费验证](https://github.com/Freakz2z/tracecite/actions/runs/36874157757) 均通过。

[GitHub Release](https://github.com/Freakz2z/tracecite/releases/tag/v0.5.1) 已公开提供 Linux x86_64 / macOS ARM64 包、原始源码 ZIP、校验文件与消费验证回执。
Mooncakes 和源码 ZIP 的 SHA-256 一致：

```text
7cf18e24f54f8fefd035da318a7d268e2dabbcd5767e2b2c20791af8880e0c14
```

实际注册表安装通过 native、JS、Wasm 公开 API 测试和 CLI 的 13 步维护流程；
从 GitHub 下载的两平台包摘要、固定提交与许可载荷均已核对，下载后的 Linux CLI 也跑通维护闭环。
重复发布尝试已被脚本提前拒绝。完整身份、资产摘要与回执见 [0.5.1 交付记录](releases/0.5.1.json)。
运行 `moon view Freakz2z/tracecite@0.5.1` 查询注册表；安装和发布保护见 [发布指南](publishing.md)。

### 历史发布 0.5.0

已发布模块为 **Freakz2z/tracecite@0.5.0**，对应源码提交
[49f87d781d4fd71a218eba38121fa12a59b30594](https://github.com/Freakz2z/tracecite/commit/49f87d781d4fd71a218eba38121fa12a59b30594)。
该提交的 [CI 运行](https://github.com/Freakz2z/tracecite/actions/runs/36694688818) 已通过。
发布源码 ZIP 的 SHA-256：

```text
22ac2a9ab7d54ac48d6b221054702b6428f1332f00231e7566af3d7639b2ec06
```

可执行 `moon view Freakz2z/tracecite@0.5.0` 查询注册表，并按
[安装说明](publishing.md)消费实际发布的库或 CLI。
0.5.1 将后续验收与许可材料纳入新版本，详见 [版本记录](../CHANGELOG.md)。
历史 0.5.0 的提交与摘要保持原样。

最终交付时保存审核过的源码 SHA、该 SHA 的 CI 链接、源码/二进制包及 SHA-256。
native 包的 BUILD-INFO.json 会记录源码 SHA、工作区是否修改、工具链和实际依赖版本；
正式构建应来自干净的固定提交。CI 上传的候选包需要结合运行对应的 SHA 识别，
不能只根据文件名认定它与已发布版本相同。

## 四项验收依据

- **完成度**：原回源、追溯、变化比较能力可执行；文档维护提供配置、CLI、Action 和修复闭环。
- **代码质量**：核心逻辑用 MoonBit 实现，公开 API 与 native I/O 分层；三目标测试、边界集成和解包消费检查由 CI 执行。
- **开源合规性**：[Apache-2.0](../LICENSE) 与模块元数据一致；[第三方通知](../THIRD_PARTY_NOTICES.md)保留依赖、标准库 NOTICE 和 native 运行时许可，打包缺项会失败。
- **MoonBit 生态相关性**：公开 Mooncakes 包可被其他 MoonBit 项目导入；portable 核心覆盖 native/JS/Wasm，native CLI 可独立安装或分发。

需要保留的边界是动态网页、图片/登录墙、语义真假判断和站点特有锚点；未检查内容会明确统计。
目前也没有长期团队采用记录或量化工时收益。验收说明应以现有功能和可复现证据为依据，
后续获得真实反馈后再补充采用与收益数据。
