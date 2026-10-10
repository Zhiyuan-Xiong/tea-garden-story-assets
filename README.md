# 茶园物语 · 设计资料与 AI 制作档案

围绕中国传统制茶技艺的国风轻经营与工艺体验项目。通过“种植—采摘—制茶—待客”连接文化说明与玩家行动，用五日梯田开放建立新手目标，再以职业、配方、品质和订单延续成长。

**[完整交接](PROJECT_HANDOFF.md) · [AI 工作流与流程图](工作流.md) · [公开网页案例／核心流程体验](https://xiongzhiyuan-portfolio.pages.dev/zh/work/tea-garden/)**

这是公开项目仓库，保存原始质量素材、完整本地 Godot 原型与 AI 制作记录。公开工程沿用 Noto Sans SC，原始两款字体不分发。AI 贯穿方案组织、素材制作、代码原型与迭代；我负责文化体验定位、视觉方向、规则取舍、短指令评审和最终质量。

## 实际游戏画面

以下为既有 Godot 原型的实机截图，保留原制作状态；公开工程的文字字体已统一替换为 Noto Sans SC。

<img src="https://media.githubusercontent.com/media/Zhiyuan-Xiong/tea-garden-story-assets/main/previews/game-home.webp" alt="游戏首页 · 山水入口与原始书法标识" width="100%">

<table>
<tr><td width="50%"><img src="https://media.githubusercontent.com/media/Zhiyuan-Xiong/tea-garden-story-assets/main/previews/village-current.webp" alt="茶村 · 建筑入口、悬挂题签与装饰树群" width="100%"><br><strong>茶村 · 建筑入口、悬挂题签与装饰树群</strong></td><td width="50%"><img src="https://media.githubusercontent.com/media/Zhiyuan-Xiong/tea-garden-story-assets/main/previews/garden-current.webp" alt="云雾茶园 · 五层十四位与逐株状态" width="100%"><br><strong>云雾茶园 · 五层十四位与逐株状态</strong></td></tr>
<tr><td width="50%"><img src="https://media.githubusercontent.com/media/Zhiyuan-Xiong/tea-garden-story-assets/main/previews/workshop-current.webp" alt="制茶工坊 · 五道工序与今日待办" width="100%"><br><strong>制茶工坊 · 五道工序与今日待办</strong></td><td width="50%"><img src="https://media.githubusercontent.com/media/Zhiyuan-Xiong/tea-garden-story-assets/main/previews/teashop-current.webp" alt="临水茶铺 · 订单与交付路径" width="100%"><br><strong>临水茶铺 · 订单与交付路径</strong></td></tr>
<tr><td width="50%"><img src="https://media.githubusercontent.com/media/Zhiyuan-Xiong/tea-garden-story-assets/main/previews/layout-current.webp" alt="自由布置 · 植物、图层与可恢复调整" width="100%"><br><strong>自由布置 · 植物、图层与可恢复调整</strong></td><td width="50%"><img src="https://media.githubusercontent.com/media/Zhiyuan-Xiong/tea-garden-story-assets/main/previews/summary.webp" alt="阶段结算 · 五日经营与成长反馈" width="100%"><br><strong>阶段结算 · 五日经营与成长反馈</strong></td></tr>
</table>

[直接体验种采制售网页 Demo](https://xiongzhiyuan-portfolio.pages.dev/zh/work/tea-garden/#play) · [按场景查看前后迭代](https://xiongzhiyuan-portfolio.pages.dev/zh/work/tea-garden/#iteration) · [截图索引](docs/SCREENSHOTS.json)

## 从这里开始

1. 阅读 `PROJECT_HANDOFF.md` 的“接手时先读这些”，明确当前五层、14 个种植位与五日成长规则。
2. 查看 `工作流.md`，理解完整指令建立上下文、精准短指令逐轮控制的方法。
3. 在 Godot 4.7.x（原工程使用 4.7.2）中导入 `assets/source/11_Godot项目/茶园物语/project.godot`，等待资源重新导入后按 F5。
4. 查询 `data/asset_catalog.json` 的实际运行路径；历史候选、生成结果与当前画面使用项分别判断。

## 仓库结构与真实路径

```text
README.md                    项目介绍与读取入口
PROJECT_HANDOFF.md           完整规范、决策、功能架构、相对素材链接
工作流.md                    AI 方法、流程图与精选迭代
assets/source/               原目录镜像，维持原名、格式和相对引用
  02_地形与植物/            地形、茶树和状态素材
  03_建筑与场景/            建筑、场景与背景层
  04_UI组件/                 UI 底板、题签和组件图像
  05_人物/                   肖像、角色及静态姿势
  06_道具与图标/            茶器、工具与状态图标
  09_生成记录/               提示词、透明检查、批次和制作记录
  11_Godot项目/茶园物语/     完整可编辑游戏工程
docs/specifications/         制作规范、素材清单和锚点参考
docs/FILE_MANIFEST.json      原文件 → 实际仓库路径、大小、SHA-256
docs/ASSET_INDEX.csv         全量可检索素材索引
docs/EXCLUDED_FILES.csv      缓存、快捷方式等排除清单
scripts/                    校验与后续素材同步工具
```

SVG、PNG、JSON 和视频保留在所属分类，未经重新压缩或改名；字体及对应引用采用公开适配版本，详见 [字体说明](assets/source/11_Godot项目/茶园物语/fonts/README.md)。为维持预览页与工程中的路径关系，完整原树保存在 `assets/source/`，`docs/specifications/` 另提供直接可读的规范入口。

### 素材分类清单

| 实际路径（assets/source/ 下） | 文件数 | MiB |
| --- | ---: | ---: |
| [00_规范与清单](assets/source/00_%E8%A7%84%E8%8C%83%E4%B8%8E%E6%B8%85%E5%8D%95/) | 49 | 2.39 |
| [01_Figma参考](assets/source/01_Figma%E5%8F%82%E8%80%83/) | 19 | 41.98 |
| [02_地形与植物](assets/source/02_%E5%9C%B0%E5%BD%A2%E4%B8%8E%E6%A4%8D%E7%89%A9/) | 16 | 18.93 |
| [03_建筑与场景](assets/source/03_%E5%BB%BA%E7%AD%91%E4%B8%8E%E5%9C%BA%E6%99%AF/) | 42 | 69.80 |
| [04_UI组件](assets/source/04_UI%E7%BB%84%E4%BB%B6/) | 54 | 39.42 |
| [05_人物](assets/source/05_%E4%BA%BA%E7%89%A9/) | 13 | 13.54 |
| [06_道具与图标](assets/source/06_%E9%81%93%E5%85%B7%E4%B8%8E%E5%9B%BE%E6%A0%87/) | 38 | 39.02 |
| [08_预览](assets/source/08_%E9%A2%84%E8%A7%88/) | 130 | 77.92 |
| [09_生成记录](assets/source/09_%E7%94%9F%E6%88%90%E8%AE%B0%E5%BD%95/) | 213 | 8.75 |
| [10_最终交付](assets/source/10_%E6%9C%80%E7%BB%88%E4%BA%A4%E4%BB%98/) | 194 | 274.95 |
| [11_Godot项目](assets/source/11_Godot%E9%A1%B9%E7%9B%AE/) | 1164 | 822.17 |
| [12_第一轮场景调整](assets/source/12_%E7%AC%AC%E4%B8%80%E8%BD%AE%E5%9C%BA%E6%99%AF%E8%B0%83%E6%95%B4/) | 42 | 49.65 |
| [13_Figma原图拆分与景深调整](assets/source/13_Figma%E5%8E%9F%E5%9B%BE%E6%8B%86%E5%88%86%E4%B8%8E%E6%99%AF%E6%B7%B1%E8%B0%83%E6%95%B4/) | 250 | 232.98 |
| [14_循环动效](assets/source/14_%E5%BE%AA%E7%8E%AF%E5%8A%A8%E6%95%88/) | 8 | 10.31 |
| [15_茶村配景与入口](assets/source/15_%E8%8C%B6%E6%9D%91%E9%85%8D%E6%99%AF%E4%B8%8E%E5%85%A5%E5%8F%A3/) | 5 | 7.41 |
| [16_茶村自由布置植物](assets/source/16_%E8%8C%B6%E6%9D%91%E8%87%AA%E7%94%B1%E5%B8%83%E7%BD%AE%E6%A4%8D%E7%89%A9/) | 7 | 7.05 |
| [17_茶树生长阶段](assets/source/17_%E8%8C%B6%E6%A0%91%E7%94%9F%E9%95%BF%E9%98%B6%E6%AE%B5/) | 5 | 6.05 |
| [18_茶田土壤区块](assets/source/18_%E8%8C%B6%E7%94%B0%E5%9C%9F%E5%A3%A4%E5%8C%BA%E5%9D%97/) | 3 | 1.67 |
| [19_云雾茶园Figma还原](assets/source/19_%E4%BA%91%E9%9B%BE%E8%8C%B6%E5%9B%ADFigma%E8%BF%98%E5%8E%9F/) | 4 | 3.13 |

其中 `07_工艺与手记/` 原目录为空，保留分类占位；工艺说明已在交接文档与工程中组织。原目录根部的 19 个 HTML 预览和旧 README／交接文档也保留在 `assets/source/`。

## 当前功能与版本

- 茶村、云雾茶园、制茶工坊和临水茶铺，以及统一库存、任务、职业、配方、订单、设置与存档。
- 当前生产茶园为五层、14 个种植位；前五日逐层开放。装饰茶树与生产种植位分别管理。
- 人物、家具、植物、背景和 UI 分层；圆形图标、悬挂题签与原生文字共同保持视觉一致。
- 现有角色资源主要为静态姿势；人物走路与拾取动画尚未完成。静态预览、Godot 原型与网页核心流程适配分别标注。

## Git LFS 与完整克隆

PNG、JPG、音视频、字体、GIF 和 ZIP 使用 Git LFS，避免把大二进制直接写入 Git 历史。134.14 MiB 的历史交付 ZIP 也使用 LFS，保留原始文件；此包是旧版快照，当前工程以交接入口为准。

```sh
git lfs install
git clone https://github.com/Zhiyuan-Xiong/tea-garden-story-assets.git
cd tea-garden-story-assets
git lfs pull
python scripts/verify_repository.py
```

公开仓库无需申请访问权限；安装 Git LFS 后即可获取完整资料。未安装 Git LFS 或跳过 LFS 下载时，部分文件会显示为文本指针，不能作为实际素材使用。

## 给另一个 Codex 会话的最简指令

> 克隆 `Zhiyuan-Xiong/tea-garden-story-assets` 并执行 `git lfs pull`。先阅读根目录 `README.md`、`PROJECT_HANDOFF.md` 与 `工作流.md`，再按 `docs/FILE_MANIFEST.json` 定位素材。Godot 工程在 `assets/source/11_Godot项目/茶园物语/project.godot`。以当前规则与资源登记为准，保留原始素材和用户存档，修改前先检查 Git 状态。

## 后续同步

```sh
git pull --ff-only
python scripts/sync_assets.py --source "本机茶园物语-制作素材的实际路径"
# 检查预览后实际复制
python scripts/sync_assets.py --source "本机茶园物语-制作素材的实际路径" --apply
python scripts/verify_repository.py
git status --short
git add README.md PROJECT_HANDOFF.md 工作流.md assets docs
git commit -m "更新茶园物语素材与设计记录"
git push
```

同步工具会持续排除旧字体并保持公开字体引用。默认预览，添加 `--apply` 才执行。它只复制新增或变更文件，不删除仓库中的历史素材，不移动或写入源目录；会更新清单，并刷新规范副本及根目录交接的相对链接。同步后按变更检查当前规则与工作流描述。

## 本次整理范围

原目录 3005 个文件中，保留 2272 个资料文件；排除 729 个缓存／快捷方式和 4 个旧字体／导入文件，另补充公开字体、字体配置和实机展示副本。未发现需要上传的密钥，未压缩或降低素材质量。清单所列素材均记录 SHA-256；2 份字体适配文件额外保留原文件校验值。公开前单独验证字体和工程启动，本次不代表重新执行全部历史游戏测试。

Noto Sans SC 遵循随附 OFL 1.1，背景音乐沿用现有署名；项目素材保留各自来源。公开展示不自动授予项目素材的再发行或商业使用权限。公开项目介绍和工作流位于[求职总仓库](https://github.com/Zhiyuan-Xiong/xiongzhiyuan-portfolio)，公开网页使用已经整理的展示资源。
