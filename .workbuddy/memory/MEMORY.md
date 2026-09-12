# 奶蛙：遗忘档案馆 — 项目长期笔记

## 工程基本信息
- Godot **4.6** + GDScript，`renderer/rendering_method="gl_compatibility"`（兼容模式，非 Vulkan）。
- 分辨率 1280×720，`stretch/mode="canvas_items"`，主场景 `res://main.tscn`，项目名"奶蛙：遗忘档案馆"。
- Godot 可执行文件：`E:\Godot\Godot_v4.6.3-stable_win64.exe`（不在 PATH 里，要用全路径）。
- git remote：`https://github.com/Daxcq/godot-naiva-archive.git`。

## 目录约定
| 路径 | 内容 |
|---|---|
| `scenes/` | 6 个场景：main / archive_space / intro_space / player / time_tunnel / interface |
| `scripts/` | 54 个 .gd，按玩法分文件（archive_* / arcade_* / check_* / meme_room_* 等） |
| `assets/audio` | wav 音效 + 角色语音（voice_andy/child/gaga/mother） |
| `assets/character` | `yellow_character.glb` + preview.png |
| `addons/godot_mcp/` | 编辑器 MCP 插件（见下） |
| `scripts/check_*.gd` | 断言式自检脚本，可 `--script res://scripts/check_archive.gd` 无头跑 |

## 运行时端口约定（重要，别搞混）
- **6400 TCP** — 编辑器 MCP 插件，**只在 Godot 编辑器进程内监听**，游戏运行时不用。
- **6401 UDP** — `visual_recognition.gd` 收 MediaPipe/OpenCV 手部状态 JSON。
- **6402 UDP** — `vision_preview.gd` 收摄像头 JPEG 帧。
- 桥接脚本引用 `res://../scripts/mediapipe_camera_bridge.py` 与 `res://../.vision-venv/Scripts/python.exe`，都在**工程目录之外**（同级父目录），所以仓库里没有 py 文件；缺失时自动回落鼠标模式。

## MCP 接入（2026-09-12 完成）
- `project.godot` 必须有 `[editor_plugins] enabled=PackedStringArray("res://addons/godot_mcp/plugin.cfg")` —— 原仓库漏了这行，插件从未生效过。
- `addons/godot_mcp/mcp_server.py`：自建的标准 MCP stdio 桥接（纯标准库，系统 python 3.8 可跑），24 个 `godot_*` 工具。
- WorkBuddy 配置在 `~/.workbuddy/mcp.json` 的 `godotMCP`。
- **使用前提：Godot 编辑器打开本工程且插件启用中**，否则工具返回中文错误提示。

## 视觉风格
霓虹赛博朋克，程序化几何搭建。青/品红霓虹对比 + 故障屏幕补光 + 霓虹橙出口光；`Environment` 开了 glow（intensity 1.1 / strength 1.08）+ 高度雾。角色走卡通风格 `yellow_character.glb`（骨骼节点名 `MilkFrog_Skeleton`，回落 `Armature`）。
