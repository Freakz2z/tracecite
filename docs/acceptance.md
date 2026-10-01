# TraceCite 成果与验收说明

整理日期：2026-10-01（北京时间）。本说明依据 Git 历史中的申报稿技术目标重建成果对照，
正式提交的申报书仍以申报人保存的版本为准。它提供可检查的证据，不代替组委会的最终验收判断。

## 九项验收清单

本节逐项对应组委会提供的验收指南。当前交付依据 0.5.1 固定源码提交
`d4090a5ffa8fb1fdf01fe48a6b27801f72753683` 及该标签的 CI、打包与实际注册表消费验证。
验收记录在发布后补入 main，不修改已发布包与版本标签。

| 序号 | 验收要求 | 交付与复核方式 |
| --- | --- | --- |
| 1 | MoonBit 为主要实现语言，moonc ≥ 0.10.14 | 核心库、文件与网页 I/O、CLI 均为 MoonBit；Python/shell 用于开发测试与打包。CI 实际使用 moonc v0.10.14+7d59c7ec9，并检查最低版本。 |
| 2 | GitHub 仓库公开可访问，提交清晰 | Freakz2z/tracecite 为 public 仓库，main 保留功能、修复、发布与验收的提交；CHANGELOG.md 列出固定提交和里程碑。 |
| 3 | 结构清晰，实现声明的核心功能 | 根包为 portable 解析/校验/比较逻辑；cli/ 为 native 文件和 HTTP 实现；cmd/main 与 cmd/tracecite 共用实现。回源核验、追溯、变化比较和文档维护都有可执行入口。 |
| 4 | README 包含目标、安装、用法、示例并可复现 | README.mbt.md 为主说明，README.md 指向它；包含源码启动、Mooncakes 库/CLI 安装、独立包、配置、Action、边界和维护演示。 |
| 5 | CI 覆盖检查、构建、测试 | .github/workflows/ci.yml 执行最低版本检查、moon check、三目标构建和测试、CLI/适配器/打包测试、实例运行及源码 ZIP 消费验证。 |
| 6 | 至少一个可运行示例 | examples/maintenance/project 提供离线最小项目，下面的一条命令可直接检查；acceptance_demo.py 提供 13 步维护闭环。 |
| 7 | 测试覆盖核心路径 | native 79 项、JS/Wasm 各 66 项；CLI 集成 34 项、适配器 6 项、许可打包 7 项、发布保护 12 项。正常路径与失败保护对应关系见下表。 |
| 8 | 发布到 mooncakes.io | 已发布 Freakz2z/tracecite@0.5.1；库和 cmd/tracecite 均通过实际注册表安装验证。发布提交、源码摘要与安装命令见后文和发布指南。 |
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
| 可交付的 MoonBit 工具与开源包 | portable 核心库、native CLI、Mooncakes 0.5.1、GitHub Action | [公开 API](../pkg.generated.mbti)、[发布与消费验证](publishing.md)、[CI](../.github/workflows/ci.yml) |
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

## 0.6.0 开发验证

当前源码模块与 CLI 为 0.6.0；正式 Mooncakes 和 GitHub Release 仍为下文的 0.5.1。
新能力包括通配符自动发现、覆盖数量要求、Setext 标题、来源影响集中复核和只读基线预览。
原来的项目配置、Action 入口和快照更新方式继续兼容。

新增 [14 步离线复核演示](../examples/review/README.md)验证新增文档、来源变化、多文档影响归并、
覆盖超限阻止候选/写入、修复绑定、删除文档与最终恢复。它保留逐步 JSON 报告，不替代真实项目采用数据。
开发测试为 native 89 项、JS/Wasm 各 76 项、CLI 集成 50 项；
便携 API 消费样例扩展为每目标 4 项，发布与独立包检查同时跑原 13 步和新 14 步演示。
相应源码见 maintenance_v060_wbtest.mbt、scripts/test_document_cli.py 和 scripts/maintenance_review_demo.py；
已推送的实现提交为 `d5baa31f16811953f4bc9cf9376575d6baa51b34`；
[常规 CI](https://github.com/Freakz2z/tracecite/actions/runs/36886731368) 和
[Linux/macOS 独立包工作流](https://github.com/Freakz2z/tracecite/actions/runs/36886730284) 均成功。
本地源码 ZIP 解包消费与 Linux 独立包验证也通过；[开发验证记录](releases/0.6.0-development.json) 明确保留开发状态，
不将候选包或本地消费推定为 0.6.0 注册表正式发布。

## 发布身份与复核方式

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
