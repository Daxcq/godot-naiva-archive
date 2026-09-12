extends RefCounted
## ============================================================
##  奶蛙:遗忘档案馆 · 统一 UI 设计系统(UIKit)
## ------------------------------------------------------------
##  全游戏的 2D UI(交互提示条 / 对话卡 / 计数徽章 / 霓虹按钮)
##  都从这里领取样式与锚位,禁止各玩法脚本自行 new 裸控件。
##
##  视觉基调:深紫黑毛玻璃底 + 霓虹青描边 + 奶油白正文,
##  与档案馆场景的青/品红霓虹一致。
##
##  锚位分区(1280x720,互不重叠):
##    左上  档案卡区        (24, 24) 宽 620 —— 对话 / 档案文本
##    右上  计数徽章        右缘 -24, y 24 —— 记忆进度
##    底中  交互提示条      底缘 -134,高 48(全游戏唯一,归 Router 管)
##    底中  按钮行          底缘 -72,高 44
##    底部  字幕带          y >= 664(StoryCue 居中 / MovementHint 左下)
## ============================================================

# ---- 色板 ----
const MILK := Color(0.955, 0.945, 0.905)          # 奶油白正文
const INK := Color(0.026, 0.02, 0.08, 0.85)       # 毛玻璃深底
const INK_RAISED := Color(0.05, 0.04, 0.14, 0.95) # 抬升底(键帽/按钮)
const CYAN := Color("3ee6ff")                     # 主霓虹青
const CYAN_BRIGHT := Color("7df3ff")              # 高亮青
const MAGENTA := Color("ff4fd8")                  # 品红点缀
const AMBER := Color("ffa040")                    # 琥珀点缀
const DIM := Color(0.58, 0.68, 0.74, 0.95)        # 弱化文字
const BORDER_DIM := Color(0.24, 0.42, 0.52, 0.55) # 常态描边

# ---- 锚位常量 ----
const CARD_POS := Vector2(24, 24)
const CARD_WIDTH := 620.0
const PROMPT_BOTTOM := 134.0
const PROMPT_HEIGHT := 48.0
const BTN_ROW_BOTTOM := 72.0
const BTN_HEIGHT := 44.0


## 基础面板样式:圆角 + 可选描边 + 内容边距。
static func panel_style(bg := INK, border := BORDER_DIM, radius := 12, border_w := 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.border_width_left = border_w
	sb.border_width_right = border_w
	sb.border_width_top = border_w
	sb.border_width_bottom = border_w
	sb.border_color = border
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	return sb


## 胶囊样式(提示条 / 徽章)。
static func capsule_style(bg := INK, border := BORDER_DIM) -> StyleBoxFlat:
	return panel_style(bg, border, 24, 1)


## 发光小圆点(提示条 / 徽章前缀)。
static func make_dot(color := CYAN, size := 10.0) -> Panel:
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(size, size)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(size * 0.5))
	dot.add_theme_stylebox_override("panel", sb)
	return dot


## 键帽:深底描边小方块,单字符(如 E / Q)。
static func make_key_cap(k: String) -> PanelContainer:
	var cap := PanelContainer.new()
	cap.custom_minimum_size = Vector2(34, 28)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := panel_style(INK_RAISED, CYAN_BRIGHT, 7, 1)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
	cap.add_theme_stylebox_override("panel", sb)
	var lb := Label.new()
	lb.text = k
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", 15)
	lb.add_theme_color_override("font_color", CYAN_BRIGHT)
	cap.add_child(lb)
	return cap


## 全场唯一的交互提示条:[圆点][键帽][正文],底部居中胶囊。
## 归 InteractionRouter 持有,各系统不得自行创建提示 Label。
static func make_prompt_bar(layer: CanvasLayer) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "SharedPrompt"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", capsule_style(INK, BORDER_DIM))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -PROMPT_BOTTOM
	layer.add_child(panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var dot := make_dot(CYAN)
	row.add_child(dot)
	var key := make_key_cap("E")
	row.add_child(key)
	var body := Label.new()
	body.add_theme_font_size_override("font_size", 17)
	body.add_theme_color_override("font_color", MILK)
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(body)
	return {"panel": panel, "key": key, "key_label": key.get_child(0) as Label, "body": body, "dot": dot}


## 左上档案卡:标题(青色小字)+ 分隔线 + 正文(自动换行)。
static func make_card(layer: CanvasLayer, width := CARD_WIDTH) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "StoryCard"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", panel_style(INK, BORDER_DIM, 14, 1))
	panel.position = CARD_POS
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = Vector2(width - 40.0, 0)
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", CYAN_BRIGHT)
	box.add_child(title)
	var rule := ColorRect.new()
	rule.color = Color(BORDER_DIM.r, BORDER_DIM.g, BORDER_DIM.b, 0.4)
	rule.custom_minimum_size = Vector2(0, 1)
	box.add_child(rule)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 19)
	body.add_theme_color_override("font_color", MILK)
	box.add_child(body)
	return {"panel": panel, "title": title, "body": body}


## 右上计数徽章:[圆点][文字],右上角胶囊。
static func make_badge(layer: CanvasLayer, accent := MAGENTA) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "StatusBadge"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", capsule_style(INK, BORDER_DIM))
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.offset_right = -24.0
	panel.offset_top = 24.0
	layer.add_child(panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	row.add_child(make_dot(accent))
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", MILK)
	row.add_child(label)
	return {"panel": panel, "label": label}


## 霓虹按钮:常态深底暗描边,hover 亮描边,pressed 加粗描边。
static func make_button(text: String, accent := CYAN) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := panel_style(INK_RAISED, BORDER_DIM, 10, 1)
	var hover := panel_style(Color(0.075, 0.062, 0.2, 0.95), accent, 10, 1)
	var pressed := panel_style(Color(0.1, 0.085, 0.26, 0.98), accent, 10, 2)
	var disabled := panel_style(Color(0.04, 0.035, 0.1, 0.7), Color(BORDER_DIM.r, BORDER_DIM.g, BORDER_DIM.b, 0.3), 10, 1)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", MILK)
	b.add_theme_color_override("font_hover_color", CYAN_BRIGHT)
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", DIM)
	return b


## 把按钮行(或单个按钮)锚到底部中央 BTN_ROW 位置。
static func anchor_button_row(ctrl: Control) -> void:
	ctrl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	ctrl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ctrl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ctrl.offset_bottom = -BTN_ROW_BOTTOM
