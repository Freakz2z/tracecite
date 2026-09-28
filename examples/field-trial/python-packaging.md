# 技术备忘录：用 `pyproject.toml` 构建并发布 Python 包

## 推荐流程

项目宜采用 `src/包名/` 布局，并准备 README、许可证和测试。`pyproject.toml` 中必须明确构建后端及其依赖；官方强调：“The `[build-system]` table should always be present” ([配置指南](https://packaging.python.org/en/latest/guides/writing-pyproject-toml/))。在 `[project]` 中填写唯一的 `name`、`version`、`description`、`readme`、`requires-python`、许可证、依赖和项目链接。除确需后端计算的字段外，优先使用静态元数据；动态字段则应记入 `dynamic`，因为“When a field is dynamic, it is the build backend’s responsibility to fill it.” ([配置指南](https://packaging.python.org/en/latest/guides/writing-pyproject-toml/))。

升级 `build` 后，在配置文件所在目录执行 `python -m build`。成功时应同时得到 wheel 和源码包；官方要求：“You should always upload a source distribution” ([打包教程](https://packaging.python.org/en/latest/tutorials/packaging-projects/))。先通过 Twine 上传 TestPyPI，再在全新虚拟环境中安装并测试导入；“You can use `pip` to install your package and verify that it works.” ([打包教程](https://packaging.python.org/en/latest/tutorials/packaging-projects/))。确认无误后，才上传正式 PyPI。

## 常见失误

最常见的问题是漏列构建期依赖，导致隔离构建失败；版本未递增则无法覆盖已发布文件。还应避免只上传 wheel、遗漏许可证或额外数据文件、把 Python 兼容范围仅写进 classifiers，以及将 API Token 写入仓库。classifiers 只服务于检索展示；真正限制安装版本应使用 `requires-python`。此外，不要把 TestPyPI 当永久仓库：“The Test system occasionally deletes packages and accounts.” ([打包教程](https://packaging.python.org/en/latest/tutorials/packaging-projects/))。