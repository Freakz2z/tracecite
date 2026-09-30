# 离线维护闭环演示

这是**受控案例**：脚本刻意修改来源，验证维护流程与失败保护。
不需要联网、模型 API 或 Agent 日志；它不代表真实团队采用率、自然错误率或节约工时。

在仓库根目录执行（需要 MoonBit 与开发工具 Python 3）：

```sh
python3 scripts/acceptance_demo.py
```

也可以使用已解压的独立 CLI：

```sh
python3 scripts/acceptance_demo.py --binary /path/to/tracecite
```

脚本将 [初始项目](project) 复制到新建的 `_build/acceptance/` 子目录，
原始示例和仓库文档不会被修改。指定 `--out /path/to/new-directory` 可保存到固定位置；
目标已经存在时停止，不覆盖已有证据。

| 阶段 | 预期结果 | 复核依据 |
| --- | --- | --- |
| `init guide.md`，再运行 `check` | 退出 0；产生项目配置与引用快照 | 默认严格、离线，本地和 CI 复用同一配置 |
| 来源标题区域补充重试规则 | 退出 2；REFERENCED_SOURCE_CHANGED | 定位 guide.md 行，输出 previous / actual |
| 同时指定旧基线与快照 | 退出 2；旧基线字节不变 | 未通过复核不能覆盖旧记录 |
| 模拟人工接受新增上下文，再更新快照 | 退出 0；再次 check 通过 | 引用原文仍然存在，来源变化已经审阅 |
| 配置超时从 20 改到 30，保留旧文档 | 退出 2；DOCUMENT_EXCERPT_MISMATCH | 定位代码围栏第 5 行，候选片段 timeout = 30 |
| 对错误片段直接保存快照 | 退出 2；旧基线字节不变 | 更新基线不能绕过当前来源核验 |
| 修正文档为 30，更新快照 | 退出 0；再次 check 通过 | 文档与实际配置一致 |
| 来源标题改名，保留旧链接 | 退出 2；ANCHOR_NOT_FOUND | 失效锚点需要修正 |
| 修正锚点、更新快照、再次检查 | 退出 0 | 维护闭环恢复通过 |

共 13 次 CLI 调用，每次验证真实退出码与 JSON 诊断。输出目录保存初始基线、
最终项目、逐步 JSON 报告和 receipt.json。出现意外结果时脚本失败，保留已有输出用于排查。
[CI](../../.github/workflows/ci.yml) 与 [native 打包验证](../../scripts/verify_native_package.py)
运行同一脚本；后者调用解包后的二进制，确认案例不依赖源码工作区中的可执行文件。

实际资料的核验结果请参阅 [外部引用审计](../../docs/external-audit.md)
和 [普通报告试验](../field-trial/README.md)，验收成果对应关系见 [验收说明](../../docs/acceptance.md)。
