extends SceneTree
## 临时视觉验证：单独渲染海报墙，抓 idle / 切换中 / 切换后 三帧。
func _init() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("0a0714")
	e.glow_enabled = true
	e.glow_intensity = 0.6
	env.environment = e
	root.add_child(env)
	var wall := MeshInstance3D.new()
	var wm := BoxMesh.new(); wm.size = Vector3(44, 9, 0.2)
	wall.mesh = wm
	wall.position = Vector3(16, 4, -2.55)
	var wall_mat := StandardMaterial3D.new(); wall_mat.albedo_color = Color("181226")
	wall.material_override = wall_mat
	root.add_child(wall)
	var archive_root := Node3D.new()
	root.add_child(archive_root)
	var posters: Node3D = load("res://scripts/archive_posters.gd").new()
	posters.setup(archive_root)
	posters._next_wave = 1.0
	var cam := Camera3D.new()
	cam.position = Vector3(16, 3.4, 6.4)
	cam.fov = 65
	root.add_child(cam)
	cam.make_current()
	var dir := DirAccess.open("res://")
	dir.make_dir_recursive("artifacts")
	await _snap("artifacts/poster_idle.png")
	await create_timer(1.75).timeout
	await _snap("artifacts/poster_transition.png")
	await create_timer(1.2).timeout
	await _snap("artifacts/poster_after.png")
	quit(0)

func _snap(path: String) -> void:
	for i in range(3):
		await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path))
	print("SAVED ", path)
