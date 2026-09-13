# 奶娃那咋了（原"奶蛙：遗忘档案馆"）— 项目长期笔记

## 工程基本信息
- Godot **4.6.3** + GDScript，`gl_compatibility`，1280×720 `canvas_items`，主场景 main.tscn。exe：`E:\Godot\Godot_v4.6.3-stable_win64.exe`（不在 PATH，用全路径）。
- 远程：`git@github.com:Daxcq/godot-naiva-archive.git`（**必须 SSH**，HTTPS 会报 could not read Username；变了就 `git remote set-url`）。
- **⚠️ ref 被外力反复删（GitHubDesktop 嫌疑）**：`git rev-parse HEAD` 返回字面量 "HEAD" = ref 丢失。抢救：已知短 sha `git rev-parse <短sha>^{commit}` 取**全长 sha** 写回 `.git/refs/heads/<branch>`（绝不写字面量"HEAD"），随后立即 push + ls-remote 终验。**本地 src ref 损坏时 `push src:dst` 会变成请求删除远端 dst**。commit 后必须马上 push。
- Blender：`E:\Blender 5.1\blender.exe`（`--background --factory-startup --python`；渲染枚举 `BLENDER_EEVEE`）。

## ⚠️ 引擎/工具坑（踩过多次）
- **`--headless --script xxx.gd` 千万别加 `--log-file`**：组合即段错误（exit 139，log 不创建）。回归日志一律 stdout 重定向 `> log.txt 2>&1`。
- `--quit-after N` 是**帧数**不是秒：check_opening/check_archive/check_minigames 需 2000~3000 帧，给少了输出全空（像崩溃其实只是没跑完）。
- `--script`（SceneTree）模式下 `_process/_ready` 不自动跑，测试要显式驱动；`root.add_child` 当帧未进树 → `global_position` 全是 (0,0,0)，断言用 `position` 或判 `is_inside_tree()`。
- **同一文件多个 Edit 并行 = lost update**，只剩最后写盘那个；同文件多处修改必须串行 Edit。
- `OS.execute()` 返回 int 退出码，不是 Array（写成 `if probe is Array` 直接 Parse Error）。
- Windows：WMIC 已废（用 PowerShell `Get-CimInstance Win32_Process`）；bash shim PATH 废（ls/grep 等 not found），复杂操作走 python subprocess；GUI exe stdout 抓不到 print——验证看端口/进程。
- 新 glb 先 `--headless --path . --import --quit-after 200` 生成 .import；`gltf/embedded_image_handling=0` 防贴图解包散落 assets/。高模先 Blender DECIMATE 减面（150万→2.4万面外观基本无差）。
- Godot 4.6 只支持 Theora(.ogv) 视频；**ffmpeg libtheora 编 P 帧必坏，唯一出路 `-g 1`（全关键帧）**；16 宏块对齐 `scale=W:-2,crop=iw:trunc(ih/16)*16` + `-r 30 -pix_fmt yuv420p`。验证完好：`ffmpeg -v error -i x.ogv -f null -`。ogv 运行时直接 load，无需 .import。

## 输入映射铁律
- `project.godot` [input] 里 InputEventKey 的 `"device"` 必须保持 0；编辑器序列化出 16 → 键盘全死。验证：`--headless --script res://scripts/check_input.gd`（devices 必须全 0）。编辑器重序列化会删中文注释（正常，补回即可）。

## 骨架节点名铁律
- yellow_character.glb 的 Skeleton3D 名就是 `"Skeleton3D"`（父级 `MilkFrog_Rig`）。路径 `MilkFrog/CharacterVisual/YellowCharacter/Reference character/MilkFrog_Rig/Skeleton3D`，13 根骨骼。main.gd 用 `_find_skeleton()`（已知名优先+递归兜底）定位，**别改回硬编码**。验证 check_walk.gd。

## 摄像头视觉（vision/）
- 端口：**6400 TCP** 编辑器 MCP（仅编辑器进程）；**6401 UDP** 手部 JSON；**6402 UDP** 摄像头 JPEG；**7654 UDP** GodotWithU Host。
- `vision/.vision-venv` **不可跨机器拷贝**（pyvenv.cfg 写死创建机路径）；缺失时 `visual_recognition.gd` 自动拉 `vision/setup_vision_env.py` 安装。**仅 `py -3.12` 可用**（mediapipe 1.0.1 只支持 3.10~3.12；本机 python 3.14/py 默认 3.14 都不行）。固定版本：numpy==1.26.4 / opencv-contrib-python==4.10.0.84 / mediapipe==1.0.1，全新装约 5 分钟。
- venv 的 python.exe 是转发壳 → 一次启动 2 进程，回收必须 `taskkill /PID <n> /T /F`。桥写 `vision/.bridge.pid`，`_start_bridge()` 前调 `_kill_stale_bridges()`；宿主 PID 由 Godot 经 argv[1] 传入（os.getppid 拿到的是壳）。**5 组僵尸桥并存 = 预览卡顿元凶**。
- 摄像头"不打开"排查顺序：① netstat 查 6401 被占 = 残留游戏实例（编辑器 F5 忘关最常见，taskkill 清）；② `_start_bridge` 路径必须是工程内 `res://vision/...`（曾被并行会话两次改坏成 `res://../...`，连带删功能，checkout HEAD 恢复）；③ venv 在不在。
- 清晰度方案（已恢复）：640×480 + `CAP_PROP_BUFFERSIZE=1` + JPEG q75（防卡顿靠缓冲+纹理复用+清僵尸桥，**别降分辨率**）。

## 烘焙框架（2026-09-13）
- `scripts/visual_baker.gd`（class VisualBaker）：把代码生成的 3D 物体烘成 tscn 挂进场景，编辑器可直接编辑。产物 `scenes/baked/atmosphere.tscn`、`posters.tscn`（ArchiveArchitecture 下 BakedVisuals_*）。生成器 `build_fx/setup(root, force:=false)` 两级兜底：try_mount 命中烘焙实例优先，否则代码生成；**产物已存在时再烘必须 force=true，否则烘出空壳覆盖原产物**。
- pack 前 `_set_owner_recursive` 补 owner（跳过根自身，否则 `p_owner == this` 报错）；重名子节点用 `parent.add_child(node, true)` 强制可读名（否则变 `@MeshInstance3D@N`，按名收集会漏）。
- `archive_fx.gd` 双来源兼容（`FX` 或 `BakedVisuals_atmosphere`）。无头重烘：`--headless --script res://scripts/bake_visuals.gd`；编辑器内 Ctrl+Shift+X（editor_bake_visuals.gd）。

## 交互地图（改坐标必跑 check_interaction_map.gd）
- 11 个交互源 XZ 圆不重叠判定；入口簇（牛来/袋鼠/keeper/记忆点1）有意交叠，靠最近者仲裁 + 白名单豁免；南墙 x∈[3,30] 是唯一开阔带。glb 正面是 +Z（yaw θ 时 +Z 指 (sinθ,0,cosθ)）。
- 入口 NPC：牛来 (-3.1,0,-1.55)、美团袋鼠 (0.8,0,1.55)，数据驱动在 `archive_entrance_npc.gd` 的 NPCS 表，**独立于主线 archive_npc_dialogue.gd**，别合并。

## 展板 / 影院
- 全屏板 UI 用 layer=95（默认 layer=1 会压在 layer=20 dim 上）；1280×720 UI 两行布局 y=716+ 会被屏底裁掉。
- 影院 `cinema_room.gd`：FEATURE = `res://assets/video/cinema_feature.ogv`（14.3MB，用户桌面《影院视频.mp4》转的），finished 循环重播，完整播放不截短。

## 插件 / 其他
- GodotWithU 协作插件 + godot_mcp 在 project.godot [editor_plugins] 启用；godot_mcp 需编辑器开着且插件启用才有效（WorkBuddy `~/.workbuddy/mcp.json` godotMCP）。改插件 .gd 必须完全重启所有编辑器实例（.godot 脚本缓存留旧代码）。
- 视觉风格：霓虹赛博朋克，青/品红对比 + glow(1.1/1.08) + 高度雾，卡通角色 yellow_character.glb。
- 开屏标题（title_card.gd）：5 字"奶娃那咋了"，通用两段式排版（"奶娃"+"那咋了"，PAIR_GAP 64 断句缝，IN_GAP 24 组内距），中央奶滴 drop_x 对齐"娃|那"缝。
