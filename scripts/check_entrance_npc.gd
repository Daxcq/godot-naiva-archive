extends SceneTree
## 入口牛 NPC 回归自检。
##
## 覆盖三件事：
##   1. 节点/模型确实建出来了，且位置在传送门落点附近（不是掉到地图外）
##   2. 对话状态机能完整走完 LINES 条台词，结束后 UI 正确清空
##   3. 距离门控有效：站在出生点能触发，跑到走廊深处不能触发
##
## 注意：--script（SceneTree）模式下节点的 _process 不会自动跑，
## 所以这里全部用手动驱动。真实运行时的行为由主循环负责。

var world: Node3D
var npc: Node
var failures: Array[String] = []

func _init() -> void:
	var packed := load("res://main.tscn") as PackedScene
	if packed == null:
		print("FAIL 无法加载 main.tscn")
		quit(1)
		return
	world = packed.instantiate() as Node3D
	root.add_child(world)
	world._ready()

	npc = world.get_node_or_null("ArchiveEntranceNPC")
	if npc == null:
		print("FAIL ArchiveEntranceNPC 未挂载到 main.gd")
		quit(1)
		return

	_test_nodes()
	_test_distance_gate()
	_test_dialogue_flow()

	print("")
	if failures.is_empty():
		print("RESULT: PASS 入口牛 NPC 全部检查通过")
		quit(0)
	else:
		for f in failures:
			print("FAIL " + f)
		print("RESULT: FAIL %d 项未通过" % failures.size())
		quit(1)

func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS " + label)
	else:
		failures.append(label)

func _test_nodes() -> void:
	# npc_root 挂在 world.archive_root 下（跟着档案馆整体显隐），
	# 所以直接从脚本变量拿，不要按脚本节点做相对路径查找。
	var root_node := npc.npc_root as Node3D
	_check(root_node != null, "牛 NPC 根节点存在")
	if root_node == null:
		return
	_check(root_node.visible == false, "未激活时默认不可见")

	var model := root_node.get_node_or_null("Model") as Node3D
	_check(model != null, "Model 容器存在")
	if model != null:
		_check(model.get_child_count() > 0, "模型实例已载入（非空）")

	var tag := root_node.get_node_or_null("NameTag") as Label3D
	_check(tag != null and tag.text == "牛来", "名牌文本 = 牛来")

	# 位置必须在走廊入口（传送门落点 ARCHIVE_SPAWN.x = -4.5 附近）。
	# 放宽到 ±4，只要还在入口段就算对。
	var p := root_node.position
	var near_spawn := absf(p.x - (-4.5)) < 4.0 and absf(p.z) < 2.2
	_check(near_spawn, "站位在走廊入口段 (实际 %s)" % [p])
	print("    位置 = %s  朝向 yaw = %.2f" % [p, root_node.rotation.y])

	var area := root_node.get_node_or_null("TalkArea") as Area3D
	_check(area != null, "交互触发区存在")

func _test_distance_gate() -> void:
	npc.set_active(true)
	var root_node := npc.npc_root as Node3D

	# 用局部 position：无头模式下世界当帧还没进树，global_position 不可信。
	# 站位与玩家同在 ArchiveArchitecture 下，局部坐标比较等价。
	# 走到出生点旁边：应触发
	world.player.position = root_node.position + Vector3(-1.6, 0, 0)
	npc._process(0.016)
	_check(npc.near == true, "站在出生点旁 → 可交互 (near=true)")
	_check(npc.prompt.text != "", "靠近后提示文字非空 (\"%s\")" % npc.prompt.text)

	# 跑到走廊深处：不应触发
	world.player.position = Vector3(10.0, 0.65, 0.0)
	npc._process(0.016)
	_check(npc.near == false, "走到走廊中段 → 不可交互 (near=false)")
	_check(npc.prompt.text == "", "远离后提示清空")

func _test_dialogue_flow() -> void:
	var root_node := npc.npc_root as Node3D
	world.player.position = root_node.position + Vector3(-1.6, 0, 0)
	npc._process(0.016)

	var total: int = npc.LINES.size()
	_check(total >= 4, "台词不少于 4 句 (实际 %d)" % total)

	# 起手：按 E 开始
	npc.line_delay = 0.0
	npc._interact()
	_check(npc.talking == true, "按 E 进入对话")
	_check(npc.line_index == 0, "从第 1 句开始")
	_check(npc.card.visible == true, "对话卡片显示")
	var first_text: String = npc.card.text
	_check(first_text.contains(String(npc.LINES[0])), "卡片内容 = 第 1 句台词")

	# 逐句推进
	var guard := 0
	while npc.talking and guard < 64:
		guard += 1
		npc.line_delay = 0.0
		npc._interact()
	_check(npc.talking == false, "台词读完后自动结束（未卡死）")
	_check(guard <= total + 1, "推进次数合理 (%d 次推完 %d 句)" % [guard, total])
	_check(npc.card.visible == false, "结束后卡片隐藏")
	_check(npc.card.text == "", "结束后卡片清空")
	_check(npc.finished_once == true, "记录了已完成标记")

	# 最后一句应是「牛来」——留白用的
	_check(String(npc.LINES[total - 1]) == "……牛来。", "末句为留白台词")

	# 重复触发不应崩（再按 E 应能重新开始）
	npc._process(0.016)
	npc.line_delay = 0.0
	npc._interact()
	_check(npc.talking == true, "可重复对话（再次按 E 重新开始）")

	# 关闭系统后必须完全静默
	npc.set_active(false)
	_check(npc.talking == false, "set_active(false) 关闭对话")
	_check(npc.prompt.visible == false, "set_active(false) 隐藏提示")
	_check((npc.npc_root as Node3D).visible == false, "set_active(false) 隐藏 NPC")
