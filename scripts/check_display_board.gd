extends SceneTree
## 奶娃展板「幸福碎片」自检：装置几何 / 碎片配置 / ogv 资源 / 交互状态机。
## 跑法：godot --headless --script res://scripts/check_display_board.gd

var _pass := 0
var _fail := 0

func _check(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("PASS ", label)
	else:
		_fail += 1
		print("FAIL ", label)

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame

	var board = scene.display_board
	_check(board != null, "display_board 已挂载")
	if board == null:
		print("RESULT: FAIL 展板未挂载,终止")
		quit(1)
		return

	# ---- 1. 碎片配置 ----
	var clips: Array = board.CLIPS
	_check(clips.size() == 6, "6 块幸福碎片")
	var ids := {}
	var all_file := true
	for c in clips:
		ids[String(c.id)] = true
		if not FileAccess.file_exists(String(c.file)):
			all_file = false
			print("   缺失视频:", String(c.file))
	_check(ids.size() == 6, "碎片 id 唯一")
	_check(all_file, "全部 ogv 文件存在")
	var captions_ok := true
	for c in clips:
		if String(c.caption).is_empty() or String(c.title).is_empty():
			captions_ok = false
	_check(captions_ok, "每块碎片都有标题与文案")
	# ogv 资源可加载(Theora 走运行时 loader,无 .import)
	var streams_ok := true
	for c in clips:
		if load(String(c.file)) == null:
			streams_ok = false
			print("   无法加载:", String(c.file))
	_check(streams_ok, "ogv 资源全部可加载")

	# ---- 2. 3D 装置几何 ----
	var root_node: Node3D = scene.archive_root.get_node_or_null("DisplayBoard")
	_check(root_node != null, "展板装置挂进 archive_root")
	if root_node != null:
		_check(root_node.position.distance_to(board.BOARD_POS) < 0.01, "展板位置 = (%.1f, %.1f)" % [board.BOARD_POS.x, board.BOARD_POS.z])
		var cells: Node3D = root_node.get_node_or_null("Cells")
		_check(cells != null and cells.get_child_count() == 6, "六格待机小窗")
		_check(root_node.get_node_or_null("Base") != null, "底座存在")
		_check(root_node.get_node_or_null("Frame") != null, "板身存在")
		var sign_label := root_node.find_children("*", "Label3D", false, false)
		_check(sign_label.size() >= 2, "招牌与副标")

	# ---- 3. UI 结构 ----
	var layer: CanvasLayer = board.layer
	_check(layer != null and not layer.visible, "全屏层初始隐藏")
	board.set_active(true)
	board._open_board()
	await process_frame
	_check(board.board_open, "打开展板")
	_check(layer.visible, "打开后全屏层可见")
	_check(scene.board_active, "main.board_active 被置位(冻结角色)")
	_check(board.cells_ui.size() == 6, "六块选择格")
	_check(board.player.visible and board.playing_index == 0, "揭开即自动播放第 1 块")
	_check(not board.caption.text.is_empty(), "自动播放显示文案")

	# ---- 4. 播放状态机(无头不真播,验证资源与状态) ----
	board._play_clip(2)
	_check(board.playing_index == 2, "播放第 3 块碎片")
	_check(board.player.stream != null, "播放流已加载")
	_check(not board.caption.text.is_empty(), "文案已显示")
	board.cell_index = 0
	board._play_clip(0)
	_check(board.playing_index == 0, "切播另一块")
	# 播完自动连播下一块。
	board._on_clip_finished()
	_check(board.playing_index == 1, "播完自动连播下一块")
	# 暂停 / 继续。
	board._toggle_pause()
	_check(board.player.paused, "E 暂停")
	board._toggle_pause()
	_check(not board.player.paused, "再按 E 继续")
	board._stop_clip()
	_check(board.playing_index == -1 and not board.player.visible, "停止后回到待机")
	board._play_clip(99)
	_check(board.playing_index == -1, "越界索引安全忽略")

	# ---- 5. 关闭与互斥 ----
	board._close_board()
	await process_frame
	_check(not board.board_open and not layer.visible, "合上展板")
	_check(not scene.board_active, "main.board_active 复位")
	board._close_board()
	_check(not board.board_open, "重复关闭幂等")
	# 与画廊画架互斥:通道被占时展板拒开。
	scene.board_active = true
	board._open_board()
	_check(not board.board_open, "board_active 被占时拒绝打开")
	scene.board_active = false

	# ---- 6. 激活链 ----
	board.set_active(false)
	_check(not board.active, "set_active(false) 生效")

	print("RESULT: %s 展板检查 %d 项通过, %d 项失败" % ["PASS" if _fail == 0 else "FAIL", _pass, _fail])
	quit(1 if _fail > 0 else 0)
