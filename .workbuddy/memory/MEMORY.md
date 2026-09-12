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
| `vision/` | 摄像头视觉依赖自包含目录：`mediapipe_camera_bridge.py` / `godot_camera_bridge.py` / `hand_landmarker.task` / `.vision-venv/`(gitignore) |
| `addons/godot_mcp/` | 编辑器 MCP 插件（见下） |
| `scripts/check_*.gd` | 断言式自检脚本，可 `--script res://scripts/check_archive.gd` 无头跑 |

## ⚠️ 输入映射铁律（踩过大坑）
- `project.godot` 的 `[input]` 里 **`InputEventKey` 绝对不能带 `"device"` 字段**。编辑器有时会序列化出 `"device":16`，而真机键盘发的是 `device=0` → 键盘输入全死（表现为"角色不能动"）。
- 只写最小形式：`Object(InputEventKey,"physical_keycode":69)`。
- 验证脚本：`--headless --script res://scripts/check_input.gd`。

## ⚠️ 骨架节点名铁律（走路效果踩的坑）
- `yellow_character.glb` 导入后，**`Skeleton3D` 的节点名就是 `"Skeleton3D"`**（不是 `MilkFrog_Skeleton`，也不是 `Armature`）。父级是 `Node3D` 叫 `MilkFrog_Rig`。
- 完整节点路径：`MilkFrog/CharacterVisual/YellowCharacter/Reference character/MilkFrog_Rig/Skeleton3D`
- 共 **13 根骨骼**：`root, L_thigh, L_shin, L_foot, R_thigh, R_shin, R_foot, spine, head, L_arm, L_hand, R_arm, R_hand`
- `main.gd` 用 `_find_skeleton()` 定位（已知名优先 + 递归兜底），**不要改回硬编码单个名字**——猜错就会 `if skeleton == null: return` 静默吞掉整个骨骼动画。
- 验证脚本：`--headless --script res://scripts/check_walk.gd`（查骨骼命中 + 4 根骨骼实际摆幅）。

## 运行时端口约定（重要，别搞混）
- **6400 TCP** — 编辑器 MCP 插件，**只在 Godot 编辑器进程内监听**，游戏运行时不用。
- **6401 UDP** — `visual_recognition.gd` 收 MediaPipe/OpenCV 手部状态 JSON。
- **6402 UDP** — `vision_preview.gd` 收摄像头 JPEG 帧。
- 桥接进程由 `visual_recognition.gd` **自动拉起**（`OS.create_process`，解释器优先 `vision/.vision-venv/Scripts/python.exe`），退出时 `taskkill /T /F` 回收，`_process` 里有 6s 冷却的自动重启。缺失时自动回落鼠标模式。

## MCP 接入（2026-09-12 完成）
- `project.godot` 必须有 `[editor_plugins] enabled=PackedStringArray("res://addons/godot_mcp/plugin.cfg")` —— 原仓库漏了这行，插件从未生效过。
- `addons/godot_mcp/mcp_server.py`：自建的标准 MCP stdio 桥接（纯标准库，系统 python 3.8 可跑），24 个 `godot_*` 工具。
- WorkBuddy 配置在 `~/.workbuddy/mcp.json` 的 `godotMCP`。
- **使用前提：Godot 编辑器打开本工程且插件启用中**，否则工具返回中文错误提示。

## 无头自检的坑（写 check_*.gd 前必读）
- `--script`（SceneTree）模式下**节点 `_process` / `_ready()` 都不会自动跑**，测试里要显式驱动（`node._process(dt)`、手动调 `_ready()`；后者可能触发重复连接告警，属噪音）。
- `--quit-after N` 是**帧数不是秒**。
- 状态机阶段名要跟代码对齐（开屏真实阶段是 `idle` 不是 `sleep`，写错会静默不推进 → 假失败）。
- 结尾的 `ObjectDB instances leaked` / `resources still in use` 是 SceneTree 脚本没 free 场景导致的，属正常噪音。
- Windows 下 WMIC 已废弃（`[WinError 2]`），进程枚举/清理改用 PowerShell `Get-CimInstance Win32_Process`。
- 老项目 `Desktop/shijueshibie-jikesong-S2` 与新项目 **27 个 .gd + 6 个 .tscn 逐字节相同** —— 遇到"功能没了"先怀疑配置/打包，别先怀疑代码丢了。

## 视觉风格
霓虹赛博朋克，程序化几何搭建。青/品红霓虹对比 + 故障屏幕补光 + 霓虹橙出口光；`Environment` 开了 glow（intensity 1.1 / strength 1.08）+ 高度雾。角色走卡通风格 `yellow_character.glb`（骨架节点名见上方"骨架节点名铁律"，**不是** `MilkFrog_Skeleton`）。
