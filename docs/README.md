# 设计资料与交接索引

- [完整项目交接](../PROJECT_HANDOFF.md)：规范、已确认决策、功能架构、当前规则、材料索引与后续边界。
- [AI 工作流](../工作流.md)：完整指令、精确修改要求、批次生成、工程实现与验证。
- [制作规范与历史清单](specifications/)：复制原始 `00_规范与清单` 的 49 份文档，保留版本和文件内容。
- [全部文件映射与 SHA-256](FILE_MANIFEST.json)、[CSV 素材索引](ASSET_INDEX.csv)、[排除项](EXCLUDED_FILES.csv)。
- 原始生成提示词：[assets/source/09_生成记录](../assets/source/09_生成记录/)。
- 工程决策与验收：[Godot docs](../assets/source/11_Godot项目/茶园物语/docs/) 与 [tests](../assets/source/11_Godot项目/茶园物语/tests/)。

历史清单和早期使用说明保留作追溯；当前规则优先读取根目录交接文档以及工程 `data/game_rules.json`、`data/garden_reference_layout.json` 和 `data/asset_catalog.json`。生成记录中的原机器路径保留，跨机器运行历史制作脚本前按文件映射调整；Godot 运行资源使用原有 `res://` 路径。

- [公开字体说明](../assets/source/11_Godot项目/茶园物语/fonts/README.md) · [实机截图索引](SCREENSHOTS.json)。
