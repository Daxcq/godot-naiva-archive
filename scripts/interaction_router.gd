extends Node
## ============================================================
##  交互焦点仲裁器(InteractionRouter)
## ------------------------------------------------------------
##  解决的问题:走廊里多个交互系统(入口牛 / 柜前档案员 / 记忆柜 /
##  街机 / 记忆目的地返回点)的触发圈会交叠——过去它们的提示文字
##  叠在一起,按一次 E 甚至会同时触发两套对话。
##
##  规则:每帧收集各系统的 offer,只选出一个「焦点」:
##    1. 正在进行中的交互(holding)独占焦点,不被抢占;
##    2. 否则 priority 高者胜,再比距离(近者胜);
##    3. 只有焦点系统允许显示提示、显示按钮、响应交互键
##       (各系统按键前查 can_interact(id))。
##
##  交互提示条是全游戏唯一一条,固定在底部中央 —— UI 永不重叠。
## ============================================================

const UIKit := preload("res://scripts/ui_kit.gd")

var prompt_panel: PanelContainer
var prompt_key_holder: Control
var prompt_key_label: Label
var prompt_body: Label
var prompt_dot: Panel

## id -> {key, body, distance, priority, holding}
var offers := {}
var focus_id := ""
var _fade := 0.0
var highlight_root: Node3D
var highlight_mesh: MeshInstance3D
var highlight_mat: StandardMaterial3D
var targets := {}


func setup(layer: CanvasLayer) -> void:
	var ui := UIKit.make_prompt_bar(layer)
	prompt_panel = ui.panel
	prompt_key_holder = ui.key
	prompt_key_label = ui.key_label
	prompt_body = ui.body
	prompt_dot = ui.dot
	prompt_panel.visible = false
	_build_highlight()
	set_process(true)

func _build_highlight() -> void:
	highlight_root = Node3D.new()
	highlight_root.name = "InteractionHighlight"
	# current_scene 在测试框架(SceneTree 脚本)下为 null,兜底挂到 root;
	# 若连 get_tree() 都还没有(未进树),跳过挂载,不影响其余逻辑。
	var tree := get_tree()
	if tree != null:
		var parent := tree.current_scene
		if parent == null:
			parent = tree.root
		parent.add_child.call_deferred(highlight_root)
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new(); mesh.inner_radius = 0.28; mesh.outer_radius = 0.38; mesh.rings = 32; mesh.ring_segments = 8
	ring.mesh = mesh
	highlight_mat = StandardMaterial3D.new(); highlight_mat.albedo_color = Color("7ff6e7"); highlight_mat.emission_enabled = true; highlight_mat.emission = Color("42d9d0"); highlight_mat.emission_energy_multiplier = 1.8
	ring.material_override = highlight_mat; highlight_root.add_child(ring); highlight_mesh = ring; highlight_root.visible = false

func register_target(id: String, position: Vector3) -> void:
	targets[id] = position


## 各系统每帧调用,申请一次交互提示。
## holding=true 表示交互正在进行中(对话/解谜),独占焦点。
func offer(id: String, body: String, distance: float, key := "E", priority := 0, holding := false) -> void:
	offers[id] = {
		"key": key,
		"body": body,
		"distance": distance,
		"priority": priority,
		"holding": holding,
	}


## 只有焦点系统(或未接 Router 的兜底场景)可以响应交互键 / 显示按钮。
func can_interact(id: String) -> bool:
	return focus_id == id


func _process(delta: float) -> void:
	var best_id := ""
	var best_score := INF
	for id in offers:
		var o: Dictionary = offers[id]
		# holding 独占 → priority → 距离。
		var score: float = float(o.distance) - float(o.priority) * 100.0
		if o.holding:
			score -= 10000.0
		if score < best_score:
			best_score = score
			best_id = id
	if best_id != focus_id:
		focus_id = best_id
	if focus_id == "" or not offers.has(focus_id):
		focus_id = ""
		prompt_panel.visible = false
		_fade = 0.0
		offers.clear()
		if highlight_root: highlight_root.visible = false
		return
	_apply(offers[focus_id])
	if highlight_root and targets.has(focus_id):
		highlight_root.position = Vector3(targets[focus_id]) + Vector3(0, 0.035, 0)
		highlight_root.visible = true
		highlight_root.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.08)
	else:
		if highlight_root: highlight_root.visible = false
	offers.clear()
	# 出现/切换时的淡入,避免提示条生硬闪烁。
	_fade = minf(_fade + delta * 7.0, 1.0)
	prompt_panel.modulate.a = _fade


func _apply(o: Dictionary) -> void:
	prompt_panel.visible = true
	var k := String(o.key)
	prompt_key_holder.visible = k != ""
	prompt_dot.visible = k == ""
	prompt_key_label.text = k
	prompt_body.text = String(o.body)
