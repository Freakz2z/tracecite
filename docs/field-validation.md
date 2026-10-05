# 0.6.x 真实仓库首轮验证

验证日期：2026-10-04。使用正式 TraceCite 0.6.0，在本地为两个公开仓库配置离线文档检查。
这是固定提交的维护适配评估；未向上游提交修改，不代表上游采用，也不证明长期维护收益。

## 固定范围与结果

| 仓库 | 固定提交 | 配置 paths | 文档 | 已检查引用 | 失败 | 待复核 | 网页跳过 | 未绑定代码块 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| moonbitlang/async | `00aa493c5a674988dc0f4dc3f9bf0a0e654427ac` | `README.md`, `src/**/*.md`, `examples/**/*.md` | 14 | 65 | 3 | 14 | 1 | 103 |
| moonbitlang/moon | `0a3f0d43b228a5338417d8a569d3cdaa833e467d` | `README.md`, `docs/**/*.md` | 51 | 222 | 10 | 52 | 63 | 82 |

两次严格检查退出码均为 2。失败数量包含工具兼容性问题，不能直接当作上游错误数量。
配置为 schema 1、strict=true、online=false、exclude=[]，不设置基线或覆盖预算，以先观察全部诊断。
完整配置、诊断摘要和工具版本保存在 [机器可读回执](field-validation/0.6.0.json)。

## 人工复核

| 固定文件与行 | 检查结果 | 复核结论与后续处理 |
| --- | --- | --- |
| [async/src/fs/README.mbt.md:11](https://github.com/moonbitlang/async/blob/00aa493c5a674988dc0f4dc3f9bf0a0e654427ac/src/fs/README.mbt.md#L11) | `#file-seeking` 不存在 | 真实断链：正文对应操作的标题已是 `Random access on files`（212 行）；目录应指向 `#random-access-on-files`。本轮未修改上游。 |
| [async/src/io/README.mbt.md:15](https://github.com/moonbitlang/async/blob/00aa493c5a674988dc0f4dc3f9bf0a0e654427ac/src/io/README.mbt.md#L15) | `#working-with-task-groups-and-pipes` 不存在 | 真实断链：固定文件内没有该标题或显式锚点。需维护者决定恢复章节还是删除旧目录项。 |
| [async/src/aqueue/README.mbt.md:18](https://github.com/moonbitlang/async/blob/00aa493c5a674988dc0f4dc3f9bf0a0e654427ac/src/aqueue/README.mbt.md#L18) | `#blockingn--backpressure` 不存在 | TraceCite 误报：99 行标题含长破折号；GitHub 渲染 API 返回 `id="user-content-blockingn--backpressure"`。当前 slug 保留长破折号，需修复 Unicode 标点并添加回归。 |
| [moon/docs/dev/reference/arch.md:115](https://github.com/moonbitlang/moon/blob/0a3f0d43b228a5338417d8a569d3cdaa833e467d/docs/dev/reference/arch.md#L115)及同文件其他 8 条 | 仓库根路径链接不可读 | 工具兼容性限制：例如 `/crates/moonbuild-rupes-recta/src/lib.rs` 对应文件实际存在；当前离线检查不支持此类 GitHub 仓库根链接，不能判定断链。修复须保持 --root 边界保护。 |
| [moon/docs/dev/reference/build.md:55](https://github.com/moonbitlang/moon/blob/0a3f0d43b228a5338417d8a569d3cdaa833e467d/docs/dev/reference/build.md#L55) | 错误尝试读取来源 `The` | TraceCite 误报：`[^subpkg]` 是脚注引用，67 行脚注定义以 The 开头；解析器将脚注当作普通引用链接。需区分脚注与链接定义并添加回归。 |

14 与 52 条待复核项主要为未关联来源的引号文本。技术文档会用引号描述选项、术语或输出值，未关联来源并不证明内容有误；本轮没有逐条判定其意图，也不计算总体误报率。
64 条网页引用未回源，185 个代码块没有 source=；均不计为已核验。未进行来源修改或人为造错，因此本轮也不作为自然发生的跨版本来源变化证据。

## 复现

需要 Git、Python 3、MoonBit 与网络以获取固定上游提交；检查本身离线。从 TraceCite 源码根目录执行：

```sh
moon update
python3 scripts/field_validation.py --output _build/field-validation-new
```

输出目录必须不存在，避免覆盖已有记录。可用 `--binary /absolute/path/to/tracecite` 检查独立包。
脚本分别 fetch 固定 SHA、核对 HEAD、写入本地检查配置，保存原始 JSON、退出码及汇总回执。
严格检查退出码 2 是被记录的验证结果；脚本解析失败或进程异常则停止。
原始报告与上游副本仅保存在输出目录，本仓库只保留自己的复核说明和精简诊断，不分发上游源码。

## 0.6.1 修复后复查

三类兼容性问题已修复并加入 portable 与 CLI 回归。按同样固定提交与配置复查：

| 案例 | 0.6.0 失败 | 0.6.1 失败 | 复核 |
| --- | --- | --- | --- |
| async | 3 | 2 | 标点锚点误报消除；两条真实断链继续报告 |
| moon | 10 | 0 | 九条根路径链接可读；脚注不再制造来源 The |

复查回执见 [0.6.1 记录](field-validation/0.6.1.json)。moon 的已检查引用从 222 变成 221，
是移除一条伪造的脚注来源；不是少检查一条实际链接。文档范围、网页跳过、未绑定代码块与待复核计数均未变。
根路径解析增加越界与符号链接回归，脚注正文中的真实链接仍被提取。
自然发生的来源变化与实际用户维护反馈继续待收集；未完成的 Roadmap 项保持未勾选。

## 0.7.1 回归复查

按上述两个固定提交与配置重跑，结果与 0.6.1 相同：async 保留两条已核实断链，moon 零检查失败；待复核、网页跳过及未绑定代码块计数未变。严格模式仍均退出 2，不能据此声称整体检查通过。
复查回执见 [0.7.1 记录](field-validation/0.7.1.json)。

非 ASCII 大小写问题另用[本项目编写的多语言标题样例](../examples/anchors/README.md)独立复现和回归；这些标题不是在上述两个仓库中发现的。该样例验证工具兼容性，不属于自然来源变化或外部采用证据。

## 引用解析与警告复查

已按固定提交逐项查看此前 66 条警告的上下文：[分类记录](field-validation/warning-review.json)包含 50 条 UNASSOCIATED_QUOTE、8 条 UNCLOSED_QUOTE、8 条 UNSUPPORTED_SOURCE_SCHEME。此前将 66 条全部称为引号警告不准确，实际引号诊断为 58 条。

10 条诊断涉及跨行的示例表达；46 条涉及术语或说明性表达；另有契约说明和带换行来源的比较语句各一条。分类说明了可能的用途，不代替上游维护者确认引用意图，当前仍保留全部警告。8 条编辑器路径以 path:line 表示源码位置，尚不是支持的路径与行选择器。

本轮另修复引用标签重复定义、空格冲突、Unicode 匹配和链接目的地解析，并增加[正反回归样例](../examples/link-parsing/README.md)。这些修复纳入 0.7.2，已发布的 0.7.1 内容不变；固定案例复查仍保留两条真实断链及所有未检查内容。

## 0.7.2 正式包复查

使用已下载并核对摘要的 0.7.2 Linux 独立包重跑相同固定提交和配置，[回执](field-validation/0.7.2.json)记录 65 份文档、286 条已检查引用。
async 的两条真实断链继续报告；两个仓库严格检查均退出 2，待复核、网页跳过及未绑定片段计数与 0.7.1 一致。引用解析修复没有通过隐藏警告或减少覆盖来制造通过结果。
