extends Node
## 档案馆入口的牛 NPC（"牛来"）。
##
## 奶蛙从传送门落地后，第一眼看到的就是它——站在走廊入口左边的墙边。
## 交互刻意保持极简：走近显示提示，按 E 逐句读完。四句讲完，
## 它会复述一句「牛来」，然后转身安静地站回去。
##
## 为什么单独一个脚本而不是塞进 archive_npc_dialogue.gd：
## 那个文件管理的是"柜前三个档案员 → 打开记忆传送门"这条主动线，
## 每个档案员读完都会生成一个传送门。入口的牛不参与这条链路，
## 它只负责在起点说几句不推进进度的话。混在一起会让那个 300 行的
## 状态机多出一堆 if。

const MODEL_PATH := "res://assets/character/niu_lai.glb"
## 站位：传送门出点 ARCHIVE_SPAWN 是 (-4.5, …)，奶蛙落地后沿 +X 进走廊。
## 走廊可走范围 x∈[-5,37]、z∈[-1.9,1.9]（见 main.gd 的 clamp）。
## 把牛放在 x=-1.6：离落点 2.9m，刚好在交互范围之外一点点——
## 玩家落地后往前走两步才会亮提示，不会一睁眼就被打断。
## z 靠后墙一侧（-1.25），既避开通路，也让奶蛙落地后回头能看见它。
const NPC_POSITION := Vector3(-1.6, 0.0, -1.25)
## 面朝方向的 yaw。奶蛙从 -4.5 过来，牛要侧身对着来路（略偏走廊内侧）。
const NPC_YAW := 0.95
## 模型自带高度 1.11m，放大到 1.31m —— 比奶蛙（约 1.05m）高一头，
## 站在一起像个"大个子"，符合它在对话里的长辈感。
const NPC_SCALE := 1.18
## 交互距离：比档案员的 2.5 稍大，因为入口空间窄、牛又靠墙，太近反而难触发。
const TALK_RANGE := 3.0
## 台词。最后一句是留给玩家的余味，所以放在「牛来」之前。
const LINES := [
	"……",
	"你也是刚被送到这儿的？我看你从上面那道光里掉下来。",
	"我叫牛来。名字是我妈起的——她说，喊这个名字，我就能站起来。",
	"后来我确实站起来了。只是站起来以后，大家都只顾着笑我丑。",
	"再后来他们不笑了，开始拿我的名字许愿。牛市来、好运来、什么都来。",
	"可从头到尾，没人问过我想不想来。",
	"……牛来。",
]

var world: Node3D
var player: CharacterBody3D
var layer: CanvasLayer
var prompt: Label
var card: Label
var button: Button

var npc_root: Node3D
var model_root: Node3D
var label_3d: Label3D

var active := false
var talking := false
var line_index := -1
var line_delay := 0.0
var idle_time := 0.0
## 读完一次后不再重复整段，只留一句短回应。
var finished_once := false
var near := false

func setup(owner: Node3D) -> void:
	world = owner
	player = owner.player
	layer = owner.get_node_or_null("Interface") as CanvasLayer
	_build_npc()
	_build_ui()
	set_active(false)

## 建造场景里的牛。模型是静态高模减面而来的，没有骨骼，
## 所以"呼吸"和"说话时点头"全部靠整体 transform 驱动。
func _build_npc() -> void:
	npc_root = Node3D.new()
	npc_root.name = "EntranceNPC_NiuLai"
	npc_root.position = NPC_POSITION
	npc_root.rotation.y = NPC_YAW
	world.archive_root.add_child(npc_root)

	model_root = Node3D.new()
	model_root.name = "Model"
	model_root.scale = Vector3.ONE * NPC_SCALE
	npc_root.add_child(model_root)

	var packed := load(MODEL_PATH) as PackedScene
	if packed == null:
		push_warning("入口牛模型缺失：%s（将用占位方块代替）" % MODEL_PATH)
		_build_placeholder()
	else:
		var instance := packed.instantiate()
		model_root.add_child(instance)
		_prepare_materials(instance)

	# 名牌。用 Label3D 而不是 UI，这样走近才有"空间感"。
	label_3d = Label3D.new()
	label_3d.name = "NameTag"
	label_3d.text = "牛来"
	label_3d.position = Vector3(0, 1.62, 0)
	label_3d.font_size = 22
	label_3d.pixel_size = 0.005
	label_3d.modulate = Color("ffd9a0")
	label_3d.outline_size = 0
	npc_root.add_child(label_3d)

	# 一盏暖色小灯，把牛从走廊的冷光里"托"出来，也是视觉引导。
	# 走廊整体是青/品红的低照度环境，0.7 的亮度根本不够——
	# 实测牛会整个沉进背景。这里给足亮度 + 贴近模型，让它在暗场里能读出来。
	var light := OmniLight3D.new()
	light.name = "NPCLight"
	light.light_color = Color("ffc78a")
	light.light_energy = 2.4
	light.omni_range = 3.2
	light.position = Vector3(0.35, 1.35, 0.85)
	npc_root.add_child(light)

	# 后侧轮廓光：勾一道暖边，避免牛和深紫色背景糊在一起。
	var rim := OmniLight3D.new()
	rim.name = "NPCRimLight"
	rim.light_color = Color("ff9a4d")
	rim.light_energy = 1.1
	rim.omni_range = 2.4
	rim.position = Vector3(-0.5, 1.15, -0.9)
	npc_root.add_child(rim)

	# 交互触发区。用 Area3D 只是为了让判定跟模型对齐，
	# 真正判断距离仍走 _process 里的 _distance()，行为更可控。
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

## 模型是 Blender 减面导出的，材质回退到项目统一的粗糙度，
## 避免跟着现有霓虹场景一起发亮——这头牛是"实物"，不该自发光。
func _prepare_materials(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_node := child as MeshInstance3D
			for i in range(mesh_node.get_surface_override_material_count()):
				pass
			var mat := mesh_node.get_active_material(0)
			if mat is StandardMaterial3D:
				var std := mat as StandardMaterial3D
				std.emission_enabled = false
				std.roughness = 0.9
		_prepare_materials(child)

## 模型缺失时的兜底：一个捏出来的奶油色方块小牛，保证玩法不崩。
func _build_placeholder() -> void:
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

func _build_ui() -> void:
	if layer == null:
		return
	# 位置与字号跟 archive_npc_dialogue.gd / archive_interaction.gd 对齐，
	# 三套系统的提示不能跳来跳去。
	prompt = Label.new()
	prompt.position = Vector2(38, 530)
	prompt.add_theme_font_size_override("font_size", 18)
	layer.add_child(prompt)

	card = Label.new()
	card.position = Vector2(38, 104)
	card.size = Vector2(850, 150)
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_theme_font_size_override("font_size", 21)
	layer.add_child(card)

	button = Button.new()
	button.position = Vector2(38, 576)
	button.custom_minimum_size = Vector2(260, 42)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_interact)
	layer.add_child(button)

func set_active(value: bool) -> void:
	active = value
	set_process(value)
	if npc_root:
		npc_root.visible = value
	if prompt:
		prompt.visible = value
	if card:
		card.visible = false
	if button:
		button.visible = false
	if not value:
		talking = false
		line_index = -1

func _input(event: InputEvent) -> void:
	if not active or player == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("interact"):
			if talking or near:
				get_viewport().set_input_as_handled()
				_interact()

func _process(delta: float) -> void:
	if not active or player == null or npc_root == null:
		return
	idle_time += delta
	line_delay = maxf(0.0, line_delay - delta)

	# 待机：极慢的呼吸 + 一点点左右晃。没骨骼，只能整体动。
	# 幅度刻意压得很小——牛是"站着不动的那种角色"，动多了就滑稽了。
	var breath := sin(idle_time * 1.5)
	var nod := 0.0
	if talking:
		# 说话时按台词节奏轻轻点头，权当"在讲话"的视觉提示。
		nod = sin(idle_time * 6.0) * 0.035
	model_root.scale = Vector3.ONE * NPC_SCALE * (1.0 + breath * 0.008)
	model_root.rotation.x = nod
	model_root.position.y = breath * 0.012

	# 名牌总是转向镜头方向做微弱浮动，避免被墙挡住看不见。
	if label_3d:
		label_3d.position.y = 1.62 + sin(idle_time * 1.2) * 0.02

	var distance := _distance()
	near = distance <= TALK_RANGE
	if talking:
		_update_prompt()
		return
	if near:
		prompt.text = "E 和牛来说两句"
		button.text = prompt.text
		button.visible = true
	else:
		prompt.text = ""
		button.visible = false

func _update_prompt() -> void:
	prompt.text = "牛来 · %d / %d" % [line_index + 1, LINES.size()]
	card.visible = true
	card.text = "%s\n\nE  继续" % String(LINES[line_index])
	button.visible = true
	button.text = "E  下一句" if line_index < LINES.size() - 1 else "E  道别"

func _interact() -> void:
	if line_delay > 0.0:
		return
	if not talking:
		if not near:
			return
		talking = true
		line_index = 0
		_show_line()
		return
	line_index += 1
	if line_index >= LINES.size():
		_end_talk()
	else:
		_show_line()

func _show_line() -> void:
	_update_prompt()
	line_delay = 0.22

func _end_talk() -> void:
	talking = false
	line_index = -1
	card.text = ""
	card.visible = false
	button.visible = false
	finished_once = true

func _distance() -> float:
	if npc_root == null or player == null:
		return INF
	# 正常运行时两者都在场景树里，用 global_position 最准。
	# 但在无头自检（--script / SceneTree）里，add_child 之后节点当帧还没真正进树，
	# global_position 会退化成单位变换、全部读成原点，导致距离恒为 0、判定永远"靠近"。
	# 这里用 in_tree 判定后回落到局部坐标，让自检和真机行为一致。
	if npc_root.is_inside_tree() and player.is_inside_tree():
		return player.global_position.distance_to(npc_root.global_position)
	return player.position.distance_to(npc_root.position)
