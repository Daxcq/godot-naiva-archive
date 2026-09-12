extends Node
## Archive corridor interactions: three required memories, one per cabinet.
signal memory_solved(id: String)
signal archive_completed
signal interaction_started(id: String)
signal interaction_feedback(id: String, event: String)
signal ending_chosen(kind: String)

const UIKit := preload("res://scripts/ui_kit.gd")

var world: Node3D
var player: CharacterBody3D
var router: Node
var card: Label
var card_title: Label
var card_panel: Control
var count: Label
var count_panel: Control
var active := false
var solved: Dictionary = {}
var active_id := ""
var active_state := ""
var state_elapsed := 0.0
var ending_elapsed := 0.0
var ending_done := false
var pause_window := 4.0
var drawer: Node3D
var archive_drawers: Node3D
var beat_figures: Array[Node3D] = []
var record_screens: Dictionary = {}
var action_button: Button
var network_button: Button
var beat_buttons: HBoxContainer
var display_time := 0.0
var nearest_index := -1
var covered_frog: Node3D
var seen_frog: Node3D
var completion_screen: Label3D
var card_time := 0.0
var sync_visual_until := 0.0
var action_row: HBoxContainer
var main_ids := ["seen_2016", "imitated_2020", "covered_2024"]
var nodes := [
	{"id":"seen_2016", "pos":Vector3(-1.0,1.1,-2.5), "title":"2016 / 第一次被看见", "text":"那时候，只要有人笑了，就算被看见。"},
	{"id":"imitated_2020", "pos":Vector3(11.4,1.1,-2.5), "title":"2020 / 被模仿", "text":"当所有人都跳同一个动作，最先跳的人还在画面里吗？"},
	{"id":"covered_2024", "pos":Vector3(23.8,1.1,-2.5), "title":"2024 / 被覆盖", "text":"被忘记不等于没有发生，只是后来的人看不到了。"}
]

func setup(owner: Node3D) -> void:
	world = owner
	player = owner.player
	var layer := owner.get_node("Interface")
	router = owner.get_node_or_null("InteractionRouter")
	# 左上档案卡:标题 + 正文,统一样式与锚位(UIKit 卡片区)。
	var card_ui := UIKit.make_card(layer)
	card = card_ui.body
	card_title = card_ui.title
	card_panel = card_ui.panel
	# 右上记忆计数徽章。
	var badge := UIKit.make_badge(layer, UIKit.CYAN)
	count = badge.label
	count_panel = badge.panel
	# 底部中央按钮行:读取/结尾双按钮与节拍三按钮共用一行,互斥显示。
	action_button = UIKit.make_button("E  读取档案")
	action_button.custom_minimum_size = Vector2(210, UIKit.BTN_HEIGHT)
	action_button.pressed.connect(interact)
	network_button = UIKit.make_button("Q  放回网络", UIKit.MAGENTA)
	network_button.custom_minimum_size = Vector2(210, UIKit.BTN_HEIGHT)
	network_button.text = "Q  放回网络"
	network_button.focus_mode = Control.FOCUS_NONE
	network_button.pressed.connect(func(): _finish_ending("network"))
	action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 14)
	action_row.add_child(action_button)
	action_row.add_child(network_button)
	UIKit.anchor_button_row(action_row)
	action_row.visible = false
	layer.add_child(action_row)
	beat_buttons = HBoxContainer.new()
	beat_buttons.add_theme_constant_override("separation", 12)
	for i in range(1, 4):
		var button := UIKit.make_button(["1  快 · 快 · 停", "2  慢 · 慢 · 快", "3  快 · 停 · 快"][i - 1])
		button.custom_minimum_size = Vector2(190, UIKit.BTN_HEIGHT)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(choose_beat.bind(i))
		beat_buttons.add_child(button)
	UIKit.anchor_button_row(beat_buttons)
	beat_buttons.visible = false
	layer.add_child(beat_buttons)
	_build_stage_markers()
	archive_drawers = preload("res://scripts/archive_drawers.gd").new()
	archive_drawers.setup(world.archive_root)
	_build_memory_displays()
	set_active(false)
	update_count()

func _build_stage_markers() -> void:
	var root := world.archive_root.get_node_or_null("MemoryNodes") as Node3D
	if root == null:
		root = Node3D.new()
		root.name = "MemoryNodes"
		world.archive_root.add_child(root)
	for item in nodes:
		var marker := Node3D.new()
		marker.name = {"seen_2016":"SeenMemory_2016", "imitated_2020":"ImitatedMemory_2020", "covered_2024":"CoveredMemory_2024"}[String(item.id)]
		marker.position = item.pos
		var mesh_node := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.52, 0.08, 0.12)
		mesh_node.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("3ee6ff") if String(item.id).contains("2016") else (Color("ff4fd8") if String(item.id).contains("2020") else Color("ffa040"))
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 1.5
		mesh_node.material_override = mat
		marker.add_child(mesh_node)
		root.add_child(marker)

func _build_memory_displays() -> void:
	var root := world.archive_root.get_node_or_null("MemoryNodes") as Node3D
	if root == null:
		return
	for spec in [["LowRes2016", Vector3(-1.0, 2.25, -2.58), "2016  //  低清传播记录\n[原始影像加载中]"] , ["Refresh2024", Vector3(23.8, 2.25, -2.58), "2024  //  热搜刷新中\n████████░░  84%"]]:
		var screen := Label3D.new()
		screen.name = spec[0]
		screen.position = spec[1] + Vector3(0, 1.15, 0.25)
		screen.text = spec[2]
		screen.font_size = 28
		screen.pixel_size = 0.006
		screen.modulate = Color("6fe8ff") if spec[0] == "LowRes2016" else Color("ffb066")
		root.add_child(screen)
		record_screens[spec[0]] = screen
		_box(root, String(spec[0]) + "Frame", spec[1] + Vector3(0, 0.22, 0.13), Vector3(2.5, 2.35, 0.13), Color("0c0722"))
	seen_frog = _pixel_frog(root, "FirstForward", Vector3(-1.0, 2.05, -2.23))
	seen_frog.visible = false
	covered_frog = _pixel_frog(root, "BuriedVersion", Vector3(23.8, 2.05, -2.23))
	covered_frog.scale = Vector3.ONE * 0.45
	var figures_root := Node3D.new()
	figures_root.name = "ImitationSilhouettes"
	figures_root.position = Vector3(11.4, 1.85, -2.15)
	root.add_child(figures_root)
	_box(root, "BeatScreenFrame", Vector3(11.4, 2.3, -2.48), Vector3(3.1, 2.35, 0.13), Color("0e081f"))
	var beat_label := Label3D.new()
	beat_label.name = "OriginalBeat"
	beat_label.position = Vector3(11.4, 3.22, -2.22)
	beat_label.font_size = 26
	beat_label.pixel_size = 0.006
	beat_label.text = "原始记录  慢 · 慢 · 快"
	root.add_child(beat_label)
	record_screens["Beat2020"] = beat_label
	for i in range(3):
		var figure := Node3D.new()
		figure.name = "Silhouette_%d" % (i + 1)
		figure.position = Vector3(-0.9 + i * 0.9, 0.0, 0.0)
		var body := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.18
		capsule.height = 0.9
		body.mesh = capsule
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.14, 0.05, 0.24, 0.9)
		material.emission_enabled = true
		material.emission = Color("e04fff")
		material.emission_energy_multiplier = 0.9
		body.material_override = material
		figure.add_child(body)
		_box(figure, "Head", Vector3(0, 0.67, 0), Vector3(0.3, 0.3, 0.13), Color("ff8ff0"))
		for side in [-1.0, 1.0]:
			var arm := Node3D.new()
			arm.name = "LeftArm" if side < 0 else "RightArm"
			arm.position = Vector3(side * 0.2, 0.27, 0)
			figure.add_child(arm)
			_box(arm, "Limb", Vector3(side * 0.18, -0.08, 0), Vector3(0.4, 0.1, 0.1), Color("d774ff"))
			_box(figure, "LeftLeg" if side < 0 else "RightLeg", Vector3(side * 0.11, -0.58, 0), Vector3(0.11, 0.45, 0.1), Color("d774ff"))
		figures_root.add_child(figure)
		beat_figures.append(figure)
	completion_screen = Label3D.new()
	completion_screen.name = "MainScreen"
	completion_screen.position = Vector3(11.4, 4.55, -2.12)
	completion_screen.font_size = 34
	completion_screen.pixel_size = 0.008
	completion_screen.text = "记忆缺失  0 / 3"
	world.archive_root.add_child(completion_screen)

func _box(parent: Node3D, title: String, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = title
	visual.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.material_override = material
	parent.add_child(visual)
	return visual

func _pixel_frog(parent: Node3D, title: String, position: Vector3) -> Node3D:
	var frog := Node3D.new()
	frog.name = title
	frog.position = position
	parent.add_child(frog)
	var rows := ["  GG GG  ", " GGGGGGG ", " GWGGGWG ", " GGGGGGG ", "  GWWWG  ", "  GGGGG  ", " GG   GG "]
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			var cell: String = rows[y][x]
			if cell != " ":
				_box(frog, "Pixel", Vector3((x - 4) * 0.12, (3 - y) * 0.12, 0), Vector3(0.115, 0.115, 0.025), Color("b2d27f") if cell == "G" else Color("eff1d7"))
	return frog

func set_active(value: bool) -> void:
	active = value
	set_process(value)
	if card_panel:
		# 档案卡只在有内容时显示,避免激活后左上角挂着一块空面板。
		card_panel.visible = value and (card_title.text != "" or card.text != "")
	if count_panel:
		count_panel.visible = value
	if action_button:
		action_button.visible = false
		network_button.visible = false
		action_row.visible = false
		beat_buttons.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not active or ending_done:
		return
	# 触发互斥:只有拿到交互焦点的系统才响应键盘,防止多系统同帧响应。
	if not _can_show():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("interact"):
			interact()
		elif event.keycode == KEY_Q and _at_exit():
			_finish_ending("network")
		elif event.keycode == KEY_1:
			choose_beat(1)
		elif event.keycode == KEY_2:
			choose_beat(2)
		elif event.keycode == KEY_3:
			choose_beat(3)

func _process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if not active or player == null or ending_done:
		return
	display_time += delta
	_update_displays()
	if card_time > 0:
		card_time -= delta
		if card_time <= 0:
			card.text = ""
			card_title.text = ""
	# 档案卡跟随内容显隐:没有正文的空面板不再挂在左上角。
	if card_panel:
		card_panel.visible = card_title.text != "" or card.text != ""
	_tick_gesture()
	action_button.visible = false
	network_button.visible = false
	action_row.visible = false
	beat_buttons.visible = false
	if active_id != "":
		_process_active(delta)
		return
	nearest_index = _nearest()
	if _at_exit():
		ending_elapsed += delta
		_offer("E", "保存记忆,或放回网络 · 停留 %.0f 秒" % maxf(0.0, 12.0 - ending_elapsed), maxf(0.0, player.position.x - 35.6))
		action_button.text = "E  保存记忆"
		if _can_show():
			action_button.visible = true
			network_button.visible = true
			action_row.visible = true
		if ending_elapsed >= 12.0:
			_finish_ending("stay")
	elif nearest_index >= 0:
		ending_elapsed = 0.0
		var item: Dictionary = nodes[nearest_index]
		var verb := "拉开抽屉" if item.id == "seen_2016" else ("暂停刷新" if item.id == "covered_2024" else "读取档案")
		_offer("E", verb + ":" + String(item.title), player.position.distance_to(item.pos))
		action_button.text = "E  读取档案"
		if _can_show():
			action_button.visible = true
			action_row.visible = true
	else:
		ending_elapsed = 0.0
		_offer("", "找回三段被遗忘的记忆" if main_count() < 3 else "出口已开启,前往尽头", 999.0)

## 向仲裁器申请显示唯一交互提示;未接 Router 时静默降级。
func _offer(key: String, body: String, distance: float, holding := false) -> void:
	if router:
		router.offer("memory", body, distance, key, 0, holding)

## 手势输入:握拳 = E(读取/保存/保存旧版本),节拍选择看指针悬停;
## 张开手掌 = Q 放回网络。仅视觉模式生效,键鼠路径不受影响。
func _tick_gesture() -> void:
	var input_state: Node = world.input_state
	if input_state == null or not input_state.is_vision_driven() or not _can_show():
		return
	if input_state.confirm_just_pressed and input_state.consume_confirm():
		if beat_buttons.visible:
			var beat := _beat_under_pointer(input_state)
			if beat > 0:
				choose_beat(beat)
		else:
			interact()
	if input_state.cancel_just_pressed and _at_exit():
		_finish_ending("network")

## 视觉指针悬停在哪个节拍按钮上(0 = 无)。
func _beat_under_pointer(input_state: Node) -> int:
	var viewport := player.get_viewport()
	var size := viewport.get_visible_rect().size
	var pos := Vector2(float(input_state.pointer.x) * size.x, float(input_state.pointer.y) * size.y)
	for i in range(beat_buttons.get_child_count()):
		var button := beat_buttons.get_child(i) as Control
		if button != null and button.get_global_rect().has_point(pos):
			return i + 1
	return 0

## 是否允许显示按钮 / 响应键盘:拿到焦点即可。
func _can_show() -> bool:
	return router == null or router.can_interact("memory")

func _nearest() -> int:
	var nearest := -1
	var best := 3.2
	for i in range(nodes.size()):
		var id := String(nodes[i].id)
		if solved.has(id):
			continue
		var distance: float = player.position.distance_to(nodes[i].pos)
		if distance < best:
			best = distance
			nearest = i
	return nearest

func _at_exit() -> bool:
	return main_count() == 3 and player.position.x >= 35.6

func interact() -> void:
	if not active or ending_done:
		return
	if active_id != "":
		if active_id == "covered_2024" and active_state == "pause" and state_elapsed <= pause_window:
			_solve(_item_by_id(active_id))
		return
	if _at_exit():
		_finish_ending("save")
		return
	var nearest := _nearest()
	if nearest >= 0:
		_begin(nodes[nearest])

func _begin(item: Dictionary) -> void:
	active_id = String(item.id)
	active_state = "active"
	state_elapsed = 0.0
	if archive_drawers:
		archive_drawers.open_for_id(active_id)
	interaction_started.emit(active_id)
	if active_id == "seen_2016":
		active_state = "drawer"
		card_title.text = "2016 / 低清影像"
		card.text = "抽屉正在打开…"
		interaction_feedback.emit(active_id, "drawer_open")
	elif active_id == "imitated_2020":
		active_state = "beat"
		card_title.text = "节拍档案"
		card.text = "原始记录的节拍是:慢 · 慢 · 快。听节拍,或看屏幕提示,选择一致的记录。"
		card_time = 0.0
	elif active_id == "covered_2024":
		active_state = "pause"
		interaction_feedback.emit(active_id, "refresh_paused")
	else:
		_solve(item)

func _process_active(delta: float) -> void:
	state_elapsed += delta
	if active_id == "seen_2016":
		if drawer:
			drawer.position.z = lerpf(-2.58, -2.02, smoothstep(0.0, 1.15, state_elapsed))
		seen_frog.visible = state_elapsed > 0.7
		_offer("", "低清影像恢复中…" if state_elapsed > 1.15 else "抽屉正在打开…", 0.0, true)
		if state_elapsed >= 1.15:
			_solve(_item_by_id(active_id))
	elif active_id == "imitated_2020":
		if active_state == "sync":
			_offer("", "原始动作与模仿重合了…", 0.0, true)
			if state_elapsed >= 1.8:
				_solve(_item_by_id(active_id))
		else:
			_offer("", "选择与原始记录一致的节拍", 0.0, true)
			beat_buttons.visible = _can_show()
	elif active_id == "covered_2024":
		_offer("E", "保存旧版本 · %.1f 秒" % maxf(0.0, pause_window - state_elapsed), 0.0, true)
		action_button.text = "E  保存旧版本"
		if _can_show():
			action_button.visible = true
		if state_elapsed > pause_window:
			interaction_feedback.emit(active_id, "refresh_resumed")
			_clear_active()
			card_title.text = "刷新恢复"
			card.text = "暂停窗口结束,热搜继续刷新。靠近后可再次尝试。"
			card_time = 6.0

func choose_beat(choice: int) -> void:
	if not active or active_id != "imitated_2020" or active_state != "beat":
		return
	if choice == 2:
		interaction_feedback.emit(active_id, "beat_correct")
		card.text = "原始节拍被找到了。三个剪影开始同步……"
		sync_visual_until = display_time + 1.8
		active_state = "sync"
		state_elapsed = 0.0
	else:
		interaction_feedback.emit(active_id, "beat_wrong")
		card.text = "节拍偏移了，屏幕只留下短暂噪声。\n再试一次，不会清空进度。"

func _update_displays() -> void:
	var synced := display_time < sync_visual_until
	for i in range(beat_figures.size()):
		var figure := beat_figures[i]
		var phase := display_time * 4.2 + (0.0 if synced else i * 1.7)
		figure.position.y = absf(sin(phase)) * 0.13
		figure.rotation.z = sin(phase) * 0.12
		figure.get_node("LeftArm").rotation.z = sin(phase) * 0.8
		figure.get_node("RightArm").rotation.z = -sin(phase) * 0.8
		figure.get_node("LeftLeg").rotation.z = sin(phase) * 0.22
		figure.get_node("RightLeg").rotation.z = -sin(phase) * 0.22
	var paused := active_id == "covered_2024" or solved.has("covered_2024")
	var refresh := record_screens["Refresh2024"] as Label3D
	if solved.has("covered_2024"):
		refresh.text = "旧版本已保存\n奶蛙 / 原始记录"
		covered_frog.scale = Vector3.ONE
	elif paused:
		refresh.text = "刷新已暂停\n旧版本：奶蛙 / 等待保存"
		covered_frog.scale = Vector3.ONE * 0.85
	else:
		var headlines := ["最新热点  ↑↑↑", "新片段已替换旧记录", "正在刷新  █████░", "奶蛙…  记录已沉底"]
		refresh.text = "2024  //  热搜刷新中\n" + headlines[int(display_time * 3.0) % headlines.size()]
		covered_frog.position.y = 1.8 - fmod(display_time * 0.5, 0.6)
		covered_frog.scale = Vector3.ONE * 0.45
	if paused:
		covered_frog.position.y = 2.05
	if seen_frog.visible:
		seen_frog.rotation.z = sin(floorf(display_time * 5.0)) * 0.05
		(record_screens["LowRes2016"] as Label3D).text = "2016  //  144p\n首次转发  %04d" % int(display_time * 2.0 + 1)

func _solve(item: Dictionary) -> void:
	var id := String(item.id)
	if solved.has(id):
		_clear_active()
		return
	var before := main_count()
	solved[id] = true
	card_title.text = String(item.title)
	card.text = String(item.text)
	card_time = 12.0
	if id == "seen_2016":
		seen_frog.visible = true
	interaction_feedback.emit(id, "solved")
	_clear_active()
	update_count()
	memory_solved.emit(id)
	if before < 3 and main_count() == 3:
		completion_screen.text = "第一次被看见  →  被模仿  →  被覆盖\n三段记忆重新相遇 / 出口已开启"
		archive_completed.emit()

func _clear_active() -> void:
	active_id = ""
	active_state = ""
	state_elapsed = 0.0

func _item_by_id(id: String) -> Dictionary:
	for item in nodes:
		if String(item.id) == id:
			return item
	return {}

func main_count() -> int:
	var result := 0
	for id in main_ids:
		if solved.has(id):
			result += 1
	return result

func update_count() -> void:
	if count:
		count.text = "主线记忆  %d / 3" % main_count()
	if completion_screen and main_count() < 3:
		completion_screen.text = "记忆缺失  %d / 3" % main_count()

func get_node_state(id: String) -> String:
	if solved.has(id):
		return "solved"
	if active_id == id:
		return "active"
	var item := _item_by_id(id)
	if active and player and not item.is_empty() and player.position.distance_to(item.pos) < 3.2:
		return "nearby"
	return "locked"

func _finish_ending(kind: String) -> void:
	if ending_done or main_count() < 3:
		return
	ending_done = true
	action_button.visible = false
	network_button.visible = false
	action_row.visible = false
	beat_buttons.visible = false
	var titles := {"save": "记忆已归档", "network": "传播仍在继续", "stay": "下一次访问,仍未确定"}
	card_title.text = String(titles.get(kind, "结局"))
	if kind == "save":
		card.text = "三段记忆被放回档案盒。\n奶蛙的轮廓稳定下来。"
	elif kind == "network":
		card.text = "记忆重新拆成头像、弹幕和短片段。\n奶蛙融入了网络背景。"
	else:
		card.text = "房间重新开始加载。\n奶蛙看向玩家,等待下一次访问。"
	interaction_feedback.emit("ending", kind)
	ending_chosen.emit(kind)
