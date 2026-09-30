# Changelog

## Unreleased

- 新增 13 步离线文档维护演示，保存逐步 JSON 诊断与验收回执，CI 上传完整证据。
- 增加申报方向与成果对照，区分受控测试、实际 Agent 接入和外部引用审计。
- 补齐第三方许可来源、完整 MoonBit core NOTICE、native 运行时组件通知；
  独立包使用全新暂存目录，附构建身份与文件摘要，缺项或校验失败时停止打包。
- 源码解包验证纳入许可、验收材料和使用安装后 CLI 的维护演示。

以上属于 0.5.0 发布后的仓库改动，尚未以新 Mooncakes 版本发布。

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
