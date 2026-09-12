extends Node
# 运行时探针：真实游戏循环里记录走路状态。用完即删。

var log_lines: Array[String] = []
var world: Node
var tick := 0
var started := false

func _process(delta: float) -> void:
	tick += 1

	if not started:
		# 等主场景就绪
		if tick < 5:
			return
		world = get_tree().current_scene
		if world == null or world.get_script() == null:
			return
		started = true
		_log("=== 探针启动 (tick=%d) ===" % tick)
		_log("current_scene = " + str(world))
		_log("scene name = " + str(world.name))
		var skel = world.get("skeleton")
		_log("world.skeleton = " + str(skel))
		var fv: Node = world.get_node_or_null("MilkFrog/CharacterVisual")
		_log("CharacterVisual = " + str(fv))
		if fv != null:
			var found := fv.find_children("*", "Skeleton3D", true, false)
			_log("子树 Skeleton3D 数量 = %d" % found.size())
			for f in found:
				if f is Skeleton3D:
					_log("  节点名='%s' 骨骼数=%d" % [f.name, (f as Skeleton3D).get_bone_count()])
		# 跳过开屏
		if world.get("opening") != null:
			world.get("opening").set("phase", "done")
			_log("opening.phase -> done")
		# 注入 D 键向右走
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_D
		ev.pressed = true
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		_log("注入 D: move_right=%s axis_expected=(1,0)" % Input.is_action_pressed("move_right"))
		return

	# 已启动：每 3 帧记录
	if tick % 3 != 0:
		return

	var skel = world.get("skeleton")
	var ist = world.get("input_state")
	var bone_deg := -1.0
	var bone_name := "?"
	if skel != null and skel is Skeleton3D:
		var idx: int = (skel as Skeleton3D).find_bone("L_thigh")
		if idx >= 0:
			var q: Quaternion = (skel as Skeleton3D).get_bone_pose_rotation(idx)
			bone_deg = rad_to_deg(q.angle_to(Quaternion.IDENTITY))
			bone_name = (skel as Skeleton3D).get_bone_name(idx)

	_log("tick=%d loco=%s axis=%s anim=%.2f skel=%s [%s]=%.2f° pos=%s" % [
		tick,
		str(world.get("locomotion")),
		str(ist.get("axis")) if ist else "?",
		float(world.get("anim_time") or 0.0),
		"OK" if skel != null else "NULL",
		bone_name, bone_deg,
		str((world.get("player").position as Vector3).snappedf(0.01)) if world.get("player") else "?"
	])

	# 记录满 ~60 行就落盘退出
	if log_lines.size() >= 45:
		_flush()

func _flush() -> void:
	var f := FileAccess.open("res://_probe.log", FileAccess.WRITE)
	for l in log_lines:
		f.store_line(l)
	f.close()
	print("=== 探针已落盘 res://_probe.log (%d 行) ===" % log_lines.size())
	set_process(false)
	get_tree().quit()

func _log(s: String) -> void:
	log_lines.append(s)
