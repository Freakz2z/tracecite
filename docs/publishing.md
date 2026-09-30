# Mooncakes 发布与接入

根包 `Freakz2z/tracecite` 提供可复用的文档解析、配置解析、来源选择、片段匹配与基线数据格式，支持 native、JS、Wasm。读取文件和访问网页的 [命令行入口](../cmd/main/main.mbt) 仅支持 native。

## 在 MoonBit 项目中使用

在消费项目安装 0.5.0：

```sh
moon add Freakz2z/tracecite@0.5.0
```

在 `moon.pkg` 中导入根包：

```text
import {
  "Freakz2z/tracecite" @tracecite,
}
```

下面的解析不访问网络，也不读取本地文件：

```moonbit
let document = @tracecite.parse_document("[配置](config.toml)\n")
let project = @tracecite.parse_document_project_config("{\"version\":1,\"paths\":[\"docs\"]}")
assert_eq(document.references.length(), 1)
assert_true(project.config.unwrap().strict)
```

消费方负责根据解析出的引用访问来源，再使用核心库进行片段匹配与基线序列化。接口列表见 [pkg.generated.mbti](../pkg.generated.mbti)。

需要命令行时可直接安装 native 包，生成的命令名为 `tracecite`：

```sh
moon install Freakz2z/tracecite/cmd/tracecite@0.5.0
tracecite init docs README.md
tracecite check
```

安装需要 MoonBit；生成的可执行文件运行时不需要 MoonBit。源码仓库也可以执行 `moon install ./cmd/tracecite`。原有 `moon run cmd/main` 继续兼容，两个入口共用 [CLI 实现](../cli/main.mbt)。命令行使用方式见 [维护指南](maintenance.md)。

## 准备发布包

在源码仓库执行：

```sh
bash scripts/release.sh
```

脚本更新依赖，检查编译、native/JS/Wasm 测试、CLI 集成测试与仓库文档，再用 `moon package` 生成源码 ZIP。随后解包验证文档资源、项目配置和基线，测试 `moon install` 生成的 `tracecite` 命令，并创建一个消费项目，通过 native、JS、Wasm 的公开 API 测试。

默认只准备包，不上传。ZIP 与 SHA-256 文件保存在 `dist/mooncakes/`。GitHub CI 同样执行包验证并保存发布候选文件，避免只在源码目录测试成功，却漏掉发布包需要的文件。

`moon package` 使用 [.moonignore](../.moonignore)；包内保留 README 图片、[Action 定义](../action.yml)、工作流和文档基线。构建产物与独立二进制压缩包不进入源码包。

当前源码包验证也要求 [验收说明](acceptance.md)、[离线维护案例](../examples/maintenance/README.md)、版本记录与第三方许可材料完整，并使用解包后安装的 CLI 跑完案例。
Mooncakes 0.5.0 已发布且不会覆盖；本轮材料属于 [未发布改动](../CHANGELOG.md)。当前生成的候选 ZIP 不是已发布 ZIP，下一次上传前需更新模块版本。固定发布提交及原始摘要见验收说明。

## 上传 Mooncakes

确认 [moon.mod](../moon.mod) 中的模块名称、版本和许可证，在拥有 `Freakz2z` 发布权限的环境登录，再运行：

```sh
moon login
bash scripts/release.sh --publish
```

`--publish` 先完成同一套验证，再调用官方 `moon publish`；成功后查询 Mooncakes 确认目标版本可见。也可以运行 `moon view Freakz2z/tracecite@0.5.0` 核对已发布版本。不要在仓库中保存凭证。

发布准备不使用 `moon publish --dry-run`；只构建源码包时使用 `moon package`。发布新版本应先修改模块版本，更新相关文档，复核引用后刷新基线，并提交源码。

## 独立 CLI 包

```sh
bash scripts/package.sh
```

脚本生成当前系统的 native 压缩包，运行不需要 MoonBit、Python 或 Node。它与 Mooncakes 源码包是两个交付方式；跨系统构建入口见 [二进制工作流](../.github/workflows/binaries.yml)。

打包脚本需要 Python 3，使用全新暂存目录，收集实际依赖和 SDK 的 LICENSE/NOTICE。
缺少必要通知、上游许可副本摘要改变或解包验证失败时停止，不替换已有压缩包。
产物附带 SHA-256 文件；包内 BUILD-INFO.json 记录源码提交、工作区修改状态、
工具链、实际依赖版本和所有载荷摘要。发布分发应从干净的固定提交构建。
组件清单与 TLS 系统依赖见 [第三方通知](../THIRD_PARTY_NOTICES.md)。
