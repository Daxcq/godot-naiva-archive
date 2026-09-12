# 奶蛙：遗忘档案馆 — 项目长期笔记

## 工程基本信息
- Godot **4.6** + GDScript，`renderer/rendering_method="gl_compatibility"`（兼容模式，非 Vulkan）。
- 分辨率 1280×720，`stretch/mode="canvas_items"`，主场景 `res://main.tscn`，项目名"奶蛙：遗忘档案馆"。
- Godot 可执行文件：`E:\Godot\Godot_v4.6.3-stable_win64.exe`（不在 PATH 里，要用全路径）。
- git remote：origin 已由 HTTPS 改为 SSH **`git@github.com:Daxcq/godot-naiva-archive.git`**。
  - **推送必须走 SSH**：终端禁交互，HTTPS 会报 `fatal: could not read Username for 'https://github.com'`。若发现又变回 HTTPS，`git remote set-url origin git@github.com:Daxcq/godot-naiva-archive.git` 即可。

## 目录约定
| 路径 | 内容 |
|---|---|
| `scenes/` | 6 个场景：main / archive_space / intro_space / player / time_tunnel / interface |
| `scripts/` | 54 个 .gd，按玩法分文件（archive_* / arcade_* / check_* / meme_room_* 等） |
| `assets/audio` | wav 音效 + 角色语音（voice_andy/child/gaga/mother） |
| `assets/character` | `yellow_character.glb`（奶蛙） + `niu_lai.glb`（入口牛 NPC） + preview.png |
| `vision/` | 摄像头视觉依赖自包含目录：`mediapipe_camera_bridge.py` / `godot_camera_bridge.py` / `hand_landmarker.task` / `setup_vision_env.py`(自动装环境) / `.vision-venv/`(gitignore，换机器需重建) |
| `addons/godot_mcp/` | 编辑器 MCP 插件（见下） |
| `scripts/check_*.gd` | 断言式自检脚本，可 `--script res://scripts/check_archive.gd` 无头跑 |

## ⚠️ 输入映射铁律（踩过大坑）
- `project.godot` 的 `[input]` 里 **`InputEventKey` 的 `"device"` 必须保持 0（缺省 / 任意设备）**。编辑器有时会序列化出 `"device":16`，而真机键盘发的是 `device=0` → 键盘输入全死（表现为"角色不能动"）。
- **Godot 编辑器只要一碰输入设置，就会把整个 `[input]` 段重新序列化成完整 `InputEventKey`（带上 `"device":0` 和一大堆默认字段），并顺手删掉我留的中文注释。** 这是正常的、无害的（`device:0` 就是任意设备），但**注释会消失** —— 发现注释没了就补回去，别以为是被人改坏了。
- 验证脚本：`--headless --script res://scripts/check_input.gd`（会打印每个动作的 `devices=[...]`，必须全是 0）。

## ⚠️ Python venv 不可移植（换电脑摄像头打不开的根因）
- `vision/.vision-venv` **不能跨机器拷贝**：`pyvenv.cfg` 里写死创建机的 `executable`（绑用户名 + Python 安装路径）和 `command`（还绑着创建时的项目路径）。换机器后全部落空 → `_resolve_bridge()` 返回空 → 静默回落鼠标模式。
- 解决方案是**自动安装器**：`vision/setup_vision_env.py`，由 `visual_recognition.gd` 在依赖缺失时自动拉起（最多重试 2 次，进程退出后自动重试启动桥接）。手动跑也可以：`py -3.12 vision/setup_vision_env.py`。
- **mediapipe 1.0.1 只支持 Python 3.10~3.12**。本机 `python` 是 3.14.3、`py` 默认 3.14.2，**都不可用**，只有 `py -3.12` 行。
- 固定依赖版本：`numpy==1.26.4 / opencv-contrib-python==4.10.0.84 / mediapipe==1.0.1`。全新装一次约 **5 分钟**（首次需联网 PyPI）。
- Windows venv 的 `python.exe` 是**转发壳**，会再拉一个 `Python312\python.exe` 子进程 → **一次启动 = 2 个进程**。回收必须 `taskkill /PID <n> /T /F`（`/T` 递归整棵树），否则摄像头被残留进程长期占用。
- `visual_recognition.gd` 用 `_notification()` 处理 `NOTIFICATION_WM_CLOSE_REQUEST` / `NOTIFICATION_PREDELETE` 做回收 —— **只靠 `_exit_tree()` 太晚**，那时进程已在销毁，阻塞式 taskkill 跑不完（实测残留 2 个进程）。
- 桥接侧还会每 60 tick 自查宿主存活（Win32 `OpenProcess(0x1000)` + `GetExitCodeProcess`，STILL_ACTIVE=259），Godot 没了就自杀。
- **`OS.execute()` 返回的是 int 退出码，不是 Array**。写成 `if probe is Array` 会直接 `Parse Error` 让整个脚本加载失败。

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
- **`--quit-after N` 是帧数不是秒，而且经常给少了**：`check_opening` / `check_archive` / `check_minigames` 需要 **2000~3000 帧**；给 900 会跑不完、**输出全空**（看着像崩溃，其实只是没跑完）。踩过两次。
- **`root.add_child(world)` 之后当帧节点还没进树**，`is_inside_tree() == false` → 所有 `global_position` 退化成原点 (0,0,0)。依赖世界坐标的断言会**假成功或假失败**。写法：`if a.is_inside_tree() and b.is_inside_tree(): 用 global_position else: 用 position`。
- 状态机阶段名要跟代码对齐（开屏真实阶段是 `idle` 不是 `sleep`，写错会静默不推进 → 假失败）。
- 结尾的 `ObjectDB instances leaked` / `resources still in use` 是 SceneTree 脚本没 free 场景导致的，属正常噪音。
- Windows 下 WMIC 已废弃（`[WinError 2]`），进程枚举/清理改用 PowerShell `Get-CimInstance Win32_Process`。
- 老项目 `Desktop/shijueshibie-jikesong-S2` 与新项目 **27 个 .gd + 6 个 .tscn 逐字节相同** —— 遇到"功能没了"先怀疑配置/打包，别先怀疑代码丢了。

## Blender / 外部模型导入（3D 素材处理）
- Blender 在 **`E:\Blender 5.1\blender.exe`**（不在 PATH；从桌面 `Blender 5.1.lnk` 里能提出路径）。无头用法：`--background --factory-startup --python script.py`。渲染引擎枚举是 `BLENDER_EEVEE`（**不是** `BLENDER_EEVEE_NEXT`，5.1 里已改回旧名）。
- **别硬啃 FBX 二进制**：手写 python 捞 `Model::` 之类字符串会被长度前缀和 IDAT 压缩数据淹掉，全是噪声。直接让 Blender 解析。
- **高模进 Godot 前必须减面**。做法：`DECIMATE`(COLLAPSE, ratio = 目标面数/现有面数) + `image.scale(1024,1024)` + `im.pack()`，导出 GLB 用 `export_yup=True`。实测 150 万面 → 2.4 万面、123MB → 3.8MB，外观基本无差别。
- 减面后**重新渲染一张图对比**确认没崩（别只看数字）。
- **`gltf/embedded_image_handling` 必须设 0**：默认 1 会把 glb 内嵌贴图**解包成一堆 PNG 散落到同目录**，污染 `assets/`。
- 新放进项目的 glb **要先 `--headless --path . --import --quit-after 200`** 生成 `.import`，否则运行时报 `No loader found for resource`。
- 改 `.import` 参数后要删掉已解包的 png 再重导；中间的 `Unrecognized UID` 报错是缓存残留，会自愈。

## 入口梗角色 NPC：牛来 + 美团袋鼠（2026-09-12）
- `archive_entrance_npc.gd` = **NPCS 配置表双 NPC 数据驱动**（只建一份脚本，台词/模型/站位全在表里）。**独立于 `archive_npc_dialogue.gd`**：档案员开传送门推进主线，入口两位只陪聊，别合并。自检 `check_entrance_npc.gd`（57 项断言，双 NPC 全覆盖）。
- **牛来**：`(-1.6,0,-1.25)` yaw 0.95，niu_lai.glb 3.8MB/2.4万面，末句留白"……牛来。"。2026-08 爆火动画《牛来》主角（母子手搓五年、9 天票房 7169 元、谐音"牛市来"、绊倒体=半导体、官号排队玩"X来"）。立意：靠被围观被记住，却没被真正看见。
- **美团袋鼠**：`(0.8,0,1.25)` yaw PI+0.47，meituan_kangaroo.glb 2.3MB/2.4万面，末句"你胆子真是肥嘟嘟的"。梗：捡手机文学"胆子肥嘟嘟" + 网友把原本修长的袋鼠**画胖三圈**才火、官方嘴硬"我们袋鼠本来就不胖"。立意：大家爱的是画出来的假它。台词第 3 句与牛来互文。
- 两人间隔 3.47m > TALK_RANGE 2.4（从 3.0 收窄过，触发圈交叠靠最近者 + InteractionRouter 仲裁兜底）。传送门落点 `(-4.5,4.0,0)`，走廊可走 `x∈[-5,37] z∈[-1.9,1.9]`。

## 视觉风格
霓虹赛博朋克，程序化几何搭建。青/品红霓虹对比 + 故障屏幕补光 + 霓虹橙出口光；`Environment` 开了 glow（intensity 1.1 / strength 1.08）+ 高度雾。角色走卡通风格 `yellow_character.glb`（骨架节点名见上方"骨架节点名铁律"，**不是** `MilkFrog_Skeleton`）。
