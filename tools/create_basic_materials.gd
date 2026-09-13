extends SceneTree

func _init():
	# 创建材质目录
	DirAccess.make_dir_recursive_absolute("res://assets/materials")

	print("创建基础材质...")

	# 1. 地板材质 - 深色镜面（反射霓虹灯光）
	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.05, 0.08, 0.12, 1.0)  # 深蓝灰
	floor_mat.metallic = 0.9
	floor_mat.roughness = 0.2
	floor_mat.emission_enabled = true
	floor_mat.emission = Color(0.0, 0.15, 0.2, 1.0)  # 微弱青色自发光
	floor_mat.emission_energy_multiplier = 0.3

	ResourceSaver.save(floor_mat, "res://assets/materials/floor_mirror.tres")
	print("✓ 地板材质: floor_mirror.tres")

	# 2. 墙壁材质 - 深色哑光
	var wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.03, 0.05, 0.08, 1.0)  # 更深的蓝黑
	wall_mat.metallic = 0.0
	wall_mat.roughness = 0.95

	ResourceSaver.save(wall_mat, "res://assets/materials/wall_dark.tres")
	print("✓ 墙壁材质: wall_dark.tres")

	# 3. 霓虹材质 - 青色
	var neon_cyan = StandardMaterial3D.new()
	neon_cyan.albedo_color = Color(0.0, 0.3, 0.35, 1.0)
	neon_cyan.emission_enabled = true
	neon_cyan.emission = Color(0.0, 1.0, 1.0, 1.0)
	neon_cyan.emission_energy_multiplier = 3.0
	neon_cyan.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	ResourceSaver.save(neon_cyan, "res://assets/materials/neon_cyan.tres")
	print("✓ 霓虹材质(青): neon_cyan.tres")

	# 4. 霓虹材质 - 品红
	var neon_magenta = StandardMaterial3D.new()
	neon_magenta.albedo_color = Color(0.35, 0.0, 0.3, 1.0)
	neon_magenta.emission_enabled = true
	neon_magenta.emission = Color(1.0, 0.0, 1.0, 1.0)
	neon_magenta.emission_energy_multiplier = 3.0
	neon_magenta.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	ResourceSaver.save(neon_magenta, "res://assets/materials/neon_magenta.tres")
	print("✓ 霓虹材质(品红): neon_magenta.tres")

	print("\n完成! 已创建 4 个基础材质")
	print("位置: assets/materials/")
	print("\n使用方法:")
	print("  在场景中选择 MeshInstance3D")
	print("  Material Override 加载材质")

	quit()
