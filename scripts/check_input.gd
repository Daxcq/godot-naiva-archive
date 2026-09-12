extends SceneTree
## 无头验证：真实键盘事件（device=0）现在能否驱动移动动作。

func _init() -> void:
	var lines: Array[String] = []
	var actions := ["move_left", "move_right", "move_forward", "move_back", "jump", "interact"]

	for action in actions:
		if not InputMap.has_action(action):
			lines.append("FAIL %-14s not registered" % action)
			continue
		var devices: Array[int] = []
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				devices.append(ev.device)
		var ok := devices.size() > 0 and devices.all(func(d): return d == 0)
		lines.append("%s %-14s devices=%s" % ["PASS" if ok else "FAIL", action, devices])

	# 用 device=0 合成真实按键，验证动作真的被触发
	lines.append("--- 真实按键模拟 (device=0) ---")
	var cases := [
		[KEY_W, "move_forward"], [KEY_S, "move_back"],
		[KEY_A, "move_left"], [KEY_D, "move_right"], [KEY_SPACE, "jump"],
	]
	var all_ok := true
	for c in cases:
		var down := InputEventKey.new()
		down.physical_keycode = c[0]
		down.pressed = true
		Input.parse_input_event(down)
		await process_frame
		var pressed := Input.is_action_pressed(c[1])
		var vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		lines.append("  %-14s pressed=%-5s vector=%s" % [c[1], pressed, vec])
		if not pressed:
			all_ok = false
		var up := InputEventKey.new()
		up.physical_keycode = c[0]
		up.pressed = false
		Input.parse_input_event(up)
		await process_frame

	# 方向键也要能用
	lines.append("--- 方向键 ---")
	for c in [[KEY_UP, "move_forward"], [KEY_DOWN, "move_back"], [KEY_LEFT, "move_left"], [KEY_RIGHT, "move_right"]]:
		var down := InputEventKey.new()
		down.physical_keycode = c[0]
		down.pressed = true
		Input.parse_input_event(down)
		await process_frame
		var pressed := Input.is_action_pressed(c[1])
		lines.append("  %-14s pressed=%s" % [c[1], pressed])
		if not pressed:
			all_ok = false
		var up := InputEventKey.new()
		up.physical_keycode = c[0]
		up.pressed = false
		Input.parse_input_event(up)
		await process_frame

	lines.append("")
	lines.append("RESULT: " + ("PASS 键盘输入已恢复" if all_ok else "FAIL 仍有动作绑定异常"))
	print("\n".join(lines))
	quit()
