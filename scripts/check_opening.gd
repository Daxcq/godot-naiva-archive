extends SceneTree
## 开场演出检查：奶蛙开屏位置 + 大笑效果 + 传送后落地。
##
## 说明：`--script` 无头模式下场景节点的 _process 不会自动步进，
## 所以这里显式驱动 opening / mitosis / terminal，逐帧断言。
## 需要截图时加 `-- --capture`。

var capture_enabled := false

func _initialize() -> void:
	capture_enabled = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	call_deferred("check")

func capture(label: String) -> void:
	if not capture_enabled:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "user://opening_%s.png" % label
	root.get_texture().get_image().save_png(path)
	print("CAPTURE: ", ProjectSettings.globalize_path(path))

func check() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	assert(scene.archive_root != null)
	assert(scene.meme_room == null)
	assert(scene.opening.morph_meshes.size() == 4)

	# ---- 1. 开屏位置：奶蛙蹲在机箱顶 ----
	scene.opening.enter("idle")
	scene.set_physics_process(false)
	var perch: Vector3 = scene.opening.FROG_PERCH
	assert(scene.player.position.is_equal_approx(perch),
		"开场奶蛙位置不对：%s != %s" % [scene.player.position, perch])
	assert(is_equal_approx(scene.frog_visual.rotation.z, -0.16),
		"开场奶蛙应有 -0.16 的侧倾，实际 %f" % scene.frog_visual.rotation.z)
	print("PASS 1: 开屏奶蛙蹲在机箱顶 %s，侧倾 %.2f" % [scene.player.position, scene.frog_visual.rotation.z])

	# ---- 2. 逐帧推进整个开场，同时盯住大笑段 ----
	var phases_seen: Array[String] = []
	var laugh_seen := false
	var laugh_peak := 0.0
	var grounded := false
	var dt := 1.0 / 60.0

	for frame in range(3600):
		# 无头下节点 _process 不跑，显式驱动终端与分裂演出。
		scene.opening.terminal._process(dt)
		scene.opening.update(dt)
		var current: String = scene.opening.phase
		if current not in phases_seen:
			phases_seen.append(current)

		# boot / pull 段在无头环境等不到真实点击，补一次确认推进状态机。
		if current == "boot" and scene.opening.elapsed > 2.2:
			scene.input_state.confirm_just_pressed = true
		if current == "pull" and scene.opening.elapsed > 2.4:
			scene.input_state.confirm_just_pressed = true

		# 大笑：分裂桥段跑到 laugh 段时验证身体姿态。
		if current == "mitosis" and scene.opening.mitosis != null:
			var stage: String = scene.opening.mitosis.stage
			if stage == "laugh":
				var amount: float = scene.opening.mitosis.laugh_amount()
				laugh_peak = maxf(laugh_peak, amount)
				if amount > 0.3 and not laugh_seen:
					laugh_seen = true
					# 后仰是这段最显眼的姿态特征。
					assert(scene.frog_visual.rotation.x < -0.01,
						"大笑时奶蛙应后仰 rotation.x<0，实际 %f" % scene.frog_visual.rotation.x)
					print("PASS 2: 大笑演出触发 amount=%.2f 后仰=%.3f" % [amount, scene.frog_visual.rotation.x])
					await capture("laugh")

		if current == "done":
			grounded = true
			break

	assert(laugh_seen, "开场没有跑到 laugh 段（最终 phase=%s）" % scene.opening.phase)
	assert(grounded, "开场没能抵达 done（最终 phase=%s，已见 %s）" % [scene.opening.phase, phases_seen])
	assert(laugh_peak > 0.5, "大笑强度峰值过低：%.2f" % laugh_peak)

	# ---- 3. 传送后落地：奶蛙必须站在档案馆地面 ----
	assert(scene.archive_root.visible, "落幕后档案馆应可见")
	assert(scene.archive_interaction != null and scene.archive_interaction.active)
	assert(is_equal_approx(scene.player.position.y, 0.625),
		"落地后奶蛙 y 应为 0.625，实际 %f" % scene.player.position.y)
	print("PASS 3: 传送到档案馆并落地 y=%.3f" % scene.player.position.y)
	print("     阶段序列: %s" % [" → ".join(phases_seen)])

	# ---- 4. 隧道转向仍然生效 ----
	scene.opening.enter("tunnel")
	scene.opening.steer = Vector2(-1, 0)
	await process_frame
	for step in range(60):
		scene.opening.terminal._process(dt)
		scene.opening.update(dt)
	var left_x: float = scene.player.position.x
	scene.opening.steer = Vector2(1, 0)
	await process_frame
	for step in range(60):
		scene.opening.terminal._process(dt)
		scene.opening.update(dt)
	assert(scene.player.position.x > left_x, "隧道内左右转向应改变轨迹")
	assert(scene.opening.phase == "tunnel")
	print("PASS 4: 隧道掌控转向生效 (x %.2f -> %.2f)" % [left_x, scene.player.position.x])

	print("PASS: 开场演出检查全部通过")
	quit()
