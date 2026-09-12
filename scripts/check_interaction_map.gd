extends SceneTree
## 交互圈两两不重叠普查(断言式自检)。
## 规则:XZ 平面上任意两个交互源的圆心距 >= r1 + r2 才算不重叠;
##       出口结算触发线(x>=35.6)上离各圈最近的点必须在圈外。
## 例外:入口簇(牛来/袋鼠/档案员/记忆点1)是有意设计的交叠——四圈同挤入口区,
##       靠 InteractionRouter「最近者胜出」仲裁,白名单豁免但打印出来。
## 数据全部取自真实来源(脚本常量表 + 场景实例),改了脚本或场景后此表自动跟随:
##   记忆点  archive_interaction.gd   var nodes           r=3.2(脚本内两处硬编码)
##   街机    archive_arcade.gd        const MACHINES      z=-2.05, r=NEAR_DISTANCE
##   入口NPC archive_entrance_npc.gd  const NPCS          r=TALK_RANGE
##   档案员  archive_npc_dialogue.gd  var groups          z 强制 -0.65, r=2.5(硬编码)
##   展板    archive_display_board.gd const BOARD_POS     r=NEAR_DISTANCE
##   画架    scenes/archive_space.tscn GalleryEasel 实例  r=脚本 NEAR_DISTANCE
##   出口    archive_interaction.gd   x>=35.6 结算态触发线
## 用法: Godot --headless --path . --script res://scripts/check_interaction_map.gd

## 入口簇豁免名单(两两同时属于此簇才豁免;单独一边不算)。
const ENTRANCE_IDS := ["keeper_seen_2016", "niu_lai", "meituan_kangaroo", "memory_seen_2016"]

func _init() -> void:
	var circles: Array = []
	# 1) 记忆点 x3。
	var interaction: Node = load("res://scripts/archive_interaction.gd").new()
	for item in interaction.nodes:
		circles.append({
			"id": "memory_%s" % String(item.id),
			"pos": Vector2(item.pos.x, item.pos.z),
			"r": 3.2,
		})
	interaction.free()
	# 2) 街机 x3(机身统一 z=-2.05)。
	var arcade_map: Dictionary = load("res://scripts/archive_arcade.gd").get_script_constant_map()
	var arcade_r: float = arcade_map["NEAR_DISTANCE"]
	for spec in arcade_map["MACHINES"]:
		circles.append({
			"id": "arcade_%s" % String(spec.id),
			"pos": Vector2(float(spec.x), -2.05),
			"r": arcade_r,
		})
	# 3) 入口 NPC x2。
	var npc_map: Dictionary = load("res://scripts/archive_entrance_npc.gd").get_script_constant_map()
	for spec in npc_map["NPCS"]:
		circles.append({
			"id": String(spec.id),
			"pos": Vector2(spec.pos.x, spec.pos.z),
			"r": npc_map["TALK_RANGE"],
		})
	# 4) 档案员(_build_groups 会把 z 强制改成 -0.65)。
	var keeper: Node = load("res://scripts/archive_npc_dialogue.gd").new()
	for group in keeper.groups:
		circles.append({
			"id": "keeper_%s" % String(group.id),
			"pos": Vector2(group.pos.x, -0.65),
			"r": 2.5,
		})
	keeper.free()
	# 5) 展板。
	var board_map: Dictionary = load("res://scripts/archive_display_board.gd").get_script_constant_map()
	var board_pos: Vector3 = board_map["BOARD_POS"]
	circles.append({
		"id": "display_board",
		"pos": Vector2(board_pos.x, board_pos.z),
		"r": board_map["NEAR_DISTANCE"],
	})
	# 6) 画廊画架:从场景实例取真实摆放(位置 + 朝向),半径取脚本常量。
	var space: Node3D = (load("res://scenes/archive_space.tscn") as PackedScene).instantiate()
	var easel: Node3D = space.get_node_or_null("GalleryEasel")
	if easel == null:
		print("[FAIL] archive_space.tscn 里没有 GalleryEasel 节点")
		quit(1)
		return
	var easel_r: float = easel.get_script().get_script_constant_map()["NEAR_DISTANCE"]
	var easel_pos := Vector2(easel.position.x, easel.position.z)
	circles.append({
		"id": "gallery_easel",
		"pos": easel_pos,
		"r": easel_r,
	})
	var fails := 0
	# 画架必须面朝走廊(北):yaw≈PI。朝南 = 画面对着墙,玩家看不见。
	var yaw_err: float = absf(wrapf(easel.rotation.y - PI, -PI, PI))
	if yaw_err > 0.05:
		print("[FAIL] 画架 yaw=%.2f,应≈PI(南墙面北)。" % easel.rotation.y)
		fails += 1
	print("=== 交互圈普查(%d 个源,画架 yaw 误差 %.3f) ===" % [circles.size(), yaw_err])
	for c in circles:
		print("  %-26s pos=(%6.2f, %6.2f)  r=%.1f" % [c.id, c.pos.x, c.pos.y, c.r])
	# 7) 两两断言。
	for i in range(circles.size()):
		for j in range(i + 1, circles.size()):
			var a: Dictionary = circles[i]
			var b: Dictionary = circles[j]
			var dist: float = a.pos.distance_to(b.pos)
			var need: float = a.r + b.r
			var pair := "%s <-> %s" % [a.id, b.id]
			if dist + 0.001 >= need:
				continue
			if ENTRANCE_IDS.has(a.id) and ENTRANCE_IDS.has(b.id):
				print("  [豁免] %s 距离 %.2f < %.2f(入口簇,最近者仲裁)" % [pair, dist, need])
			else:
				print("[FAIL] %s 距离 %.2f < 需求 %.2f(重叠 %.2f)" % [pair, dist, need, need - dist])
				fails += 1
	# 8) 出口结算线:x>=35.6 时才有「保存记忆」offer;结算态玩家站在触发线上,
	#    若线落在别的交互圈内,结算提示会被最近者抢走。线上最近点必须在所有圈外。
	for c in circles:
		var nearest_z: float = clampf(c.pos.y, -1.9, 1.9)
		var d: float = Vector2(35.6, nearest_z).distance_to(c.pos)
		if d < c.r - 0.001:
			print("[FAIL] 出口触发线穿入 %s 的圈(最近距 %.2f < r %.2f),结算 offer 会被抢。" % [c.id, d, c.r])
			fails += 1
	if fails == 0:
		print("=== 交互圈普查:全部通过,无意外重叠 ===")
	else:
		print("=== 交互圈普查:%d 处重叠,见上方 [FAIL] ===" % fails)
	quit(1 if fails > 0 else 0)
