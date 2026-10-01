# Changelog

## Unreleased

- 增加手动发布源码验证工作流：签出固定标签，下载注册表原始 ZIP，核对源码和摘要，验证真实消费后附加 Release 资产。
- 补齐 0.5.1 发布后的固定提交、资产摘要与验收回执；原版本标签和已发布源码包保持不变。

## 0.5.1 — 2026-10-01

已发布 [GitHub Release](https://github.com/Freakz2z/tracecite/releases/tag/v0.5.1) 和
[Freakz2z/tracecite@0.5.1](https://mooncakes.io/docs/Freakz2z/tracecite)。
源码提交：[d4090a5](https://github.com/Freakz2z/tracecite/commit/d4090a5ffa8fb1fdf01fe48a6b27801f72753683)。
交付摘要与消费验证见 [验收说明](docs/acceptance.md)。

- 同步模块、CLI 与安装说明版本，保留 0.5.0 的公开接口和维护行为。
- 发布前要求干净的固定标签提交；已有版本与注册表异常会阻止上传。
- 验证所有包内文件与源码一致；发布后核对注册表摘要、三目标真实消费与已安装 CLI 的维护闭环。
- native 包文件名带版本号，两平台构建通过后创建附校验文件和身份清单的 GitHub Release 草稿。

- 新增 ROADMAP.md，记录后续版本目标、任务与完成标准，并在 README 提供入口。

- 按组委会 9 项指南补齐逐项验收清单、源码结构和核心测试路径对照；CI 直接运行最小离线样例并检查格式与接口生成。

- 新增 13 步离线文档维护演示，保存逐步 JSON 诊断与验收回执，CI 上传完整证据。
- 增加申报方向与成果对照，区分受控测试、实际 Agent 接入和外部引用审计。
- 补齐第三方许可来源、完整 MoonBit core NOTICE、native 运行时组件通知；
  独立包使用全新暂存目录，附构建身份与文件摘要，缺项或校验失败时停止打包。
- 源码解包验证纳入许可、验收材料和使用安装后 CLI 的维护演示。

本版本将 0.5.0 发布后的文档与许可改动纳入正式源码包，交付标签为 v0.5.1。

## 0.5.0 — 2026-09-30

已发布 [Freakz2z/tracecite@0.5.0](https://mooncakes.io/docs/Freakz2z/tracecite)。
源码提交：[49f87d7](https://github.com/Freakz2z/tracecite/commit/49f87d781d4fd71a218eba38121fa12a59b30594)。

- 新增 Markdown 文档引用维护：本地链接、标题/行范围/区域、绑定源码的代码块、逐字引文。
- 保存引用快照，来源变化定位到文档行并展示之前与当前内容；明确统计未检查引用与代码块。
- 增加 tracecite.json 项目配置和 init 入口，本地与 GitHub Action 复用检查规则。
- 兼容原 cmd/main；增加可安装的 cmd/tracecite，核心库仍支持 native、JS、Wasm。
- 发布准备验证实际源码 ZIP、CLI 安装和三个目标的全新消费项目；公开注册表安装验证通过。

基准测试：native 79/79、JS/Wasm 各 66/66，CLI 集成 34 项，适配器 6 项。
发布 ZIP 摘要与固定 CI 见 [验收说明](docs/acceptance.md)。

## 早期开发里程碑

以下按提交记录列出演进，不将历史改动推定为某个注册表版本的完整发布内容。

| 日期（北京时间） | 成果 | 提交 |
| --- | --- | --- |
| 2026-09-23 | JSONL 输入约定、来源追溯校验、native CLI、portable 核心与 CI | [b0d6e6f](https://github.com/Freakz2z/tracecite/commit/b0d6e6f) / [487accf](https://github.com/Freakz2z/tracecite/commit/487accf) |
| 2026-09-24 | 跨运行引文/来源比较与本地文件独立回读 | [4e42c10](https://github.com/Freakz2z/tracecite/commit/4e42c10) / [7ac8255](https://github.com/Freakz2z/tracecite/commit/7ac8255) |
| 2026-09-28 | 网页独立回源、轻量笔记和普通报告，实际 Agent 接入与外部审计 | [adf163e](https://github.com/Freakz2z/tracecite/commit/adf163e) / [881e947](https://github.com/Freakz2z/tracecite/commit/881e947) |
| 2026-09-30 | 文档维护、项目配置、源码包消费验证与 0.5.0 正式发布 | [6ef7b71](https://github.com/Freakz2z/tracecite/commit/6ef7b71) / [0ac1293](https://github.com/Freakz2z/tracecite/commit/0ac1293) |
