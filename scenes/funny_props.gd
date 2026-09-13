extends Node3D
# 搞笑道具场景 - 篮球、会动的鸡、西瓜、持刀人
# 篮球 / 鸡可交互:靠近按 E,播放「只因」音效并触发弹跳动画。
# 持刀人可交互:华强买瓜四段式,按剧情顺序推进:
#   问瓜「这瓜保熟吗」→ 背景音乐(77.25s 拔刀重音,西瓜被劈倒)→「你劈我瓜是吧」→「杀人啦」→ 循环。

const ZHIYIN_SFX := preload("res://assets/audio/zhiyin.wav")
const HQ_ASK := preload("res://assets/audio/huaqiang_bao_shu.wav")
const HQ_BGM := preload("res://assets/audio/huaqiang_bgm.wav")
const HQ_PI := preload("res://assets/audio/huaqiang_pi_gua.wav")
const HQ_SHA := preload("res://assets/audio/huaqiang_sha_ren.wav")
const HQ_STREAMS := [HQ_ASK, HQ_BGM, HQ_PI, HQ_SHA]
const HQ_LABELS := ["问一句:这瓜保熟吗", "坐看好戏", "听他嚷嚷", "快跑!"]
const HQ_ACCENT_TIME := 77.25  # BGM 里拔刀重击的时刻
const MELON_TIME := 1.0

const INTERACT_RANGE := 2.6
const KICK_TIME := 0.55

@onready var basketball: Node3D = $Basketball
@onready var chicken: Node3D = $Chicken
@onready var knife_man: Node3D = $KnifeMan
@onready var watermelon: Node3D = $Watermelon

var time_passed = 0.0
var player: Node3D
var router: Node
var interactables := {}
var hq_stage := 0
var hq_kick := 0.0
var hq_accent_watch := false
var melon_topple := 0.0
var melon_base_pos: Vector3
var melon_base_rot: Vector3

func _ready():
	print("=== 搞笑道具已加载 ===")
	print("  篮球 - 橙色球体(靠近按 E 拍一下)")
	print("  鸡 - 会上下摇头(靠近按 E 逗一下)")
	print("  西瓜 - 绿色条纹球体(持刀人剧情里会被劈)")
	print("  持刀人 - 实体小人(蓝衣、怒目)+ 手里一把菜刀")
	print("         华强买瓜四段式:问瓜 → 背景音乐+劈瓜重音 → 你劈我瓜是吧 → 杀人啦")
	# 子场景的 _ready 早于 main.gd 创建 InteractionRouter,延后一帧接线
	call_deferred("_setup_interaction")

func _setup_interaction() -> void:
	var world := _find_world()
	if world:
		player = world.get("player") as Node3D
		router = world.get_node_or_null("InteractionRouter")
	if player == null:
		print("  (未找到玩家,道具交互已禁用)")
		return
	melon_base_pos = watermelon.position
	melon_base_rot = watermelon.rotation
	for spec in [["funny_basketball", basketball, "拍一下篮球"], ["funny_chicken", chicken, "逗一下鸡"], ["funny_knife", knife_man, HQ_LABELS[0]]]:
		var sfx := AudioStreamPlayer3D.new()
		sfx.stream = ZHIYIN_SFX if spec[0] != "funny_knife" else HQ_ASK
		sfx.volume_db = 2.0
		sfx.unit_size = 16.0  # 减小距离衰减,近处听得清
		spec[1].add_child(sfx)
		interactables[spec[0]] = {"node": spec[1], "label": spec[2], "sfx": sfx, "kick": 0.0, "base_y": spec[1].position.y}

func _find_world() -> Node:
	var n: Node = self
	while n != null:
		if "player" in n and n.get("player") != null:
			return n
		n = n.get_parent()
	return null

func _unhandled_input(event: InputEvent) -> void:
	if player == null or not event.is_action_pressed("interact"):
		return
	# 与仲裁器一致:只在最近的道具上响应,且必须拿到交互焦点
	var best_id := ""
	var best_dist := INTERACT_RANGE
	for id in interactables:
		var node: Node3D = interactables[id].node
		var dist: float = player.global_position.distance_to(node.global_position)
		if dist < best_dist:
			best_dist = dist
			best_id = id
	if best_id != "" and (router == null or router.can_interact(best_id)):
		_play(best_id)

func _play(id: String) -> void:
	var item: Dictionary = interactables[id]
	if id == "funny_knife":
		_advance_huaqiang(item)
		return
	(item.sfx as AudioStreamPlayer3D).play()
	item.kick = KICK_TIME

## 持刀人四段式剧情,顺序与原片同向,播完一轮后循环。
func _advance_huaqiang(item: Dictionary) -> void:
	var sfx: AudioStreamPlayer3D = item.sfx
	sfx.stream = HQ_STREAMS[hq_stage]
	sfx.play()
	hq_kick = 1.0
	if hq_stage == 1:
		# 重新开演:扶正西瓜,盯住拔刀重音时刻
		watermelon.position = melon_base_pos
		watermelon.rotation = melon_base_rot
		melon_topple = 0.0
		hq_accent_watch = true
	hq_stage = (hq_stage + 1) % HQ_STREAMS.size()
	item.label = HQ_LABELS[hq_stage]

## 拔刀重音是否已到(播放位置达到 77.25s);独立成纯函数便于无头测试
func _hq_accent_reached(playback_pos: float) -> bool:
	return playback_pos >= HQ_ACCENT_TIME

func _trigger_accent() -> void:
	hq_accent_watch = false
	melon_topple = MELON_TIME

func _process(delta):
	time_passed += delta

	# 鸡的动画 - 上下摇头 / 左右摇晃 / 上下跳动;被逗时惊跳 + 打转
	var chicken_kick: float = interactables["funny_chicken"].kick if interactables.has("funny_chicken") else 0.0
	if chicken:
		chicken.rotation.x = sin(time_passed * 3.0) * 0.3
		chicken.rotation.z = cos(time_passed * 2.5) * 0.2
		chicken.position.y = 0.3 + abs(sin(time_passed * 4.0)) * 0.15
		if chicken_kick > 0.0:
			var p: float = 1.0 - chicken_kick / KICK_TIME
			chicken.position.y += sin(PI * p) * 0.5
			chicken.rotation.y += delta * TAU * 2.0

	# 篮球的拍跳动画
	if interactables.has("funny_basketball"):
		var item: Dictionary = interactables["funny_basketball"]
		var node: Node3D = item.node
		if item.kick > 0.0:
			var p: float = 1.0 - item.kick / KICK_TIME
			node.position.y = item.base_y + sin(PI * p) * 0.55
			node.scale = Vector3.ONE * (1.0 + 0.12 * sin(PI * p))
		else:
			node.position.y = item.base_y
			node.scale = Vector3.ONE

	# 持刀人 - 挥刀动作;交互时刀身震颤
	if knife_man:
		var knife = knife_man.get_node_or_null("Knife")
		if knife:
			# 刀上下挥动
			knife.rotation.z = sin(time_passed * 2.0) * 0.8 - 0.5 + sin(time_passed * 13.0) * 0.35 * hq_kick
	if hq_kick > 0.0:
		hq_kick = maxf(0.0, hq_kick - delta * 1.4)

	# 拔刀重音监视:到点让西瓜被"劈"倒
	if hq_accent_watch and interactables.has("funny_knife"):
		var sfx: AudioStreamPlayer3D = interactables["funny_knife"].sfx
		if sfx.playing and sfx.stream == HQ_BGM and _hq_accent_reached(sfx.get_playback_position()):
			_trigger_accent()
		elif not sfx.playing or sfx.stream != HQ_BGM:
			hq_accent_watch = false

	# 西瓜被劈:跳起、翻滚、停在一边
	if melon_topple > 0.0:
		melon_topple = maxf(0.0, melon_topple - delta)
		var p: float = 1.0 - melon_topple / MELON_TIME
		watermelon.position.y = lerpf(melon_base_pos.y, 0.5, p) + sin(PI * p) * 0.4
		watermelon.position.x = melon_base_pos.x - 0.45 * p
		watermelon.rotation.z = -PI / 2 * minf(1.0, p * 1.5)

	# 交互提示申请:与其他系统共用 InteractionRouter 的焦点仲裁
	if router and player:
		for id in interactables:
			var item: Dictionary = interactables[id]
			var dist: float = player.global_position.distance_to(item.node.global_position)
			if dist <= INTERACT_RANGE:
				router.offer(id, item.label, dist, "E")
		for id in interactables:
			var item: Dictionary = interactables[id]
			if item.kick > 0.0:
				item.kick = maxf(0.0, item.kick - delta)
