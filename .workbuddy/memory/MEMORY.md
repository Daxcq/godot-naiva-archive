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
- **7654 UDP(ENet)** — `godot_with_u` 编辑器协作插件 Host 默认端口（仅 Host 模式监听，Join 是客户端）。
- 桥接进程由 `visual_recognition.gd` **自动拉起**（`OS.create_process`，解释器优先 `vision/.vision-venv/Scripts/python.exe`），退出时 `taskkill /T /F` 回收，`_process` 里有 6s 冷却的自动重启。缺失时自动回落鼠标模式。
- **⚠️ 摄像头"不打开"排查顺序（2026-09-12 第二次踩坑后总结）**：① 先查 `netstat -ano -p udp | findstr 640`——6401 被占 = 有残留游戏实例（**编辑器里 F5 跑完游戏忘关**最常见），报错"端口 6401 不可用"就是这个，`taskkill /PID <游戏PID> /T /F` 清掉；② 再查 `visual_recognition.gd` 的 `_start_bridge` 路径是否仍是工程内 `res://vision/...`——它已被并行会话两次回退成工程外 `res://../...` 错路径（第二次连带删了自动安装器/自动重启/退出回收/`_dismiss_title`/落地 NPC 激活，靠 checkout HEAD 恢复）；③ venv 本身是否在（见上节）。真窗口验证套路：Popen 启动 `--log-file <tmp>`，每 5s 轮询 6401/6402 应 5 秒内出现，terminate 后 6s 端口应释放；Windows GUI 模式 stdout 抓不到 print，**验证看端口和进程，别指望日志**；netstat/tasklist 输出 GBK 解码。

## GodotWithU 协作插件（2026-09-12 安装）
- 来源：桌面 `addons/godot_with_u`（作者 Airysh v0.5.1），已拷入项目 `addons/` 并在 `project.godot` `[editor_plugins]` 启用（与 godot_mcp 并列）。
- **功能**：编辑器多人实时协作——场景节点增删/属性/选择同步、脚本 CRDT 文本同步、幽灵光标、资源锁；新加入者自动收到 host 的场景初始状态。
- **用法**：右侧上栏 Dock「🌐 GodotWithU」→ 一台点 Host（默认端口 7654），另一台填 IP 点 Join。本机双开填 127.0.0.1；局域网填主机内网 IPv4；**代码里只有 ENet 直连，没有 BitChat P2P 实现**（注释里是规划），跨机协作需同一局域网或端口转发。
- **我改过三处**（原版刷屏）：`_on_action_captured` 未连接直接 return；删掉 SEND/RECV/APPLYING 逐包 print。**改任何插件 .gd 后必须完全重启所有编辑器实例**（.godot 脚本缓存会留旧代码——插件头注释原话）。

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
- **牛来**：`(-3.1,0,-1.55)` yaw 0.88 + 暖黄 tint `Color(1.0,0.82,0.32)`（原米白偏灰），niu_lai.glb 3.8MB/2.4万面，末句留白"……牛来。"。2026-08 爆火动画《牛来》主角（母子手搓五年、9 天票房 7169 元、谐音"牛市来"、绊倒体=半导体、官号排队玩"X来"）。立意：靠被围观被记住，却没被真正看见。原位 (-1.6,-1.25) 正压走廊中轴，玩家落地视线锥总被挡，2026-09-12 挪西北墙角。
- **美团袋鼠**：`(0.8,0,1.55)` yaw -1.85（原 PI+0.47 面朝东北背对玩家），meituan_kangaroo.glb 2.3MB/2.4万面，末句"你胆子真是肥嘟嘟的"。梗：捡手机文学"胆子肥嘟嘟" + 网友把原本修长的袋鼠**画胖三圈**才火、官方嘴硬"我们袋鼠本来就不胖"。立意：大家爱的是画出来的假它。台词第 3 句与牛来互文。
- **⚠️ 两个 glb 正面都是 +Z**（实测：yaw=1.1 时两者都面朝东北/东南侧，名牌正对即朝向正）：Godot 中 yaw θ 时 +Z 指向 (sinθ, 0, cosθ)。配朝向先假设 +Z，截图看名牌是否镜像即可判断正反。
- 两人间隔 3.47m > TALK_RANGE 2.4（从 3.0 收窄过，触发圈交叠靠最近者 + InteractionRouter 仲裁兜底）。传送门落点 `(-4.5,4.0,0)`，走廊可走 `x∈[-5,37] z∈[-1.9,1.9]`。

## 奶娃展板「幸福碎片」（2026-09-12 交付）
- `archive_display_board.gd`：南墙 x=11.4 z=1.95 立式视频展板，走近 E 揭开全屏板 → A/D 六格 → E 播放 → ESC 合板；与画廊画架共用 `world.board_active` 冻结通道互斥。自检 `check_display_board.gd` 29 项。
- 六块碎片 ogv 在 `assets/video/`（星月夜/夜路/天台摇摆/认真跳/夜街/变强，各 8-10s）。ffmpeg 转 Theora。**ogv 运行时 loader 直接 load，无需 .import**。Godot 4.6 原生只支持 Theora(.ogv)。
- **⚠️ ffmpeg 8.1 (Gyan full build) 的 libtheora 编 P 帧必坏**：`-g` 默认/30/force_key_frames 全产出 `error in unpack_block_qpis / unpack_dct_coeffs` 损坏流（Godot 播放花屏大色块，ffmpeg 自己解码也报错，rc=69）。**唯一干净出路 `-g 1`（每帧关键帧 intra 直出）**，q 模式/码率模式/有无音频都无关。体积约 1.5MB/s@640x352 q7。**验证 ogv 是否完好：`ffmpeg -v error -i x.ogv -f null -` 看 decode rc 和报错行数**。
- Theora 兼容参数：`scale=640:-2,crop=iw:trunc(ih/16)*16`（16 宏块对齐，Godot theora 解码器对非对齐尺寸不可靠）+ `-r 30 -pix_fmt yuv420p -ar 44100 -ac 2`。
- **全屏板 UI 层用 layer=95**（Interface/VisionPreview 是默认 layer=1 但实证压在 layer=20 的 dim 上，提 95 后被盖住）。UI 布局铁律（1280x720）：chips 单行 6 格 x=52+i*200 y=640、stage 880x450@134、caption y=596——两行布局 y=716/782 会被屏底裁掉。
- **⚠️ 同一文件多个 Edit 并行 = lost update 竞态**：4 个 Edit 并行同文件，互相覆盖只剩最后写盘的 1 个（截图渲染旧布局才暴露）。同文件多处修改必须逐个串行 Edit。

## 视觉风格
霓虹赛博朋克，程序化几何搭建。青/品红霓虹对比 + 故障屏幕补光 + 霓虹橙出口光；`Environment` 开了 glow（intensity 1.1 / strength 1.08）+ 高度雾。角色走卡通风格 `yellow_character.glb`（骨架节点名见上方"骨架节点名铁律"，**不是** `MilkFrog_Skeleton`）。

## 交互地图与不重叠设计（2026-09-12 定稿）
- **11 个交互源**（XZ 圆圈，不重叠判定 = 圆心距 ≥ r1+r2；常驻断言 check_interaction_map.gd，改坐标必跑）：
  记忆点x3 (-1/11.4/23.8, -2.5) r3.2硬编码｜街机x3 (5.2/17.6/30, -2.05) r2.4｜keeper (-1,-0.65) r2.5硬编码且仅1组｜牛来 (-3.1,-1.55) 袋鼠 (0.8,1.55) r2.4=TALK_RANGE｜展板 (33,1.95) r2.4｜画廊画架 (7.9,1.55) r1.8 yaw PI 面北｜出口结算线 x≥35.6。
- **入口簇四圈有意交叠**（牛来/袋鼠/keeper/记忆点1，最近者仲裁白名单豁免）；**南墙 x∈[3,30] 是唯一开阔带**，新增交互点先跑普查再落位。
- 画架几何在 scenes/gallery_easel.tscn（并行会话场景化），摆放 transform 在 archive_space.tscn 实例（yaw PI basis = (-1,0,0, 0,1,0, 0,0,-1)）；**tscn 不支持注释**，选址理由写在 gallery_easel.gd 头部。
- 离线截图三坑：set_active(false) 藏节点（强制 visible=true）；冻结用 PROCESS_MODE_DISABLED；DisplayBoard(extends Node) 视觉根是内部同名子节点。
