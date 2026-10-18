# 工程职责演示（0.9.0 开发线）

演示源码范围解析、多处版本差异、受限计算和基线写入保护。每一步都执行实际 MoonBit CLI，并断言退出码、诊断内容或已有文件字节；案例由本项目构造，不作为外部采用记录。

当前开发源码需要 moonc 0.10.15 或更新版本；本轮验证使用 v0.10.15+943464bfa。

从仓库根目录执行（输出目录须不存在）：

```sh
moon update
python3 scripts/engineering_demo.py --out _build/acceptance/engineering-local
```

默认执行 11 次 CLI 调用，覆盖以下结果：

| 步骤 | 预期结果 |
| --- | --- |
| 01 | 初始化选中章节的基线，退出 0 |
| 02 | 修改章节外内容仍通过，退出 0 |
| 03 | 章节内两处远距离修改，退出 2，列出观察行 2/123 的两个编辑块，完整候选仍含所有稳定行 |
| 05/06 | 初始化 520 行来源后整体改写，退出 2，差异表超预算明确为 cell_limit，不伪造编辑数量 |
| 07 | 显式同时比较旧基线并尝试写入，退出 2，旧基线不变 |
| 08/09/10 | 绑定配置片段失效，退出 2；不生成可写候选、不覆盖基线 |
| 11 | 引用工作区外确实存在的文件，退出 2，SOURCE_OUTSIDE_ROOT |
| 12 | 请求本机 HTTP 来源，退出 2，INVALID_OR_BLOCKED_URL，无需公网服务 |

传入已构建或已安装的 CLI 可用 --binary 参数。额外传入 --compare-binary 指向正式 0.8.0 CLI，会增加步骤 04：在同一基线上断言旧版未展示第二处修改，两个版本的验证统计与完整候选保持一致。

输出含 reports/ 下逐步原始 JSON、隔离项目和 receipt.json。[差异引擎阶段回执](../../docs/cases/engineering-0.9.0-development.json)包含该阶段的实际对比、实现与二进制摘要；后续一致性增强的摘要单独保存。重复运行应选择新的输出目录，已有证据不会被覆盖。

技术职责、算法边界与组委会意见回应见 [工程说明](../../docs/engineering-depth.md)。来源差异不替代主张的语义判断，0.9.0 开发能力尚未包含在正式 0.8.0 安装包中。

## 扫描后发生变化的四个案例

Linux 环境可以执行 python3 scripts/consistency_demo.py --out _build/acceptance/consistency-local（输出目录须不存在）。可用 --binary 指向构建或安装后的 CLI。

演示用容量为 4096 字节的 stdout 管道暂停在扫描完成、保存之前，再分别修改来源、文档、项目配置及目标基线。前三者得到 CHECK_INPUT_CHANGED，最后一项得到 SNAPSHOT_CONFLICT；全部退出 2，旧基线或另一写入者的内容保留，当前进程的临时文件清除。每一步保存扫描 JSON、提交 stderr 和摘要。[回执](../../docs/cases/consistency-0.9.0-development.json)记录实际结果。

该屏障不使用等待时长猜测或运行时测试开关。管道容量控制依赖 Linux；核心保护另可通过 moon test cli/document_consistency_wbtest.mbt --deny-warn 运行七项 native 测试，覆盖同长度改写、首次字节观察、删除、链接改向、过期写入者、创建冲突和预约归属。当前实现属于乐观验证，不声称已经提供外部文件系统事务或跨运行候选确认。
