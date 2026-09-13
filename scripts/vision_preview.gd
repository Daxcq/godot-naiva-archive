extends CanvasLayer
## 右下角视觉识别预览。优先显示 Godot CameraServer 的真实摄像头画面，
## 若当前设备不可用，则显示清晰的识别状态与鼠标兜底提示。

var preview: TextureRect
var status_label: Label
var placeholder: Label
var feed = null
var frame_socket := PacketPeerUDP.new()
const FRAME_PORT := 6402
var frame_parts: Dictionary = {}
var last_frame_at := -100.0
# 性能关键：UDP 分片只组装不解码，每 _process 至多解码最新一张 JPEG，
# 积压旧帧直接丢弃；GPU 纹理复用（ImageTexture.update 原地刷新）。
var latest_jpeg := PackedByteArray()

func _ready() -> void:
	_preview_ui()
	frame_socket.bind(FRAME_PORT, "127.0.0.1")
	_connect_camera()

func _preview_ui() -> void:
	var panel := PanelContainer.new()
	panel.name = "VisionPreviewPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.position = Vector2(-286, -196)
	panel.size = Vector2(260, 170)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var title := Label.new()
	title.text = "  VISUAL INPUT  ·  用户视野"
	title.add_theme_font_size_override("font_size", 13)
	box.add_child(title)
	var preview_holder := Control.new()
	preview_holder.custom_minimum_size = Vector2(248, 132)
	preview_holder.clip_contents = true
	box.add_child(preview_holder)
	var preview_background := ColorRect.new()
	preview_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_background.color = Color("101d25")
	preview_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_holder.add_child(preview_background)
	preview = TextureRect.new()
	preview.name = "UserCamera"
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# 摄像头画面铺满预览框：保持比例并裁掉多余边缘，避免左右黑边。
	# 这样人像会同时贴近预览框的左右与上下边缘，更容易看清手势。
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	preview.self_modulate = Color.WHITE
	preview.modulate = Color.WHITE
	preview_holder.add_child(preview)
	placeholder = Label.new()
	placeholder.text = "\n                 ◉\n          等待用户画面"
	placeholder.position = Vector2(0, 42)
	placeholder.size = Vector2(248, 80)
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.add_theme_font_size_override("font_size", 14)
	placeholder.modulate = Color("79a7af")
	preview_holder.add_child(placeholder)
	status_label = Label.new()
	status_label.text = "正在连接摄像头…"
	status_label.add_theme_font_size_override("font_size", 11)
	box.add_child(status_label)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.07, 0.94)
	style.border_color = Color(0.25, 0.75, 0.76, 0.7)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _connect_camera() -> void:
	# Godot 的 CameraServer 在桌面端只暴露 AR/platform feed，
	# 不会像浏览器 getUserMedia 一样枚举普通 USB webcam。
	# 因此这里仅尝试平台 feed，并对 Windows 普通摄像头给出明确提示。
	CameraServer.set_monitoring_feeds(true)
	var count := CameraServer.get_feed_count()
	if count <= 0:
		status_label.text = "摄像头桥接启动中… · 鼠标模式兜底"
		placeholder.text = "\n                 ◉\n       正在后台启动\n         MediaPipe 识别"
		return
	feed = CameraServer.get_feed(0)
	if feed == null:
		status_label.text = "平台摄像头 feed 不可用 · 鼠标模式"
		return
	feed.feed_is_active = true
	preview.texture = feed.get_texture()
	placeholder.visible = preview.texture == null
	status_label.text = "用户画面 · 手部识别已连接"

func _process(_delta: float) -> void:
	# 只组装不解码：把积压的 UDP 分片拼成帧，但只保留最新一张 JPEG。
	# 旧做法在 while 循环里逐帧解码，积压越多单帧耗时越长，恶性循环导致卡顿。
	var assembled := false
	while frame_socket.get_available_packet_count() > 0:
		var packet := frame_socket.get_packet()
		if packet.size() > 8:
			var frame_id := (int(packet[0]) << 24) | (int(packet[1]) << 16) | (int(packet[2]) << 8) | int(packet[3])
			var index := (int(packet[4]) << 8) | int(packet[5])
			var total := (int(packet[6]) << 8) | int(packet[7])
			if total <= 0 or total > 512:
				continue
			if not frame_parts.has(frame_id): frame_parts[frame_id] = {"total": total, "parts": {}}
			frame_parts[frame_id]["parts"][index] = packet.slice(8)
			if frame_parts[frame_id]["parts"].size() == total:
				var jpeg := PackedByteArray()
				for i in range(total): jpeg.append_array(frame_parts[frame_id]["parts"][i])
				frame_parts.erase(frame_id)
				latest_jpeg = jpeg
				assembled = true
			# 丢弃过期分片帧（阈值收紧：挂着的不完整帧越少，越不容易显示旧画面）。
			if frame_parts.size() > 2:
				frame_parts.erase(frame_parts.keys()[0])
			continue
		if packet.size() > 4 and packet[0] == 255 and packet[1] == 216:
			latest_jpeg = packet
			assembled = true
	# 每 _process 至多解码 1 帧：只解最新的，其余积压帧全部跳过。
	if assembled and not latest_jpeg.is_empty():
		var image := Image.new()
		if image.load_jpg_from_buffer(latest_jpeg) == OK:
			_apply_frame(image)
			placeholder.visible = false
			status_label.text = "用户画面 · 摄像头桥接已连接"
			last_frame_at = Time.get_ticks_msec() / 1000.0
		latest_jpeg = PackedByteArray()
	if feed != null and preview != null:
		var texture = feed.get_texture()
		if texture != null and preview.texture != texture:
			preview.texture = texture
			placeholder.visible = false
	if Time.get_ticks_msec() / 1000.0 - last_frame_at > 2.0 and feed == null:
		status_label.text = "未收到画面 · 摄像头桥接未就绪"
	var vision := get_parent().get_node_or_null("VisualRecognition")
	if vision != null and last_frame_at > -10.0:
		var state: Dictionary = vision.get_observation()
		if bool(state.get("active", false)) and String(state.get("source", "")) == "vision":
			status_label.text = "用户画面 · 手部识别已检测"
	elif vision != null and vision.has_method("get_bridge_status"):
		# 桥接还没出帧时，把后台进程状态显示出来，方便现场排查。
		placeholder.text = "\n                 ◉\n       正在后台启动\n         MediaPipe 识别"
		status_label.text = String(vision.get_bridge_status())

func _apply_frame(image: Image) -> void:
	# 复用同一张 GPU 纹理原地刷新，避免每帧 create_from_image 新建纹理
	# 造成的 GPU 资源 churn（接收端卡顿根因）。
	if preview.texture is ImageTexture:
		var tex := preview.texture as ImageTexture
		if tex.get_width() == image.get_width() and tex.get_height() == image.get_height():
			tex.update(image)
			return
	preview.texture = ImageTexture.create_from_image(image)
