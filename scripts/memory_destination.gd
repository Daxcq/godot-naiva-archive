extends Node3D
## 第一个记忆空间：平原游乐园。运行时程序化搭建，独立于旧的封闭房间。

var memory_id := ""
var title := "平原游乐园"
var interaction_position := Vector3(0, 1.0, -1.8)
var spawn_position := Vector3(0, 0.75, 7.0)
var return_position := Vector3(5.0, 1.0, 6.0)
var _player: CharacterBody3D
var _elapsed := 0.0
var _enabled := true
var _animated: Array[Node3D] = []
var _collectibles: Array[Node3D] = []
var _collected := 0
var _collection_label: Label3D
var _status_label: Label3D
var _hotspots: Array[Dictionary] = []
var _completion_beacon: Node3D

func setup(id: String) -> void:
	memory_id = id
	_player = get_parent().get_node_or_null("MilkFrog") as CharacterBody3D
	_build_playground()

func _process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if not _enabled: return
	_elapsed += delta
	for i in range(_animated.size()):
		var item := _animated[i]
		if is_instance_valid(item): item.rotation.y += delta * (0.18 + i * 0.008)
	if _player == null: return
	for token in _collectibles:
		if is_instance_valid(token) and not token.get_meta("collected", false) and token.global_position.distance_to(_player.global_position) < 1.25:
			token.set_meta("collected", true); token.visible = false; _collected += 1
			_collection_label.text = "热梗票根  %d / %d" % [_collected, _collectibles.size()]
			if _collected >= _collectibles.size():
				_status_label.text = "收集完成：广场中央的彩虹灯亮了"
				_completion_beacon.visible = true

func set_completed() -> void:
	for token in _collectibles:
		if is_instance_valid(token): token.scale = Vector3.ONE * 1.18

func set_enabled(value: bool) -> void:
	_enabled = value; visible = value; set_process(value)

func get_prompt(local_pos: Vector3) -> String:
	if local_pos.distance_to(return_position) < 2.4: return "E 返回档案长廊"
	for hotspot in _hotspots:
		if local_pos.distance_to(hotspot.pos) < 2.0: return "E " + String(hotspot.text)
	return "" if _collected >= _collectibles.size() else "靠近彩色票根收集 · %d / %d" % [_collected, _collectibles.size()]

func interact(local_pos: Vector3) -> bool:
	for hotspot in _hotspots:
		if local_pos.distance_to(hotspot.pos) < 2.0:
			_status_label.text = String(hotspot.result); return true
	return false

func _build_playground() -> void:
	_box("Plaza", Vector3(0, -0.12, 0), Vector3(30, 0.24, 18), _mat(Color("d9c6a2"), 0.0), true)
	_box("GrassWest", Vector3(-11, 0.01, 0), Vector3(8, 0.06, 17), _mat(Color("72b978"), 0.0))
	_box("GrassEast", Vector3(11, 0.01, 0), Vector3(8, 0.06, 17), _mat(Color("72b978"), 0.0))
	_box("SkyDome", Vector3(0, 5.5, -9), Vector3(34, 11, 0.2), _mat(Color("96d8f5"), 0.0))
	_box("HorizonHill", Vector3(0, 1.6, -8.0), Vector3(34, 3.0, 0.4), _mat(Color("a5cf8a"), 0.0))
	_box("GateL", Vector3(-4.5, 2.5, 7.2), Vector3(0.3, 5.0, 0.45), _mat(Color("fff7dc"), 0.0), true)
	_box("GateR", Vector3(4.5, 2.5, 7.2), Vector3(0.3, 5.0, 0.45), _mat(Color("fff7dc"), 0.0), true)
	_box("GateTop", Vector3(0, 5.0, 7.2), Vector3(9.3, 0.35, 0.45), _mat(Color("f29b68"), 0.5))
	_label("平原游乐园", Vector3(0, 5.2, 6.9), Color("fff8dc"))
	_build_ferris_wheel(); _build_carousel(Vector3(-7, 0, -1.0)); _build_slide(Vector3(7, 0, -1.6)); _build_picnic_zone(); _build_trees(); _build_meme_stations(); _build_return_portal()
	_collection_label = Label3D.new(); _collection_label.text = "热梗票根  0 / 6"; _collection_label.position = Vector3(0, 6.2, -8.6); _collection_label.font_size = 30; _collection_label.pixel_size = 0.006; _collection_label.modulate = Color("fff6c7"); add_child(_collection_label)
	_status_label = Label3D.new(); _status_label.text = "在广场上寻找会发光的彩色票根"; _status_label.position = Vector3(0, 5.65, -8.6); _status_label.font_size = 22; _status_label.pixel_size = 0.005; _status_label.modulate = Color("ffffff"); add_child(_status_label)
	_completion_beacon = _box("CompletionBeacon", Vector3(0, 2.0, 0), Vector3(0.25, 4.0, 0.25), _mat(Color("ffdf70"), 2.0)); _completion_beacon.visible = false

func _build_ferris_wheel() -> void:
	_box("WheelLegL", Vector3(-3.0, 2.6, -4.0), Vector3(0.35, 5.2, 0.35), _mat(Color("718096"), 0.1), true); _box("WheelLegR", Vector3(3.0, 2.6, -4.0), Vector3(0.35, 5.2, 0.35), _mat(Color("718096"), 0.1), true)
	var wheel := MeshInstance3D.new(); wheel.name = "FerrisWheel"; wheel.position = Vector3(0, 5.2, -4.0); var torus := TorusMesh.new(); torus.inner_radius = 3.0; torus.outer_radius = 3.14; wheel.mesh = torus; wheel.material_override = _mat(Color("f2bd61"), 0.5); add_child(wheel); _animated.append(wheel)
	for i in range(10):
		var a := TAU * i / 10.0; var cabin := _box("WheelCabin", Vector3(cos(a) * 3.0, 5.2 + sin(a) * 3.0, -4.0), Vector3(0.42, 0.5, 0.42), _mat([Color("ff8e9e"), Color("69cfff"), Color("ffe179")][i % 3], 0.7)); _animated.append(cabin)

func _build_carousel(at: Vector3) -> void:
	_box("CarouselBase", at + Vector3(0, 0.25, 0), Vector3(4.0, 0.5, 4.0), _mat(Color("f3a7b9"), 0.2), true); _box("CarouselRoof", at + Vector3(0, 2.6, 0), Vector3(4.8, 0.2, 4.8), _mat(Color("ffe28a"), 0.8))
	for i in range(6):
		var a := TAU * i / 6.0; var horse := _box("CarouselSeat", at + Vector3(cos(a) * 1.35, 1.15, sin(a) * 1.35), Vector3(0.45, 0.7, 0.3), _mat([Color("ff7894"), Color("70cfff"), Color("fff09a")][i % 3], 0.5)); _animated.append(horse)

func _build_slide(at: Vector3) -> void:
	_box("SlideTower", at + Vector3(0, 1.9, 0), Vector3(2.2, 3.8, 2.2), _mat(Color("69b9e5"), 0.2), true); _box("SlidePlatform", at + Vector3(1.4, 3.7, 0), Vector3(1.2, 0.18, 1.8), _mat(Color("fff0a2"), 0.5), true)
	var ramp := _box("SlideRamp", at + Vector3(3.0, 0.75, 0), Vector3(4.8, 0.22, 1.3), _mat(Color("f4bf5d"), 0.6)); ramp.rotation.z = -0.18

func _build_picnic_zone() -> void:
	for x in [-3.0, 3.0]: _box("Bench", Vector3(x, 0.45, 3.2), Vector3(2.2, 0.18, 0.55), _mat(Color("9b694e"), 0.0), true)
	_box("PicnicTable", Vector3(0, 0.7, 4.2), Vector3(2.8, 0.16, 1.2), _mat(Color("d38b58"), 0.0), true)

func _build_trees() -> void:
	for x in [-13.0, -10.0, 10.0, 13.0]:
		_box("TreeTrunk", Vector3(x, 1.25, -4.8), Vector3(0.38, 2.5, 0.38), _mat(Color("79573f"), 0.0)); var crown := MeshInstance3D.new(); crown.name = "TreeCrown"; crown.position = Vector3(x, 3.0, -4.8); var sphere := SphereMesh.new(); sphere.radius = 1.45; sphere.height = 2.7; crown.mesh = sphere; crown.material_override = _mat(Color("5eae73"), 0.0); add_child(crown)

func _build_meme_stations() -> void:
	var specs := [[Vector3(-10, 0, 2), "拍一拍回声亭", "拍手动作会让喷泉亮起来", Color("ff8f9f")], [Vector3(10, 0, 2), "好运喷泉", "好运正在加载……请保持微笑", Color("62d8ff")], [Vector3(-2, 0, -5.5), "今日热搜牌", "你也在现场 · 这条真的绝了", Color("ffe27a")]]
	for spec in specs:
		var at: Vector3 = spec[0]; var accent: Color = spec[3]; _box("MemeKiosk", at + Vector3(0, 0.8, 0), Vector3(2.2, 1.6, 1.4), _mat(Color("fff9e5"), 0.0), true); _box("MemeSign", at + Vector3(0, 2.0, -0.05), Vector3(2.5, 0.6, 0.08), _mat(accent, 1.1)); _label(String(spec[1]), at + Vector3(0, 2.0, -0.15), accent.lightened(0.25)); _hotspots.append({"pos": at + Vector3(0, 0.8, 1.0), "text": "互动：" + String(spec[1]), "result": String(spec[2])})
	for i in range(6):
		var at := Vector3(-11.0 + (i % 3) * 10.5, 0.5, 5.2 if i < 3 else -0.2); var token := _box("MemeTicket_%02d" % i, at, Vector3(0.42, 0.42, 0.12), _mat([Color("ff8e9e"), Color("63d8ff"), Color("ffe179")][i % 3], 1.8)); token.set_meta("collected", false); _collectibles.append(token)

func _build_return_portal() -> void:
	var ring := MeshInstance3D.new(); ring.name = "ReturnPortalRing"; ring.position = return_position; var torus := TorusMesh.new(); torus.inner_radius = 0.85; torus.outer_radius = 0.98; ring.mesh = torus; ring.material_override = _mat(Color("f5a25d"), 1.8); add_child(ring); _animated.append(ring); _label("E 返回档案长廊", return_position + Vector3(0, 1.35, 0), Color("fff0c2"))

func _mat(color: Color, emission: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.roughness = 0.72
	if color.a < 1.0: mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0: mat.emission_enabled = true; mat.emission = Color(color.r, color.g, color.b); mat.emission_energy_multiplier = emission
	return mat

func _box(name: String, at: Vector3, size: Vector3, material: Material, collision := false) -> MeshInstance3D:
	var visual := MeshInstance3D.new(); visual.name = name; visual.position = at; var mesh := BoxMesh.new(); mesh.size = size; visual.mesh = mesh; visual.material_override = material; add_child(visual)
	if collision:
		var body := StaticBody3D.new(); body.name = name + "Collision"; body.position = at; var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = size; shape.shape = box; body.add_child(shape); add_child(body)
	return visual

func _label(text: String, at: Vector3, color: Color) -> void:
	var label := Label3D.new(); label.text = text; label.position = at; label.font_size = 24; label.pixel_size = 0.006; label.modulate = color; add_child(label)
