extends Node
## 奶娃展板「幸福碎片」：档案走廊南墙上的立式视频展板。
##
## 参考抖音「揭开藏在生活中的小幸福」的互动意象：
## 待机时展板上是六格微光小窗轮番呼吸；走近按 E 揭开全屏板面，
## A/D 挑一块碎片，E 播放对应视频，每块碎片配一句"小幸福"文案。
## 播放用的是 Godot 原生 Theora(.ogv)，素材由 ffmpeg 裁剪转码。
##
## 与 gallery_easel（奶娃画廊·图片画架）共用 world.board_active
## 冻结通道——任何一块全屏板打开时，main.gd 都冻结角色移动，
## 两个系统也天然互斥（打开前检查通道未被占用）。

signal board_started
signal board_closed

const UIKit := preload("res://scripts/ui_kit.gd")

const BOARD_POS := Vector3(11.4, 0.0, 1.95)
const BOARD_YAW := PI          # 南墙,面朝走廊(北)
const NEAR_DISTANCE := 2.6
const CELLS_ACROSS := 3

## 六块幸福碎片。时长/文案/主色随内容定;
## 视频统一 640 宽 ogv,由 assets/video 下的裁剪产物提供。
const CLIPS := [
	{
		"id": "star", "title": "星月夜", "file": "res://assets/video/clip_star.ogv",
		"caption": "偶尔，也允许自己飘进一片星空。",
		"accent": "3ee6ff",
	},
	{
		"id": "night", "title": "夜 路", "file": "res://assets/video/clip_night.ogv",
		"caption": "晚风免费，路灯也是。",
		"accent": "ffb45e",
	},
	{
		"id": "rooftop", "title": "天台摇摆", "file": "res://assets/video/clip_rooftop.ogv",
		"caption": "和朋友一起犯傻，是最便宜的幸福。",
		"accent": "ffd9a0",
	},
	{
		"id": "dance", "title": "认 真 跳", "file": "res://assets/video/clip_dance.ogv",
		"caption": "没人看的时候，也要认真跳舞。",
		"accent": "ff4fd8",
	},
	{
		"id": "street", "title": "夜 街", "file": "res://assets/video/clip_street.ogv",
		"caption": "不会跳也没关系，节奏会等你。",
		"accent": "b26bff",
	},
	{
		"id": "strong", "title": "变 强", "file": "res://assets/video/clip_strong.ogv",
		"caption": "在变得更强之前，先抱臂三秒。",
		"accent": "5cff6e",
	},
]

var world: Node3D
var router: Node
var active := false
var board_open := false
var playing_index := -1
var cell_index := 0
var cells_root: Node3D
var cell_mats: Array[StandardMaterial3D] = []
var layer: CanvasLayer
var dim: ColorRect
var headline: Label
var subline: Label
var stage: Panel
var player: VideoStreamPlayer
var caption: Label
var cells_ui: Array[Panel] = []
var idle_time := 0.0

func setup(owner: Node3D) -> void:
	world = owner
	router = owner.get_node_or_null("InteractionRouter")
	_build_board()
	_build_ui()
	set_active(false)

# ---------- 3D 装置 ----------

func _build_board() -> void:
	var root := Node3D.new()
	root.name = "DisplayBoard"
	root.position = BOARD_POS
	root.rotation.y = BOARD_YAW
	world.archive_root.add_child(root)

	var body_color := Color("171034")
	_box(root, "Base", Vector3(0, 0.12, 0), Vector3(2.9, 0.24, 0.5), body_color)
	_box(root, "Pylon", Vector3(0, 0.85, -0.1), Vector3(0.4, 1.4, 0.28), body_color)
	# 板身与内衬,留出屏幕凹陷。
	_box(root, "Frame", Vector3(0, 2.05, 0), Vector3(2.7, 1.75, 0.14), Color("241a4d"))
	_box(root, "Bezel", Vector3(0, 2.05, 0.085), Vector3(2.56, 1.6, 0.03), Color("0b0618"))
	# 六格微光小窗:待机时轮番呼吸,像一排小橱窗。
	cells_root = Node3D.new()
	cells_root.name = "Cells"
	root.add_child(cells_root)
	for i in range(CLIPS.size()):
		var col := i % CELLS_ACROSS
		var row := i / CELLS_ACROSS
		var accent := Color(String(CLIPS[i].accent))
		var cell := _box(cells_root, "Cell%d" % i,
			Vector3(-0.82 + col * 0.82, 2.38 - row * 0.66, 0.11),
			Vector3(0.72, 0.5, 0.02),
			accent.darkened(0.72), 0.8)
		cell_mats.append(cell.material_override as StandardMaterial3D)
	# 招牌。
	var sign := Label3D.new()
	sign.text = "奶 娃 展 板"
	sign.position = Vector3(0, 3.18, 0.05)
	sign.font_size = 44
	sign.pixel_size = 0.005
	sign.modulate = Color("ffd9a0")
	root.add_child(sign)
	var sub := Label3D.new()
	sub.text = "生活小幸福 · 走近揭开"
	sub.position = Vector3(0, 2.95, 0.05)
	sub.font_size = 17
	sub.pixel_size = 0.005
	sub.modulate = UIKit.DIM
	root.add_child(sub)
	var glow := OmniLight3D.new()
	glow.name = "BoardGlow"
	glow.position = Vector3(0, 2.3, 1.0)
	glow.light_color = Color("ffd9a0")
	glow.light_energy = 0.9
	glow.omni_range = 3.4
	root.add_child(glow)

func _box(parent: Node3D, title: String, at: Vector3, size: Vector3, color: Color, emission := 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = title
	node.position = at
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.55
	mat.metallic = 0.3
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = Color(color.r, color.g, color.b)
		mat.emission_energy_multiplier = emission
	node.material_override = mat
	parent.add_child(node)
	return node

# ---------- 全屏 UI ----------

func _build_ui() -> void:
	layer = CanvasLayer.new()
	layer.name = "DisplayBoardLayer"
	layer.layer = 95   # 压过 Interface/VisionPreview 等默认层 HUD,保证全屏板最顶。
	layer.visible = false
	world.add_child(layer)

	dim = ColorRect.new()
	dim.color = Color(0.01, 0.005, 0.03, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	headline = Label.new()
	headline.text = "奶 娃 幸 福 碎 片"
	headline.add_theme_font_size_override("font_size", 40)
	headline.add_theme_color_override("font_color", Color("ffd9a0"))
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.set_anchors_preset(Control.PRESET_TOP_WIDE)
	headline.position.y = 52
	layer.add_child(headline)

	subline = Label.new()
	subline.text = "—— 揭开藏在生活里的小幸福 ——"
	subline.add_theme_font_size_override("font_size", 17)
	subline.add_theme_color_override("font_color", UIKit.DIM)
	subline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subline.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subline.position.y = 106
	layer.add_child(subline)

	# 中央播放舞台。
	stage = Panel.new()
	stage.name = "Stage"
	var style := UIKit.panel_style(Color(0.03, 0.02, 0.09, 0.96), Color(1.0, 0.85, 0.55, 0.5), 10, 2)
	stage.add_theme_stylebox_override("panel", style)
	stage.size = Vector2(880, 450)
	stage.position = Vector2((1280.0 - 880.0) / 2.0, 134)
	layer.add_child(stage)

	player = VideoStreamPlayer.new()
	player.name = "Player"
	player.set_anchors_preset(Control.PRESET_FULL_RECT)
	player.expand = true
	player.visible = false
	stage.add_child(player)
	player.finished.connect(_on_clip_finished)

	# 待机提示(播放器空闲时显示)。
	var idle_hint := Label.new()
	idle_hint.name = "IdleHint"
	idle_hint.text = "\n\n选择一块碎片 · A / D 移动 · E 播放"
	idle_hint.add_theme_font_size_override("font_size", 22)
	idle_hint.add_theme_color_override("font_color", UIKit.DIM)
	idle_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	idle_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(idle_hint)

	caption = Label.new()
	caption.name = "Caption"
	caption.add_theme_font_size_override("font_size", 21)
	caption.add_theme_color_override("font_color", UIKit.MILK)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.set_anchors_preset(Control.PRESET_TOP_WIDE)
	caption.position.y = 596
	layer.add_child(caption)

	# 底部碎片选择格。
	for i in range(CLIPS.size()):
		var spec: Dictionary = CLIPS[i]
		var cell := Panel.new()
		# 单行六格横向居中:6*176 + 5*24 = 1176,起点 (1280-1176)/2 = 52。
		cell.name = "Chip%d" % i
		cell.size = Vector2(176, 52)
		cell.position = Vector2(52 + i * 200, 640)
		cell.add_theme_stylebox_override("panel", UIKit.capsule_style())
		layer.add_child(cell)
		var tag := Label.new()
		tag.text = "%d · %s" % [i + 1, String(spec.title)]
		tag.add_theme_font_size_override("font_size", 16)
		tag.add_theme_color_override("font_color", Color(String(spec.accent)))
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.set_anchors_preset(Control.PRESET_FULL_RECT)
		cell.add_child(tag)
		cells_ui.append(cell)

	var hint := Label.new()
	hint.text = "ESC / 张开手掌  合上展板"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", UIKit.DIM)
	hint.position = Vector2(24, 20)
	layer.add_child(hint)

# ---------- 状态与交互 ----------

func set_active(value: bool) -> void:
	active = value
	set_process(value)
	if not value and board_open:
		_close_board()

func _process(delta: float) -> void:
	if not active or world == null:
		return
	idle_time += delta
	# 待机小窗呼吸:未播放时六格轮番微光,播放哪块哪块常亮。
	for i in range(cell_mats.size()):
		var mat := cell_mats[i]
		var pulse := 0.55 + sin(idle_time * 2.1 + i * 1.05) * 0.35
		mat.emission_energy_multiplier = 1.25 if i == playing_index else pulse
	if board_open:
		if router:
			router.offer("board", "", 0.0, "", 9, true)
		_sync_chip_styles()
		# 手势:张开手掌合板(播放中也允许)。
		var input_state: Node = world.input_state
		if input_state != null and input_state.is_vision_driven() and input_state.cancel_just_pressed:
			_close_board()
		return
	var distance: float = world.player.position.distance_to(BOARD_POS)
	if distance < NEAR_DISTANCE and router:
		router.offer("board", "揭开奶娃展板 · %d 块幸福碎片" % CLIPS.size(), distance, "E")
	var gesture: Node = world.input_state
	if gesture != null and gesture.is_vision_driven() and gesture.confirm_just_pressed and gesture.consume_confirm():
		if distance < NEAR_DISTANCE and (router == null or router.can_interact("board")):
			_open_board()

func _unhandled_input(event: InputEvent) -> void:
	if not active or world == null:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if board_open:
		if event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
			var dir := -1 if event.is_action_pressed("move_left") else 1
			cell_index = wrapi(cell_index + dir, 0, CLIPS.size())
			if playing_index >= 0:
				_stop_clip()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact"):
			get_viewport().set_input_as_handled()
			if playing_index >= 0:
				_stop_clip()
			else:
				_play_clip(cell_index)
		elif event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_close_board()
		return
	if event.is_action_pressed("interact"):
		var distance: float = world.player.position.distance_to(BOARD_POS)
		if distance < NEAR_DISTANCE and (router == null or router.can_interact("board")):
			get_viewport().set_input_as_handled()
			_open_board()

func _open_board() -> void:
	if board_open or world.board_active:
		return
	board_open = true
	world.board_active = true
	cell_index = maxi(cell_index, 0)
	playing_index = -1
	_show_idle()
	layer.visible = true
	board_started.emit()

func _close_board() -> void:
	if not board_open:
		return
	_stop_clip()
	board_open = false
	world.board_active = false
	layer.visible = false
	board_closed.emit()

func _play_clip(index: int) -> void:
	if index < 0 or index >= CLIPS.size():
		return
	var spec: Dictionary = CLIPS[index]
	var stream := load(String(spec.file)) as VideoStream
	if stream == null:
		push_warning("碎片视频缺失: %s" % String(spec.file))
		return
	playing_index = index
	cell_index = index
	player.stream = stream
	player.visible = true
	player.play()
	caption.text = "「%s」  %s" % [String(spec.title), String(spec.caption)]
	stage.get_node("IdleHint").visible = false

func _stop_clip() -> void:
	if playing_index < 0:
		return
	player.stop()
	player.visible = false
	playing_index = -1
	_show_idle()

func _on_clip_finished() -> void:
	_stop_clip()

func _show_idle() -> void:
	player.visible = false
	stage.get_node("IdleHint").visible = true
	caption.text = ""

func _sync_chip_styles() -> void:
	for i in range(cells_ui.size()):
		var selected := i == cell_index and playing_index < 0
		var playing := i == playing_index
		var accent := Color(String(CLIPS[i].accent))
		var border := accent if (selected or playing) else UIKit.BORDER_DIM
		var bg := Color(0.05, 0.04, 0.14, 0.95) if (selected or playing) else UIKit.INK
		cells_ui[i].add_theme_stylebox_override("panel", UIKit.capsule_style(bg, border))
