extends Node

signal confirm_triggered
signal source_changed(new_source: String)

const GRAB_ON := 0.62
const GRAB_OFF := 0.32
const CONFIRM_COOLDOWN := 0.32
const CANCEL_ON := 0.78
const CANCEL_OFF := 0.48
const SWIPE_WINDOW := 0.28
const SWIPE_DISTANCE := 0.16
const SWIPE_COOLDOWN := 0.34
const AXIS_DEADZONE := 0.08
const KEYBOARD_OVERRIDE := 0.05
const POINTER_RESPONSE := 14.0
const RESYNC_RESPONSE := 3.5
const RESYNC_DURATION := 0.45

@export var visual_recognition_path: NodePath = ^"../VisualRecognition"

var active := false
var source := "fallback"
var axis := Vector2.ZERO
var steer := Vector2.ZERO
var pointer := Vector2(0.5, 0.5)
var grab := 0.0
var spread := 0.5
var confidence := 0.0
var confirm_pressed := false
var confirm_just_pressed := false
var confirm_just_released := false
## 张开手掌 = 取消/退出(仅视觉模式)。鼠标模拟的 spread 恒为 0.5,不会误触。
var cancel_just_pressed := false
## 通用挥手(仅视觉模式):(±1,0) 左右挥 / (0,±1) 上下挥,主轴定方向。
## 画廊翻页 / 展板切片 / 俄方硬降 / 标题跳过 都读这一个信号。
var swipe_just := Vector2i.ZERO

var _vision: Node
var _latched := false
var _cooldown := 0.0
var _cancel_latched := false
var _cancel_cooldown := 0.0
var _swipe_clock := 0.0
var _swipe_cooldown := 0.0
var _swipe_samples: Array[Vector3] = []  # (时间, 指针x, 指针y)
var _resync := 0.0
var _seeded := false

func _ready() -> void:
	_vision = get_node_or_null(visual_recognition_path)
	if _vision == null:
		push_warning("InputState 未找到 VisualRecognition，仅使用键鼠输入")

func poll(delta: float) -> void:
	var observation := _read_observation()
	var next_source := String(observation.get("source", "fallback"))
	if next_source != source:
		source = next_source
		_resync = RESYNC_DURATION
		source_changed.emit(source)

	active = bool(observation.get("active", false))
	grab = clampf(float(observation.get("grab", 0.0)), 0.0, 1.0)
	spread = clampf(float(observation.get("spread", 0.5)), 0.0, 1.0)
	confidence = clampf(float(observation.get("confidence", 0.0)), 0.0, 1.0)

	var raw_pointer := Vector2(
		clampf(float(observation.get("x", 0.5)), 0.0, 1.0),
		clampf(float(observation.get("y", 0.5)), 0.0, 1.0)
	)
	if not _seeded:
		pointer = raw_pointer
		_seeded = true
	else:
		if _resync > 0.0:
			_resync = maxf(_resync - delta, 0.0)
		var response := RESYNC_RESPONSE if _resync > 0.0 else POINTER_RESPONSE
		pointer = pointer.lerp(raw_pointer, 1.0 - exp(-delta * response))

	steer = (pointer - Vector2(0.5, 0.5)) * 2.0
	axis = _resolve_axis()
	_resolve_confirm(delta)
	_resolve_cancel(delta)
	_resolve_swipe(delta)

func consume_confirm() -> bool:
	if confirm_just_pressed:
		confirm_just_pressed = false
		return true
	return false

func is_vision_driven() -> bool:
	return source == "vision" and active

func reset() -> void:
	_latched = false
	_cooldown = 0.0
	_cancel_latched = false
	_cancel_cooldown = 0.0
	_swipe_cooldown = 0.0
	_swipe_samples.clear()
	swipe_just = Vector2i.ZERO
	_resync = 0.0
	_seeded = false
	axis = Vector2.ZERO
	steer = Vector2.ZERO
	pointer = Vector2(0.5, 0.5)
	confirm_pressed = false
	confirm_just_pressed = false
	confirm_just_released = false
	cancel_just_pressed = false

func _read_observation() -> Dictionary:
	if _vision != null and _vision.has_method("peek_observation"):
		return _vision.peek_observation()
	if _vision != null and _vision.has_method("get_observation"):
		return _vision.get_observation()
	return {
		"active": true, "source": "fallback", "x": 0.5, "y": 0.5,
		"grab": 1.0 if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 0.0,
		"spread": 0.5, "confidence": 0.0
	}

func _resolve_axis() -> Vector2:
	var keyboard := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if keyboard.length() > KEYBOARD_OVERRIDE:
		return keyboard.limit_length(1.0)
	if source == "vision" and active:
		if steer.length() > AXIS_DEADZONE:
			return steer.limit_length(1.0)
	return Vector2.ZERO

func _resolve_confirm(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	confirm_just_pressed = false
	confirm_just_released = false
	var was_latched := _latched
	if _latched:
		if grab < GRAB_OFF:
			_latched = false
	elif grab > GRAB_ON:
		_latched = true
	confirm_pressed = _latched
	if _latched and not was_latched:
		if _cooldown <= 0.0:
			_cooldown = CONFIRM_COOLDOWN
			confirm_just_pressed = true
			confirm_triggered.emit()
	elif was_latched and not _latched:
		confirm_just_released = true

## 张开手掌的上升沿 = 取消/退出。与握拳(确认)天然互斥:握拳时 spread 低。
func _resolve_cancel(delta: float) -> void:
	_cancel_cooldown = maxf(_cancel_cooldown - delta, 0.0)
	cancel_just_pressed = false
	if not is_vision_driven():
		_cancel_latched = false
		return
	var was := _cancel_latched
	if _cancel_latched:
		if spread < CANCEL_OFF:
			_cancel_latched = false
	elif spread > CANCEL_ON:
		_cancel_latched = true
	if _cancel_latched and not was and _cancel_cooldown <= 0.0:
		_cancel_cooldown = CONFIRM_COOLDOWN
		cancel_just_pressed = true

## 通用挥手:窗口内指针位移超阈值判为一挥,取主轴定方向,右/下为正。
## 画廊翻页 / 展板切片 / 俄方硬降 / 标题跳过 都读这一个信号,不再各写各的采样。
func _resolve_swipe(delta: float) -> void:
	_swipe_clock += delta
	_swipe_cooldown = maxf(_swipe_cooldown - delta, 0.0)
	swipe_just = Vector2i.ZERO
	if not is_vision_driven():
		_swipe_samples.clear()
		return
	_swipe_samples.append(Vector3(_swipe_clock, pointer.x, pointer.y))
	while _swipe_samples.size() > 1 and _swipe_clock - _swipe_samples[0].x > SWIPE_WINDOW:
		_swipe_samples.remove_at(0)
	if _swipe_cooldown > 0.0 or _swipe_samples.size() < 2:
		return
	var last: Vector3 = _swipe_samples[_swipe_samples.size() - 1]
	var first: Vector3 = _swipe_samples[0]
	var d := Vector2(last.y - first.y, last.z - first.z)
	if maxf(absf(d.x), absf(d.y)) < SWIPE_DISTANCE:
		return
	if absf(d.x) >= absf(d.y):
		swipe_just = Vector2i(1 if d.x > 0.0 else -1, 0)
	else:
		swipe_just = Vector2i(0, 1 if d.y > 0.0 else -1)
	_swipe_cooldown = SWIPE_COOLDOWN
	_swipe_samples.clear()
