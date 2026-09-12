extends SceneTree
# 用真正的引擎主循环 + 手动驱动帧，最接近真机地记录走路状态
# 跑法： Godot --headless --path . --script res://scripts/_probe2.gd

var world: Node
var tick := 0
var lines: Array[String] = []
var ready_done := false

func _initialize() -> void:
	world = load("res://main.tscn").instantiate()
	# 关键：先 add_child，让引擎自己跑完 _ready，再往下走
	root.add_child(world)
	print("已 add_child")

func _process(delta: float) -> bool:
	tick += 1

	if not ready_done:
		if tick < 3:
			return false
		ready_done = true
		_lines()
		return false

	# 手动推进帧，模拟真机
	if tick % 2 == 0:
		world._physics_process(0.016)
		_record()

	if lines.size() >= 40:
		_dump()
		return true
	return false

func _lines() -> void:
	_put("=== 启动检查 ===")
	_put("world = " + str(world))
	_put("world.skeleton = " + str(world.get("skeleton")))
	var fv: Node = world.get_node_or_null("MilkFrog/CharacterVisual")
	_put("CharacterVisual = " + str(fv))
	if fv != null:
		var arr := fv.find_children("*", "Skeleton3D", true, false)
		_put("子树 Skeleton3D 数 = %d" % arr.size())
		for a in arr:
			if a is Skeleton3D:
				_put("  '%s' bones=%d" % [a.name, (a as Skeleton3D).get_bone_count()])
	# 跳过开屏
	world.get("opening").set("phase", "done")
	_put("opening.phase -> " + str(world.get("opening").get("phase")))
	# 注入 D 键
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_D
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	_put("注入D: move_right=%s get_vector=%s" % [
		Input.is_action_pressed("move_right"),
		Input.get_vector("move_left", "move_right", "move_forward", "move_back")])

func _record() -> void:
	var skel = world.get("skeleton")
	var deg := -1.0
	if skel != null and skel is Skeleton3D:
		var i: int = (skel as Skeleton3D).find_bone("L_thigh")
		if i >= 0:
			deg = rad_to_deg((skel as Skeleton3D).get_bone_pose_rotation(i).angle_to(Quaternion.IDENTITY))
	var ist = world.get("input_state")
	_put("f%3d loco=%-6s axis=%s anim=%5.2f skel=%s 摆角=%6.2f° pos=%s" % [
		tick, str(world.get("locomotion")), str(ist.get("axis")) if ist else "?",
		float(world.get("anim_time") or 0.0),
		"OK" if skel != null else "NULL", deg,
		str((world.get("player").position as Vector3).snappedf(0.01)) if world.get("player") else "?"])

func _dump() -> void:
	var f := FileAccess.open("res://_probe.log", FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	for l in lines:
		print("[P] " + l)
	print("=== 落盘 res://_probe.log ===")

func _put(s: String) -> void:
	lines.append(s)
