# 奶娃那咋了

《奶娃那咋了》——Godot 4 场景原型。使用程序化几何搭建霓虹赛博朋克风格的网络梗记忆档案馆，通过横向电影镜头、巨大工业设施、前景遮挡和青/品红霓虹光对比形成电子夜色氛围。

运行：用 Godot 打开本目录的 `project.godot`，按 F6/F5；或执行：

```powershell
godot --path .
```

操作：A/D 左右移动，W/S 向场景深处/近处移动，也支持方向键；空格跳跃。斜向移动不会加速，前后活动限制在柜前通道内。

场景光照：四盏带阴影的品红/青霓虹吊灯、故障屏幕青色补光、霓虹橙出口光及主角弱补光。三个档案柜（2016 / 2020 / 2024）包含年代标牌、索引卡、发光把手、磨损材质和散落档案，每柜前有一名档案员 NPC，对话结束后打开记忆传送门，分别通往霓虹夜市、深夜街镇和数据公园三个记忆场景。柜位之间的空白走廊摆有三台可玩街机（贪吃蛇 / 俄罗斯方块 / 打砖块，靠近按 E 进入、ESC 退出）和整墙霓虹海报。细节集中在 `scripts/archive_details.gd`、`scripts/archive_arcade.gd` 与 `scripts/archive_posters.gd`。

渲染检查：Godot 加 `--script res://scripts/check_archive.gd -- --capture` 可输出走廊各点位与三个记忆房间的截图到 Godot 用户数据目录；`--script res://scripts/check_minigames.gd` 无头验证三个街机小游戏逻辑。

## 视觉识别接入

项目已接入 `scripts/visual_recognition.gd`。它在 `127.0.0.1:6401` 监听 UDP JSON，接收 MediaPipe/OpenCV 等识别进程输出的标准化手部状态：

```json
{"x":0.5,"y":0.5,"grab":0.0,"spread":0.8,"confidence":0.95}
```

`x/y` 为 0—1 的画面坐标，`grab` 和 `spread` 为 0—1，`confidence` 低于 0.2 的帧会被丢弃。收到有效帧时，角色移动由手掌位置驱动；识别进程断开超过 0.35 秒后自动切回鼠标模式。

注意：Godot 4.6 Windows 桌面版的 `CameraServer` 仅支持平台/AR camera feed，不会直接枚举普通 USB webcam（例如 ASUS FHD webcam）。因此真实用户画面由工程内的独立 OpenCV/MediaPipe 采集进程读取摄像头，再把识别状态与画面通过 UDP 送回引擎；UDP 识别状态接口也可直接使用。

### 摄像头自动启动（换电脑无需手动配置）

游戏启动时会**自动拉起**摄像头桥接进程，退出时自动回收，不需要另外开终端跑脚本。

桥接实现在 `vision/` 下，随仓库一起迁移：

| 文件 | 作用 |
|---|---|
| `vision/mediapipe_camera_bridge.py` | 主桥接：OpenCV 读摄像头 + MediaPipe 手部识别，状态发 UDP 6401、画面发 UDP 6402 |
| `vision/godot_camera_bridge.py` | 备用桥接：仅转发摄像头画面，不跑手部识别 |
| `vision/hand_landmarker.task` | MediaPipe 手部模型（7.8MB，随仓库携带） |
| `vision/setup_vision_env.py` | 依赖自动安装器 |

**换电脑后第一次运行**：`vision/.vision-venv` 不入库（虚拟环境里的路径绑死创建它的那台机器，复制过去也无法使用）。游戏检测到依赖缺失时会**自动在后台运行 `setup_vision_env.py`**，重新建虚拟环境并安装依赖（首次约需几分钟，需要能访问 PyPI）。装好后桥接会自动启动，无需重启游戏。

界面右下角的预览面板会显示当前状态，例如「摄像头已在后台启动」「正在安装摄像头依赖…」「需要安装 Python」等。

手动触发安装（比如想提前装好，或自动安装失败时排错）：

```powershell
python vision/setup_vision_env.py
```

前置条件：本机需有 **Python 3.10 ~ 3.12**（mediapipe 1.0.1 暂不支持 3.13+）。若只有更高版本，请另装一个 3.12 再运行上面的命令。

依赖版本固定在 `setup_vision_env.py` 的 `REQUIREMENTS` 里（numpy 1.26.4 / opencv-contrib-python 4.10.0.84 / mediapipe 1.0.1），与开发机一致。

## 入口的梗角色 NPC（牛来 + 美团袋鼠）

传送门落地后，走廊入口一左一右站着两个"被梗出来"的角色：左后墙的**牛来**、右前墙的**美团袋鼠**。走近 2.4 米内按 `E` 交谈，逐句读完自动结束，可重复；两人触发圈有部分交叠，取距离最近者响应（InteractionRouter 做焦点仲裁兜底）。

| 项 | 牛来 | 美团袋鼠 |
|---|---|---|
| 脚本 | `scripts/archive_entrance_npc.gd`（双 NPC 数据驱动，`NPCS` 配置表） | 同左 |
| 模型 | `assets/character/niu_lai.glb`（3.8 MB，2.4 万面） | `assets/character/meituan_kangaroo.glb`（2.3 MB，2.4 万面） |
| 站位 | `(-1.6, 0, -1.25)`，yaw 0.95 | `(0.8, 0, 1.25)`，yaw π+0.47 |
| 台词 | 7 句，末句留白「……牛来。」 | 7 句，末句甩梗「你胆子真是肥嘟嘟的」 |
| 自检 | `--headless --script res://scripts/check_entrance_npc.gd`（57 项断言，双角色全覆盖） | 同左 |

两个角色是同一个时代情绪的两面：牛来靠"丑"被围观而火、从头到尾没被真正看见；袋鼠被网友画胖三圈才火、大家爱上的是画出来的那个。对话里互相提一嘴（"旁边那头牛靠'丑'火的，我靠'胖'火的"）。

它们和 `archive_npc_dialogue.gd` 里的三个档案员是**两套独立系统**：档案员读完会开记忆传送门、推进主线；入口的两位只陪聊，不碰进度。

**模型来源与优化**：两个原始素材都是几十上百 MB 的 FBX 高模，直接进 Godot 会严重掉帧。已用 Blender 统一减面 + 贴图降采样：

```
牛来    1,498,869 面 / 123.5 MB  →  23,999 面 / 3.8 MB   (62× / 32×)
袋鼠       49,996 面 /  21.8 MB  →  24,000 面 / 2.3 MB   (2.1× / 9.5×)
```

外观基本无差别（减面用的是 collapse，保留了原有的角/耳/圆肚子轮廓）。若将来还要换模型，注意三点：
- 导出 GLB 时保持 `+Y up`，从 Blender 的 Z-up 转换后高度应落在 Godot 的 Y 轴上（模型原点在脚底，直接摆地面即可）。
- `<模型>.glb.import` 里 `gltf/embedded_image_handling` 要设 **0**（保持贴图内嵌）。设成 1 会把贴图解包成一堆散落的 PNG 扔进 `assets/character/`。
- 新模型入项目后先 `--headless --path . --import --quit-after 200` 生成 `.import`，否则运行时报 `No loader found for resource`。

## 编辑器 MCP 接入

`addons/godot_mcp/` 是编辑器内的控制插件，在 Godot 编辑器进程里监听 `127.0.0.1:6400`，接收 `{"type": "...", "params": {...}}` 形式的 JSON 命令并返回 JSON 结果。它可以查看/创建/删除节点、读写属性、调整层级、设置材质与网格、读写脚本、打包与实例化子场景，以及控制编辑器的运行/停止。

启用在 `project.godot` 的 `[editor_plugins]` 段：

```ini
[editor_plugins]

enabled=PackedStringArray("res://addons/godot_mcp/plugin.cfg")
```

启用后编辑器底部会出现 **MCP** 面板；`Godot MCP Plugin activated` / `Godot MCP Server listening on port 6400` 两行日志表示已就绪。

`addons/godot_mcp/mcp_server.py` 是标准 MCP (stdio) 服务，把 MCP 的 `tools/call` 翻译成上述 TCP 协议，注册了 24 个 `godot_*` 工具。WorkBuddy 侧配置在 `~/.workbuddy/mcp.json`：

```json
{
  "mcpServers": {
    "godotMCP": {
      "command": "C:\\Program Files\\python\\python.exe",
      "args": ["<工程路径>\\addons\\godot_mcp\\mcp_server.py"],
      "env": {
        "GODOT_MCP_HOST": "127.0.0.1",
        "GODOT_MCP_PORT": "6400",
        "GODOT_PROJECT_PATH": "<工程路径>"
      }
    }
  }
}
```

使用顺序：**先让 Godot 编辑器打开本工程并保持运行**，MCP 桥接才有可连接的对象；编辑器未运行时工具会返回明确的中文提示，而不是静默失败。

端口占用：编辑器的 MCP 用 `6400`（TCP，仅插件启用时占用）。运行时视觉链路用 `6401`（UDP 手部状态接收）与 `6402`（UDP 摄像头帧），互不冲突——`6400` 只在编辑器进程内监听，游戏运行时并不监听它。

## 项目海报

`assets/posters/` 提供 4 张可直接导入 Godot 的 SVG 海报：项目主视觉、平原游乐园、传送门手势说明和热梗票根收集玩法。

