# 奶娃那咋了（原"奶蛙：遗忘档案馆"）— 项目长期笔记

## 工程基本信息
- Godot **4.6.3** + GDScript，`gl_compatibility`，1280×720 `canvas_items`，主场景 main.tscn。exe：`E:\Godot\Godot_v4.6.3-stable_win64.exe`（不在 PATH，用全路径）。
- 远程：`git@github.com:Daxcq/godot-naiva-archive.git`（**必须 SSH**，HTTPS 报 could not read Username；变了就 `git remote set-url`）。
- **⚠️ ref 被外力反复删（已到第 12 次，GitHubDesktop 嫌疑，后期实时删）**：症状 = `git rev-parse HEAD` 返回字面量 "HEAD" 或 ambiguous、push 报 `src refspec does not match any`、refs/heads/feat/ 目录消失。**抢救 = python 写回 ref 后同一进程内立即 push（间隔 <1s 必成），随后 ls-remote 终验**。ref 已删时用 `git fsck --no-reflogs --lost-found` 捞 dangling commit（取 committer date 最新的）。**本地 src ref 损坏时 `push src:dst` 会变成请求删除远端 dst——push 一律用全长 sha 作 src**。
- **⚠️ 远端 main 会被队友经 GitHubDesktop 并行推 commit**（2026-09-13 遇到：手势增强+海报两个 commit）。push 报 `behind its remote` 时**先 `git fetch` 看 `git show --stat`，然后 merge 远端再推**，别强推。对方改 main.gd/input_state.gd/vision 桥，与我们的迁移改动区域不重叠，通常干净合入。

## ⚠️ 引擎/工具坑（踩过多次）
- **`--headless --script xxx.gd` 千万别加 `--log-file`**（段错误 exit 139）。日志一律 stdout 重定向 `> log.txt 2>&1`。
- `--quit-after N` 是**帧数**不是秒：check 类需 2000~3000 帧，给少了输出全空（像崩溃其实只是没跑完）。
- `--script`（SceneTree）模式 `_process/_ready` 不自动跑，测试要显式驱动；`root.add_child` 当帧未进树 → `global_position` 全 (0,0,0)，断言用 `position` 或判 `is_inside_tree()`。
- 同一文件多个 Edit 并行 = lost update；同文件多处修改必须串行。
- `OS.execute()` 返回 int 退出码不是 Array。Windows：WMIC 已废（用 `Get-CimInstance Win32_Process`）；bash shim PATH 废（grep 等 not found），复杂操作走 python subprocess。
- 新 glb 先 `--headless --path . --import --quit-after 200` 生成 .import；`gltf/embedded_image_handling=0` 防贴图散落。高模先 Blender DECIMATE 减面（150万→2.4万面外观基本无差）。Blender：`E:\Blender 5.1\blender.exe`。
- Godot 4.6 只支持 Theora(.ogv) 视频；**ffmpeg libtheora 编 P 帧必坏，唯一出路 `-g 1`（全关键帧）**+ 16 宏块对齐 + yuv420p。ogv 运行时直接 load 无需 .import。

## 输入 / 骨架铁律
- `project.godot` [input] InputEventKey 的 `"device"` 必须保持 0（序列化出 16 → 键盘全死）。验证 check_input.gd。
- yellow_character.glb 的 Skeleton3D 名就是 `"Skeleton3D"`，13 根骨骼；main.gd 用 `_find_skeleton()` 定位，**别改回硬编码**。验证 check_walk.gd。

## 摄像头视觉（vision/）
- 端口：6400 TCP 编辑器 MCP；6401 UDP 手部 JSON；6402 UDP 摄像头 JPEG；7654 UDP GodotWithU Host。
- `vision/.vision-venv` **不可跨机器拷贝**；缺失时自动拉 `vision/setup_vision_env.py`。**仅 `py -3.12` 可用**（mediapipe 1.0.1 只支持 3.10~3.12）。固定 numpy==1.26.4/opencv-contrib-python==4.10.0.84/mediapipe==1.0.1。
- venv python.exe 是转发壳 → 一次启动 2 进程，回收 `taskkill /PID <n> /T /F`。桥写 `vision/.bridge.pid`；宿主 PID 由 Godot 经 argv[1] 传入。**5 组僵尸桥 = 预览卡顿元凶**。摄像头不打开排查：① 6401 被占=残留游戏实例；② `_start_bridge` 路径必须是 `res://vision/...`（被改坏过两次）；③ venv 在不在。

## 烘焙框架
- `scripts/visual_baker.gd` 把代码生成的 3D 物体烘成 tscn（scenes/baked/atmosphere.tscn、posters.tscn）。产物已存在再烘必须 `force=true`（否则空壳覆盖）。pack 前 `_set_owner_recursive`（跳过根）；重名子节点 `add_child(node, true)`。`archive_fx.gd` 双来源兼容（FX 或 BakedVisuals_atmosphere）。无头重烘 bake_visuals.gd。

## 交互地图 / NPC
- 改坐标必跑 check_interaction_map.gd（11 交互源 XZ 圆不重叠）。入口簇有意交叠，靠最近者仲裁+白名单。glb 正面是 +Z。
- 入口 NPC：牛来 (-3.1,0,-1.55)、袋鼠 (0.8,0,1.55)，数据驱动在 archive_entrance_npc.gd，**独立于主线 archive_npc_dialogue.gd**，别合并。

## 队友内容已迁入（2026-09-13，commit 31828d40）
- 动画版模型 yellow_character_animated.glb（AnimationPlayer 6 动作，main.gd 优先用它，无则回退程序化摆骨）；科幻贴图地板/墙 + props FBX；搞笑道具 funny_props.tscn（华强买瓜四段式）；梗问答 quiz（archive_interaction.gd，三记忆小玩法成功后 `_begin_quiz()`，答对才 solve；covered_2024 需在 pause 窗口内按 E 才进 quiz）；走廊显示屏 archive_video_screen.gd（ogv，播放冻结移动）；真图轮播相框 archive_photo_frames.gd。

## 其他
- 展板 UI layer=95（默认 1 压在 dim 上）；UI y=716+ 被屏底裁。影院 cinema_room.gd 完整播放不截短。
- GodotWithU + godot_mcp 已启用；改插件 .gd 必须完全重启所有编辑器实例。
- 开屏标题（title_card.gd）：5 字两段式（"奶娃"+"那咋了"），中央奶滴对齐"娃|那"缝。
