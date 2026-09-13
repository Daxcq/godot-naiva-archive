extends Node3D
## 奶蛙影院：长廊后段的可编辑电影机入口与全屏放映页。

const UIKit := preload("res://scripts/ui_kit.gd")
const CINEMA_POS := Vector3(29.5, 0.0, 1.55)
const NEAR_DISTANCE := 2.8
## 今日放映：完整播放俊博提供的《影院视频》（27s，960 宽 Theora）。
## Godot 4.6 原生只支持 Theora(.ogv)，mp4 无 loader（实测 No loader found）。
const FEATURE := "res://assets/video/cinema_feature.ogv"
const FALLBACK_OGV := "res://assets/video/clip_rooftop.ogv"

var world: Node3D
var router: Node
var active := false
var open := false
var pulse := 0.0
var layer: CanvasLayer
var player: VideoStreamPlayer
var status: Label
var lens: StandardMaterial3D

func setup(owner: Node3D) -> void:
	world = owner
	router = owner.get_node_or_null("InteractionRouter")
	_build_model()
	_build_ui()
	set_active(false)

func _build_model() -> void:
	var body := Color("17152b")
	_box("Plinth", Vector3(0,0.12,0), Vector3(4.8,0.24,1.0), body)
	_box("Cabinet", Vector3(0,1.05,0), Vector3(3.4,1.9,0.68), Color("28224b"))
	_box("ScreenFrame", Vector3(0,2.42,-0.38), Vector3(3.0,1.25,0.12), Color("090817"))
	_box("ScreenGlow", Vector3(0,2.42,-0.45), Vector3(2.7,1.0,0.03), Color("25205d"), 1.2)
	_box("ProjectorTop", Vector3(0,2.25,0.42), Vector3(1.6,0.35,0.55), Color("3b2e69"))
	var lens_mesh := SphereMesh.new(); lens_mesh.radius = 0.22; lens_mesh.height = 0.44
	var lens_node := MeshInstance3D.new(); lens_node.name = "ProjectorLens"; lens_node.mesh = lens_mesh; lens_node.position = Vector3(0,2.25,0.74)
	lens = StandardMaterial3D.new(); lens.albedo_color = Color("9cecff"); lens.emission_enabled = true; lens.emission = Color("46c9ff"); lens.emission_energy_multiplier = 2.0; lens_node.material_override = lens; add_child(lens_node)
	var light := OmniLight3D.new(); light.position = Vector3(0,2.25,1.0); light.light_color = Color("62d9ff"); light.light_energy = 1.2; light.omni_range = 4.5; add_child(light)
	var sign := Label3D.new(); sign.text = "奶 蛙 影 院"; sign.position = Vector3(0,3.42,0); sign.font_size = 52; sign.pixel_size = 0.005; sign.modulate = Color("ffd88a"); add_child(sign)
	var sub := Label3D.new(); sub.text = "按 E 进入 · 今日放映"; sub.position = Vector3(0,3.12,0); sub.font_size = 18; sub.pixel_size = 0.005; sub.modulate = UIKit.DIM; add_child(sub)
	_box("CurtainL", Vector3(-1.63,2.35,-0.3), Vector3(0.16,1.65,0.16), Color("b52868"), 0.6)
	_box("CurtainR", Vector3(1.63,2.35,-0.3), Vector3(0.16,1.65,0.16), Color("b52868"), 0.6)

func _box(n: String, at: Vector3, size: Vector3, color: Color, emission := 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.name = n; node.position = at
	var mesh := BoxMesh.new(); mesh.size = size; node.mesh = mesh
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.roughness = 0.5
	if emission > 0.0: mat.emission_enabled = true; mat.emission = color; mat.emission_energy_multiplier = emission
	node.material_override = mat; add_child(node); return node

func _build_ui() -> void:
	layer = CanvasLayer.new(); layer.name = "CinemaLayer"; layer.layer = 110; layer.visible = false; world.add_child(layer)
	var dim := ColorRect.new(); dim.color = Color(0.015,0.01,0.04,0.96); dim.set_anchors_preset(Control.PRESET_FULL_RECT); layer.add_child(dim)
	var title := Label.new(); title.text = "奶 蛙 影 院"; title.position = Vector2(0,42); title.size = Vector2(1280,52); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size",40); title.add_theme_color_override("font_color",Color("ffd88a")); layer.add_child(title)
	var sub := Label.new(); sub.text = "放映厅 01  ·  这一刻，暂停翻档"; sub.position = Vector2(0,96); sub.size = Vector2(1280,30); sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; sub.add_theme_color_override("font_color",UIKit.DIM); layer.add_child(sub)
	var stage := Panel.new(); stage.position = Vector2(160,145); stage.size = Vector2(960,480); stage.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.03,0.02,0.09,1),Color("62d9ff"),12,2)); layer.add_child(stage)
	player = VideoStreamPlayer.new(); player.expand = true; player.set_anchors_preset(Control.PRESET_FULL_RECT); player.visible = false; stage.add_child(player); player.finished.connect(_on_finished)
	status = Label.new(); status.position = Vector2(0,210); status.size = Vector2(960,140); status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; status.add_theme_font_size_override("font_size",24); status.add_theme_color_override("font_color",UIKit.MILK); status.visible = false; stage.add_child(status)
	var hint := Label.new(); hint.text = "E / 握拳  播放 / 暂停     ESC 或张开手掌离开放映厅"; hint.position = Vector2(0,660); hint.size = Vector2(1280,32); hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hint.add_theme_color_override("font_color",UIKit.DIM); layer.add_child(hint)

func set_active(value: bool) -> void:
	active = value; visible = value; set_process(value)
	if not value and open: _close()

func _process(delta: float) -> void:
	if not active or world == null: return
	pulse += delta
	if lens: lens.emission_energy_multiplier = 1.6 + sin(pulse * 3.0) * 0.45
	if open:
		if router: router.offer("cinema", "", 0.0, "", 9, true)
		var inp: Node = world.input_state
		if inp and inp.is_vision_driven():
			if inp.cancel_just_pressed: _close()
			elif inp.confirm_just_pressed and inp.consume_confirm(): _toggle()
		return
	var d: float = world.player.position.distance_to(CINEMA_POS)
	if d < NEAR_DISTANCE and router: router.offer("cinema", "进入奶蛙影院 · 今日放映", d, "E")
	var inp2: Node = world.input_state
	if inp2 and inp2.is_vision_driven() and inp2.confirm_just_pressed and inp2.consume_confirm() and d < NEAR_DISTANCE: _open()

func _unhandled_input(event: InputEvent) -> void:
	if not active or not (event is InputEventKey and event.pressed and not event.echo): return
	if open:
		if event.keycode == KEY_ESCAPE: _close(); get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact"): _toggle(); get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and world.player.position.distance_to(CINEMA_POS) < NEAR_DISTANCE: _open(); get_viewport().set_input_as_handled()

func _open() -> void:
	if open or world.board_active: return
	open = true; world.board_active = true; layer.visible = true; _play_feature()

func _close() -> void:
	if not open: return
	player.stop(); player.visible = false; open = false; world.board_active = false; layer.visible = false

func _play_feature() -> void:
	var stream := load(FEATURE) as VideoStream
	if stream == null:
		stream = load(FALLBACK_OGV) as VideoStream
	if stream: player.stream = stream; player.visible = true; player.play()

func _toggle() -> void:
	if player.stream: player.paused = not player.paused

func _on_finished() -> void:
	if open: _play_feature()
