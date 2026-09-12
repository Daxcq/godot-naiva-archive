extends SceneTree
# 真渲染对比：把角色摆到镜头正中、侧对镜头，抓"静止 vs 最大摆幅"两帧
# 跑法： Godot --path . --script res://scripts/_probe3.gd

var world: Node
var tick := 0
var phase := 0
var img_a: Image
var img_b: Image

func _initialize() -> void:
	world = load("res://main.tscn").instantiate()
	root.add_child(world)

func _process(delta: float) -> bool:
	tick += 1
	if tick < 3:
		return false

	if tick == 3:
		world.get("opening").set("phase", "done")
		# 藏掉档案馆（避免大黑框挡住），只留角色
		world.get("archive_root").visible = false
		world.get_node("PresentDayGallery").visible = false
		world.get_node("GroundCollision").visible = false
		# 角色抬高到画面正中
		var player: Node3D = world.get_node("MilkFrog")
		player.global_position = Vector3(0, 2.5, 0)
		var cv: Node3D = world.get_node("MilkFrog/CharacterVisual")
		cv.rotation = Vector3.ZERO
		cv.scale = Vector3.ONE
		# 相机对准角色中心
		var cam: Camera3D = world.get_node("CinematicSideCamera")
		cam.global_position = Vector3(0, 2.4, 5.0)
		cam.look_at(Vector3(0, 2.4, 0))
		cam.fov = 35.0
		print("[S] 场景已摆好, player=", player.global_position)
		return false

	var skel = world.get("skeleton")
	if skel == null or not (skel is Skeleton3D):
		print("[S] skeleton null"); return true
	var sk: Skeleton3D = skel

	if tick == 8:
		# A: 中立
		for nm in ["L_thigh", "R_thigh", "L_arm", "R_arm", "spine"]:
			var i := sk.find_bone(nm)
			if i >= 0:
				sk.set_bone_pose_rotation(i, Quaternion.IDENTITY)
		return false

	if tick == 12:
		img_a = _grab()
		print("[S] A 已抓")
		return false

	if tick == 16:
		# B: 最大摆幅 0.28 rad（与游戏内 walk 一致）
		sk.set_bone_pose_rotation(sk.find_bone("L_thigh"), Quaternion(Vector3.RIGHT, 0.28))
		sk.set_bone_pose_rotation(sk.find_bone("R_thigh"), Quaternion(Vector3.RIGHT, -0.28))
		sk.set_bone_pose_rotation(sk.find_bone("L_arm"), Quaternion(Vector3.RIGHT, -0.224))
		sk.set_bone_pose_rotation(sk.find_bone("R_arm"), Quaternion(Vector3.RIGHT, 0.224))
		return false

	if tick == 20:
		img_b = _grab()
		print("[S] B 已抓")
		_save_and_diff()
		return true
	return false

func _grab() -> Image:
	RenderingServer.force_draw()
	return get_root().get_texture().get_image()

func _save_and_diff() -> void:
	if img_a == null or img_b == null:
		print("[S] 抓图失败"); return
	img_a.save_png("res://shot_A.png")
	img_b.save_png("res://shot_B.png")
	# 找差异包围盒
	var minx := 99999; var maxx := -1; var miny := 99999; var maxy := -1
	var cnt := 0
	for y in img_a.get_height():
		for x in img_a.get_width():
			var ca := img_a.get_pixel(x, y)
			var cb := img_b.get_pixel(x, y)
			if absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b) > 0.04:
				cnt += 1
				minx = mini(minx, x); maxx = maxi(maxx, x)
				miny = mini(miny, y); maxy = maxi(maxy, y)
	print("[S] 差异像素 %d 个" % cnt)
	if cnt > 0:
		print("[S] 差异包围盒 x=[%d,%d] y=[%d,%d]  尺寸=%dx%d" % [minx,maxx,miny,maxy,maxx-minx,maxy-miny])
	print("[S] 已保存 res://shot_A.png / shot_B.png")
	print("[S] 画面尺寸 %dx%d" % [img_a.get_width(), img_a.get_height()])
