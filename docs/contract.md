# TraceCite 输入约定

TraceCite 提供轻量引用笔记和 Agent JSONL 两种输入。轻量笔记适合快速验证；JSONL 用于保留工具调用、来源与回答之间的关系。

## 轻量引用笔记

每条记录各写一行 `claim:`、`quote:` 和 `url:`，字段可以换序；空行或 `---` 分隔多条记录。字段值为单行文本，冒号后面的内容按原样保留（两侧空白会去掉）。以 `#` 开头的行为注释。

```text
claim: The report lists the example domains.
quote: example.com and example.org are maintained for documentation purposes.
url: https://www.iana.org/help/example-domains
```

运行 `moon run cmd/main verify-notes notes.md`。命令回源读取每个 URL，并检查 `quote` 是否出现在当前页面的可见文本中。HTML 实体与标签由 HTML5 解析器处理，匹配时会折叠空白，但保留大小写与标点。`claim` 用于让人理解记录，不进行语义蕴含判断。

## Agent JSONL

每行是一个事件，按观察顺序排列；一次运行中的 `run_id` 一致，`call_id` 和来源 `id` 唯一。未知字段允许保留。

```jsonl
{"type":"tool_call","run_id":"r1","call_id":"c1","tool":"search"}
{"type":"tool_result","run_id":"r1","call_id":"c1","ok":true,"sources":[{"id":"s1","uri":"https://www.iana.org/help/example-domains","content":"example.com and example.org are maintained for documentation purposes."}]}
{"type":"answer","run_id":"r1","claims":[{"text":"The report lists the example domains.","citations":[{"source_id":"s1","quote":"example.com and example.org are maintained for documentation purposes."}]}]}
```

- `tool_call`：需要 `call_id` 和 `tool`。
- `tool_result`：需要 `call_id`、布尔值 `ok`；成功来源包含 `id`、`uri` 和用于证据校验的 `content`。失败结果不能提供来源。
- `answer`：每次运行恰好一个；证据模式要求至少一个 claim，每个 claim 至少一条 citation。引用需要 `source_id` 和非空 `quote`。

`moon run cmd/main trace.jsonl --evidence` 核对引用片段是否是捕获内容的逐字子串。`moon run cmd/main verify-urls trace.jsonl` 先运行证据校验，再按来源 URL 回源核对引用；它不依赖轨迹里的捕获内容来判定网页当前是否包含该引用。`verify-files` 重新读取 `file:` 来源指定的当前文件。`compare old.jsonl new.jsonl` 按稳定 URI 比较捕获内容，报告 `added`、`removed` 和 `changed`。

诊断使用稳定错误码，报告不回显来源正文或引用片段。校验成功退出码为 0；证据不匹配、来源不可用或来源变化为 2；命令参数或笔记格式错误为 1。可传 `--json` 获取机器可读输出。

## HTTP 回源行为

- 仅接受 `http://`、`https://` 和各自默认端口；不支持带用户凭据、IPv6 字面地址或非 ASCII 主机名的 URL。
- 逐跳检查重定向目标，最多跟随五次；拒绝 HTTPS 降级到 HTTP。
- 拒绝本地、私网和保留 IPv4/IPv6 地址；检查 DNS 返回的第一个 IPv4 和第一个 IPv6 地址。对托管执行环境，HTTPS 域名解析到 `198.18.0.0/15` 时允许该网络路由；该段的 IP 字面地址和 HTTP 请求不允许。TLS 证书仍需匹配原始主机名。
- 每个来源请求最多 20 秒、2 MiB。HTML 会提取可见文本；支持 `text/*`、XHTML、JSON 和未声明类型的 UTF-8 页面。超出范围的内容类型、非 UTF-8 页面或 HTTP 错误会返回诊断码。

异步 HTTP 库在连接时重新解析域名，当前校验器没有固定完整 DNS 答案。不要将其当作面向不可信 URL 的服务端网络隔离层。远端页面可能变化；引用出现不证明 claim 的语义真实性，也不构成网页历史快照。
