extends Node3D
## 队友迁移：真图轮播相框——assets/posters 下 8 张海报图，
## 按框尺寸居中裁切铺满，扫描线切换轮播，带 RGB 色散与行撕裂故障。
## 与 archive_posters.gd（程序化霓虹海报）并存：本组挂在背墙第二排
## （y≈7.5），横向避开走廊大屏（x 10.4~17.6）区域。

const IMAGE_DIR := "res://assets/posters"
const IMAGE_COUNT := 8
## 轮播间隔与单张切换时长；每张错开 STAGGER 秒启动，形成沿墙传播的波浪。
const SWITCH_INTERVAL := 7.0
const TRANSITION_DURATION := 0.75
const STAGGER := 0.16
const WAVE_INITIAL_DELAY := 2.6

const FRAMES := [
	{"x": 1.6, "y": 7.5, "w": 1.6, "h": 1.05, "accent": "ff4fd8", "flicker": false},
	{"x": 4.9, "y": 7.4, "w": 1.5, "h": 1.0, "accent": "3ee6ff", "flicker": true},
	{"x": 8.2, "y": 7.6, "w": 1.6, "h": 1.05, "accent": "b26bff", "flicker": false},
	{"x": 20.2, "y": 7.5, "w": 1.5, "h": 1.0, "accent": "5cffc2", "flicker": true},
	{"x": 23.5, "y": 7.4, "w": 1.6, "h": 1.05, "accent": "ffa040", "flicker": false},
	{"x": 26.8, "y": 7.6, "w": 1.5, "h": 1.0, "accent": "ff5c8a", "flicker": false},
	{"x": 30.1, "y": 7.5, "w": 1.6, "h": 1.05, "accent": "3ee6ff", "flicker": true},
	{"x": 33.4, "y": 7.4, "w": 1.5, "h": 1.0, "accent": "b26bff", "flicker": false}
]

const DISPLAY_SHADER := "
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D tex_prev : source_color, filter_linear;
uniform sampler2D tex_next : source_color, filter_linear;
uniform vec2 uv_scale_prev = vec2(1.0);
uniform vec2 uv_offset_prev = vec2(0.0);
uniform vec2 uv_scale_next = vec2(1.0);
uniform vec2 uv_offset_next = vec2(0.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float time_s = 0.0;
uniform float noise_burst : hint_range(0.0, 1.0) = 0.0;
uniform vec3 accent : source_color = vec3(0.24, 0.9, 1.0);

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }

vec3 sample_torn(sampler2D tex, vec2 su, vec2 so, vec2 uv, float tear) {
	vec2 g = uv;
	g.x += tear * (hash2(vec2(floor(uv.y * 36.0), floor(time_s * 24.0))) - 0.5) * 0.1;
	return texture(tex, g * su + so).rgb;
}

void fragment() {
	vec2 uv = UV;
	float bar = progress;
	float active = step(0.001, progress) * step(progress, 0.999);
	float d = abs(uv.y - bar);
	float glitch = active * smoothstep(0.22, 0.0, d) + noise_burst * 0.35;
	vec3 prev = sample_torn(tex_prev, uv_scale_prev, uv_offset_prev, uv, glitch);
	vec3 next = sample_torn(tex_next, uv_scale_next, uv_offset_next, uv, glitch);
	vec2 ca = vec2(glitch * 0.012, 0.0);
	next.r = texture(tex_next, (uv + ca) * uv_scale_next + uv_offset_next).r;
	next.b = texture(tex_next, (uv - ca) * uv_scale_next + uv_offset_next).b;
	vec3 col = mix(prev, next, step(uv.y, bar));
	col += accent * smoothstep(0.025, 0.0, d) * active * 2.2;
	col += accent * (active * 0.14 + noise_burst * 0.08) * hash2(uv + vec2(time_s * 13.0));
	col *= 0.94 + 0.06 * sin(uv.y * 240.0 + time_s * 2.0);
	col *= 1.0 + 0.03 * sin(time_s * 1.7);
	float vig = smoothstep(0.0, 0.06, uv.x) * smoothstep(1.0, 0.94, uv.x)
		* smoothstep(0.0, 0.06, uv.y) * smoothstep(1.0, 0.94, uv.y);
	col = mix(col * 0.55, col, vig);
	float led = step(length((uv - vec2(0.952, 0.052)) * 26.0), 1.0);
	col = mix(col, accent * (1.1 + active * 1.8), led);
	ALBEDO = col;
}
"

var _textures: Array[Texture2D] = []
var _frames: Array[Dictionary] = []
var _flicker: Array[Dictionary] = []
var _clock := 0.0
var _next_wave := WAVE_INITIAL_DELAY

func setup(archive_root: Node3D) -> void:
	name = "ArchivePhotoFrames"
	archive_root.add_child(self)
	_load_textures()
	for i in range(FRAMES.size()):
		_build_frame(FRAMES[i], i)
	set_process(true)

func _load_textures() -> void:
	for i in range(IMAGE_COUNT):
		var path := "%s/poster_%02d.jpg" % [IMAGE_DIR, i + 1]
		var tex: Texture2D = null
		if ResourceLoader.exists(path):
			tex = load(path)
		if tex == null:
			# 编辑器尚未扫描导入时兜底：直接从磁盘读图，保证任何启动顺序都能显示。
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			if img:
				tex = ImageTexture.create_from_image(img)
		if tex:
			_textures.append(tex)
	if _textures.is_empty():
		push_warning("未找到相框图 assets/posters/poster_01..08.jpg，相框将显示空灯箱")

## 居中裁切UV：让任意宽高比的图无变形地铺满框。
func _crop_params(tex: Texture2D, w: float, h: float) -> Array[Vector2]:
	if tex == null or tex.get_width() == 0 or tex.get_height() == 0:
		return [Vector2.ONE, Vector2.ZERO]
	var quad_aspect := w / h
	var tex_aspect := float(tex.get_width()) / float(tex.get_height())
	if tex_aspect > quad_aspect:
		var sx := quad_aspect / tex_aspect
		return [Vector2(sx, 1.0), Vector2((1.0 - sx) * 0.5, 0.0)]
	var sy := tex_aspect / quad_aspect
	return [Vector2(1.0, sy), Vector2(0.0, (1.0 - sy) * 0.5)]

func _build_frame(spec: Dictionary, order: int) -> void:
	var accent := Color(String(spec.accent))
	var w: float = spec.w
	var h: float = spec.h
	var frame := Node3D.new()
	frame.name = "PhotoFrame_%d" % order
	frame.position = Vector3(spec.x, spec.y, -2.42)
	add_child(frame)
	# 底板：比画面大一圈的深色灯箱壳。
	_panel(frame, "Backing", Vector3.ZERO, Vector3(w + 0.08, h + 0.08, 0.03), Color("0b0618"), 0.0)
	# 霓虹灯管外框：四条发光边。
	for edge in [
		[Vector3(0, h * 0.5 + 0.01, 0.025), Vector3(w + 0.06, 0.04, 0.02)],
		[Vector3(0, -h * 0.5 - 0.01, 0.025), Vector3(w + 0.06, 0.04, 0.02)],
		[Vector3(-w * 0.5 - 0.01, 0, 0.025), Vector3(0.04, h + 0.08, 0.02)],
		[Vector3(w * 0.5 + 0.01, 0, 0.025), Vector3(0.04, h + 0.08, 0.02)]]:
		var tube := _panel(frame, "NeonEdge", edge[0], edge[1], accent, 2.6)
		if spec.get("flicker", false):
			_flicker.append({"mesh": tube, "seed": randf() * TAU})
	# 画面：两张图之间做扫描线切换轮播。
	var start_index := order % maxi(_textures.size(), 1)
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = DISPLAY_SHADER
	mat.shader = shader
	var tex_a: Texture2D = _textures[start_index] if not _textures.is_empty() else null
	var crop_a := _crop_params(tex_a, w, h)
	mat.set_shader_parameter("tex_prev", tex_a)
	mat.set_shader_parameter("tex_next", tex_a)
	mat.set_shader_parameter("uv_scale_prev", crop_a[0])
	mat.set_shader_parameter("uv_offset_prev", crop_a[1])
	mat.set_shader_parameter("uv_scale_next", crop_a[0])
	mat.set_shader_parameter("uv_offset_next", crop_a[1])
	mat.set_shader_parameter("accent", accent)
	var screen := MeshInstance3D.new()
	screen.name = "Screen"
	var quad := QuadMesh.new()
	quad.size = Vector2(w, h)
	screen.mesh = quad
	screen.position = Vector3(0, 0, 0.02)
	screen.material_override = mat
	frame.add_child(screen)
	# 频道读数：轮播切换时同步跳变。
	var channel := Label3D.new()
	channel.name = "Channel"
	channel.text = "CH-%02d" % (start_index + 1)
	channel.position = Vector3(-w * 0.5 + 0.14, -h * 0.5 + 0.09, 0.045)
	channel.font_size = 18
	channel.pixel_size = 0.004
	channel.outline_size = 6
	channel.modulate = accent
	frame.add_child(channel)
	_frames.append({
		"mat": mat, "w": w, "h": h, "channel": channel,
		"index": start_index, "prev_index": start_index,
		"start_at": -1.0, "noise": 0.0
	})

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	# 到点后触发一轮波浪：所有相框按顺序错开切换到下一张图。
	if _clock >= _next_wave and _textures.size() > 1:
		_next_wave = _clock + SWITCH_INTERVAL + FRAMES.size() * STAGGER
		for i in range(_frames.size()):
			var entry: Dictionary = _frames[i]
			entry.prev_index = entry.index
			entry.index = (int(entry.index) + 1) % _textures.size()
			entry.start_at = _clock + i * STAGGER
			_swap_material_textures(entry, true)
	for entry in _frames:
		_tick_frame(entry, delta)
	# 坏灯管闪烁：低频正弦叠加高频抖动，偶尔完全熄灭一瞬。
	for flick in _flicker:
		var mesh := flick.mesh as MeshInstance3D
		var mat := mesh.material_override as StandardMaterial3D
		var phase: float = _clock * 7.0 + float(flick.seed)
		var pulse := 2.2 + sin(phase) * 0.5 + sin(phase * 3.7) * 0.35
		if sin(phase * 0.43) > 0.985:
			pulse = 0.1
		mat.emission_energy_multiplier = maxf(pulse, 0.1)

## 把当前图与下一张图同时挂到材质上；advance 时下一张 = index，当前 = prev_index。
func _swap_material_textures(entry: Dictionary, advance: bool) -> void:
	var mat: ShaderMaterial = entry.mat
	var w: float = entry.w
	var h: float = entry.h
	var tex_prev: Texture2D = _textures[int(entry.prev_index)]
	var tex_next: Texture2D = _textures[int(entry.index)]
	var crop_prev := _crop_params(tex_prev, w, h)
	var crop_next := _crop_params(tex_next, w, h)
	mat.set_shader_parameter("tex_prev", tex_prev)
	mat.set_shader_parameter("uv_scale_prev", crop_prev[0])
	mat.set_shader_parameter("uv_offset_prev", crop_prev[1])
	mat.set_shader_parameter("tex_next", tex_next)
	mat.set_shader_parameter("uv_scale_next", crop_next[0])
	mat.set_shader_parameter("uv_offset_next", crop_next[1])
	if advance:
		var channel: Label3D = entry.channel
		channel.text = "CH-%02d" % (int(entry.index) + 1)

func _tick_frame(entry: Dictionary, delta: float) -> void:
	var mat: ShaderMaterial = entry.mat
	mat.set_shader_parameter("time_s", _clock)
	# 待机时偶发的数字干扰毛刺：随机触发、快速衰减。
	if randf() < delta * 0.35:
		entry.noise = randf_range(0.35, 0.9)
	entry.noise = maxf(float(entry.noise) - delta * 1.8, 0.0)
	mat.set_shader_parameter("noise_burst", entry.noise)
	var progress := 0.0
	if float(entry.start_at) >= 0.0:
		progress = clampf((_clock - float(entry.start_at)) / TRANSITION_DURATION, 0.0, 1.0)
		if progress >= 1.0:
			entry.start_at = -1.0
			entry.prev_index = entry.index
			_swap_material_textures(entry, false)
	# 缓入缓出让扫描线有加速度。
	mat.set_shader_parameter("progress", smoothstep(0.0, 1.0, progress))
	# 切换期间频道读数急促闪烁。
	var channel: Label3D = entry.channel
	if progress > 0.0 and progress < 1.0:
		channel.modulate.a = 0.35 + 0.65 * absf(sin(_clock * 30.0))
	else:
		channel.modulate.a = 1.0

func _panel(parent: Node3D, title: String, at: Vector3, size: Vector3, color: Color, emission: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = title
	node.position = at
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	node.material_override = mat
	parent.add_child(node)
	return node
