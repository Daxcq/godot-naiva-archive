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
## 优先用随工程携带的 venv，其次回落工程外的旧位置。
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
	var resolved := _resolve_bridge()
	if String(resolved[0]).is_empty() or String(resolved[1]).is_empty():
		push_warning("未找到 MediaPipe 环境（vision/.vision-venv 与 vision/*_bridge.py），使用鼠标模式。")
		bridge_status = "未找到摄像头依赖"
		return
	bridge_pid = OS.create_process(resolved[0], [resolved[1]], false)
	if bridge_pid <= 0:
		push_warning("MediaPipe 桥接启动失败，使用鼠标模式")
		bridge_status = "桥接启动失败"
		return
	bridge_ready = true
	bridge_status = "摄像头已在后台启动"

func _process(delta: float) -> void:
	_relaunch_cooldown = maxf(_relaunch_cooldown - delta, 0.0)
	# 桥接进程意外退出（拔掉摄像头、崩溃）时尝试重新拉起，但不要刷屏。
	if enabled and bridge_ready and _relaunch_cooldown <= 0.0:
		if bridge_pid > 0 and not OS.is_process_running(bridge_pid):
			bridge_pid = -1
			bridge_ready = false
			bridge_status = "桥接已退出，正在重试"
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

func _shutdown_bridge() -> void:
	if bridge_pid > 0 and OS.is_process_running(bridge_pid):
		if OS.get_name() == "Windows":
			# Windows 的 py/python 启动链可能包含子进程，递归结束避免摄像头被占用。
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
