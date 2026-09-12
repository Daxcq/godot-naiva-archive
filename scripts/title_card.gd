extends Control
## 开场标题「奶娃之旅」。左侧「奶娃」、右侧「之旅」各自从屏幕外翻滚飞入，
## 落位瞬间果冻弹跳并溅出奶滴，随后整排字像果冻一样轻轻晃；
## 两组字中间弹出一颗小奶滴作分隔。奶蛙被唤醒（或超时兜底）时
## 标题先拉长再融化、滴着奶滴坠落退场。

const TITLE := ["奶", "娃", "之", "旅"]
const VIEW := Vector2(1280, 720)
const CENTER := Vector2(640, 468)
const CELL := 200.0        # 单字占位宽
const CHAR_BOX := 200.0    # 字容器边长，缩放/旋转枢轴取容器中心
const PAIR_GAP := 230.0    # 「奶娃」与「之旅」两组之间的缝
const FONT_SIZE := 150
const FLIGHT := 0.62       # 单字飞行时长
const STAGGER := 0.16      # 逐字错峰起飞
const FIRST_DELAY := 0.15
const POP_TIME := 1.35     # 中央奶滴弹出时刻
const MIN_HOLD := 3.4      # 最短保留：飞入+落位必须完整演完，唤醒再早也等演完才退场
const FALLBACK_QUIT := 12.0

const MILK := Color(1.0, 0.972, 0.905)
const PLUM := Color(0.23, 0.16, 0.4)
const SHADOW := Color(0.12, 0.06, 0.28, 0.4)

class Char:
	var label: Label
	var home := Vector2.ZERO
	var from := Vector2.ZERO
	var side := 1.0
	var delay := 0.0
	var landed := false
	var land_time := 0.0
	var fall_speed := 0.0
	var exit_wait := 0.0
	var drip_acc := 0.0

var chars: Array[Char] = []
var subtitle: Label
var phase := "enter"
var elapsed := 0.0
var idle_time := 0.0
var exit_time := 0.0
var drop_scale := 0.0
var drop_alpha := 0.0
var drop_popped := false
var sub_alpha := 0.0
var pending_exit := false
var droplets: Array = []  # {pos, vel, r, life, max_life}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var offsets := [-CELL - PAIR_GAP * 0.5, -PAIR_GAP * 0.5, PAIR_GAP * 0.5, CELL + PAIR_GAP * 0.5]
	for i in range(TITLE.size()):
		var ch := Char.new()
		var center := Vector2(CENTER.x + offsets[i], CENTER.y)
		ch.home = center
		ch.side = -1.0 if i < 2 else 1.0
		ch.delay = FIRST_DELAY + i * STAGGER
		ch.exit_wait = i * 0.06
		ch.from = Vector2(-CHAR_BOX * 1.5 if ch.side < 0 else VIEW.x + CHAR_BOX * 1.5, center.y)
		ch.label = _make_label(TITLE[i], center)
		add_child(ch.label)
		chars.append(ch)
	subtitle = _make_subtitle()
	add_child(subtitle)

func _make_label(glyph: String, center: Vector2) -> Label:
	var label := Label.new()
	label.text = glyph
	label.size = Vector2(CHAR_BOX, CHAR_BOX)
	label.position = center - Vector2(CHAR_BOX, CHAR_BOX) * 0.5
	label.pivot_offset = Vector2(CHAR_BOX, CHAR_BOX) * 0.5
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", MILK)
	label.add_theme_color_override("font_outline_color", PLUM)
	label.add_theme_constant_override("outline_size", 12)
	label.add_theme_color_override("font_shadow_color", SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 6)
	return label

func _make_subtitle() -> Label:
	var label := Label.new()
	label.text = "网 络 流 行 梗 编 年 馆"
	label.position = Vector2(0, CENTER.y + 116)
	label.size = Vector2(VIEW.x, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.8, 0.77, 0.95))
	label.add_theme_color_override("font_shadow_color", SHADOW)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.modulate = Color(1, 1, 1, 0)
	return label

## 退场请求：奶蛙一醒就会喊这里。但标题有最短保留时间，
## 保证开场演出完整放完——期间的请求先记下，到点自动融化。
func dismiss() -> void:
	if phase == "exit" or phase == "gone":
		return
	pending_exit = true
	_try_exit()

func _try_exit() -> void:
	if not pending_exit or phase == "exit" or phase == "gone":
		return
	if elapsed < MIN_HOLD:
		return
	phase = "exit"
	exit_time = 0.0

func _process(delta: float) -> void:
	if phase == "gone":
		return
	elapsed += delta
	match phase:
		"enter":
			_update_enter(delta)
			_update_chrome(delta, 1.0)
		"idle":
			_update_idle(delta)
			_update_chrome(delta, 1.0)
		"exit":
			_update_exit(delta)
	if phase == "enter" or phase == "idle":
		if elapsed > FALLBACK_QUIT:
			pending_exit = true
		_try_exit()
	_update_droplets(delta)
	queue_redraw()

## 飞入段：回弹缓动 + 翻滚 + 弧线，落位瞬间触发果冻挤压与奶滴。
func _update_enter(delta: float) -> void:
	var all_landed := true
	for i in range(chars.size()):
		var ch := chars[i]
		if ch.landed:
			_apply_landing_pose(ch, delta)
			continue
		all_landed = false
		var p := clampf((elapsed - ch.delay) / FLIGHT, 0.0, 1.0)
		var f := _back_out(p)
		ch.label.position = ch.from.lerp(ch.home, f) - Vector2(CHAR_BOX, CHAR_BOX) * 0.5
		ch.label.position.y -= sin(p * PI) * 70.0
		ch.label.rotation = -ch.side * (1.0 - f) * 1.15
		var s := 0.5 + 0.5 * f
		ch.label.scale = Vector2(s, s)
		if p >= 1.0:
			ch.landed = true
			ch.land_time = 0.0
			_spawn_splash(ch.home + Vector2(0, CHAR_BOX * 0.5 - 12), ch.side, 12)
	if all_landed and elapsed > FIRST_DELAY + (TITLE.size() - 1) * STAGGER + FLIGHT + 0.45:
		phase = "idle"
		idle_time = 0.0

## 待机段：果冻挤压余波 + 整排字波浪轻晃。
func _update_idle(delta: float) -> void:
	idle_time += delta
	var ramp := smoothstep(0.0, 0.6, idle_time)
	for i in range(chars.size()):
		var ch := chars[i]
		_apply_landing_pose(ch, delta)
		ch.label.position = ch.home - Vector2(CHAR_BOX, CHAR_BOX) * 0.5 + Vector2(0, sin(elapsed * 2.1 + i * 0.85) * 6.0 * ramp)
		ch.label.rotation = sin(elapsed * 1.6 + i * 0.7) * 0.028 * ramp

## 落位后的阻尼弹跳：横向挤宽、纵向压扁，慢慢弹回 1。
func _apply_landing_pose(ch: Char, delta: float) -> void:
	ch.land_time += delta
	var k := exp(-5.0 * ch.land_time)
	var sx := 1.0 + 0.32 * k * cos(15.0 * ch.land_time)
	ch.label.scale = Vector2(sx, 1.0 - (sx - 1.0) * 0.9)

## 中央奶滴与副标题：错峰弹出、缓缓浮现。
func _update_chrome(delta: float, exit_fade: float) -> void:
	if elapsed >= POP_TIME and not drop_popped:
		drop_popped = true
		_spawn_splash(Vector2(CENTER.x, CENTER.y + 20), 0.0, 6)
	if drop_popped:
		var p := clampf((elapsed - POP_TIME) / 0.5, 0.0, 1.0)
		drop_scale = _elastic_out(p)
		drop_alpha = 1.0
	if elapsed > 1.25:
		sub_alpha = lerpf(sub_alpha, 0.85, 1.0 - exp(-delta * 3.0))
	subtitle.modulate.a = sub_alpha * exit_fade
	drop_alpha = minf(drop_alpha, exit_fade)

## 退场段：先拉长蓄力，再融化坠落，边掉边滴奶，最后整体隐去。
func _update_exit(delta: float) -> void:
	exit_time += delta
	var chrome_fade := 1.0 - clampf(exit_time / 0.55, 0.0, 1.0)
	_update_chrome(delta, chrome_fade)
	var done := true
	for i in range(chars.size()):
		var ch := chars[i]
		var t := exit_time - ch.exit_wait
		if t < 0.0:
			done = false
			continue
		if t < 0.14:
			var p := t / 0.14
			ch.label.scale = Vector2(lerpf(1.0, 0.82, p), lerpf(1.0, 1.3, p))
			ch.label.rotation = sin(elapsed * 1.6 + i * 0.7) * 0.028
			done = false
		else:
			var ft := t - 0.14
			ch.fall_speed += 3400.0 * delta
			ch.label.position.y += ch.fall_speed * delta
			ch.label.rotation += (1.0 if i % 2 == 0 else -1.0) * 2.1 * delta
			ch.label.modulate.a = 1.0 - smoothstep(0.2, 0.6, ft)
			ch.drip_acc += delta
			if ch.drip_acc > 0.07 and ch.label.modulate.a > 0.2:
				ch.drip_acc = 0.0
				_spawn_splash(ch.label.position + Vector2(CHAR_BOX, CHAR_BOX) * 0.5 + Vector2(0, CHAR_BOX * 0.4), ch.side, 1)
			if ch.label.modulate.a > 0.0:
				done = false
	if done and exit_time > 1.6:
		phase = "gone"
		visible = false
		set_process(false)

func _spawn_splash(origin: Vector2, side: float, count: int) -> void:
	for i in range(count):
		var spread := randf_range(-90.0, 90.0)
		var push := side * randf_range(60.0, 300.0) if absf(side) > 0.01 else randf_range(-120.0, 120.0)
		droplets.append({
			"pos": origin + Vector2(randf_range(-60.0, 60.0), randf_range(-14.0, 10.0)),
			"vel": Vector2(push + spread, -randf_range(140.0, 430.0)),
			"r": randf_range(3.0, 7.0),
			"life": 0.0,
			"max_life": randf_range(0.45, 0.8),
		})

func _update_droplets(delta: float) -> void:
	for i in range(droplets.size() - 1, -1, -1):
		var d: Dictionary = droplets[i]
		d["life"] += delta
		if d["life"] > d["max_life"]:
			droplets.remove_at(i)
			continue
		var vel: Vector2 = d["vel"]
		vel.y += 1500.0 * delta
		d["vel"] = vel
		d["pos"] = d["pos"] + vel * delta

func _draw() -> void:
	if drop_alpha > 0.01 and drop_scale > 0.0:
		var bob := sin(elapsed * 2.4) * 4.0
		_draw_drop(Vector2(CENTER.x, CENTER.y + 14 + bob), drop_scale, drop_alpha)
	for d in droplets:
		var fade: float = 1.0 - d["life"] / d["max_life"]
		var col: Color = MILK
		col.a = fade
		draw_circle(d["pos"], d["r"] * (0.6 + 0.4 * fade), col)

func _draw_drop(pos: Vector2, scale_f: float, alpha: float) -> void:
	var body_r := 13.0 * scale_f
	var body_c := pos + Vector2(0, 6) * scale_f
	var top := pos + Vector2(0, -26) * scale_f
	var col := MILK
	col.a = alpha
	var line := PLUM
	line.a = alpha
	draw_colored_polygon(PackedVector2Array([
		body_c + Vector2(-body_r * 0.92, -body_r * 0.42),
		top,
		body_c + Vector2(body_r * 0.92, -body_r * 0.42),
	]), col)
	draw_circle(body_c, body_r, col)
	draw_arc(body_c, body_r, 0.0, TAU, 24, line, 2.0, true)
	var hl := Color(1, 1, 1, alpha * 0.85)
	draw_circle(body_c + Vector2(-body_r * 0.35, -body_r * 0.18), body_r * 0.28, hl)

func _back_out(t: float) -> float:
	const S := 2.2
	var u := t - 1.0
	return 1.0 + (S + 1.0) * u * u * u + S * u * u

func _elastic_out(t: float) -> float:
	if t <= 0.0:
		return 0.0
	if t >= 1.0:
		return 1.0
	return pow(2.0, -10.0 * t) * sin((t * 10.0 - 0.75) * TAU / 3.0) + 1.0
