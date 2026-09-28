# 独立公开资料审计（2026-09-28）

为了检验工具是否只能通过自造样例，选取第三方公开仓库 [awesome-engineering-team-management 的固定版本](https://github.com/kdeldycke/awesome-engineering-team-management/blob/880e027f32da577d88871c7d8960fa302bc73a12/readme.md)。取样规则在运行前确定：按文件顺序选出**前 10 行同时含中文弯引号 `“` 与 Markdown 链接 `](` 的行**，不按结果筛选。原始行号是 127、131、133、141、143、145、147、157、159、161；本项目不复制或修改该仓库。

工具读取这个本地截取文件，10 条引文均关联到来源；对当时网页正文的检查结果是 **7/10 匹配，3 条需复核**。人工回看来源后：

| 原始行 | 工具结果 | 人工复核 |
| --- | --- | --- |
| [131](https://github.com/kdeldycke/awesome-engineering-team-management/blob/880e027f32da577d88871c7d8960fa302bc73a12/readme.md#L131) | 不匹配 | 将 [CSS-Tricks 原文](https://css-tricks.com/mistakes-ive-made-as-an-engineering-manager/)的数个标题缩写、串接成一条带引号的句子，不是逐字连续原文；应拆成真实引文或改为转述。 |
| [147](https://github.com/kdeldycke/awesome-engineering-team-management/blob/880e027f32da577d88871c7d8960fa302bc73a12/readme.md#L147) | 不匹配 | 引文中插入了说明性括号；[原始 Hacker News 评论](https://news.ycombinator.com/item?id=23973859)没有这几个词。将解释放到引号之外，或只引用原文。 |
| [143](https://github.com/kdeldycke/awesome-engineering-team-management/blob/880e027f32da577d88871c7d8960fa302bc73a12/readme.md#L143) | 不匹配 | 来源指向 [X 帖子](https://x.com/mit_csail/status/1604884273789603842)，HTTP 页面返回 200，但可提取文本中没有引文；它可能位于图片或动态内容中。**不能据此判定引文本身错误**，需要人工找可读取的原始材料。 |

另两种最初出现的误报经修复后归零：Hacker News 页面明确声明 UTF-8，旧实现却按 Windows-1252 解码弯引号；归档文章使用省略号连接两段原文，逐字连续匹配无法识别。现在工具遵从 HTTP charset、忽略引号字形差异，并允许省略号两侧足够长的片段按顺序出现在同一来源中。工具仍不判断引文支撑的整句主张是否正确。

为验证修订通路，仅在本地副本中把第 131 行改成来源中真实出现的单个标题，并移除第 147 行引号内的说明性括号；复查变成 **9/10**，剩下的是上述 X 页面。修订没有发送给第三方仓库，也没有把未验证的 X 引文算作通过。

复现取样与检查（需要 Python 3、MoonBit 和网络；从本仓库根目录运行）：

```sh
python3 - <<'PY'
from pathlib import Path
from urllib.request import urlopen

url = 'https://raw.githubusercontent.com/kdeldycke/awesome-engineering-team-management/880e027f32da577d88871c7d8960fa302bc73a12/readme.md'
text = urlopen(url, timeout=20).read().decode('utf-8')
lines = [line for line in text.splitlines() if '“' in line and '](' in line][:10]
Path('/tmp/tracecite-external-sample.md').write_text('# External sample\n\n' + '\n'.join(lines) + '\n')
PY
moon run cmd/main check-report /tmp/tracecite-external-sample.md --json
```

这个案例证明 TraceCite 能对一个并非为它编写的公开文档提出**两条可核实的逐字引文修订建议**。10 条样本太少，且来源和网页内容会变化，不能推算总体错误率、审核工时节省或语义准确率。
