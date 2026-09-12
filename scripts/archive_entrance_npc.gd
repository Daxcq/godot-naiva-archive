extends Node
## 档案馆入口的梗角色组：牛来（西北墙角）与美团袋鼠（南墙）。
##
## 奶蛙从传送门落地后，入口两侧站着两个"被梗出来"的角色。
## 站位刻意避开落地视线锥(-4.5,4)→(-1.8,2.35,0)：牛来贴西北墙角、
## 袋鼠贴南墙，走廊中轴保持空旷，谁也不挡谁。
## 交互刻意保持极简：走近显示提示，按 E 逐句读完，可重复。
## 只允许同时与其中一人对话——取距离最近者。
##
## 两个角色是同一个时代情绪的两面：
##   牛来 —— 靠"丑"被围观而火，从头到尾没被真正看见；
##   袋鼠 —— 被网友画胖了三圈才火，大家爱上的是画出来的那个"它"。
## 对话里互相提一嘴，让站在同一屋檐下的他们认出彼此的命运。
##
## 为什么是数据驱动而不是两个脚本：两只角色的交互流程完全一致
## （靠近→E→逐句→结束），只有台词/模型/站位不同。复制一份 280 行
## 脚本只改常量是最差的维护形态，所以收敛成一个 NPCS 配置表。
## 它依旧独立于 archive_npc_dialogue.gd：那边管理"柜前三个档案员 →
## 开记忆传送门"的主动线，这边只陪聊、不推进度。

## 交互距离。原 3.0 时两个 NPC 的触发圈大面积交叠(两者仅相距 3.47m),
## 站中间按一次 E 会同时弹两套对话。收窄到 2.4,再由
## InteractionRouter 做距离仲裁兜底:同圈时只有最近的那个响应。
const TALK_RANGE := 2.4
## 台词推进的最小间隔，防手滑一按跳两句。
const LINE_DELAY := 0.22

const NPCS := [
	{
		"id": "niu_lai",
		"label": "牛来",
		# 使用可编辑包装场景；打开 scenes/entrance_npc_niu_lai.tscn 可直接调整模型。
		"model": "res://scenes/entrance_npc_niu_lai.tscn",
		# 贴西北墙角：原 (-1.6,-1.25) 正压走廊中轴，玩家落地(-4.5,4)→镜头
		# 看(-1.8,2.35,0)的视线锥里它总被奶蛙挡住；挪到墙角让开出生锥角。
		"pos": Vector3(-3.1, 0.0, -1.55),
		"yaw": 0.88,
		"scale": 1.18,
		"tag_y": 1.62,
		# 保留模型原始材质，不再叠加金黄色染色。
		"tint": Color(1, 1, 1),
		"lines": [
			"……",
			"你也是刚被送到这儿的？我看你从上面那道光里掉下来。",
			"我叫牛来。名字是我妈起的——她说，喊这个名字，我就能站起来。",
			"后来我确实站起来了。只是站起来以后，大家都只顾着笑我丑。",
			"再后来他们不笑了，开始拿我的名字许愿。牛市来、好运来、什么都来。",
			"可从头到尾，没人问过我想不想来。",
			"……牛来。",
		],
	},
	{
		"id": "meituan_kangaroo",
		"label": "美团袋鼠",
		# 使用可编辑包装场景；打开 scenes/entrance_npc_meituan_kangaroo.tscn 可直接调整模型。
		"model": "res://scenes/entrance_npc_meituan_kangaroo.tscn",
		"pos": Vector3(0.8, 0.0, 1.55),
		# 实测两个 glb 正面都是 +Z：yaw=1.1 时袋鼠面朝东北(背对玩家)。
		# -1.85 让 +Z 转向 (-0.96,-0.28)——西偏北,正对走廊中轴与玩家来向。
		"yaw": -1.85,
		"scale": 1.18,
		"tag_y": 1.38,
		"tint": Color(1, 1, 1),
		"lines": [
			"站住。先把话放这儿：不许提我的体重。",
			"……算了，你肯定也刷到过了。全网都说我圆滚滚、胖乎乎，还给我画胖了三圈。",
			"冤枉啊。我原本身形修长，是送外卖跑出来的线条。旁边那头牛靠“丑”火的，我靠“胖”火的——都不是我们本来的样子。",
			"现在官方都不敢认瘦，只能嘴硬：“我们袋鼠本来就不胖。”你听听，连亲妈都不敢认了。",
			"最气的还在后头——那个胖胖的我，收到的喜爱比我本人多十倍。大家爱的，是画出来的那个。",
			"所以在档案馆门口多啰嗦一句：哪天你也被大家记成了别的样子，记得偶尔，纠正一下他们。",
			"好啦，不耽误你了……敢一个人翻旧档案，你胆子真是肥嘟嘟的。",
		],
	},
]

const UIKit := preload("res://scripts/ui_kit.gd")

var world: Node3D
var player: CharacterBody3D
var layer: CanvasLayer
var router: Node
var card_title: Label
var card_panel: Control
var card: Label
var button: Button

## 每个 NPC 一份运行时状态，与 NPCS 下标一一对应。
var entries: Array = []

var active := false
var active_index := -1
var line_delay := 0.0

func setup(owner: Node3D) -> void:
	world = owner
	player = owner.player
	layer = owner.get_node_or_null("Interface") as CanvasLayer
	router = owner.get_node_or_null("InteractionRouter")
	for i in range(NPCS.size()):
		_build_npc(i)
	_build_ui()
	set_active(false)

## 建造场景里的角色。模型都是静态减面 glb，没有骨骼，
## "呼吸"和"说话点头"全靠整体 transform 驱动。
func _build_npc(index: int) -> void:
	var spec: Dictionary = NPCS[index]
	var node_name := "EntranceNPC_%s" % String(spec.id)
	var npc_root := world.get_node_or_null(node_name) as Node3D
	var model_root: Node3D
	var authored_instance := npc_root != null
	if npc_root != null:
		# 主场景中的可编辑实例：保留编辑器里的位置/旋转/模型层级。
		model_root = npc_root.get_child(0) as Node3D
	else:
		npc_root = Node3D.new()
		npc_root.name = node_name
		npc_root.position = spec.pos
		npc_root.rotation.y = float(spec.yaw)
		world.archive_root.add_child(npc_root)
		model_root = Node3D.new()
		model_root.name = "Model"
		model_root.scale = Vector3.ONE * float(spec.scale)
		npc_root.add_child(model_root)
		var packed := load(String(spec.model)) as PackedScene
		if packed == null:
			push_warning("入口 NPC 模型缺失：%s（将用占位方块代替）" % String(spec.model))
			_build_placeholder(model_root)
		else:
			var instance := packed.instantiate()
			model_root.add_child(instance)
	# 动态生成的旧模式使用配置缩放；主场景实例保留编辑器里作者设定的变换。
	if not authored_instance:
		model_root.scale = Vector3.ONE * float(spec.scale)
	_prepare_materials(model_root, spec.get("tint", Color(1, 1, 1)))

	# 名牌。用 Label3D 而不是 UI，走近才有"空间感"。
	var tag := Label3D.new()
	tag.name = "NameTag"
	tag.text = String(spec.label)
	tag.position = Vector3(0, float(spec.tag_y), 0)
	tag.font_size = 22
	tag.pixel_size = 0.005
	tag.modulate = Color("ffd9a0")
	tag.outline_size = 0
	npc_root.add_child(tag)

	# 暖色主灯 + 后侧轮廓光：走廊是青/品红低照度环境，
	# 实测不给足亮度角色会整个沉进背景。
	var light := OmniLight3D.new()
	light.name = "NPCLight"
	light.light_color = Color("ffc78a")
	light.light_energy = 2.4
	light.omni_range = 3.2
	light.position = Vector3(0.35, 1.35, 0.85)
	npc_root.add_child(light)
	var rim := OmniLight3D.new()
	rim.name = "NPCRimLight"
	rim.light_color = Color("ff9a4d")
	rim.light_energy = 1.1
	rim.omni_range = 2.4
	rim.position = Vector3(-0.5, 1.15, -0.9)
	npc_root.add_child(rim)

	var area := Area3D.new()
	area.name = "TalkArea"
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = TALK_RANGE
	capsule.height = 2.2
	shape.shape = capsule
	shape.position.y = 1.1
	area.add_child(shape)
	npc_root.add_child(area)

	entries.append({
		"root": npc_root,
		"model": model_root,
		"base_scale": model_root.scale,
		"tag": tag,
		"idle_time": randf() * 10.0,
		"talking": false,
		"line_index": -1,
		"finished_once": false,
		"near": false,
	})

## 模型缺失时的兜底：奶油色方块小人，保证玩法不崩。
func _build_placeholder(model_root: Node3D) -> void:
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color("f0dba8")
	body_mat.roughness = 0.9
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.34
	body_mesh.height = 0.95
	body.mesh = body_mesh
	body.material_override = body_mat
	body.position.y = 0.6
	model_root.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.3
	head_mesh.height = 0.6
	head.mesh = head_mesh
	head.material_override = body_mat
	head.position.y = 1.15
	model_root.add_child(head)

## 减面导出的材质回退到项目统一的粗糙度，禁用自发光——
## 这些角色是"实物"，不该跟着霓虹场景一起发亮。
## tint 乘在 albedo 上做整体调色；当前两个角色默认保留原始颜色。
## 同一 glb 的多个 mesh 可能共享同一份 Material 资源，
## 必须去重，否则 tint 会被重复应用、越乘越黄。
func _prepare_materials(node: Node, tint := Color(1, 1, 1)) -> void:
	var visited := {}
	_prepare_materials_inner(node, tint, visited)

func _prepare_materials_inner(node: Node, tint: Color, visited: Dictionary) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_node := child as MeshInstance3D
			for s in range(mesh_node.get_surface_override_material_count()):
				var mat := mesh_node.get_active_material(s)
				if mat is StandardMaterial3D and not visited.has(mat):
					visited[mat] = true
					var std := mat as StandardMaterial3D
					std.emission_enabled = false
					std.roughness = 0.9
					std.albedo_color = std.albedo_color * tint
		_prepare_materials_inner(child, tint, visited)

func _build_ui() -> void:
	if layer == null:
		return
	# 统一 UIKit 卡片区(左上)与按钮行(底中),与档案员/记忆柜共用锚位。
	var card_ui := UIKit.make_card(layer, 720.0)
	card = card_ui.body
	card_title = card_ui.title
	card_panel = card_ui.panel
	card_panel.visible = false

	button = UIKit.make_button("E  交谈")
	button.custom_minimum_size = Vector2(260, UIKit.BTN_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_interact)
	UIKit.anchor_button_row(button)
	button.visible = false
	layer.add_child(button)

func set_active(value: bool) -> void:
	active = value
	set_process(value)
	for entry in entries:
		var root_node: Node3D = entry.root
		root_node.visible = value
		entry.talking = false
		entry.line_index = -1
	if card_panel:
		card_panel.visible = false
		card.text = ""
		card_title.text = ""
	if button:
		button.visible = false
	active_index = -1

func _input(event: InputEvent) -> void:
	if not active or player == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("interact"):
			# 触发互斥:对话进行中独占焦点;否则必须是交互焦点才响应,
			# 避免与柜前档案员/记忆柜同帧双触发。
			if active_index >= 0 or _can_act():
				get_viewport().set_input_as_handled()
				_interact()

func _can_act() -> bool:
	return router == null or router.can_interact("entrance")

func _offer(key: String, body: String, distance: float, holding := false) -> void:
	if router:
		router.offer("entrance", body, distance, key, 0, holding)

func _process(delta: float) -> void:
	if not active or player == null:
		return
	line_delay = maxf(0.0, line_delay - delta)
	# 手势输入:握拳 = E(交谈 / 推进对话)。仅视觉模式生效。
	var input_state: Node = world.input_state
	if input_state != null and input_state.is_vision_driven():
		if input_state.confirm_just_pressed and input_state.consume_confirm():
			if active_index >= 0 or _can_act():
				_interact()

	# 待机：极慢的呼吸 + 说话时轻轻点头。没骨骼，只能整体动。
	# 幅度刻意压小——他们都是"站着/坐着不动的那种角色"，动多了就滑稽了。
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		entry.idle_time = float(entry.idle_time) + delta
		var model: Node3D = entry.model
		var base_scale: Vector3 = entry.get("base_scale", Vector3.ONE * float(NPCS[i].scale))
		var breath := sin(float(entry.idle_time) * 1.5)
		var nod := sin(float(entry.idle_time) * 6.0) * 0.035 if entry.talking else 0.0
		model.scale = base_scale * (1.0 + breath * 0.008)
		model.rotation.x = nod
		model.position.y = breath * 0.012
		var tag: Label3D = entry.tag
		tag.position.y = float(NPCS[i].tag_y) + sin(float(entry.idle_time) * 1.2) * 0.02

	if active_index >= 0:
		_update_prompt(entries[active_index])
		return
	var nearest := _nearest_entry()
	if nearest >= 0:
		var spec: Dictionary = NPCS[nearest]
		var distance := _distance(nearest)
		_offer("E", "和%s说两句" % String(spec.label), distance)
		if _can_act():
			button.text = "E  和%s说两句" % String(spec.label)
			button.visible = true
		else:
			button.visible = false
	else:
		button.visible = false

func _update_prompt(entry: Dictionary) -> void:
	var spec: Dictionary = NPCS[active_index]
	var lines: Array = spec.lines
	_offer("", "%s · %d / %d" % [String(spec.label), int(entry.line_index) + 1, lines.size()], 0.0, true)
	card_panel.visible = true
	card_title.text = String(spec.label)
	card.text = String(lines[entry.line_index])
	button.visible = true
	button.text = "E  下一句" if int(entry.line_index) < lines.size() - 1 else "E  道别"

func _advance() -> void:
	var entry: Dictionary = entries[active_index]
	var spec: Dictionary = NPCS[active_index]
	entry.line_index = int(entry.line_index) + 1
	if int(entry.line_index) >= (spec.lines as Array).size():
		_end_talk(entry)
	else:
		_show_line(entry)

func _show_line(entry: Dictionary) -> void:
	_update_prompt(entry)
	line_delay = LINE_DELAY

func _end_talk(entry: Dictionary) -> void:
	entry.talking = false
	entry.line_index = -1
	entry.finished_once = true
	card.text = ""
	card_title.text = ""
	card_panel.visible = false
	button.visible = false
	active_index = -1

func _interact() -> void:
	if line_delay > 0.0:
		return
	# 已在对话中：推进当前对象。
	if active_index >= 0:
		_advance()
		return
	var nearest := _nearest_entry()
	if nearest < 0:
		return
	active_index = nearest
	var entry: Dictionary = entries[nearest]
	entry.talking = true
	entry.line_index = 0
	_show_line(entry)

## 交互范围内最近的 NPC 下标,都不在范围内返回 -1。
func _nearest_entry() -> int:
	var nearest := -1
	var best := TALK_RANGE
	for i in range(entries.size()):
		var distance := _distance(i)
		if distance < best:
			best = distance
			nearest = i
	return nearest

## 距离判定。无头自检里节点当帧可能还没进树，
## global_position 会退化成原点，所以按 in_tree 分流（真机永远走 global 分支）。
func _distance(index: int) -> float:
	var entry: Dictionary = entries[index]
	var root_node: Node3D = entry.root
	if root_node == null or player == null:
		return INF
	if root_node.is_inside_tree() and player.is_inside_tree():
		return player.global_position.distance_to(root_node.global_position)
	return player.position.distance_to(root_node.position)
