extends Node3D
## 奶娃画廊·画架。造型来自场景资产 scenes/gallery_easel.tscn(靠墙摆放),
## 本脚本只负责:画作轮播、靠近提示、E/握拳打开画廊、浏览期锁焦点。
## 画布材质在场景里(Canvas 节点的 material_override),这里换贴图即可。

const UIKit := preload("res://scripts/ui_kit.gd")
const ART_DIR := "res://assets/artworks"
## 触发半径 1.8:画架摆南墙 (7.9,1.55) 朝北(见 archive_space.tscn GalleryEasel)。
## 北墙已被蛇机(5.2,r2.4)/记忆点2(11.4,r3.2)/方块机(17.6,r2.4)的圈排满,
## r1.8 在北墙无解(档案员圈把窗口夹死);南墙 7.9 是全局唯一两侧余量>=0.3 的点:
## 对蛇机余 0.30、对记忆点2 余 0.35、对袋鼠余 2.9。改位置前先跑 check_interaction_map.gd。
const NEAR_DISTANCE := 1.8
const SLIDE_INTERVAL := 4.2

@onready var canvas: MeshInstance3D = $Canvas
@onready var glow_light: OmniLight3D = $PictureLight

var world: Node3D
var router: Node
var active := false
var board_open := false
var artworks: Array[Texture2D] = []
var board: Control
var board_layer: CanvasLayer
var screen_mat: StandardMaterial3D
var slide_time := 0.0
var slide_index := 0
var slide_fade := 1.0
var sfx: AudioStreamPlayer

func setup(owner_world: Node3D) -> void:
	world = owner_world
	router = world.get_node_or_null("InteractionRouter")
	_load_artworks()
	# 防御:setup 可能在进树前被测试框架调用,@onready 还没解析。
	if canvas == null:
		canvas = get_node_or_null("Canvas") as MeshInstance3D
	if glow_light == null:
		glow_light = get_node_or_null("PictureLight") as OmniLight3D
	if canvas != null:
		screen_mat = canvas.get_material_override() as StandardMaterial3D
		if not artworks.is_empty() and screen_mat != null:
			screen_mat.albedo_texture = artworks[0]
			screen_mat.emission_texture = artworks[0]
	board_layer = CanvasLayer.new()
	board_layer.name = "GalleryBoardLayer"
	board_layer.layer = 20
	board_layer.visible = false
	add_child(board_layer)
	board = preload("res://scripts/gallery_board.gd").new()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	board_layer.add_child(board)
	board.closed.connect(_close_board)
	board.setup(artworks, world.input_state)
	sfx = AudioStreamPlayer.new()
	sfx.volume_db = -8.0
	add_child(sfx)

func set_active(value: bool) -> void:
	active = value
	set_process(value)
	visible = value
	if not value and board_open:
		_close_board()

func _load_artworks() -> void:
	var dir := DirAccess.open(ART_DIR)
	if dir == null:
		push_warning("画板图片目录缺失: %s" % ART_DIR)
		return
	var names: Array[String] = []
	for file in dir.get_files():
		if file.ends_with(".jpg") or file.ends_with(".jpeg") or file.ends_with(".png"):
			names.append(file)
	names.sort()
	for file_name in names:
		var tex := load("%s/%s" % [ART_DIR, file_name]) as Texture2D
		if tex != null:
			artworks.append(tex)
	if artworks.is_empty():
		push_warning("画廊没有可用图片,画架只展示空画布")

func _process(delta: float) -> void:
	if world.arcade_active or world.board_active:
		return
	_tick_slideshow(delta)
	if board_open:
		# 浏览中锁住交互焦点,其他系统的提示/按键全部让位。
		if router:
			router.offer("easel", "", 0.0, "", 9, true)
		return
	var distance: float = world.player.position.distance_to(global_position)
	if distance < NEAR_DISTANCE and router:
		router.offer("easel", "翻开奶娃画廊 · %d 幅" % artworks.size(), distance, "E")
	# 手势:握拳翻画板。
	var input_state: Node = world.input_state
	if input_state != null and input_state.is_vision_driven() and input_state.confirm_just_pressed and input_state.consume_confirm():
		if distance < NEAR_DISTANCE and (router == null or router.can_interact("easel")):
			_open_board()

## 画布轮播:换画瞬间灯光压暗再亮起,像展馆换展。
func _tick_slideshow(delta: float) -> void:
	if artworks.is_empty() or screen_mat == null:
		return
	slide_time += delta
	if slide_time >= SLIDE_INTERVAL:
		slide_time = 0.0
		slide_index = (slide_index + 1) % artworks.size()
		var tex: Texture2D = artworks[slide_index]
		screen_mat.albedo_texture = tex
		screen_mat.emission_texture = tex
		slide_fade = 0.25
	slide_fade = minf(slide_fade + delta * 1.6, 1.0)
	var pulse := 0.5 + sin(Time.get_ticks_msec() * 0.0016) * 0.06
	screen_mat.emission_energy_multiplier = pulse * slide_fade
	if glow_light != null:
		glow_light.light_energy = 0.85 * slide_fade

func _unhandled_input(event: InputEvent) -> void:
	if not active or board_open or world == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("interact"):
			var distance: float = world.player.position.distance_to(global_position)
			if distance < NEAR_DISTANCE and (router == null or router.can_interact("easel")):
				get_viewport().set_input_as_handled()
				_open_board()

func _open_board() -> void:
	if artworks.is_empty():
		return
	board_open = true
	world.board_active = true
	board_layer.visible = true
	sfx.stream = load("res://assets/audio/signal.wav")
	sfx.play()
	board.open()

func _close_board() -> void:
	board_open = false
	world.board_active = false
	board_layer.visible = false
