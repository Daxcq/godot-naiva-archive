extends SceneTree
## 入口 NPC(牛来 + 美团袋鼠)回归自检。
##
## 覆盖四件事：
##   1. 双 NPC 节点/模型确实建出来了，且都在走廊入口段
##   2. 对话状态机能完整走完台词，结束后 UI 正确清空
##   3. 距离门控有效：站在谁旁边只能触发谁，走廊深处谁都触发不了
##   4. 交互提示走 InteractionRouter 焦点仲裁(触发互斥)
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
	# 等一帧让 AudioStreamPlayer 完成 playback 注册，
	# 否则 headless 下 voice_player.playing 恒为 false（播放断言假失败）。
	await process_frame

	npc = world.get_node_or_null("ArchiveEntranceNPC")
	if npc == null:
		print("FAIL ArchiveEntranceNPC 未挂载到 main.gd")
		quit(1)
		return

	_test_nodes()
	_test_distance_gate()
	_test_dialogue_flow(0)
	_test_dialogue_flow(1)
	_test_router_focus()

	print("")
	if failures.is_empty():
		print("RESULT: PASS 入口 NPC 全部检查通过")
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

func _entry(i: int) -> Dictionary:
	return npc.entries[i]

func _test_nodes() -> void:
	var count: int = (npc.NPCS as Array).size()
	_check(count == 2, "配置了两个入口 NPC (实际 %d)" % count)
	_check(npc.entries.size() == count, "运行时状态与配置一一对应")
	if npc.entries.size() < 1:
		return

	for i in range(npc.entries.size()):
		var spec: Dictionary = npc.NPCS[i]
		var root_node := _entry(i).root as Node3D
		_check(root_node != null, "%s 根节点存在" % String(spec.label))
		if root_node == null:
			continue
		_check(root_node.visible == false, "%s 未激活时默认不可见" % String(spec.label))

		# 模型引用以 entries[i].model 为准（与 _process 呼吸动画同一来源）：
		# 主场景实例化模式下是包装场景首个子节点（NiuLaiModel/MeituanKangarooModel），
		# 只有运行时兜底生成才有名为 "Model" 的容器，按名字找会误报。
		var model := _entry(i).model as Node3D
		_check(model != null, "%s Model 容器存在" % String(spec.label))
		if model != null:
			_check(model.get_child_count() > 0, "%s 模型实例已载入（非空）" % String(spec.label))

		var tag := root_node.get_node_or_null("NameTag") as Label3D
		_check(tag != null and tag.text == String(spec.label), "%s 名牌文本正确" % String(spec.label))

		# 位置必须在走廊入口段（传送门落点 ARCHIVE_SPAWN.x = -4.5 附近）。
		var p := root_node.position
		var near_spawn := absf(p.x - (-2.0)) < 6.0 and absf(p.z) < 2.2
		_check(near_spawn, "%s 站位在走廊入口段 (实际 %s)" % [String(spec.label), p])

		var area := root_node.get_node_or_null("TalkArea") as Area3D
		_check(area != null, "%s 交互触发区存在" % String(spec.label))

	# 两人必须隔得比交互半径远，站在 A 正旁时 B 不构成竞争。
	var gap: float = (npc.NPCS[0].pos as Vector3).distance_to(npc.NPCS[1].pos)
	_check(gap > float(npc.TALK_RANGE),
			"两 NPC 间隔 %.2f > TALK_RANGE %.2f" % [gap, npc.TALK_RANGE])

func _test_distance_gate() -> void:
	npc.set_active(true)
	if npc.entries.size() < 2:
		return

	# 用局部 position：无头模式下世界当帧还没进树，global_position 不可信。
	# 站位与玩家同在 ArchiveArchitecture 下，局部坐标比较等价。
	var niu_root := _entry(0).root as Node3D
	var roo_root := _entry(1).root as Node3D

	# 站到牛来旁边：只有牛来可交互
	world.player.position = niu_root.position + Vector3(-1.6, 0, 0)
	npc._process(0.016)
	_check(npc._nearest_entry() == 0, "站在牛来旁 → 命中牛来")

	# 站到袋鼠旁边：只有袋鼠可交互
	world.player.position = roo_root.position + Vector3(1.4, 0, 0)
	npc._process(0.016)
	_check(npc._nearest_entry() == 1, "站在袋鼠旁 → 命中袋鼠")

	# 跑到走廊深处：谁都触发不了
	world.player.position = Vector3(10.0, 0.65, 0.0)
	npc._process(0.016)
	_check(npc._nearest_entry() == -1, "走到走廊中段 → 无人可交互")

func _test_dialogue_flow(index: int) -> void:
	if npc.entries.size() < 2:
		return
	var spec: Dictionary = npc.NPCS[index]
	var label := String(spec.label)
	# 测试站位偏移：离自己 < TALK_RANGE，离另一个 > TALK_RANGE。
	var offset := Vector3(-1.6, 0, 0) if index == 0 else Vector3(1.4, 0, 0)
	var root_node := _entry(index).root as Node3D
	world.player.position = root_node.position + offset
	npc.set_active(true)
	npc._process(0.016)

	var lines: Array = spec.lines
	var total: int = lines.size()
	_check(total >= 4, "%s台词不少于 4 句 (实际 %d)" % [label, total])

	# 起手：按 E 开始
	npc.line_delay = 0.0
	npc._interact()
	_check(npc.active_index == index, "按 E 进入%s对话" % label)
	_check(int(_entry(index).line_index) == 0, "%s 从第 1 句开始" % label)
	_check(npc.card_panel.visible == true, "%s 对话卡片显示" % label)
	_check(npc.card_title.text == label, "%s 卡片标题正确" % label)
	# 对话实录语音：开聊即播（牛来 8s 名场面循环 / 袋鼠"肥嘟嘟"全量）。
	_check(npc.voice_player != null and npc.voice_player.stream != null, "%s 对话语音已装载" % label)
	_check(npc.voice_player.playing, "%s 对话语音播放中" % label)
	var want_loop := bool(spec.get("voice_loop", false))
	_check((npc.voice_player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD) == want_loop,
			"%s 语音循环设置正确" % label)
	var first_text: String = npc.card.text
	_check(first_text.contains(String(lines[0])), "%s 卡片内容 = 第 1 句台词" % label)
	_check(String(npc.button.text).contains("下一句"),
			"%s 按钮提示推进 (\"%s\")" % [label, npc.button.text])

	# 逐句推进
	var guard := 0
	while npc.active_index >= 0 and guard < 64:
		guard += 1
		npc.line_delay = 0.0
		npc._interact()
	_check(npc.active_index == -1, "%s 台词读完后自动结束（未卡死）" % label)
	_check(guard <= total + 1, "%s 推进次数合理 (%d 次推完 %d 句)" % [label, guard, total])
	_check(npc.card_panel.visible == false, "%s 结束后卡片隐藏" % label)
	_check(npc.card.text == "", "%s 结束后卡片清空" % label)
	_check(bool(_entry(index).finished_once) == true, "%s 记录了已完成标记" % label)

	# 末句点题：牛来留白、袋鼠甩梗
	var last_line := String(lines[total - 1])
	if index == 0:
		_check(last_line == "……牛来。", "牛来末句为留白台词")
	else:
		_check(last_line.contains("肥嘟嘟"), "%s 末句甩出梗台词" % label)

	# 重复触发不应崩（再按 E 应能重新开始）
	npc._process(0.016)
	npc.line_delay = 0.0
	npc._interact()
	_check(npc.active_index == index, "%s 可重复对话（再次按 E 重新开始）" % label)

	# 走开即散：对话和语音一起停。
	world.player.position = Vector3(10.0, 0.65, 0.0)
	npc._process(0.016)
	_check(npc.active_index == -1, "%s 走开后对话自动结束" % label)
	_check(not npc.voice_player.playing, "走开后对话语音停止")

	# 关闭系统后必须完全静默（set_active 同时重置对话状态，不泄漏给下一段测试）
	npc.set_active(false)
	_check(npc.active_index == -1, "set_active(false) 关闭%s对话" % label)
	_check(npc.card_panel.visible == false, "set_active(false) 隐藏卡片")
	_check((_entry(index).root as Node3D).visible == false, "set_active(false) 隐藏%s" % label)

func _test_router_focus() -> void:
	# 交互提示必须走 InteractionRouter:靠近时 offer,且拿到焦点;
	# 离开后焦点释放。
	var router := world.get_node_or_null("InteractionRouter")
	if router == null:
		_check(false, "InteractionRouter 未创建")
		return
	npc.set_active(true)
	var niu_root := _entry(0).root as Node3D
	world.player.position = niu_root.position + Vector3(-1.6, 0, 0)
	npc._process(0.016)
	# 无头模式 _process 不自动跑,仲裁器要手动驱动一帧来结算焦点。
	router._process(0.016)
	_check(router.focus_id == "entrance", "靠近牛来 → 入口 NPC 拿到交互焦点")
	world.player.position = Vector3(10.0, 0.65, 0.0)
	npc._process(0.016)
	router._process(0.016)
	_check(router.focus_id != "entrance", "离开后焦点释放")
	npc.set_active(false)
