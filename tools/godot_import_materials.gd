"""
Godot 材质导入脚本
自动为下载的纹理创建 Godot StandardMaterial3D 资源
"""

extends SceneTree

const ASSETS_TEXTURES_DIR = "res://assets/textures"
const MATERIALS_DIR = "res://assets/materials"

func _init():
	print("=" * 60)
	print("Godot 材质导入工具")
	print("=" * 60)

	# 创建材质目录
	DirAccess.make_dir_recursive_absolute(MATERIALS_DIR)

	# 处理所有材质
	process_all_materials()

	quit()

func process_all_materials():
	var categories = ["floors", "walls", "metal"]
	var total_count = 0

	for category in categories:
		print("\n【处理 %s 材质】" % category)
		print("-" * 60)

		var category_path = ASSETS_TEXTURES_DIR + "/" + category
		var dir = DirAccess.open(category_path)

		if dir == null:
			print("  ⚠️  目录不存在: %s" % category_path)
			continue

		dir.list_dir_begin()
		var material_name = dir.get_next()

		while material_name != "":
			if dir.current_is_dir() and not material_name.begins_with("."):
				var material_path = category_path + "/" + material_name
				if create_godot_material(material_name, material_path, category):
					total_count += 1

			material_name = dir.get_next()

		dir.list_dir_end()

	print("\n" + "=" * 60)
	print("导入完成")
	print("=" * 60)
	print("\n✅ 已创建 %d 个 Godot 材质资源" % total_count)
	print("\n材质保存位置: %s" % MATERIALS_DIR)
	print("\n使用方法:")
	print("  在场景中选择 MeshInstance3D")
	print("  在 Inspector 的 Material Override 中加载材质")
	print("  路径: res://assets/materials/<材质名称>.tres")

func create_godot_material(material_name: String, material_path: String, category: String) -> bool:
	print("\n创建材质: %s" % material_name)

	# 创建 StandardMaterial3D
	var material = StandardMaterial3D.new()

	# 查找纹理文件
	var textures = find_textures(material_path)

	if textures.is_empty():
		print("  ⚠️  未找到纹理文件")
		return false

	print("  找到纹理: %s" % str(textures.keys()))

	# 设置 Albedo
	if textures.has("albedo"):
		var albedo_tex = load(textures["albedo"])
		if albedo_tex:
			material.albedo_texture = albedo_tex
			print("  ✅ Albedo")

	# 设置基础颜色(根据类型)
	match category:
		"floors":
			material.albedo_color = Color(0.16, 0.16, 0.16, 1.0)  # 深灰
		"walls":
			material.albedo_color = Color(0.1, 0.15, 0.2, 1.0)   # 深蓝灰
		"metal":
			material.albedo_color = Color(0.3, 0.35, 0.4, 1.0)   # 金属灰

	# 设置 Normal
	if textures.has("normal"):
		var normal_tex = load(textures["normal"])
		if normal_tex:
			material.normal_enabled = true
			material.normal_texture = normal_tex
			material.normal_scale = 1.0
			print("  ✅ Normal")

	# 设置 Roughness
	if textures.has("roughness"):
		var roughness_tex = load(textures["roughness"])
		if roughness_tex:
			material.roughness_texture = roughness_tex
			if category == "metal":
				material.roughness = 0.4  # 拉丝金属
			else:
				material.roughness = 0.8  # 混凝土较粗糙
			print("  ✅ Roughness")
	else:
		material.roughness = 0.8

	# 设置 Metallic
	if textures.has("metallic"):
		var metallic_tex = load(textures["metallic"])
		if metallic_tex:
			material.metallic_texture = metallic_tex
			material.metallic = 1.0 if category == "metal" else 0.0
			print("  ✅ Metallic")
	else:
		material.metallic = 1.0 if category == "metal" else 0.0

	# 设置 AO
	if textures.has("ao"):
		var ao_tex = load(textures["ao"])
		if ao_tex:
			material.ao_enabled = true
			material.ao_texture = ao_tex
			material.ao_light_affect = 0.5
			print("  ✅ AO")

	# UV 缩放(地板重复平铺)
	if category == "floors":
		material.uv1_scale = Vector3(4, 4, 1)
	else:
		material.uv1_scale = Vector3(2, 2, 1)

	# 保存材质资源
	var save_path = MATERIALS_DIR + "/" + material_name + ".tres"
	var result = ResourceSaver.save(material, save_path)

	if result == OK:
		print("  💾 保存到: %s" % save_path)
		return true
	else:
		print("  ❌ 保存失败: %d" % result)
		return false

func find_textures(material_path: String) -> Dictionary:
	var textures = {}
	var dir = DirAccess.open(material_path)

	if dir == null:
		return textures

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png"):
			var full_path = material_path + "/" + file_name

			# 检测贴图类型
			if "_albedo" in file_name or "_color" in file_name:
				textures["albedo"] = full_path
			elif "_normal" in file_name:
				textures["normal"] = full_path
			elif "_roughness" in file_name:
				textures["roughness"] = full_path
			elif "_metallic" in file_name:
				textures["metallic"] = full_path
			elif "_ao" in file_name:
				textures["ao"] = full_path
			elif "_displacement" in file_name or "_height" in file_name:
				textures["displacement"] = full_path

		file_name = dir.get_next()

	dir.list_dir_end()
	return textures
