extends Node3D

@onready var player: CharacterBody3D = $MilkFrog
@onready var camera: Camera3D = $CinematicSideCamera
@onready var frog_visual: Node3D = $MilkFrog/CharacterVisual
@onready var tunnel_overlay: ColorRect = $Interface/TransitionOverlay
@onready var loading_bar: ColorRect = $Interface/TransitionOverlay/LoadingBar
@onready var archive_root: Node3D = $ArchiveArchitecture
@onready var opening: Node = $StoryDirector
@onready var visual_recognition: Node = $VisualRecognition
@onready var input_state: Node = $InputState
@onready var camera_director: Node = $CameraDirector
@onready var arrival_portal: Node3D = $ArrivalPortal
var story_phase := 0
var phase_time := 0.0
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var animated_parts: Array[Node3D] = []
var animated_part_base: Dictionary = {}
var frog_visual_base_y := 0.0
var locomotion := "idle"
var anim_time := 0.0
var meme_room: Node3D
var archive_interaction: Node
var archive_fx: Node
var archive_npc: Node
var archive_arcade: Node
var archive_entrance_npc: Node
var archive_video_screen: Node
var interaction_router: Node
var gallery_easel: Node3D
var display_board: Node
var cinema_room: Node
var text_archive_station: Node
var arcade_active := false
## 奶娃画廊画板打开时冻结世界移动(与街机同机制)。
var board_active := false
var destination_root: Node3D
var destination_id := ""
var destination_active := false
var destination_elapsed := 0.0
var in_destination := false

func _ready() -> void:
	archive_root.visible = false
	# 传送门只在开场抵达段出现；旧加载界面的节点保留用于兼容旧场景，
	# 但从启动开始就明确隐藏，避免任何转场闪白时误显示进度条。
	arrival_portal.visible = false
	$Interface/TransitionOverlay/LoadingLabel.visible = false
	$Interface/TransitionOverlay/LoadingTrack.visible = false
	$Interface/TransitionOverlay/LoadingBar.visible = false
	camera_director.set_follow_bounds(0.0, 31.5)
	# 没有登录界面：开机是世界里的一个物理动作，由 BootTerminal 承担。
	opening.phase = "idle"
	opening.setup(self)
	# 骨架定位：glb 导入后 Skeleton3D 的节点名就是 "Skeleton3D"（父级叫 MilkFrog_Rig），
	# 并不存在 "MilkFrog_Skeleton" / "Armature" 这两个名字。
	# 先按已知名字试，最后递归兜底找任意 Skeleton3D —— 少了兜底会导致
	# apply_locomotion_pose() 里的摆腿/摆臂被 if skeleton == null: return 静默跳过。
	skeleton = _find_skeleton(frog_visual)
	frog_visual_base_y = frog_visual.position.y
	_collect_animated_parts(frog_visual)
	if skeleton == null:
		push_warning("未在 CharacterVisual 下找到 Skeleton3D，走路摆腿效果将不可见")
	# 队友迁移：动画版奶蛙模型(yellow_character_animated.glb)自带 AnimationPlayer，
	# idle/walk/run/jump/fall 六套动作由动画接管；找不到时仍回落程序化摆骨骼。
	animation_player = _find_animation_player(frog_visual)
	if animation_player == null:
		push_warning("未在 CharacterVisual 下找到 AnimationPlayer，角色将使用程序化摆骨骼")
	else:
		for anim_name in ["idle", "walk", "run"]:
			var animation := animation_player.get_animation(anim_name)
			if animation:
				animation.loop_mode = Animation.LOOP_LINEAR
		animation_player.play("idle")
	# 档案走廊玩法栈：三段记忆交互、氛围 FX、柜前 NPC、霓虹海报与三台街机。
	meme_room = null
	# 交互焦点仲裁器:必须先于各交互系统创建,它们 setup 时会来认领。
	# 全场唯一交互提示条 + 每帧只选一个焦点,解决触发圈重叠时的
	# 提示叠字与一次按键多系统同时响应的问题。
	interaction_router = preload("res://scripts/interaction_router.gd").new()
	interaction_router.name = "InteractionRouter"
	add_child(interaction_router)
	interaction_router.setup($Interface)
	interaction_router.register_target("entrance", Vector3(-3.1, 0.0, -1.55))
	interaction_router.register_target("keeper", Vector3(-1.0, 0.0, 0.55))
	interaction_router.register_target("memory", Vector3(11.4, 0.0, -2.5))
	interaction_router.register_target("arcade", Vector3(30.0, 0.0, -2.05))
	interaction_router.register_target("board", Vector3(11.4, 0.0, 1.95))
	interaction_router.register_target("cinema", Vector3(29.5, 0.0, 1.55))
	interaction_router.register_target("text_archive", Vector3(26.2, 0.0, 1.45))
	interaction_router.register_target("easel", Vector3(20.0, 0.0, 1.7))
	archive_interaction = preload("res://scripts/archive_interaction.gd").new()
	archive_interaction.name = "ArchiveInteraction"
	add_child(archive_interaction)
	archive_interaction.setup(self)
	archive_interaction.set_active(false)
	preload("res://scripts/archive_details.gd").build_fx(archive_root)
	archive_fx = preload("res://scripts/archive_fx.gd").new()
	archive_fx.name = "ArchiveFX"
	add_child(archive_fx)
	archive_fx.setup(self, archive_interaction)
	archive_npc = preload("res://scripts/archive_npc_dialogue.gd").new()
	archive_npc.name = "ArchiveNPCDialogue"
	add_child(archive_npc)
	archive_npc.setup(self)
	archive_npc.set_active(false)
	archive_npc.dialogue_started.connect(_on_npc_dialogue_started)
	archive_npc.portal_entered.connect(_on_memory_portal_entered)
	# 入口的牛：独立于档案员的主动线，只在走廊起点陪聊。
	# 它不产生传送门、不推进进度，所以不参与 archive_npc 的状态机。
	archive_entrance_npc = preload("res://scripts/archive_entrance_npc.gd").new()
	archive_entrance_npc.name = "ArchiveEntranceNPC"
	add_child(archive_entrance_npc)
	archive_entrance_npc.setup(self)
	archive_entrance_npc.set_active(false)
	preload("res://scripts/archive_posters.gd").new().setup(archive_root)
	# 队友迁移：真图轮播相框（背墙第二排），与程序化霓虹海报并存。
	preload("res://scripts/archive_photo_frames.gd").new().setup(archive_root)
	archive_arcade = preload("res://scripts/archive_arcade.gd").new()
	archive_arcade.name = "ArchiveArcade"
	add_child(archive_arcade)
	archive_arcade.setup(self)
	archive_arcade.set_active(false)
	archive_arcade.game_started.connect(_on_arcade_started)
	archive_arcade.game_closed.connect(_on_arcade_closed)
	# 奶娃画廊画架:造型是场景资产(archive_space.tscn 内靠墙实例),
	# 这里只取节点接上交互逻辑,落地后可交互。
	gallery_easel = archive_root.get_node_or_null("GalleryEasel")
	if gallery_easel != null:
		gallery_easel.setup(self)
		gallery_easel.set_active(false)
	# 奶娃展板「幸福碎片」:南墙上的视频展板,与画廊画架共用 board_active 冻结通道。
	display_board = preload("res://scripts/archive_display_board.gd").new()
	display_board.name = "DisplayBoard"
	add_child(display_board)
	display_board.setup(self)
	display_board.set_active(false)
	# 奶蛙影院：后段空地的可编辑电影机与全屏放映页。
	cinema_room = get_node_or_null("CinemaRoom")
	if cinema_room != null:
		cinema_room.setup(self)
		cinema_room.set_active(false)
	text_archive_station = get_node_or_null("TextArchiveStation")
	if text_archive_station != null:
		text_archive_station.setup(self)
		text_archive_station.set_active(false)
	# 队友迁移：走廊旧显示屏(DeadScreen)，靠近按 E 播放奶蛙合成影像，Esc 退出。
	archive_video_screen = preload("res://scripts/archive_video_screen.gd").new()
	archive_video_screen.name = "ArchiveVideoScreen"
	add_child(archive_video_screen)
	archive_video_screen.setup(self)

func _physics_process(delta: float) -> void:
	# InputState 全局每帧轮询:街机 / 画廊 / 记忆房间打开时也要喂手势数据,
	# 否则 cancel_just_pressed / confirm_just_pressed 会永远不更新。
	input_state.poll(delta)
	# 队友迁移:显示屏播放中冻结世界移动(Esc 退出由显示屏自己处理)。
	if archive_video_screen and archive_video_screen.is_playing():
		player.velocity = Vector3.ZERO
		return
	if arcade_active or board_active:
		return
	if destination_active or in_destination:
		if destination_active:
			_update_memory_tunnel(delta)
		else:
			_update_destination_room(delta)
		return
	camera_director.process_shake(delta)
	if opening.update(delta):
		return
	phase_time += delta
	# 移动方向已由 InputState 归一化：键鼠优先，视觉识别兜底。
	var direction: Vector2 = input_state.axis
	# 冲刺:SHIFT 或视觉模式持续握拳;爬行保持键盘 CTRL。
	var sprinting: bool = Input.is_key_pressed(KEY_SHIFT) or (input_state.is_vision_driven() and input_state.confirm_pressed)
	var crawling := Input.is_key_pressed(KEY_CTRL)
	var speed := direction.length()
	locomotion = "crawl" if crawling else ("run" if sprinting and speed > 0.05 else ("walk" if speed > 0.05 else "idle"))
	anim_time += delta * (10.0 if locomotion == "run" else (6.0 if locomotion == "walk" else 3.0))
	var horizontal_velocity := Vector2(player.velocity.x, player.velocity.z)
	var move_speed := 1.8 if crawling else (7.0 if sprinting else 4.0)
	horizontal_velocity = horizontal_velocity.move_toward(direction * move_speed, 18.0 * delta)
	player.velocity.x = horizontal_velocity.x
	player.velocity.z = horizontal_velocity.y
	if not player.is_on_floor():
		player.velocity.y -= 18.0 * delta
	else:
		# 捏手指(握拳)在靠近交互点时 = 点击交互,不再触发跳跃;
		# 只有周围没有任何可交互内容时,握拳才等于起跳。
		var near_interactable: bool = interaction_router != null and interaction_router.focus_id != ""
		if Input.is_action_just_pressed("jump") or (input_state.confirm_just_pressed and not near_interactable):
			player.velocity.y = 6.4
	player.move_and_slide()
	player.position.x = clamp(player.position.x, -5.0, 37.0)
	# 留出角色半径，保持在柜前通道及地面碰撞范围内。
	player.position.z = clampf(player.position.z, -1.9, 1.9)
	if (player.position.z <= -1.9 and player.velocity.z < 0.0) or (player.position.z >= 1.9 and player.velocity.z > 0.0):
		player.velocity.z = 0.0
	frog_visual.rotation.z = lerp(frog_visual.rotation.z, -direction.x * 0.08, delta * 8.0)
	# 角色会朝向实际行进方向，而不是永远面向镜头。
	if direction.length_squared() > 0.01:
		var target_yaw := atan2(direction.x, direction.y)
		frog_visual.rotation.y = lerp_angle(frog_visual.rotation.y, target_yaw, delta * 9.0)
	frog_visual.position.y = sin(Time.get_ticks_msec() * 0.012) * min(horizontal_velocity.length() / 4.0, 1.0) * 0.05
	apply_locomotion_pose()

	# 镜头交给 CameraDirector：滞后跟随 + 统一震屏叠加。
	camera_director.set_follow_bounds(0.0 if story_phase < 2 else 2.0, 31.5)
	camera_director.follow(delta, player.position)

func _on_npc_dialogue_started(_id: String) -> void:
	if archive_interaction:
		archive_interaction.set_active(false)

func _on_arcade_started(_id: String) -> void:
	arcade_active = true
	if archive_interaction:
		archive_interaction.set_active(false)
	if archive_npc:
		archive_npc.set_active(false)

func _on_arcade_closed(_id: String) -> void:
	arcade_active = false
	if archive_interaction:
		archive_interaction.set_active(true)
	if archive_npc:
		archive_npc.set_active(true)

func _on_memory_portal_entered(id: String) -> void:
	destination_id = id
	destination_active = true
	destination_elapsed = 0.0
	in_destination = false
	archive_root.visible = false
	if archive_interaction:
		archive_interaction.set_active(false)
	if archive_npc:
		archive_npc.set_active(false)
	if archive_entrance_npc:
		archive_entrance_npc.set_active(false)
	if archive_arcade:
		archive_arcade.set_active(false)
	if gallery_easel:
		gallery_easel.set_active(false)
	if display_board:
		display_board.set_active(false)
	if cinema_room:
		cinema_room.set_active(false)
	if text_archive_station:
		text_archive_station.set_active(false)
	var tunnel := get_node("TimeTunnel") as Node3D
	tunnel.visible = true
	player.position = Vector3(100, 2.1, 2)
	camera.position = Vector3(100, 3.0, 10.0)
	camera.look_at(Vector3(100, 3.0, -18.0))
	tunnel_overlay.visible = true
	tunnel_overlay.color = Color(0.08, 0.04, 0.15, 0.0)
	loading_bar.visible = false
	tunnel_overlay.get_node("LoadingLabel").text = "记忆通道：" + id
	tunnel_overlay.get_node("LoadingLabel").visible = true
	tunnel_overlay.get_node("LoadingLabel").modulate.a = 1.0

func _update_memory_tunnel(delta: float) -> void:
	if not destination_active:
		return
	destination_elapsed += delta
	var tunnel := get_node("TimeTunnel") as Node3D
	var p := clampf(destination_elapsed / 3.8, 0.0, 1.0)
	var steer := Vector2.ZERO
	if get_viewport():
		steer = (get_viewport().get_mouse_position() / get_viewport().get_visible_rect().size - Vector2(0.5, 0.5)) * 2.0
	player.position = Vector3(100.0 + steer.x * 1.8, 2.1 - steer.y * 1.1 + sin(destination_elapsed * 4.0) * 0.08, 2.0 - p * 38.0)
	camera.position = camera.position.lerp(Vector3(100.0 + steer.x * 0.8, 3.0 - steer.y * 0.4, 10.0 - p * 18.0), delta * 5.0)
	camera.look_at(Vector3(100.0 + steer.x * 0.5, 3.0, -18.0 - p * 20.0))
	tunnel_overlay.color.a = smoothstep(0.0, 0.25, p) * 0.32
	if p >= 1.0:
		destination_active = false
		in_destination = true
		tunnel.visible = false
		tunnel_overlay.visible = false
		tunnel_overlay.get_node("LoadingLabel").visible = false
		destination_root = preload("res://scripts/memory_destination.gd").new()
		destination_root.name = "MemoryDestination_" + destination_id
		destination_root.position = Vector3(200, 0, 0)
		add_child(destination_root)
		destination_root.setup(destination_id)
		player.position = destination_root.position + destination_root.spawn_position
		camera.position = player.position + Vector3(3.5, 3.0, 8.5)
		camera.look_at(player.position + Vector3(0, 1.0, -1.0))
		frog_visual.rotation = Vector3.ZERO

func _update_destination_room(delta: float) -> void:
	if destination_root == null:
		return
	destination_root.tick(delta)
	var direction: Vector2 = input_state.axis
	var move := Vector3(direction.x, 0, direction.y)
	player.velocity.x = move.x * 3.2
	player.velocity.z = move.z * 3.2
	player.velocity.y = 0.0
	player.move_and_slide()
	# 游乐园是开阔大世界，解除旧记忆房间的狭窄边界。
	player.position.x = clampf(player.position.x, 185.0, 215.0)
	player.position.z = clampf(player.position.z, -8.0, 8.0)
	var focus := player.global_position + Vector3(0, 1.0, 0)
	camera.global_position = camera.global_position.lerp(focus + Vector3(3.5, 3.0, 8.5), delta * 4.0)
	camera.look_at(focus + Vector3(0, 0, -1.0), Vector3.UP)
	var cue := get_node("Interface/StoryCue") as Label
	var local_pos := player.position - destination_root.position
	if local_pos.distance_to(destination_root.return_position) < 2.4:
		# 返回点是可交互目标:走共享提示条,与其他系统一样做焦点仲裁。
		if interaction_router:
			interaction_router.offer("destination", "返回档案长廊", 0.0, "E")
		cue.text = ""
		var gate: bool = interaction_router == null or interaction_router.can_interact("destination")
		if gate and (Input.is_action_just_pressed("interact") or input_state.confirm_just_pressed):
			_return_from_destination()
	else:
		cue.text = destination_root.get_prompt(local_pos) if destination_root.has_method("get_prompt") else destination_root.title + "  ·  探索记忆空间"
		if (Input.is_action_just_pressed("interact") or input_state.confirm_just_pressed) and destination_root.has_method("interact"):
			destination_root.interact(local_pos)

func _return_from_destination() -> void:
	if destination_root:
		destination_root.queue_free()
		destination_root = null
	in_destination = false
	destination_id = ""
	archive_root.visible = true
	archive_npc.set_active(true)
	if archive_entrance_npc:
		archive_entrance_npc.set_active(true)
	archive_interaction.set_active(true)
	if archive_arcade:
		archive_arcade.set_active(true)
	if gallery_easel:
		gallery_easel.set_active(true)
	if display_board:
		display_board.set_active(true)
	if cinema_room:
		cinema_room.set_active(true)
	if text_archive_station:
		text_archive_station.set_active(true)
	player.position = Vector3(23.8, 0.65, 0.0)
	camera.position = Vector3(26.5, 4.5, 12.5)
	camera.look_at(Vector3(26.5, 3, 0))
	get_node("Interface/StoryCue").text = ""

# 骨架定位：已知名字优先，找不到就递归兜底。
# 不同 glb 导出/导入方式给出的节点名不一致，硬编码单一名字极易静默失效。
func _find_skeleton(root_node: Node) -> Skeleton3D:
	for known in ["MilkFrog_Skeleton", "MilkFrog_Rig", "Armature", "Skeleton3D"]:
		var hit := root_node.find_child(known, true, false) as Skeleton3D
		if hit != null:
			return hit
	return _find_skeleton_recursive(root_node)

func _find_skeleton_recursive(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for c in node.get_children():
		var r := _find_skeleton_recursive(c)
		if r != null:
			return r
	return null

## 队友迁移：递归找 AnimationPlayer（动画版奶蛙模型自带）。
func _find_animation_player(root_node: Node) -> AnimationPlayer:
	if root_node is AnimationPlayer:
		return root_node as AnimationPlayer
	for child in root_node.get_children():
		var hit := _find_animation_player(child)
		if hit != null:
			return hit
	return null

func _collect_animated_parts(node: Node) -> void:
	# 某些 GLB 导入设置会把骨骼展开成普通 Node3D；兼容这类模型，
	# 通过节点名找到手臂/腿部并保留它们的原始旋转。
	for child in node.get_children():
		if child is Node3D:
			var key := String(child.name).to_lower()
			if (key.contains("arm") or key.contains("leg") or key.contains("thigh") or key.contains("foot")) and not (child is Skeleton3D):
				animated_parts.append(child as Node3D)
				animated_part_base[child] = (child as Node3D).rotation
			_collect_animated_parts(child)

func apply_locomotion_pose() -> void:
	var moving := locomotion != "idle"
	var phase := sin(anim_time)
	if locomotion == "crawl":
		frog_visual.rotation.x = lerp(frog_visual.rotation.x, -0.52, 0.16)
		frog_visual.scale = frog_visual.scale.lerp(Vector3(1.08, 0.62, 1.08), 0.16)
	else:
		frog_visual.rotation.x = lerp(frog_visual.rotation.x, 0.0, 0.16)
		frog_visual.scale = frog_visual.scale.lerp(Vector3.ONE, 0.16)
	# 队友迁移:动画版模型由 AnimationPlayer 接管动作(空中自动 jump/fall),
	# 不再程序化摆骨骼,避免动画轨道与 set_bone_pose_rotation 互相打架。
	if animation_player != null:
		var target := "idle"
		if not player.is_on_floor():
			target = "jump" if player.velocity.y > 0.0 else "fall"
		elif locomotion == "run":
			target = "run"
		elif locomotion == "walk" or locomotion == "crawl":
			target = "walk"
		if animation_player.current_animation != target:
			animation_player.play(target, 0.12)
		return
	var bob: float = abs(phase) * (0.045 if moving else 0.008)
	frog_visual.position.y = frog_visual_base_y + bob
	var stride := 0.0 if locomotion == "idle" else (0.28 if locomotion == "walk" else (0.55 if locomotion == "run" else 0.18))
	if skeleton != null:
		var spine_index := skeleton.find_bone("spine")
		if locomotion == "crawl":
			if spine_index >= 0: skeleton.set_bone_pose_rotation(spine_index, Quaternion(Vector3.RIGHT, -0.48))
		elif spine_index >= 0: skeleton.set_bone_pose_rotation(spine_index, Quaternion.IDENTITY)
		for pair in [["L_thigh", 1.0], ["R_thigh", -1.0], ["L_arm", -0.8], ["R_arm", 0.8]]:
			var index := skeleton.find_bone(pair[0])
			if index >= 0:
				var amount: float = float(pair[1]) * stride * phase
				skeleton.set_bone_pose_rotation(index, Quaternion(Vector3.RIGHT, amount))
	# 无 Skeleton3D 时，直接摆动展开后的肢体节点。
	if skeleton == null and not animated_parts.is_empty():
		for i in range(animated_parts.size()):
			var part := animated_parts[i]
			var base: Vector3 = animated_part_base.get(part, part.rotation)
			var sign := -1.0 if i % 2 == 0 else 1.0
			var amount := sign * stride * phase * (0.85 if String(part.name).to_lower().contains("arm") else 0.65)
			part.rotation = base + Vector3(amount, 0.0, 0.0)
