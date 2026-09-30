# TraceCite 成果与验收说明

整理日期：2026-09-30（北京时间）。本说明依据 Git 历史中的申报稿技术目标重建成果对照，
正式提交的申报书仍以申报人保存的版本为准。它提供可检查的证据，不代替组委会的最终验收判断。

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
| 可交付的 MoonBit 工具与开源包 | portable 核心库、native CLI、Mooncakes 0.5.0、GitHub Action | [公开 API](../pkg.generated.mbti)、[发布与消费验证](publishing.md)、[CI](../.github/workflows/ci.yml) |
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

## 发布身份与复核方式

已发布模块为 **Freakz2z/tracecite@0.5.0**，对应源码提交
[49f87d781d4fd71a218eba38121fa12a59b30594](https://github.com/Freakz2z/tracecite/commit/49f87d781d4fd71a218eba38121fa12a59b30594)。
该提交的 [CI 运行](https://github.com/Freakz2z/tracecite/actions/runs/36694688818) 已通过。
发布源码 ZIP 的 SHA-256：

```text
22ac2a9ab7d54ac48d6b221054702b6428f1332f00231e7566af3d7639b2ec06
```

可执行 `moon view Freakz2z/tracecite@0.5.0` 查询注册表，并按
[安装说明](publishing.md)消费实际发布的库或 CLI。
本轮新增验收材料与许可打包在 [版本记录](../CHANGELOG.md) 中列为未发布改动；
它们属于新的仓库提交，不声称已经进入既有的 0.5.0 Mooncakes ZIP，也不覆盖该版本。

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
