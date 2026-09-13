extends Node
## Godot 视觉识别输入层。
##
## 识别器通过 UDP 接收标准化手部状态，协议示例：
## {"x":0.5,"y":0.5,"grab":0.0,"spread":0.8,"confidence":0.95}
## 外部 MediaPipe/OpenCV 进程只需要发送 JSON 到 127.0.0.1:6401。
## 未连接时自动进入鼠标/键盘模拟模式，保证流程可测试。
##
## 生命周期：游戏启动时自动拉起摄像头桥接进程，退出时自动回收，
## 不需要用户另外开一个终端跑脚本。

signal observation_changed(observation: Dictionary)

const LISTEN_PORT := 6401
const LOST_TIMEOUT := 0.35
## 视觉依赖放在工程内的 vision/ 目录，随仓库一起搬迁，不再依赖工程外的相对路径。
const VISION_DIR := "res://vision"
const BRIDGE_SCRIPT_NAMES := ["mediapipe_camera_bridge.py", "godot_camera_bridge.py"]
## 桥接进程把壳/工作两个 PID 写进这个文件；下次启动前据此清场（见 _kill_stale_bridges）。
const BRIDGE_PID_FILE := ".bridge.pid"
const SETUP_SCRIPT_NAME := "setup_vision_env.py"
## 优先用随工程携带的 venv，其次回落工程外的旧位置。
## 注意：venv 的路径是绑死创建机器的（pyvenv.cfg 里的 executable/command 是绝对路径），
## 所以换电脑后这些候选全都找不到 —— 届时走 _install_env() 自动重建。
const VENV_CANDIDATES := [
	"res://vision/.vision-venv/Scripts/python.exe",
	"res://.vision-venv/Scripts/python.exe",
	"res://../.vision-venv/Scripts/python.exe",
]
## 桥接进程意外退出后的重启冷却，避免刷屏。
const BRIDGE_RELAUNCH_COOLDOWN := 6.0

var socket := PacketPeerUDP.new()
var observation: Dictionary = {
	"active": false, "x": 0.5, "y": 0.5, "grab": 0.0,
	"spread": 0.5, "confidence": 0.0, "source": "fallback"
}
var last_packet_at := -100.0
var enabled := true
var bridge_pid := -1
var bridge_ready := false
var bridge_status := "未启动"
var _relaunch_cooldown := 0.0
var _installing := false
var _install_pid := -1
## 自动安装最多尝试 2 次：装不上通常是没 Python 或没网络，反复试没意义。
const MAX_INSTALL_ATTEMPTS := 2
var _install_attempts := 0

func _ready() -> void:
	# 自动化检查/CI 不应绑定桌面视觉端口，也不应启动摄像头进程。
	if OS.has_feature("headless"):
		set_process(false)
		return
	var err := socket.bind(LISTEN_PORT, "127.0.0.1")
	if err != OK:
		push_warning("视觉识别 UDP 端口 %d 不可用，使用鼠标模拟模式；不会重复启动桥接进程" % LISTEN_PORT)
		bridge_status = "端口 %d 被占用" % LISTEN_PORT
		return
	_start_bridge()

## 依次尝试候选路径；返回 [解释器绝对路径, 桥接脚本绝对路径]。
func _resolve_bridge() -> Array:
	var script_path := ""
	for name in BRIDGE_SCRIPT_NAMES:
		var candidate := ProjectSettings.globalize_path("%s/%s" % [VISION_DIR, name])
		if FileAccess.file_exists(candidate):
			script_path = candidate
			break
	var python_path := ""
	for candidate in VENV_CANDIDATES:
		var path := ProjectSettings.globalize_path(candidate)
		if FileAccess.file_exists(path):
			python_path = path
			break
	return [python_path, script_path]

func _start_bridge() -> void:
	_kill_stale_bridges()
	var resolved := _resolve_bridge()
	if String(resolved[0]).is_empty() or String(resolved[1]).is_empty():
		# 换了电脑后最常见的情况：venv 不在（它无法随仓库迁移），
		# 这里自动拉一个安装器后台重建环境，装完由 _process 自动重试。
		_install_env()
		return
	# 第二个参数 = 本进程 PID：桥接用它做宿主存活自检。
	# 不能靠桥接自己 os.getppid()——venv 转发壳隔在中间，拿到的是壳的 PID。
	bridge_pid = OS.create_process(resolved[0], [resolved[1], str(OS.get_process_id())], false)
	if bridge_pid <= 0:
		push_warning("MediaPipe 桥接启动失败，使用鼠标模式")
		bridge_status = "桥接启动失败"
		return
	bridge_ready = true
	bridge_status = "摄像头已在后台启动"

## 上一次游戏异常退出（崩溃/被任务管理器结束）时，桥接进程可能来不及回收：
## 摄像头被占着、残帧还在往 6402 乱发——多桥并存正是预览卡顿的一大元凶。
## 桥接启动时会把 PID 写进 .bridge.pid，这里在拉起新桥前先按记录清场。
func _kill_stale_bridges() -> void:
	var path := ProjectSettings.globalize_path("%s/%s" % [VISION_DIR, BRIDGE_PID_FILE])
	if not FileAccess.file_exists(path):
		return
	var text := FileAccess.get_file_as_string(path).strip_edges()
	# 先删文件再杀：万一 taskkill 卡住，也不会把同一批 PID 重复杀。
	DirAccess.remove_absolute(path)
	if text.is_empty():
		return
	for pid_str in text.split(" ", false):
		var pid := int(pid_str)
		if pid <= 0 or not OS.is_process_running(pid):
			continue
		if OS.get_name() == "Windows":
			# 壳进程要 /T 递归带走真正干活的子进程（venv 转发壳结构）。
			OS.execute("taskkill", ["/PID", pid_str, "/T", "/F"], [], true)
		else:
			OS.kill(pid)
	print("[vision] 已按 %s 清理残留桥接进程：%s" % [BRIDGE_PID_FILE, text])

## 找一个可用的系统 Python 来执行安装脚本。
## 直接跑 `<cmd> --version` 探测，避免选到不存在的命令。
## 注意：版本筛选交给 setup_vision_env.py（它知道 mediapipe 支持 3.10~3.12），
## 这里只负责确认命令能跑起来。
func _find_system_python() -> String:
	# 工程外的旧 venv 若还在（同机迁移场景），直接用它。
	for legacy in [
		"res://.vision-venv/Scripts/python.exe",
		"res://../.vision-venv/Scripts/python.exe",
	]:
		var path := ProjectSettings.globalize_path(legacy)
		if FileAccess.file_exists(path):
			return path
	# 否则探测 PATH 上的解释器（Windows 优先 py launcher）。
	# OS.execute 返回退出码（int），探测 0 即视为可用。
	var candidates := ["py", "python", "python3"] if OS.get_name() == "Windows" else ["python3", "python"]
	for cmd in candidates:
		var code := OS.execute(cmd, ["--version"], [], true)
		if code == 0:
			return cmd
	return ""

## 后台自动安装摄像头依赖。装完 _process 里会自动重新尝试启动桥接。
func _install_env() -> void:
	if _installing:
		return
	if _install_attempts >= MAX_INSTALL_ATTEMPTS:
		bridge_status = "摄像头依赖缺失（已停止自动安装）"
		return
	var setup_path := ProjectSettings.globalize_path("%s/%s" % [VISION_DIR, SETUP_SCRIPT_NAME])
	if not FileAccess.file_exists(setup_path):
		push_warning("未找到摄像头依赖，且缺少 %s，使用鼠标模式。" % SETUP_SCRIPT_NAME)
		bridge_status = "缺少摄像头依赖"
		_install_attempts = MAX_INSTALL_ATTEMPTS
		return
	var python_cmd := _find_system_python()
	if python_cmd.is_empty():
		push_warning("未找到系统 Python，无法自动安装摄像头依赖，使用鼠标模式。")
		bridge_status = "需要安装 Python"
		_install_attempts = MAX_INSTALL_ATTEMPTS
		return
	_install_pid = OS.create_process(python_cmd, [setup_path], false)
	if _install_pid <= 0:
		push_warning("摄像头依赖安装器启动失败，使用鼠标模式。")
		bridge_status = "依赖安装启动失败"
		_install_attempts = MAX_INSTALL_ATTEMPTS
		return
	_installing = true
	_install_attempts += 1
	bridge_status = "正在安装摄像头依赖…（第 %d 次）" % _install_attempts
	print("[vision] 检测到摄像头依赖缺失，已在后台启动环境安装（首次约需几分钟）")

func _process(delta: float) -> void:
	_relaunch_cooldown = maxf(_relaunch_cooldown - delta, 0.0)

	# 依赖安装器跑完了：不管成败都撤掉标记，让下面重新尝试拉起桥接。
	if _installing and _install_pid > 0 and not OS.is_process_running(_install_pid):
		_installing = false
		_install_pid = -1
		_relaunch_cooldown = 0.0
		print("[vision] 依赖安装流程结束，重新尝试启动摄像头桥接")

	# 桥接进程意外退出（拔掉摄像头、崩溃）时尝试重新拉起，但不要刷屏。
	if enabled and bridge_ready and _relaunch_cooldown <= 0.0:
		if bridge_pid > 0 and not OS.is_process_running(bridge_pid):
			bridge_pid = -1
			bridge_ready = false
			bridge_status = "桥接已退出，正在重试"
			_relaunch_cooldown = BRIDGE_RELAUNCH_COOLDOWN
			_start_bridge()

	# 从未成功启动过、也没在装依赖时，定期重试（覆盖“解释器刚装好”这类情况）。
	if enabled and not bridge_ready and not _installing and _relaunch_cooldown <= 0.0:
		_relaunch_cooldown = BRIDGE_RELAUNCH_COOLDOWN
		_start_bridge()

	var got_packet := false
	while socket.get_available_packet_count() > 0:
		var text := socket.get_packet().get_string_from_utf8()
		var parsed = JSON.parse_string(text)
		if parsed is Dictionary and _accept_packet(parsed):
			got_packet = true
			last_packet_at = Time.get_ticks_msec() / 1000.0
	if got_packet:
		observation["source"] = "vision"
	elif Time.get_ticks_msec() / 1000.0 - last_packet_at > LOST_TIMEOUT:
		_update_fallback()
	observation_changed.emit(observation)

func _exit_tree() -> void:
	# 退出时回收桥接进程，避免摄像头被占用、进程残留。
	_shutdown_bridge()
	socket.close()

func _notification(what: int) -> void:
	# 玩家点关闭按钮时先把摄像头收掉。
	# 不能只依赖 _exit_tree()：那一阶段进程正在销毁，阻塞式 taskkill 常来不及跑完。
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_shutdown_bridge()

func _shutdown_bridge() -> void:
	if bridge_pid > 0 and OS.is_process_running(bridge_pid):
		if OS.get_name() == "Windows":
			# Windows 的 venv python.exe 是个转发壳，真正干活的是它的子进程，
			# 因此必须 /T 递归结束整棵树；/F 强制避免弹确认框。
			# 这里用阻塞执行，确保 Godot 退出前命令已生效。
			OS.execute("taskkill", ["/PID", str(bridge_pid), "/T", "/F"], [], true)
		else:
			OS.kill(bridge_pid)
	bridge_pid = -1
	bridge_ready = false
	bridge_status = "已关闭"

func get_bridge_status() -> String:
	return bridge_status

func _accept_packet(data: Dictionary) -> bool:
	var confidence := clampf(float(data.get("confidence", 1.0)), 0.0, 1.0)
	if confidence < 0.2:
		return false
	observation["active"] = bool(data.get("active", true))
	observation["x"] = clampf(float(data.get("x", 0.5)), 0.0, 1.0)
	observation["y"] = clampf(float(data.get("y", 0.5)), 0.0, 1.0)
	observation["grab"] = clampf(float(data.get("grab", 0.0)), 0.0, 1.0)
	observation["spread"] = clampf(float(data.get("spread", 0.5)), 0.0, 1.0)
	observation["confidence"] = confidence
	return true

func _update_fallback() -> void:
	var viewport := get_viewport()
	var size := viewport.get_visible_rect().size
	var mouse := viewport.get_mouse_position()
	observation["active"] = enabled and size.x > 0.0
	observation["x"] = clampf(mouse.x / size.x, 0.0, 1.0)
	observation["y"] = clampf(mouse.y / size.y, 0.0, 1.0)
	observation["grab"] = 1.0 if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 0.0
	observation["spread"] = 0.5
	observation["confidence"] = 0.0
	observation["source"] = "fallback"

func get_observation() -> Dictionary:
	return observation.duplicate()

## 每帧读取用这个，避免 duplicate() 的分配。调用方不要写入返回值。
func peek_observation() -> Dictionary:
	return observation

func set_enabled(value: bool) -> void:
	enabled = value
