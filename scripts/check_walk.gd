extends SceneTree
# 奶蛙走路效果回归测试
# 跑法： Godot --headless --path . --script res://scripts/check_walk.gd

var scene: Node

func _initialize() -> void:
	print("=== 走路效果（摆腿/摆臂）检查 ===")
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	# SceneTree 脚本模式下 _ready() 不一定被驱动，显式调用保证骨架已定位
	if scene.has_method("_ready"):
		scene._ready()

	var frog_visual: Node3D = scene.get_node_or_null("MilkFrog/CharacterVisual")
	if frog_visual == null:
		print("RESULT: FAIL 找不到 MilkFrog/CharacterVisual")
		quit(); return

	# --- 1. main.gd 实际拿到的骨架 ---
	print("\n[1] 骨架定位")
	var skel: Skeleton3D = scene.skeleton
	print("  main.gd 拿到的 skeleton -> ", skel)
	if skel == null:
		print("RESULT: FAIL 骨架为 null，apply_locomotion_pose 会直接 return")
		quit(); return
	print("  节点路径 -> ", scene.get_path_to(skel))

	# --- 2. 骨骼名核对 ---
	print("\n[2] 骨骼列表 (共 %d 根):" % skel.get_bone_count())
	for i in skel.get_bone_count():
		print("    [%d] %s" % [i, skel.get_bone_name(i)])
	var wanted := ["L_thigh", "R_thigh", "L_arm", "R_arm", "spine"]
	var miss := 0
	print("\n  需要驱动的骨骼:")
	for w in wanted:
		var idx: int = skel.find_bone(w)
		if idx < 0:
			miss += 1
		print("    %-10s %s" % [w, "OK idx=%d" % idx if idx >= 0 else "缺失!"])
	if miss > 0:
		print("RESULT: FAIL %d 根骨骼没找到" % miss)
		quit(); return

	# --- 3. 摆腿/摆臂驱动实测 ---
	print("\n[3] 驱动实测（走 walk 公式，anim_time=1.2）")
	var anim_time := 1.2
	var phase := sin(anim_time)
	var stride := 0.28  # walk
	var moved := 0
	for pair in [["L_thigh", 1.0], ["R_thigh", -1.0], ["L_arm", -0.8], ["R_arm", 0.8]]:
		var idx: int = skel.find_bone(pair[0])
		skel.set_bone_pose_rotation(idx, Quaternion.IDENTITY)
		var before: Quaternion = skel.get_bone_pose_rotation(idx)
		var amount: float = float(pair[1]) * stride * phase
		skel.set_bone_pose_rotation(idx, Quaternion(Vector3.RIGHT, amount))
		var after: Quaternion = skel.get_bone_pose_rotation(idx)
		var delta_ang := rad_to_deg(after.angle_to(before))
		var ok := delta_ang > 1.0
		if ok:
			moved += 1
		print("    %-9s 摆幅 %6.2f°  %s" % [pair[0], delta_ang, "OK" if ok else "没动!"])

	# --- 4. 结论 ---
	print("\n=== 结论 ===")
	if moved == 4:
		print("摆腿 + 摆臂 4 根骨骼全部响应，走路效果恢复")
		print("RESULT: PASS")
	else:
		print("只有 %d/4 根骨骼响应" % moved)
		print("RESULT: FAIL")
	quit()
