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


func setup(layer: CanvasLayer) -> void:
	var ui := UIKit.make_prompt_bar(layer)
	prompt_panel = ui.panel
	prompt_key_holder = ui.key
	prompt_key_label = ui.key_label
	prompt_body = ui.body
	prompt_dot = ui.dot
	prompt_panel.visible = false
	set_process(true)


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
		return
	_apply(offers[focus_id])
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
