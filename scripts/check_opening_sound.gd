extends SceneTree
## 开场音效时间线探针：逐帧驱动开场演出，把每一个 AudioStreamPlayer
## 的发声瞬间按时间戳打印出来，用于定位"嘎嘎提拉晒前多出来的音效"。

var log_lines: Array[String] = []

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame

	var players: Array[AudioStreamPlayer] = []
	for node in scene.find_children("*", "AudioStreamPlayer", true, false):
		players.append(node)

	var was_playing := {}
	for p in players:
		was_playing[p] = false

	var dt := 1.0 / 60.0
	var t := 0.0
	var last_phase := ""

	for frame in range(4200):
		scene.opening.terminal._process(dt)
		scene.opening.update(dt)
		var current: String = scene.opening.phase
		if current != last_phase:
			log_lines.append("[%6.2fs] PHASE -> %s" % [t, current])
			last_phase = current

		if current == "boot" and scene.opening.elapsed > 2.2:
			scene.input_state.confirm_just_pressed = true
		if current == "pull" and scene.opening.elapsed > 2.4:
			scene.input_state.confirm_just_pressed = true

		for p in players:
			var playing: bool = p.playing
			if playing and not was_playing[p]:
				var stream_path := "-"
				if p.stream != null:
					stream_path = str(p.stream.resource_path)
				log_lines.append("[%6.2fs] SOUND %s vol=%.1f stream=%s" % [t, String(p.get_path()), p.volume_db, stream_path])
			was_playing[p] = playing

		t += dt
		if current == "done":
			break

	print("\n===== 开场音效时间线 =====")
	for line in log_lines:
		print(line)
	print("===== 结束 (共 %.2fs) =====" % t)
	quit()
