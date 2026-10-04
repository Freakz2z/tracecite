# 0.6.1 文档兼容性最小样例

样例同时包含 Unicode 标点标题、脚注正文中的普通链接、仓库根路径链接及绑定代码块。
从 TraceCite 源码根目录执行：

```sh
moon run cmd/main check guide.md --root examples/compatibility/project --no-config --strict
```

预期 LOCAL_OK、3 条引用、零失败、零待复核、零网页跳过和零未绑定代码块。
独立 CLI 对应 tracecite check guide.md --root examples/compatibility/project --no-config --strict。

`/source.md` 与 `/config.toml` 相对 --root，不是操作系统根目录。
脚注标记不被当作文件路径，脚注正文中的真实链接仍会检查。
标题中的长破折号被移除，空格仍生成连字符，因此锚点为 blockingn--backpressure。
