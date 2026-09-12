extends Node3D
## 纯文字档案站：把走廊里的装饰文字变成可阅读、可切换的内容节点。

const UIKit := preload("res://scripts/ui_kit.gd")
const STATION_POS := Vector3(26.2, 0.0, 1.45)
const NEAR_DISTANCE := 2.5
const ENTRIES := [
	{"year":"2016", "title":"第一次被看见", "body":"那条短视频只有十几秒。\n没有精心布景，也没有准备好的台词。\n有人在评论区写：\n\n“我今天也这样，先笑一下再说。”\n\n于是一个陌生人，把自己的坏心情借给了大家。"},
	{"year":"2020", "title":"所有人都在重复", "body":"动作被拆成拍子，拍子被做成模板。\n\n第一个人留下了原版，\n第二个人留下了模仿，\n后来的人只记住了滤镜。\n\n可模仿不是偷走。\n它也证明：那一秒真的传到过别人那里。"},
	{"year":"2024", "title":"被覆盖以后", "body":"热搜刷新得很快。\n昨天的名字，今天已经沉到底部。\n\n档案馆不负责让谁永远流行，\n这里只负责把发生过的事留一盏灯。\n\n被忘记，不等于没有发生。"},
	{"year":"附录", "title":"给后来的人", "body":"如果你也曾经突然被很多人看见，\n请记得把自己的名字写回来。\n\n如果你从来没有被看见，\n也请不要把沉默当成证据。\n\n你经历过的那一刻，已经足够真实。"},
]

var world: Node3D
var router: Node
var active := false
var open := false
var index := 0
var layer: CanvasLayer
var page: Label
var page_title: Label
var page_year: Label
var marker_mat: StandardMaterial3D
var glow_time := 0.0

func setup(owner: Node3D) -> void:
	world = owner
	router = owner.get_node_or_null("InteractionRouter")
	_build_model()
	_build_ui()
	set_active(false)

func _build_model() -> void:
	_box("Base", Vector3(0,0.12,0), Vector3(2.8,0.24,0.72), Color("16152a"))
	_box("Cabinet", Vector3(0,1.15,0), Vector3(2.15,2.1,0.48), Color("28234a"))
	_box("PaperSlot", Vector3(0,1.35,0.29), Vector3(1.65,1.15,0.035), Color("efe4c4"))
	_box("Header", Vector3(0,2.45,0.29), Vector3(1.7,0.32,0.04), Color("3ee6ff"), 1.2)
	var sign := Label3D.new(); sign.text = "文字档案"; sign.position = Vector3(0,2.48,0.36); sign.font_size = 34; sign.pixel_size = 0.005; sign.modulate = Color("baf7ff"); add_child(sign)
	var sub := Label3D.new(); sub.text = "四段被留下的声音"; sub.position = Vector3(0,2.16,0.32); sub.font_size = 17; sub.pixel_size = 0.005; sub.modulate = UIKit.DIM; add_child(sub)
	var marker := MeshInstance3D.new(); marker.name = "ReadMarker"; marker.position = Vector3(0,0.4,0.38); var mesh := CylinderMesh.new(); mesh.top_radius = 0.18; mesh.bottom_radius = 0.18; mesh.height = 0.05; marker.mesh = mesh; marker_mat = StandardMaterial3D.new(); marker_mat.albedo_color = Color("ffd88a"); marker_mat.emission_enabled = true; marker_mat.emission = marker_mat.albedo_color; marker_mat.emission_energy_multiplier = 1.5; marker.material_override = marker_mat; add_child(marker)

func _box(n: String, at: Vector3, size: Vector3, color: Color, emission := 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.name = n; node.position = at; var mesh := BoxMesh.new(); mesh.size = size; node.mesh = mesh; var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.roughness = 0.6
	if emission > 0.0: mat.emission_enabled = true; mat.emission = color; mat.emission_energy_multiplier = emission
	node.material_override = mat; add_child(node); return node

func _build_ui() -> void:
	layer = CanvasLayer.new(); layer.name = "TextArchiveLayer"; layer.layer = 105; layer.visible = false; world.add_child(layer)
	var dim := ColorRect.new(); dim.color = Color(0.012,0.01,0.035,0.95); dim.set_anchors_preset(Control.PRESET_FULL_RECT); layer.add_child(dim)
	var frame := Panel.new(); frame.position = Vector2(230,105); frame.size = Vector2(820,550); frame.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.04,0.035,0.1,0.98),Color("3ee6ff"),10,2)); layer.add_child(frame)
	page_year = Label.new(); page_year.position = Vector2(50,38); page_year.size = Vector2(720,42); page_year.add_theme_font_size_override("font_size",18); page_year.add_theme_color_override("font_color",Color("3ee6ff")); frame.add_child(page_year)
	page_title = Label.new(); page_title.position = Vector2(50,76); page_title.size = Vector2(720,56); page_title.add_theme_font_size_override("font_size",32); page_title.add_theme_color_override("font_color",Color("ffd88a")); frame.add_child(page_title)
	page = Label.new(); page.position = Vector2(50,160); page.size = Vector2(720,300); page.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; page.add_theme_font_size_override("font_size",22); page.add_theme_color_override("font_color",UIKit.MILK); frame.add_child(page)
	var hint := Label.new(); hint.text = "A / D 阅读上一段 / 下一段     E 或 ESC 合上档案"; hint.position = Vector2(0,690); hint.size = Vector2(1280,30); hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hint.add_theme_color_override("font_color",UIKit.DIM); layer.add_child(hint)

func set_active(value: bool) -> void:
	active = value; visible = value; set_process(value)
	if not value and open: _close()

func _process(delta: float) -> void:
	if not active or world == null: return
	glow_time += delta
	if marker_mat: marker_mat.emission_energy_multiplier = 1.4 + sin(glow_time * 2.5) * 0.35
	if open:
		if router: router.offer("text_archive", "", 0.0, "", 9, true)
		var inp: Node = world.input_state
		if inp and inp.is_vision_driven() and inp.cancel_just_pressed: _close()
		return
	var d: float = world.player.position.distance_to(STATION_POS)
	if d < NEAR_DISTANCE and router: router.offer("text_archive", "翻阅文字档案 · 4 段记忆", d, "E")
	var inp2: Node = world.input_state
	if inp2 and inp2.is_vision_driven() and inp2.confirm_just_pressed and inp2.consume_confirm() and d < NEAR_DISTANCE: _open()

func _unhandled_input(event: InputEvent) -> void:
	if not active or not (event is InputEventKey and event.pressed and not event.echo): return
	if open:
		if event.keycode == KEY_ESCAPE: _close(); get_viewport().set_input_as_handled()
		elif event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
			index = wrapi(index + (-1 if event.is_action_pressed("move_left") else 1), 0, ENTRIES.size()); _show_entry(); get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact"): _close(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and world.player.position.distance_to(STATION_POS) < NEAR_DISTANCE:
		_open(); get_viewport().set_input_as_handled()

func _open() -> void:
	if open or world.board_active: return
	open = true; world.board_active = true; layer.visible = true; _show_entry()

func _close() -> void:
	if not open: return
	open = false; world.board_active = false; layer.visible = false

func _show_entry() -> void:
	var entry: Dictionary = ENTRIES[index]
	page_year.text = "%s  /  TEXT ARCHIVE  %d / %d" % [String(entry.year), index + 1, ENTRIES.size()]
	page_title.text = String(entry.title)
	page.text = String(entry.body)
