extends Node
## 开场演出。经由 CameraDirector 借用电影镜头，直到落地档案馆为止。
##
## 开机不是 UI：玩家在世界里按下一台 CRT 的物理电源键。
## 引导全靠非语言线索——掌光、奶蛙的视线、电源键呼吸。

## 奶蛙蜷在机箱顶上睡觉。终端立在展台上，机箱顶 y = 0.5 + 0.14 + 1.32。
const FROG_PERCH := Vector3(-3.5, 2.585, -0.35)
const PALM_SPAN := Vector2(3.4, 2.6)
const PALM_CENTER := Vector3(-3.5, 1.7, 1.3)
const WAKE_TRAVEL := 0.12
const IDLE_TIMEOUT := 6.0
const INVITE_TIMEOUT := 14.0
const ARCHIVE_SPAWN := Vector3(-4.5, 4.0, 0.0)
const ARCHIVE_FLOOR_Y := 0.625
const ARRIVAL_PORTAL_POSITION := Vector3(-4.5, 2.25, -0.15)
const ARRIVAL_HOLD := 0.14
const ARRIVAL_FALL_TIME := 1.05
## 分裂桥段自带固定时长（约 9s），这里再加一道硬上限防卡。
const MITOSIS_TIMEOUT := 12.0
const MITOSIS_ACT := preload("res://scripts/mitosis_act.gd")

var world: Node3D
var phase := "idle"
var elapsed := 0.0
var tunnel: Node3D
var signal_node: MeshInstance3D
var fragments: Array[Node3D] = []
var gallery_pieces: Array[Node3D] = []
var original_transforms: Array[Transform3D] = []
var cue: Label
var steer := Vector2.ZERO
var pull_start := Vector3.ZERO
var camera_start := Vector3.ZERO
var input_state: Node
var camera_director: Node
var terminal: Node3D
var arrival_portal: ArrivalPortal
var mitosis: Node3D
var palm_point := PALM_CENTER
var palm_strength := 0.0
var pointer_travel := 0.0
var last_pointer := Vector2(0.5, 0.5)
var thump_time := -1.0
var thumped := false
var _thump_registered := false
var morph_meshes: Array[MeshInstance3D] = []
var ambience: AudioStreamPlayer
var effect: AudioStreamPlayer
var grabbed := false
var landed := false
## 吸入白块 / 隧道穿越时挂在奶蛙身上的奶色拖尾。
var trail: CPUParticles3D

func pose(blink: float, reach: float) -> void:
	for mesh in morph_meshes:
		for i in range(mesh.mesh.get_blend_shape_count()):
			var key: String = mesh.mesh.get_blend_shape_name(i)
			mesh.set_blend_shape_value(i, blink if key == "Blink" else reach)

func sound(name: String) -> void:
	effect.stream = load("res://assets/audio/%s.wav" % name)
	effect.play()

## 奶蛙睁眼的一刻，开场标题融化退场。
func _dismiss_title() -> void:
	var card: Node = world.get_node_or_null("Interface/TitleCard")
	if card != null and card.has_method("dismiss"):
		card.dismiss()

func setup(owner_world: Node3D) -> void:
	world = owner_world
	input_state = world.input_state
	camera_director = world.camera_director
	for node in world.frog_visual.find_children("*", "MeshInstance3D", true, false):
		if node.mesh.get_blend_shape_count() > 0:
			morph_meshes.append(node)
	ambience = $Ambience
	effect = $StorySound
	ambience.finished.connect(ambience.play)
	ambience.play()
	pose(1, 0)
	var gallery: Node3D = world.get_node("PresentDayGallery")
	for child in gallery.get_children():
		if child is MeshInstance3D and child.name != "UnknownSignal":
			gallery_pieces.append(child)
			original_transforms.append(child.transform)
	signal_node = gallery.get_node("UnknownSignal")
	signal_node.visible = false
	tunnel = world.get_node("TimeTunnel")
	tunnel.visible = false
	for child in tunnel.get_children():
		if child.is_in_group("tunnel_fragments"):
			fragments.append(child)
	cue = world.get_node("Interface/StoryCue")
	cue.text = ""
	terminal = gallery.get_node("BootTerminal")
	# 分裂桥段挂在展厅下，随展厅一起隐去。
	mitosis = MITOSIS_ACT.new()
	mitosis.name = "MitosisAct"
	gallery.add_child(mitosis)
	arrival_portal = world.arrival_portal
	if arrival_portal != null:
		arrival_portal.visible = false
	world.player.position = FROG_PERCH
	world.frog_visual.rotation.z = -0.16
	last_pointer = input_state.pointer
	# 奶色拖尾:吸入白块与隧道穿越时挂在奶蛙身后,像一滴被拽飞的牛奶。
	trail = CPUParticles3D.new()
	trail.name = "FrogTrail"
	trail.amount = 70
	trail.lifetime = 0.6
	trail.emitting = false
	var spark := QuadMesh.new()
	spark.size = Vector2(0.1, 0.1)
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spark_mat.albedo_color = Color(0.75, 0.92, 1.0, 0.55)
	spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spark.material = spark_mat
	trail.mesh = spark
	trail.direction = Vector3.ZERO
	trail.spread = 180.0
	trail.initial_velocity_min = 0.2
	trail.initial_velocity_max = 0.9
	trail.gravity = Vector3.ZERO
	trail.damping_min = 1.0
	trail.damping_max = 2.0
	trail.scale_amount_min = 0.5
	trail.scale_amount_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(0.8, 0.95, 1.0, 0.9))
	fade.set_color(1, Color(0.4, 0.7, 1.0, 0.0))
	trail.color_ramp = fade
	trail.position = Vector3(0, 0.6, 0)
	world.player.add_child(trail)

func enter(next: String) -> void:
	# 兼容旧的阶段名：抵达不再显示加载界面，而是直接打开传送门。
	if next == "load":
		next = "arrival"
	phase = next
	elapsed = 0.0
	match next:
		"seen":
			sound("signal")
			_dismiss_title()
		"boot":
			terminal.power_on()
			camera_director.add_shake(0.42)
			sound("signal")
		"mitosis":
			# 奶蛙就在机箱顶上分裂，分身从同一点弹出。
			mitosis.begin(world.player.position)
		"pull":
			sound("pull")
			if trail != null:
				trail.emitting = true
		"tunnel":
			sound("tunnel")
		"arrival":
			effect.stop()
			if trail != null:
				trail.emitting = false
			_begin_arrival()
		"land": landed = false
		"done": pose(0, 0)

func update(delta: float) -> bool:
	if phase == "done":
		return false
	elapsed += delta
	# 确认动作由 InputState 归一化：视觉识别的抓握与鼠标左键等价。
	var clicked: bool = input_state.consume_confirm()
	steer = steer.lerp(input_state.steer, 1.0 - exp(-delta * 4.0))
	var body: Node3D = world.frog_visual
	_track_palm(delta)
	match phase:
		"idle":
			# 暗房待机。零文字零按钮，只有呼吸和极慢的镜头漂移说明「没卡住」。
			pose(1, 0)
			body.scale = Vector3(1, 0.94 + sin(elapsed * 1.8) * 0.012, 1)
			_boot_camera(sin(elapsed * 0.22) * 0.55)
			# 鼠标兑底下 active 永远为真，所以“被看见”要区分两种输入：
			# 视觉模式看手是否真的进画，鼠标模式看指针是否真的在动。
			var noticed: bool = input_state.is_vision_driven() and palm_strength > 0.35
			if noticed or pointer_travel > WAKE_TRAVEL or clicked or elapsed > IDLE_TIMEOUT:
				enter("seen")
		"seen":
			# 「我看见你了」：睁眼、看向掌光。零教程能不能成立全看这一下。
			pose(1.0 - smoothstep(0.1, 0.9, elapsed), 0)
			body.scale = body.scale.lerp(Vector3.ONE, delta * 3.0)
			body.rotation.z = lerpf(body.rotation.z, 0.0, delta * 3.0)
			_look_at_point(body, palm_point, delta * 4.0)
			_boot_camera(sin(elapsed * 0.22) * 0.4)
			if elapsed > 1.15:
				enter("invite")
		"invite":
			# 非语言的「指那儿」：电源键呼吸，奶蛙视线在键与你的手之间来回。
			pose(0, 0)
			terminal.set_invite(true)
			var to_button := fmod(elapsed, 2.4) > 1.2
			var gaze: Vector3 = terminal.button_world_position() if to_button else palm_point
			_look_at_point(body, gaze, delta * 3.2)
			body.scale = body.scale.lerp(Vector3(1, 1, 1), delta * 3.0)
			_boot_camera(sin(elapsed * 0.22) * 0.3)
			if clicked or elapsed > INVITE_TIMEOUT:
				terminal.set_invite(false)
				enter("boot")
		"boot":
			# 开机自检跑在终端自己身上；这里只管奶蛙被吓醒和拍机箱。
			var startle := maxf(1.0 - elapsed * 1.6, 0.0)
			body.scale = Vector3(1.0 - startle * 0.16, 1.0 + startle * 0.26, 1.0 - startle * 0.16)
			if elapsed < 1.0:
				_look_at_point(body, terminal.screen_world_position(), delta * 6.0)
			else:
				_look_at_point(body, palm_point, delta * 2.0)
			world.player.position.y = FROG_PERCH.y + startle * 0.22
			_boot_camera(0.0)
			_drive_thump(delta, body)
			if terminal.is_complete():
				enter("mitosis")
		"mitosis":
			# 分裂桥段：本体只驱动主角，分身的表演在 mitosis_act 里。
			mitosis.advance(delta)
			_drive_mitosis_body(delta, body)
			_mitosis_camera()
			if mitosis.is_complete() or elapsed > MITOSIS_TIMEOUT:
				mitosis.cleanup()
				signal_node.visible = true
				pull_start = world.player.position
				camera_start = world.camera.position
				enter("pull")
		"pull":
			var p := clampf(elapsed / 4.5, 0, 1)
			var force := p * p * p
			pose(0, smoothstep(0.15, 0.48, p))
			ambience.volume_db = lerpf(-12, -40, p)
			terminal.collapse(force)
			# 非语言的「握住」邀请：信号急促脉动，握住后转为稳定亮起。
			if p > 0.3 and p < 0.78 and not grabbed:
				signal_node.scale *= 1.0 + sin(elapsed * 22.0) * 0.16
				if clicked:
					grabbed = true
					camera_director.add_shake(0.3)
			var destination := Vector3(4.5, 4.0, -3.0)
			# 飞行轨迹:起步滞重(挣扎),中段抬头划弧,后段加速吸进白块;
			# 摆动幅度随靠近收束,像被越拉越紧的吸力吞没。
			var travel := pow(p, 1.6)
			var pull_point := pull_start.lerp(destination, travel)
			pull_point.y += sin(p * PI) * (0.4 + force * 1.2)
			var struggle := 1.0 - p
			pull_point.x += (sin(elapsed * 5.2) * 0.42 + sin(elapsed * 11.0) * 0.1) * struggle
			pull_point.z += cos(elapsed * 4.3) * 0.3 * struggle
			world.player.position = pull_point
			# 头朝白光:身体转向光块并抬头,拉长成"被拽飞"的姿态。
			var to_light := destination + Vector3(0, 0.4, 0) - body.global_position
			var flat := Vector2(to_light.x, to_light.z).length()
			if flat > 0.01:
				body.rotation.y = lerp_angle(body.rotation.y, atan2(to_light.x, to_light.z), delta * 6.0)
				body.rotation.x = lerp(body.rotation.x, -atan2(to_light.y, flat) * 0.8, delta * 5.0)
			body.rotation.z = -sin(p * PI) * 0.4 + sin(elapsed * 5.2) * 0.18 * struggle
			body.scale = Vector3(1.0 - force * 0.5, 1.0 - force * 0.42, 1.0 + force * 0.55)
			signal_node.position = destination.lerp(pull_start + Vector3(0, 1, 0), sin(p * PI) * 0.65)
			signal_node.scale = Vector3.ONE * (1 + force * 22)
			camera_director.add_shake(force * 0.16)
			for i in range(gallery_pieces.size()):
				var piece := gallery_pieces[i]
				var original := original_transforms[i]
				piece.position = original.origin.lerp(destination, force * 0.5)
				piece.scale = Vector3(1 - force * 0.65, 1 - force * 0.3, 1 + force * 9)
				piece.rotation.z = sin(float(i)) * force * 0.35
			camera_director.apply_cinematic(
				camera_start.lerp(Vector3(4.5, 4.1, 2.8), force),
				Vector3(4.5 * p, 3.0 + p, -3),
				44 + force * 34
			)
			flash(smoothstep(0.87, 1.0, p))
			if p >= 1:
				world.get_node("PresentDayGallery").visible = false
				tunnel.visible = true
				enter("tunnel")
		"tunnel":
			var p := clampf(elapsed / 9.0, 0, 1)
			pose(0, (0.8 if grabbed else 0.45) * (1 - smoothstep(0.75, 1, p)))
			var bend := Vector2(sin(elapsed * 0.7) * 0.7, cos(elapsed * 0.6) * 0.4) + steer * 2.5
			for i in range(fragments.size()):
				var z := fposmod(float(i / 12) * 4.5 + elapsed * (12 + p * 12), 58.5) - 49.0
				var angle := float(i % 12) * TAU / 12 + z * 0.022 + elapsed * 0.15
				var depth := (8 - z) / 58.0
				fragments[i].position = Vector3(cos(angle) * 4.5 + bend.x * depth * depth * 5, sin(angle) * 3.3 + 3 + bend.y * depth * depth * 4, z)
				fragments[i].rotation.z = angle * 0.2
			# 超人飞行:头朝隧道深处,随转向压坡。逻辑轨迹干净地跟随 steer;
			# 漂浮/呼吸感全部放在视觉层(frog_visual),不污染逻辑位置。
			world.player.position = Vector3(
				100.0 + steer.x * 1.8,
				2.1 - steer.y * 1.2,
				2.0 - p * 2.4
			)
			var surge := 1.0 + sin(elapsed * 1.7) * 0.18
			body.scale = body.scale.lerp(Vector3(0.78, 0.78, 1.06) * surge, delta * 5.0)
			body.position = Vector3(
				sin(elapsed * 2.6) * 0.22,
				sin(elapsed * 2.0) * 0.12 + sin(elapsed * 1.3) * 0.35,
				0.0
			)
			body.rotation.y = lerp_angle(body.rotation.y, PI, delta * 4.0)
			body.rotation.x = lerp(body.rotation.x, -0.3 + sin(elapsed * 2.3) * 0.06, delta * 5.0)
			body.rotation.z = lerp(body.rotation.z, -steer.x * 0.5, delta * 5.0)
			camera_director.apply_cinematic(
				Vector3(100 + steer.x * 0.8, 2.8 - steer.y * 0.4, 7.2),
				Vector3(100 + bend.x * 0.8, 2.6 + bend.y * 0.5, -14),
				78 + sin(p * PI) * 7,
				-steer.x * 0.12
			)
			flash(maxf(1.0 - elapsed * 1.8, smoothstep(0.91, 1, p)))
			if p >= 1:
				enter("arrival")
		"arrival":
			# 给传送门一个短暂的开合读秒，之后奶蛙从门口掉出。
			if elapsed >= ARRIVAL_HOLD:
				enter("land")
		"land":
			pose(0, 0)
			ambience.volume_db = lerpf(-40, -18, clampf(elapsed / 1.8, 0, 1))
			# 传送门在落地镜头里逐渐解析，完全不显示旧的加载 UI。
			if arrival_portal != null:
				arrival_portal.set_progress(clampf(elapsed / 0.62, 0.0, 1.0))
			var fall_p := clampf(elapsed / ARRIVAL_FALL_TIME, 0.0, 1.0)
			var fall_ease := 1.0 - pow(1.0 - fall_p, 2.15)
			world.player.position.y = lerpf(ARCHIVE_SPAWN.y, ARCHIVE_FLOOR_Y, fall_ease)
			if elapsed > 0.92:
				if not landed:
					landed = true
					sound("landing")
					camera_director.add_shake(0.55)
				var impact := sin(clampf((elapsed - 0.92) / 0.45, 0, 1) * PI)
				body.scale = Vector3(1 + impact * 0.12, 1 - impact * 0.2, 1)
			if elapsed > 1.8:
				if arrival_portal != null:
					arrival_portal.close()
				world.tunnel_overlay.visible = false
				world.story_phase = 2
				world.phase_time = 2
				world.player.velocity = Vector3.ZERO
				# 落地完成后启用档案走廊玩法：记忆交互、柜前 NPC 与街机。
				if world.archive_interaction != null:
					world.archive_interaction.set_active(true)
				if world.archive_npc != null:
					world.archive_npc.set_active(true)
				if world.archive_entrance_npc != null:
					world.archive_entrance_npc.set_active(true)
				if world.archive_arcade != null:
					world.archive_arcade.set_active(true)
				if world.gallery_easel != null:
					world.gallery_easel.set_active(true)
				if world.display_board != null:
					world.display_board.set_active(true)
				if world.cinema_room != null:
					world.cinema_room.set_active(true)
				if world.text_archive_station != null:
					world.text_archive_station.set_active(true)
				enter("done")
	return true

## 抵达档案馆：切换场景、定位镜头，并在出生点打开视觉传送门。
## 传送门是纯视觉 Node3D，没有碰撞，不会干扰奶蛙的落地物理。
func _begin_arrival() -> void:
	if arrival_portal == null:
		# 旧场景没有传送门时仍能安全抵达；只跳过视觉门。
		push_warning("ArrivalPortal 节点缺失，抵达段将以无门模式继续")
	tunnel.visible = false
	world.get_node("PresentDayGallery").visible = false
	world.archive_root.visible = true
	for child in world.get_children():
		if child is StaticBody3D and child.has_meta("archive_collision"):
			child.process_mode = Node.PROCESS_MODE_INHERIT
	world.player.velocity = Vector3.ZERO
	world.player.position = ARCHIVE_SPAWN
	camera_director.snap_to(Vector3(-1.8, 4.6, 12.5), Vector3(-1.8, 2.35, 0), 44)
	world.frog_visual.rotation = Vector3.ZERO
	world.frog_visual.scale = Vector3.ONE
	world.frog_visual.position = Vector3.ZERO
	# tunnel 结束时可能留下最后一帧闪白；在传送门镜头开始前清掉它。
	world.tunnel_overlay.visible = false
	world.tunnel_overlay.color = Color(0.02, 0.04, 0.08, 0)
	world.tunnel_overlay.get_node("LoadingLabel").visible = false
	world.tunnel_overlay.get_node("LoadingTrack").visible = false
	world.tunnel_overlay.get_node("LoadingBar").visible = false
	if arrival_portal != null:
		arrival_portal.open_at(ARRIVAL_PORTAL_POSITION)
		arrival_portal.set_progress(0.0)

## 掌光：把 InputState 的归一化指针投到展台前的一层世界平面上。
## 不用相机 unproject，因为开场镜头本身在动，固定平面更稳。
func _track_palm(delta: float) -> void:
	var pointer: Vector2 = input_state.pointer
	pointer_travel += pointer.distance_to(last_pointer)
	last_pointer = pointer
	var active: bool = input_state.active
	var target := 1.0 if active else 0.0
	palm_strength = lerpf(palm_strength, target, 1.0 - exp(-delta * 5.0))
	palm_point = PALM_CENTER + Vector3(
		(pointer.x - 0.5) * PALM_SPAN.x,
		(0.5 - pointer.y) * PALM_SPAN.y,
		0.0
	)
	if terminal != null:
		terminal.set_palm(palm_point, palm_strength if phase != "pull" else 0.0)

## 开机段的镜头：靠近终端的侧住机位，极慢漂移说明程序活着。
func _boot_camera(drift: float) -> void:
	camera_director.apply_cinematic(
		Vector3(-2.4 + drift, 2.9, 4.5),
		Vector3(-3.4, 1.95, -0.3),
		40.0
	)

## 转向目标。只动 yaw，保持侧视构图不被破坏。
func _look_at_point(body: Node3D, target: Vector3, weight: float) -> void:
	var to_target := target - body.global_position
	if to_target.length_squared() < 0.0004:
		return
	var yaw := atan2(to_target.x, to_target.z)
	body.rotation.y = lerp_angle(body.rotation.y, yaw, clampf(weight, 0.0, 1.0))

## 进度条卡 99% 的踹机箱喜剧桥段,时间轴共约 2.45 秒:
##   0.00-0.55 慢慢下蹲蓄力,再猛地拉长成弹簧
##   0.55-0.85 喜剧定格:绷到最长带一丝发抖
##   0.85-0.99 假跺!结结实实一下——进度条毫无反应
##   0.99-1.39 迷惑:直起身歪头,小碎跳表示「嗯?」
##   1.39-1.71 深吸一口气,这次蓄得更满
##   1.71-1.85 真跺!命中帧放行进度条 + 大震屏 + 镜头前冲
##   1.85-2.45 果冻余震,慢慢弹回原形
func _drive_thump(delta: float, body: Node3D) -> void:
	if thump_time < 0.0:
		if terminal.needs_thump():
			thump_time = 0.0
		return
	if thumped:
		return
	thump_time += delta
	var t := thump_time
	world.player.position.y = FROG_PERCH.y
	if t < 0.55:
		# 蓄力:前 70% 慢压,后 30% 猛拉长。
		var p := t / 0.55
		if p < 0.7:
			var q := p / 0.7
			body.scale = Vector3(1.0 + q * 0.14, 1.0 - q * 0.22, 1.0 + q * 0.14)
			body.rotation.z = -q * 0.14
		else:
			var q := (p - 0.7) / 0.3
			body.scale = Vector3(1.14 - q * 0.32, 0.78 + q * 0.5, 1.14 - q * 0.32)
			body.rotation.z = -0.14 + q * 0.3
	elif t < 0.85:
		# 喜剧定格:绷紧 + 高频微抖。
		var tremble := sin(t * 60.0) * 0.012
		body.scale = Vector3(0.82 + tremble, 1.28 - tremble, 0.82)
		body.rotation.z = 0.16 + tremble
		world.player.position.y = FROG_PERCH.y + 0.03
	elif t < 0.99:
		# 假跺:砸下去,但什么都不发生。
		var p := (t - 0.85) / 0.14
		body.scale = Vector3(lerpf(0.82, 1.34, p), lerpf(1.28, 0.66, p), lerpf(0.82, 1.34, p))
		body.rotation.z = lerpf(0.16, 0.0, p)
		world.player.position.y = lerpf(FROG_PERCH.y + 0.03, FROG_PERCH.y - 0.06, p)
		if p >= 1.0:
			camera_director.add_shake(0.3)
			sound("landing")
	elif t < 1.39:
		# 迷惑:直起身,左右歪头看进度条,原地小碎跳。
		var p := (t - 0.99) / 0.4
		body.scale = body.scale.lerp(Vector3.ONE, delta * 10.0)
		body.rotation.z = sin(p * TAU * 2.0) * 0.09 * (1.0 - p)
		world.player.position.y = FROG_PERCH.y + absf(sin(p * TAU)) * 0.05
	elif t < 1.71:
		# 二次蓄力:吸得更多,踉跄着抬得更狠。
		var p := (t - 1.39) / 0.32
		body.scale = Vector3(1.0 - p * 0.24, 1.0 + p * 0.4, 1.0 - p * 0.24)
		body.rotation.z = p * 0.2
		world.player.position.y = FROG_PERCH.y + p * 0.05
	elif t < 1.85:
		# 真跺:命中帧放行 + 大震屏 + FOV 前冲(下一帧 _boot_camera 会拉回)。
		var p := (t - 1.71) / 0.14
		body.scale = Vector3(lerpf(0.76, 1.42, p), lerpf(1.4, 0.6, p), lerpf(0.76, 1.42, p))
		body.rotation.z = lerpf(0.2, 0.0, p)
		world.player.position.y = lerpf(FROG_PERCH.y + 0.05, FROG_PERCH.y - 0.09, p)
		if p >= 1.0 and not _thump_registered:
			_thump_registered = true
			terminal.register_thump()
			camera_director.add_shake(0.75)
			camera_director.apply_cinematic(Vector3(-2.4, 2.9, 4.5), Vector3(-3.4, 1.95, -0.3), 35.0)
			sound("landing")
	else:
		# 果冻余震:阻尼弹跳回原形,收尾后冻结。
		var ft := t - 1.85
		var k := exp(-4.6 * ft)
		var sx := 1.0 + 0.3 * k * cos(13.0 * ft)
		body.scale = Vector3(sx, 1.0 - (sx - 1.0) * 0.85, sx)
		body.rotation.z = 0.35 * k * sin(11.0 * ft)
		world.player.position.y = FROG_PERCH.y
		if ft > 0.6:
			body.scale = Vector3.ONE
			body.rotation.z = 0.0
			thumped = true

## 分裂桥段里的主角：被撑大、对话、目送妈妈离开、然后笑场。
## 分身自己的表演在 mitosis_act 里，这里不碰它。
func _drive_mitosis_body(delta: float, body: Node3D) -> void:
	var stage: String = mitosis.stage
	# 分裂全程主角站在机箱顶不动，抖动靠 scale 与 rotation 表达。
	world.player.position.y = FROG_PERCH.y
	match stage:
		"swell":
			# 被体内的妈妈撑得鼓起来，越接近弹开越发抖。
			var s: float = mitosis.swell_amount()
			var tremor := sin(elapsed * 34.0) * s * 0.035
			body.scale = Vector3(1.0 + s * 0.3 + tremor, 1.0 + s * 0.12, 1.0 + s * 0.3)
			body.rotation.z = tremor * 1.6
			pose(0.0, s * 0.7)
		"split":
			# 同一帧弹回去，果冻余震。
			var back: float = mitosis.swell_amount()
			body.scale = Vector3(1.0 + back * 0.22, 1.0 - back * 0.1, 1.0 + back * 0.22)
			body.rotation.z = lerpf(body.rotation.z, 0.0, delta * 8.0)
			pose(0.0, back * 0.4)
			_look_at_point(body, mitosis.twin_world_position(), delta * 7.0)
		"banter":
			body.scale = body.scale.lerp(Vector3.ONE, delta * 6.0)
			body.rotation.z = lerpf(body.rotation.z, 0.0, delta * 6.0)
			pose(0.0, 0.0)
			_look_at_point(body, mitosis.twin_world_position(), delta * 5.0)
		"abandon":
			# 目送：跟着妈妈转头，身体微前倾。
			body.scale = body.scale.lerp(Vector3(0.98, 1.02, 0.98), delta * 4.0)
			pose(0.0, 0.0)
			_look_at_point(body, mitosis.twin_world_position(), delta * 6.0)
		"beat":
			# 喜剧停顿：一动不动地盯着妈妈消失的方向。
			body.scale = body.scale.lerp(Vector3.ONE, delta * 3.0)
			pose(0.0, 0.0)
		"laugh":
			# 捧腹大笑：闭眼、后仰、按笑声节奏抽动。
			var amount: float = mitosis.laugh_amount()
			var shake := sin(mitosis.stage_time * TAU * 6.5)
			body.scale = Vector3(
				1.0 + amount * 0.16 + shake * amount * 0.05,
				1.0 - amount * 0.1 - shake * amount * 0.06,
				1.0 + amount * 0.16
			)
			body.rotation.z = shake * amount * 0.14
			# 往后仰，笑得直不起腰
			body.rotation.x = -amount * 0.34
			pose(1.0, 0.0)

## 分裂桥段的镜头：swell/split 推近看果冻感，
## abandon 拉宽保住跑走的妈妈，laugh 再收紧到主角身上。
func _mitosis_camera() -> void:
	var stage: String = mitosis.stage
	var twin: Vector3 = mitosis.twin_world_position()
	var focus: Vector3 = (world.player.position + twin) * 0.5
	match stage:
		"abandon":
			camera_director.apply_cinematic(
				Vector3(focus.x + 1.6, 3.0, 7.4),
				Vector3(focus.x, 1.7, -0.3),
				54.0
			)
		"beat", "laugh":
			camera_director.apply_cinematic(
				Vector3(-2.6, 2.95, 3.7),
				Vector3(-3.5, 2.35, -0.3),
				35.0
			)
		_:
			camera_director.apply_cinematic(
				Vector3(-2.9, 2.95, 3.9),
				Vector3(focus.x, 2.3, -0.3),
				37.0
			)

func flash(amount: float) -> void:
	world.tunnel_overlay.visible = amount > 0
	world.tunnel_overlay.color = Color(0.7, 0.9, 0.94, amount)
	world.tunnel_overlay.get_node("LoadingLabel").modulate.a = 0
	world.loading_bar.visible = false
	world.loading_bar.get_parent().get_node("LoadingTrack").visible = false

