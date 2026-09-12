extends Control
## 奶娃画廊 · 全屏画廊 UI。
## 网格:鎏金画框卡片,交错浮现,悬停亮起;点开进入鉴赏模式:
## 聚光灯 + 鎏金双框 + Ken Burns 慢推镜头 + 策展人批注。
## 视觉识别:挥手快翻(右挥=下一幅,左挥=上一幅),手悬停屏幕左右缘连续快翻。
## 翻页带方向感动画:旧画滑出、金光扫过、新画回弹滑入。
## 关闭:ESC / 关闭按钮 / 张开手掌。

signal closed

const UIKit := preload("res://scripts/ui_kit.gd")
const GOLD := Color("e8c46a")
const GOLD_DIM := Color(0.91, 0.77, 0.42, 0.42)
const COLS := 4
const CARD_W := 260.0
const CARD_IMG_H := 180.0
## 挥手判定:0.28 秒窗口内指针横移超过阈值即算一挥。
const SWIPE_WINDOW := 0.28
const SWIPE_DISTANCE := 0.16
const SWIPE_COOLDOWN := 0.34
## 手悬停屏幕左右缘的连翻:驻留 0.45 秒后每 0.3 秒翻一张。
const EDGE_ZONE := 0.15
const EDGE_DWELL := 0.45
const EDGE_REPEAT := 0.3
## 策展人批注:按作品序号循环取用。
const CAPTIONS := [
	"修复师批注：奶油调子拿捏得极准。",
	"修复师批注：构图飘逸,相传出自佚名奶蛙之手。",
	"修复师批注：腹部的留白是全画灵魂。",
	"修复师批注：笔触湿润,像刚从牛奶里捞出。",
	"修复师批注：装裱前请勿投喂。",
	"修复师批注：被围观次数已不可考。",
	"修复师批注：画中蛙的眼神过于真诚。",
	"修复师批注：出土于热搜底层第 7 页。",
	"修复师批注：颜料成分 87% 是梗。",
	"修复师批注：建议每次观看不超过三小时。",
	"修复师批注：曾一夜之间传遍整个广场。",
	"修复师批注：复刻版与原作一样可爱。",
	"修复师批注：看久了会不自觉点头。",
	"修复师批注：档案员拒绝为真实性背书。"
]

var input_state: Node
var artworks: Array[Texture2D] = []
var grid: GridContainer
var cards: Array[PanelContainer] = []
var card_normal: StyleBoxFlat
var card_hover: StyleBoxFlat
var detail: Control
var flip_holder: Control
var detail_image: TextureRect
var sweep: ColorRect
var detail_caption: Label
var detail_no: Label
var detail_index := 0
var open_time := 0.0
var zoom_tween: Tween
var flip_tween: Tween
var sweep_tween: Tween
var sfx: AudioStreamPlayer
## 挥手采样:(时间, 指针x),窗口内位移超阈值判定为一挥。
var swipe_samples: Array[Vector2] = []
var swipe_cooldown := 0.0
var edge_dir := 0
var edge_time := 0.0
var repeat_timer := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	sfx = AudioStreamPlayer.new()
	sfx.volume_db = -14.0
	add_child(sfx)

func setup(textures: Array[Texture2D], gesture_input: Node) -> void:
	input_state = gesture_input
	artworks = textures
	_build_ui()

func open() -> void:
	visible = true
	open_time = 0.0
	detail.visible = false
	_stagger_cards()

func close() -> void:
	visible = false
	closed.emit()

func _play_cue(cue_name: String) -> void:
	sfx.stream = load("res://assets/audio/%s.wav" % cue_name)
	sfx.play()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.016, 0.01, 0.045, 0.97)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	# 顶部标题行。
	var title := Label.new()
	title.text = "奶 娃 画 廊"
	title.position = Vector2(48, 20)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", GOLD)
	add_child(title)
	var subtitle := Label.new()
	subtitle.text = "名画修复档案 · %d 幅作品" % artworks.size()
	subtitle.position = Vector2(240, 34)
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", UIKit.DIM)
	add_child(subtitle)
	var close_button := UIKit.make_button("ESC  退出画廊", UIKit.MAGENTA)
	close_button.custom_minimum_size = Vector2(190, UIKit.BTN_HEIGHT)
	close_button.pressed.connect(close)
	close_button.anchor_left = 1.0
	close_button.anchor_right = 1.0
	close_button.offset_left = -230.0
	close_button.offset_right = -40.0
	close_button.offset_top = 22.0
	close_button.offset_bottom = 22.0 + UIKit.BTN_HEIGHT
	add_child(close_button)
	# 画框墙:4 列大卡,装进滚动容器。
	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_top = 0.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 76.0
	scroll.offset_right = -76.0
	scroll.offset_top = 84.0
	scroll.offset_bottom = -16.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	grid = GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 24)
	grid.custom_minimum_size = Vector2(1104.0, 0)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	card_normal = _card_style(GOLD_DIM)
	card_hover = _card_style(GOLD)
	for i in range(artworks.size()):
		grid.add_child(_make_card(i))
	# 鉴赏模式(大图)整层,盖在网格上。
	_build_detail()

func _card_style(border: Color) -> StyleBoxFlat:
	var sb := UIKit.panel_style(Color(0.05, 0.04, 0.13, 0.96), border, 10, 1)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 6.0
	return sb

func _make_card(index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", card_normal)
	card.custom_minimum_size = Vector2(CARD_W, CARD_IMG_H + 42)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var image := TextureRect.new()
	image.texture = artworks[index]
	image.custom_minimum_size = Vector2(CARD_W - 16, CARD_IMG_H)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.clip_contents = true
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(image)
	var caption := Label.new()
	caption.text = "No.%02d" % (index + 1)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", UIKit.DIM)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(caption)
	card.mouse_entered.connect(func():
		if not detail.visible:
			card.add_theme_stylebox_override("panel", card_hover)
			card.pivot_offset = card.size * 0.5
			card.scale = Vector2(1.04, 1.04))
	card.mouse_exited.connect(func():
		card.add_theme_stylebox_override("panel", card_normal)
		card.scale = Vector2.ONE)
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_show_detail(index, 0))
	cards.append(card)
	return card

## 交错浮现:像策展人把画一幅幅挂上墙。
func _stagger_cards() -> void:
	for i in range(cards.size()):
		var card := cards[i]
		card.modulate.a = 0.0
		card.scale = Vector2(0.92, 0.92)
		card.pivot_offset = card.size * 0.5
		var tween := create_tween()
		tween.tween_interval(0.05 * i)
		tween.tween_property(card, "modulate:a", 1.0, 0.32)
		tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _build_detail() -> void:
	detail = Control.new()
	detail.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail.visible = false
	detail.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(detail)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.006, 0.004, 0.02, 0.99)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	detail.add_child(bg)
	# 聚光灯:径向渐变,暖金洒在画上。
	var spot := TextureRect.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1.0, 0.88, 0.62, 0.3), Color(1.0, 0.88, 0.62, 0.0)])
	var gradient_tex := GradientTexture2D.new()
	gradient_tex.gradient = gradient
	gradient_tex.fill = GradientTexture2D.FILL_RADIAL
	gradient_tex.fill_from = Vector2(0.5, 0.42)
	gradient_tex.fill_to = Vector2(0.5, 1.05)
	gradient_tex.width = 512
	gradient_tex.height = 512
	spot.texture = gradient_tex
	spot.set_anchors_preset(Control.PRESET_FULL_RECT)
	spot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_child(spot)
	# 鎏金双框:外框粗金边,内框细线;CenterContainer 保证任何尺寸都居中。
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -96.0
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	detail.add_child(center)
	var outer := PanelContainer.new()
	var outer_style := UIKit.panel_style(Color(0.03, 0.02, 0.08), GOLD, 4, 4)
	outer_style.content_margin_left = 10.0
	outer_style.content_margin_right = 10.0
	outer_style.content_margin_top = 10.0
	outer_style.content_margin_bottom = 10.0
	outer.add_theme_stylebox_override("panel", outer_style)
	outer.mouse_filter = Control.MOUSE_FILTER_PASS
	center.add_child(outer)
	var inner := PanelContainer.new()
	var inner_style := UIKit.panel_style(Color(0.06, 0.05, 0.14), Color(GOLD.r, GOLD.g, GOLD.b, 0.7), 2, 1)
	inner_style.content_margin_left = 4.0
	inner_style.content_margin_right = 4.0
	inner_style.content_margin_top = 4.0
	inner_style.content_margin_bottom = 4.0
	inner.add_theme_stylebox_override("panel", inner_style)
	inner.mouse_filter = Control.MOUSE_FILTER_PASS
	outer.add_child(inner)
	# 画片容器:翻页动画动它,与 Ken Burns(缩放画片)互不干扰。
	flip_holder = Control.new()
	flip_holder.custom_minimum_size = Vector2(720.0, 500.0)
	flip_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flip_holder.clip_contents = false
	inner.add_child(flip_holder)
	detail_image = TextureRect.new()
	detail_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flip_holder.add_child(detail_image)
	# 金光扫过:翻页时一道细金光横掠画面。
	sweep = ColorRect.new()
	sweep.color = Color(1.0, 0.9, 0.6, 0.0)
	sweep.size = Vector2(5.0, 500.0)
	sweep.position = Vector2(-10.0, 0.0)
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flip_holder.add_child(sweep)
	# 批注、页码、操作提示:底部通栏居中。
	detail_caption = _bottom_label(64.0, 20, UIKit.MILK)
	detail_no = _bottom_label(36.0, 15, GOLD)
	var hint := _bottom_label(10.0, 13, UIKit.DIM)
	hint.text = "挥手快翻 · 手停左右缘连续翻 · ← → 或 A D 翻页 · E / ESC 返回画墙 · 张开手掌退出"
	detail.add_child(detail_caption)
	detail.add_child(detail_no)
	detail.add_child(hint)
	# 左右翻页大按钮:贴左右边,垂直居中。
	var prev_button := UIKit.make_button("‹", GOLD)
	prev_button.custom_minimum_size = Vector2(64, 72)
	prev_button.pressed.connect(func(): _step_detail(-1))
	prev_button.anchor_top = 0.5
	prev_button.anchor_bottom = 0.5
	prev_button.offset_left = 48.0
	prev_button.offset_right = 112.0
	prev_button.offset_top = -36.0
	prev_button.offset_bottom = 36.0
	prev_button.add_theme_font_size_override("font_size", 30)
	detail.add_child(prev_button)
	var next_button := UIKit.make_button("›", GOLD)
	next_button.custom_minimum_size = Vector2(64, 72)
	next_button.pressed.connect(func(): _step_detail(1))
	next_button.anchor_left = 1.0
	next_button.anchor_right = 1.0
	next_button.anchor_top = 0.5
	next_button.anchor_bottom = 0.5
	next_button.offset_left = -112.0
	next_button.offset_right = -48.0
	next_button.offset_top = -36.0
	next_button.offset_bottom = 36.0
	next_button.add_theme_font_size_override("font_size", 30)
	detail.add_child(next_button)

func _bottom_label(bottom: float, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = 1.0
	label.anchor_bottom = 1.0
	label.offset_top = -bottom - 30.0
	label.offset_bottom = -bottom
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## 打开鉴赏模式。dir=0 直达;±1 表示从相邻画翻页而来,带方向滑入。
func _show_detail(index: int, dir: int) -> void:
	detail_index = clampi(index, 0, artworks.size() - 1)
	detail_image.texture = artworks[detail_index]
	detail_no.text = "No.%02d  /  %02d" % [detail_index + 1, artworks.size()]
	detail_caption.text = String(CAPTIONS[detail_index % CAPTIONS.size()])
	if not detail.visible:
		detail.visible = true
		_play_cue("split")
		_start_ken_burns()
		detail_caption.modulate.a = 1.0
		detail_no.modulate.a = 1.0
		return
	_play_cue("pull")
	_flip_in(dir)

## 方向感翻页:金光先扫过,画片从挥动方向滑入(带回弹),批注同步滑入。
func _flip_in(dir: int) -> void:
	if flip_tween:
		flip_tween.kill()
	flip_holder.pivot_offset = flip_holder.size * 0.5
	flip_holder.position = Vector2(dir * 560.0, 0.0)
	flip_holder.rotation = dir * 0.07
	flip_holder.modulate.a = 0.0
	detail_caption.modulate.a = 0.0
	detail_no.modulate.a = 0.0
	flip_tween = create_tween()
	flip_tween.set_parallel(true)
	flip_tween.tween_property(flip_holder, "position", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flip_tween.tween_property(flip_holder, "rotation", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flip_tween.tween_property(flip_holder, "modulate:a", 1.0, 0.18)
	flip_tween.tween_property(detail_caption, "modulate:a", 1.0, 0.24).set_delay(0.08)
	flip_tween.tween_property(detail_no, "modulate:a", 1.0, 0.24).set_delay(0.12)
	_sweep(dir)

## 金光扫过:一道细金光沿挥动方向横掠画面。
func _sweep(dir: int) -> void:
	if sweep_tween:
		sweep_tween.kill()
	var width := flip_holder.size.x
	sweep.position = Vector2(-12.0 if dir > 0 else width + 12.0, 0.0)
	sweep.size.y = flip_holder.size.y
	sweep.color.a = 0.75
	sweep_tween = create_tween()
	sweep_tween.set_parallel(true)
	sweep_tween.tween_property(sweep, "position:x", width + 12.0 if dir > 0 else -12.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	sweep_tween.tween_property(sweep, "color:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## Ken Burns:极慢的推近拉远,让画"活"过来。
func _start_ken_burns() -> void:
	if zoom_tween:
		zoom_tween.kill()
	detail_image.pivot_offset = detail_image.size * 0.5
	detail_image.scale = Vector2.ONE
	zoom_tween = create_tween()
	zoom_tween.set_loops()
	zoom_tween.tween_property(detail_image, "scale", Vector2(1.05, 1.05), 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	zoom_tween.tween_property(detail_image, "scale", Vector2.ONE, 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _step_detail(dir: int) -> void:
	var next := wrapi(detail_index + dir, 0, artworks.size())
	_show_detail(next, dir)

func _process(delta: float) -> void:
	if not visible:
		return
	open_time += delta
	if input_state == null or not detail.visible:
		return
	_tick_gesture_flip(delta)

## 视觉识别翻页:挥手快翻 + 手悬停左右缘连续翻。
func _tick_gesture_flip(delta: float) -> void:
	if not input_state.is_vision_driven() or open_time < 0.4:
		return
	swipe_cooldown = maxf(swipe_cooldown - delta, 0.0)
	var px: float = input_state.pointer.x
	# 边缘驻留连翻:手停在左/右缘,先驻留再每 0.3 秒翻一张。
	var want := 0
	if px < EDGE_ZONE:
		want = -1
	elif px > 1.0 - EDGE_ZONE:
		want = 1
	if want != 0 and want == edge_dir:
		edge_time += delta
		repeat_timer -= delta
		if edge_time >= EDGE_DWELL and repeat_timer <= 0.0:
			_step_detail(want)
			repeat_timer = EDGE_REPEAT
			swipe_samples.clear()
			return
	else:
		edge_dir = want
		edge_time = 0.0
		repeat_timer = 0.0
	# 挥手检测:窗口内横移超阈值即翻,方向 = 挥动方向。
	if want == 0 and swipe_cooldown <= 0.0:
		swipe_samples.append(Vector2(open_time, px))
		while swipe_samples.size() > 1 and open_time - swipe_samples[0].x > SWIPE_WINDOW:
			swipe_samples.remove_at(0)
		if swipe_samples.size() >= 2:
			var dx: float = swipe_samples[swipe_samples.size() - 1].y - swipe_samples[0].y
			if absf(dx) >= SWIPE_DISTANCE:
				_step_detail(1 if dx > 0.0 else -1)
				swipe_cooldown = SWIPE_COOLDOWN
				swipe_samples.clear()
	else:
		swipe_samples.clear()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if detail.visible:
				detail.visible = false
			else:
				close()
		elif event.is_action_pressed("interact") and detail.visible:
			get_viewport().set_input_as_handled()
			detail.visible = false
		elif detail.visible and (event.is_action_pressed("move_left") or event.keycode == KEY_LEFT):
			get_viewport().set_input_as_handled()
			_step_detail(-1)
		elif detail.visible and (event.is_action_pressed("move_right") or event.keycode == KEY_RIGHT):
			get_viewport().set_input_as_handled()
			_step_detail(1)
