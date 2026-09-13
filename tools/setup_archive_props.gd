@tool
extends EditorScript

# 自动布置档案馆道具的编辑器脚本
# 在 Godot 编辑器中运行: File → Run Script

func _run():
	print("=== 开始布置档案馆道具 ===")

	var scene_root = get_scene()
	if scene_root == null:
		print("❌ 请先打开 archive_space.tscn 场景")
		return

	print("✓ 当前场景: " + scene_root.name)

	# 创建道具容器节点
	var props_container = Node3D.new()
	props_container.name = "ArchiveProps"
	scene_root.add_child(props_container)
	props_container.owner = scene_root

	print("\n【布置货架 - 主走廊两侧】")
	setup_shelves(props_container, scene_root)

	print("\n【布置箱子 - 存储区域】")
	setup_crates(props_container, scene_root)

	print("\n【布置桌椅 - 工作区】")
	setup_desks(props_container, scene_root)

	print("\n【添加青色点光源】")
	setup_lights(props_container, scene_root)

	print("\n=== ✓ 布置完成！===")
	print("下一步:")
	print("  1. 保存场景 (Ctrl+S)")
	print("  2. 运行场景 (F5)")
	print("  3. 查看效果")

func setup_shelves(parent: Node3D, root: Node):
	"""布置货架 - 走廊两侧对称排列"""
	var shelf_path = "res://assets/models/props/Prop_Shelves_WideTall.fbx"

	# 检查模型是否存在
	if not ResourceLoader.exists(shelf_path):
		print("  ❌ 未找到货架模型: " + shelf_path)
		return

	var shelf_scene = load(shelf_path)

	# 左侧货架 (4个)
	var left_positions = [
		Vector3(-8, 0, 0),
		Vector3(-8, 0, -10),
		Vector3(-8, 0, -20),
		Vector3(-8, 0, -30)
	]

	# 右侧货架 (4个)
	var right_positions = [
		Vector3(8, 0, 0),
		Vector3(8, 0, -10),
		Vector3(8, 0, -20),
		Vector3(8, 0, -30)
	]

	var shelf_count = 0

	# 左侧
	for pos in left_positions:
		var shelf = shelf_scene.instantiate()
		shelf.name = "Shelf_Left_" + str(shelf_count)
		shelf.position = pos
		shelf.rotation_degrees = Vector3(0, 90, 0)  # 面向走廊中心
		parent.add_child(shelf)
		shelf.owner = root
		shelf_count += 1

	# 右侧
	for pos in right_positions:
		var shelf = shelf_scene.instantiate()
		shelf.name = "Shelf_Right_" + str(shelf_count)
		shelf.position = pos
		shelf.rotation_degrees = Vector3(0, -90, 0)  # 面向走廊中心
		parent.add_child(shelf)
		shelf.owner = root
		shelf_count += 1

	print("  ✓ 放置 %d 个货架" % shelf_count)

func setup_crates(parent: Node3D, root: Node):
	"""布置箱子 - 角落和墙边堆叠"""
	var crate_path = "res://assets/models/props/Prop_Crate_Large.fbx"
	var barrel_path = "res://assets/models/props/Prop_Barrel1.fbx"

	if not ResourceLoader.exists(crate_path):
		print("  ❌ 未找到箱子模型")
		return

	var crate_scene = load(crate_path)
	var barrel_scene = load(barrel_path) if ResourceLoader.exists(barrel_path) else null

	# 箱子堆叠位置（2层堆叠）
	var crate_groups = [
		# 左前角
		[Vector3(-15, 0, 5), Vector3(-15, 1.2, 5), Vector3(-16, 0, 5)],
		# 右前角
		[Vector3(15, 0, 5), Vector3(15, 1.2, 5), Vector3(16, 0, 5)],
		# 走廊末端
		[Vector3(-10, 0, -38), Vector3(-10, 1.2, -38), Vector3(-11, 0, -38)],
		[Vector3(10, 0, -38), Vector3(10, 1.2, -38), Vector3(11, 0, -38)],
	]

	var crate_count = 0
	for group in crate_groups:
		for pos in group:
			var crate = crate_scene.instantiate()
			crate.name = "Crate_" + str(crate_count)
			crate.position = pos
			crate.rotation_degrees = Vector3(0, randf_range(-15, 15), 0)  # 随机旋转
			parent.add_child(crate)
			crate.owner = root
			crate_count += 1

	# 添加几个圆桶
	if barrel_scene != null:
		var barrel_positions = [
			Vector3(-5, 0, 3),
			Vector3(5, 0, 3),
			Vector3(-12, 0, -35),
			Vector3(12, 0, -35),
		]

		for pos in barrel_positions:
			var barrel = barrel_scene.instantiate()
			barrel.name = "Barrel_" + str(crate_count)
			barrel.position = pos
			parent.add_child(barrel)
			barrel.owner = root
			crate_count += 1

	print("  ✓ 放置 %d 个箱子/容器" % crate_count)

func setup_desks(parent: Node3D, root: Node):
	"""布置桌椅 - 工作区"""
	var desk_path = "res://assets/models/props/Prop_Desk_Medium.fbx"
	var chair_path = "res://assets/models/props/Prop_Chair.fbx"

	if not ResourceLoader.exists(desk_path):
		print("  ❌ 未找到桌子模型")
		return

	var desk_scene = load(desk_path)
	var chair_scene = load(chair_path) if ResourceLoader.exists(chair_path) else null

	# 工作台位置（货架之间）
	var desk_setups = [
		{"desk": Vector3(-3, 0, -5), "chair": Vector3(-3, 0, -3.5), "rotation": 180},
		{"desk": Vector3(3, 0, -15), "chair": Vector3(3, 0, -13.5), "rotation": 180},
		{"desk": Vector3(-3, 0, -25), "chair": Vector3(-3, 0, -23.5), "rotation": 180},
	]

	var furniture_count = 0

	for setup in desk_setups:
		# 桌子
		var desk = desk_scene.instantiate()
		desk.name = "Desk_" + str(furniture_count)
		desk.position = setup["desk"]
		desk.rotation_degrees = Vector3(0, setup["rotation"], 0)
		parent.add_child(desk)
		desk.owner = root
		furniture_count += 1

		# 椅子
		if chair_scene != null:
			var chair = chair_scene.instantiate()
			chair.name = "Chair_" + str(furniture_count)
			chair.position = setup["chair"]
			chair.rotation_degrees = Vector3(0, setup["rotation"], 0)
			parent.add_child(chair)
			chair.owner = root
			furniture_count += 1

	print("  ✓ 放置 %d 件桌椅" % furniture_count)

func setup_lights(parent: Node3D, root: Node):
	"""添加青色点光源营造氛围"""

	# 青色点光源位置（照亮货架区域）
	var light_positions = [
		Vector3(-8, 4, -5),
		Vector3(8, 4, -5),
		Vector3(-8, 4, -15),
		Vector3(8, 4, -15),
		Vector3(-8, 4, -25),
		Vector3(8, 4, -25),
		Vector3(0, 4, -35),
	]

	for i in range(light_positions.size()):
		var light = OmniLight3D.new()
		light.name = "CyanLight_" + str(i)
		light.position = light_positions[i]
		light.light_color = Color(0, 1, 1)  # 青色
		light.light_energy = 1.5
		light.omni_range = 8.0
		light.omni_attenuation = 0.5
		light.shadow_enabled = true

		parent.add_child(light)
		light.owner = root

	print("  ✓ 添加 %d 个青色点光源" % light_positions.size())
