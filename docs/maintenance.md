# 文档引用维护指南

`check` 直接读取 Markdown 和来源文件。引用来源相对当前文档的目录解析；`--root` 定义整个工作区的边界，而不是改变每条来源的相对目录。

## 项目配置：本地与 CI 用同一套规则

首次接入时，选择要长期维护的文档范围：

```sh
moon run cmd/main init docs README.md --root /path/to/repository
```

检查通过后，`init` 生成 `tracecite.json` 和 `.tracecite-docs.json`。已有同名配置或基线时会停止；来源不匹配、没有可检查引用或存在待复核项时不会创建配置和基线。新项目默认严格、离线检查。

将这两个文件提交到项目。之后，本地和 CI 都使用：

```sh
moon run cmd/main check --root /path/to/repository
```

独立 CLI 对应 `tracecite check`；从项目根目录运行时可省略 `--root`。本仓库的规则见 [tracecite.json](../tracecite.json)：

```json source=../tracecite.json
{
  "version": 1,
  "paths": ["README.mbt.md", "docs/maintenance.md", "docs/publishing.md"],
  "exclude": [],
  "baseline": ".tracecite-docs.json",
  "strict": true,
  "online": false
}
```

| 字段 | 省略时的值 | 含义 |
| --- | --- | --- |
| `version` | 必填 | 当前为 `1`，未知版本和字段会报错 |
| `paths` | `["."]` | 文件或目录的数组，不能为空 |
| `exclude` | `[]` | 排除文件或目录，目录包含其子路径；不支持通配符 |
| `baseline` | 无 | 可选的 `.json` 基线路径；`null` 表示不比较基线 |
| `strict` | `true` | 待复核项导致失败 |
| `online` | `false` | 是否访问网页来源 |

配置里的路径相对 `--root`，不相对配置文件所在目录；只接受根目录内的相对路径。即使 Action 的进程在工具目录运行，也读取调用方仓库的配置。配置文件上限为 64 KiB。

参数覆盖规则：指定文件或目录时替换配置中的 `paths`；`--exclude` 追加排除项；`--baseline` 覆盖基线；`--online` / `--offline`、`--strict` / `--no-strict` 覆盖对应开关。输出格式只由 `--json` 或 `--github` 控制。

`--config rules/project.json` 选择其他配置，明确指定的文件不存在时会报错；`init --config rules/project.json --snapshot rules/baseline.json` 可定制首次创建位置，父目录需已存在。`--no-config` 跳过自动加载，也保留旧版未配置的 CLI 默认值：离线、非严格、扫描当前根目录。

GitHub Action 不填写输入时复用调用方配置；没有配置时保留严格、离线检查的原有默认行为。`report:` 兼容入口跳过项目配置。

## 本地代码或配置片段

代码围栏的语言之后加 `source=路径`。路径含空格时用双引号包住整个属性值。下面的代码块直接核对项目真实的 [模块配置](../moon.mod)：

```text source=../moon.mod
import {
  "moonbitlang/async@0.22.1",
  "bobzhang/html_parser@0.2.0",
}
```

片段按完整行查找，保留大小写、缩进与引号。只统一 CRLF/LF；不执行代码，不根据语义推测它属于哪个文件。整个来源文件中的其他片段改变，不会使仍然存在的这段代码失败。

需要限定来源范围时，可以在路径后面加行选择器或命名区域：

````markdown
```toml source=../config.toml#L2-L4
timeout = 20
retries = 3
enabled = true
```

```toml source=../config.toml#region:defaults
timeout = 20
```
````

命名区域的来源文件示例：

```text
# ANCHOR: defaults
timeout = 20
# ANCHOR_END: defaults
```

使用范围选择器时，基线会记录选中区域；区域中的其他内容改变也会要求复核。普通片段不带选择器时，记录匹配片段本身。

## 链接与标题

行内链接、引用式链接与图片链接都会提取本地目标；同一行 HTML 标签的 `href`、`src` 属性也会提取，例如 README 的 SVG 图片。展示属性中的引号和 Markdown 示例不当作引文或链接。文件和目录可以被检查；Markdown 标题支持 ATX 标题，自动生成小写锚点，重复标题依次加 `-1`、`-2`，并避开已有锚点。支持空格路径的百分号编码，以及 `<含空格的路径>` 写法。

ATX 标题支持 `#` 后的空格或制表符，以及可选的结尾 `#`；标题中的行内链接使用展示文字生成锚点，HTML 排版标签不计入标题文字。HTML 注释中的标题不会生成锚点，也不会截断正在引用的正文区域。

行内代码支持一个或多个反引号，开闭反引号数量必须一致。代码里的链接、双引号和 HTML 注释标记都是示例内容；未闭合的反引号作为普通文字处理，不会遮掉后面的真实链接。

实际入口是 [README 的快速开始](../README.mbt.md#快速开始)。自引用也可以使用 [本节](#链接与标题)。

```markdown
[安装](guide.md#安装)
[源码](../config.toml#L2-L4)
[配置][defaults]

[defaults]: ../config.toml
```

目前不解析 Setext 标题、自定义 HTML ID 或站点特有锚点规则；这些情况要改用支持的来源范围或人工核查。目录扫描默认跳过 Git、MoonBit 构建目录、依赖目录和 Python 缓存，递归扫描不跟随符号链接；直接指定的文档符号链接会解析到根目录内的真实文件。

## 逐字引文

本地文件和网页都能作为逐字引文来源。行内引文使用双引号，后面的来源链接位于同一行、同一句中。来源也可以是引用式链接：

```markdown
“The timeout is twenty seconds.” ([说明](source.md#settings))
"The timeout is twenty seconds." ([说明][settings])

[settings]: source.md#settings
```

无法在同一句表达来源时，使用相邻的显式引用块：

```markdown
> 原文：“The timeout is twenty seconds.”
> 来源：[说明](source.md#settings)
```

网页检查需要 `--online`。这会独立访问来源，验证可见文本中的引文；普通网页链接只检查可访问性，不检查它支持了什么主张，也不验证网页 URL 的标题锚点。引文忽略排版空白和引号字形差异；明确的省略号允许有序的较长原文片段。

## 快照与复核

```sh
moon run cmd/main check --snapshot .tracecite-docs.json
moon run cmd/main check
```

快照是工具生成的 JSON 文件，可以随仓库提交。引用身份由相对文档路径、来源、类型与文档片段组成，不包含文档行号。移动段落不会误报为新增引用；修改文档引用、增加引用，则需要复核并重新保存基线。

本地选择器记录被选中的内容；无选择器的代码块记录匹配片段。网页引文记录匹配位置前后各至多 100 个字符的归一化上下文，避免把整页导航和远处内容的改动都当作引用变化。普通无锚点链接仅记录存在性或可访问性，不做整份文件、整张图片或整页网页的变化监控。

基线比较发现变化时返回退出码 2，展示之前观察到的内容和当前内容。先人工决定文档是否需要修改；确认后，用 `--snapshot` 命令保存新基线。它忽略配置中的旧基线，仍独立检查引用与来源是否匹配。显式同时提供 `--baseline` 时仍会比较旧基线；发现变化或待复核项会拒绝写入。工具不会把失败检查自动接受成新基线。

来源片段在来源中出现多次时，无范围的逐字引文以首次匹配位置提取上下文；需要精确限制本地引用位置时应指定标题、行范围或命名区域。已有基线中的引用被从文档删除后，该引用不再检查；下一次保存基线会去掉它。比较文档子集只读取相关引用；保存快照会替换整个快照文件，应使用准备维护的完整文档范围。

## 输出与退出码

每次输出检查文件数、实际检查引用数、失败数、待复核数，以及跳过的网页和未绑定来源的代码块数量。`LOCAL_OK` 仅针对实际检查的本地引用。

| 退出码 | 含义 |
| --- | --- |
| 0 | 实际检查的引用通过；严格模式下没有待复核项 |
| 1 | 参数、读取输入或写入快照失败 |
| 2 | 引用不匹配、来源不可用、来源改变、零条可检查引用；严格模式下也包含待复核项 |

`--json` 输出结构化结果；`--github` 输出 GitHub 文件行号诊断。代码块没有 `source=` 会计入未检查数量，不会被执行；引文没有明确来源会报告 `UNASSOCIATED_QUOTE`。不存在的来源、失效锚点、不匹配片段分别用不同错误码。配置解析和文件读写错误返回 1，不会伪装成检查通过。

常用命令：

```sh
moon run cmd/main check docs README.md --strict
moon run cmd/main check docs --exclude docs/drafts --json
moon run cmd/main check docs --root /path/to/repository --github --strict
```

## 依赖与原有接口

本地检查只读取仓库内的文件；不需要 Agent、模型 API、Python、Node、数据库或后台服务。源码方式需要 MoonBit，独立 native 二进制无需 MoonBit 运行时安装。

网页回源复用原有 HTTP/HTML 实现，访问限制见 [HTTP 回源行为](contract.md#http-回源行为)。JSONL 与原来的 Agent 校验入口保留兼容，见 [原有输入约定](contract.md)；它们是可选接入方式。
