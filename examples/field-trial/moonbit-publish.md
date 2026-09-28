# MoonBit 模块发布备忘录

Mooncakes 的发布单位是模块，而非单个包：“A module is a publishing unit that contains multiple packages.”（[官方文档](https://docs.moonbitlang.com/en/stable/toolchain/moon/package-manage-tour.html#setup-moonbit-project)）

发布前先在模块根目录运行 `moon check`、`moon test`，确认各目标后端均正常。随后检查 `moon.mod`：`name` 应采用 `<用户名>/<模块名>`，因为“For modules published to mooncakes.io, the module name must begin with the username.”（[模块配置](https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html#name)）同时更新符合 SemVer 的 `version`，并补齐 `license`、`description`、`repository`、`keywords` 和 README。

首次发布运行 `moon register`，已有账号则执行 `moon login`。出现“API token saved to ~/.moon/credentials.json”即表示登录成功（[账号设置](https://docs.moonbitlang.com/en/stable/toolchain/moon/package-manage-tour.html#setup-mooncakes-io-account)）。正式上传前使用 `moon package --list`；官方建议：“Use `moon package --list` to inspect the files that will be packaged.”（[发布文件](https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html#publishing-files-with-moonignore)）确认清单后执行 `moon publish`，其含义是“Publish the current module”（[命令说明](https://docs.moonbitlang.com/en/latest/toolchain/moon/commands.html#moon-publish)）。

常见失误包括：版本号未递增、模块名与登录用户名不符、误把本地路径依赖带入发布、README 或许可证缺失，以及 `.moonignore` 误排除必要资源。在 workspace 根目录直接发布也会失败，因为“Some commands are module-only (for example `publish`).”（[Workspace 文档](https://docs.moonbitlang.com/en/latest/toolchain/moon/workspace.html#work-at-workspace-root)）应进入具体成员目录，或执行 `moon -C <模块目录> publish`。