# Mooncakes 发布与接入

根包 `Freakz2z/tracecite` 提供可复用的文档解析、配置解析、来源选择、片段匹配与基线数据格式，支持 native、JS、Wasm。读取文件和访问网页的 [命令行入口](../cmd/main/main.mbt) 仅支持 native。

## 在 MoonBit 项目中使用

当前正式版本为 0.5.1；0.6.0 新接口处于开发源码，尚未上传注册表。
在消费项目安装正式版本：

```sh
moon add Freakz2z/tracecite@0.5.1
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
moon install Freakz2z/tracecite/cmd/tracecite@0.5.1
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
0.5.1 将此前的验收、许可与 Roadmap 材料纳入源码包，变化见 [版本记录](../CHANGELOG.md)。每个发布版本使用独立版本号和固定标签，不覆盖已有版本。ZIP 的 .sha256 与 .json 侧文件记录摘要和源码身份。

## 上传 Mooncakes

确认 [moon.mod](../moon.mod) 中的模块名称、版本和许可证，在拥有 `Freakz2z` 发布权限的环境登录，完成测试并提交、推送源码，确认该提交 CI 通过后，创建与模块版本对应的标签，再运行：

```sh
git tag v0.6.0
git push origin v0.6.0
moon login
bash scripts/release.sh --publish
```

`--publish` 先要求工作区干净、CLI 与模块版本一致、版本标签指向当前 HEAD，并查询注册表。只有明确的 404 才视为新版本；已有版本、权限错误、服务异常或未知响应均停止。随后完成同一套验证，在上传前再次核对源码提交和版本，再调用官方 `moon publish`；成功后核对注册表摘要、从真实注册表安装库和 CLI，验证 native/JS/Wasm API 及 13 步维护流程。也可以运行 `moon view Freakz2z/tracecite@0.5.1` 核对已发布版本。不要在仓库中保存凭证。

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

## 正式 GitHub Release

版本标签触发两平台构建。工作流核对两份压缩包的版本、源码 SHA、干净工作区标记、许可载荷与 SHA-256；全部通过后创建 **草稿** Release，上传 Linux/macOS 包、校验文件及 release-assets.json。

维护者完成 Mooncakes 发布与真实消费验证后，将 dist/mooncakes/ 中的 ZIP、摘要、源码身份和发布验证回执上传同一草稿。复核该标签的 CI 与两平台工作流结果后，将草稿公开发布。工作流不会自动替换已存在的 Release 资产。

也可手动运行 [发布源码验证工作流](../.github/workflows/release-source.yml)，指定已有版本标签。
工作流签出固定标签，核对独立包的来源提交，下载注册表的原始 ZIP 并核对摘要与包内源码；
三目标 API 和安装后的 CLI 验证通过才附加源码与回执。它不发布 Mooncakes、不替换已有附件，也不自动公开草稿。

不同环境重新打包的 ZIP 元数据可能不同；补传时应使用注册表中的原始 ZIP，不能仅凭同一源码提交认定文件摘要一致。

正式包名称包含版本，例如 tracecite-0.5.1-linux-x86_64.tar.gz。解压后执行其中的 tracecite，无需 MoonBit、Python 或 Node；联网检查仍使用系统 TLS 库与证书。

独立复查注册表安装：

```sh
python3 scripts/verify_release_package.py --consume-registry
```

复查需要本地 dist/mooncakes/ 中已验证的对应源码 ZIP，以核对注册表摘要。维护流程证据保存在 _build/acceptance/published-版本/，成功回执写入 ZIP 同目录的 .published.json 文件。
