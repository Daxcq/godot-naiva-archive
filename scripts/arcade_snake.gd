extends Control
## 街机贪吃蛇：16×12 网格，方向复用 move_* 动作，interact 重开，ESC 由街机层接管。

const COLS := 16
const ROWS := 12
const CELL := 34.0
const STEP_TIME := 0.16

var snake: Array[Vector2i] = []
var direction := Vector2i.RIGHT
var pending_direction := Vector2i.RIGHT
var food := Vector2i(10, 6)
var score := 0
var dead := false
var step_timer := 0.0
var rng := RandomNumberGenerator.new()
## 手势输入(InputState),由街机层注入;为空时纯键盘。
var gesture: Node
## 8-bit 音效包(res://scripts/pixel_sfx.gd)。
var sfx: Node

func _ready() -> void:
	sfx = load("res://scripts/pixel_sfx.gd").new()
	add_child(sfx)
	set_process(true)

func _gesture_confirm() -> bool:
	return gesture != null and gesture.is_vision_driven() and gesture.confirm_just_pressed and gesture.consume_confirm()

func reset() -> void:
	snake = [Vector2i(5, 6), Vector2i(4, 6), Vector2i(3, 6)]
	direction = Vector2i.RIGHT
	pending_direction = direction
	score = 0
	dead = false
	step_timer = 0.0
	if sfx: sfx.play("arcade_start")
	_spawn_food()
	queue_redraw()

func _spawn_food() -> void:
	while true:
		food = Vector2i(rng.randi_range(0, COLS - 1), rng.randi_range(0, ROWS - 1))
		if not snake.has(food):
			return

func _process(delta: float) -> void:
	if (Input.is_action_just_pressed("interact") or _gesture_confirm()) and dead:
		reset()
		return
	if gesture != null and gesture.is_vision_driven():
		# 手势:手掌偏移决定转向(取主轴),相当于推摇杆。
		var lean: Vector2 = gesture.steer
		if lean.length() > 0.4:
			if absf(lean.x) >= absf(lean.y):
				var gx := int(signf(lean.x))
				if gx != 0 and gx != -direction.x:
					pending_direction = Vector2i(gx, 0)
			else:
				var gy := int(signf(lean.y))
				if gy != 0 and gy != -direction.y:
					pending_direction = Vector2i(0, gy)
	else:
		var input := Vector2i(int(Input.get_axis("move_left", "move_right")), int(Input.get_axis("move_forward", "move_back")))
		if input.x != 0 and input.x != -direction.x:
			pending_direction = Vector2i(input.x, 0)
		elif input.y != 0 and input.y != -direction.y:
			pending_direction = Vector2i(0, input.y)
	if dead:
		return
	step_timer += delta
	if step_timer < STEP_TIME:
		return
	step_timer = 0.0
	direction = pending_direction
	var head: Vector2i = snake[0] + direction
	if head.x < 0 or head.x >= COLS or head.y < 0 or head.y >= ROWS or snake.has(head):
		dead = true
		if sfx: sfx.play("arcade_over", -8.0)
		queue_redraw()
		return
	snake.push_front(head)
	if head == food:
		score += 10
		if sfx: sfx.play("arcade_score", -8.0)
		_spawn_food()
	else:
		snake.pop_back()
	queue_redraw()

func _draw() -> void:
	var board := Vector2(COLS * CELL, ROWS * CELL)
	var origin := (size - board) * 0.5
	draw_rect(Rect2(origin - Vector2(6, 6), board + Vector2(12, 12)), Color("5cff6e"), false, 3.0)
	draw_rect(Rect2(origin, board), Color(0.015, 0.01, 0.045))
	# 网格微光。
	for x in range(COLS + 1):
		draw_line(origin + Vector2(x * CELL, 0), origin + Vector2(x * CELL, board.y), Color(0.36, 1.0, 0.43, 0.06))
	for y in range(ROWS + 1):
		draw_line(origin + Vector2(0, y * CELL), origin + Vector2(board.x, y * CELL), Color(0.36, 1.0, 0.43, 0.06))
	draw_rect(Rect2(origin + Vector2(food.x, food.y) * CELL + Vector2(5, 5), Vector2(CELL - 10, CELL - 10)), Color("ff4fd8"))
	for i in range(snake.size()):
		var cell: Vector2i = snake[i]
		var body := Color("5cff6e") if i == 0 else Color("35c24d").lerp(Color("1a7030"), float(i) / maxf(snake.size(), 1.0))
		draw_rect(Rect2(origin + Vector2(cell.x, cell.y) * CELL + Vector2(3, 3), Vector2(CELL - 6, CELL - 6)), body)
	var font := ThemeDB.fallback_font
	draw_string(font, origin + Vector2(0, -20), "贪吃蛇  ·  得分 %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("5cff6e"))
	draw_string(font, origin + Vector2(board.x - 260, -20), "WASD/方向键 移动 · ESC 退出", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("c9d4f2"))
	if dead:
		draw_string(font, origin + board * 0.5 + Vector2(-120, 0), "信号中断  ·  E 握拳重开", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("ff4fd8"))
