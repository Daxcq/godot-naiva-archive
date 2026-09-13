extends Node
## 走廊旧显示屏：靠近按 E 播放合成影像，Esc 退出。

const VIDEO_PATH := "res://assets/video/corridor_screen.ogv"
const SCREEN_PIXELS := Vector2i(1024, 576)
const INTERACTION_POINT := Vector2(14.0, -1.7)
const REACH := 2.6
const CAMERA_POSITION := Vector3(14.0, 6.3, 3.6)
const CAMERA_TARGET := Vector3(14.0, 6.3, -2.23)

var world: Node3D
var player: CharacterBody3D
var camera: Camera3D
var camera_director: Node
var router: Node
var screen: MeshInstance3D
var scanline: Node3D
var screen_labels: Array[Label3D] = []
var video: VideoStreamPlayer
var video_surface: MeshInstance3D
var video_material: StandardMaterial3D
var playing := false
var saved_camera_transform: Transform3D
var saved_camera_fov := 44.0
var scanline_was_visible := false
var label_visibility := {}

func setup(owner: Node3D) -> void:
	world = owner
	player = owner.player
	camera = owner.camera
	camera_director = owner.camera_director
	router = owner.get_node_or_null("InteractionRouter")
	screen = owner.archive_root.get_node("DeadScreen") as MeshInstance3D
	scanline = owner.archive_root.get_node_or_null("Scanline") as Node3D
	for child in owner.archive_root.get_children():
		if child is Label3D and child.position.x >= 10.4 and child.position.x <= 17.6 and child.position.y >= 4.0 and child.position.y <= 8.7:
			screen_labels.append(child)

	var viewport := SubViewport.new()
	viewport.name = "VideoViewport"
	viewport.size = SCREEN_PIXELS
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	video = VideoStreamPlayer.new()
	video.name = "Video"
	video.size = Vector2(SCREEN_PIXELS)
	video.stream = load(VIDEO_PATH) as VideoStream
	video.finished.connect(_stop_video)
	viewport.add_child(video)

	video_material = StandardMaterial3D.new()
	video_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	video_material.no_depth_test = true
	video_material.albedo_texture = viewport.get_texture()
	video_surface = MeshInstance3D.new()
	video_surface.name = "VideoSurface"
	var quad := QuadMesh.new()
	quad.size = Vector2(6.65, 6.65 * 9.0 / 16.0)
	video_surface.mesh = quad
	video_surface.material_override = video_material
	video_surface.position.z = 0.031
	video_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	video_surface.visible = false
	screen.add_child(video_surface)

func _process(delta: float) -> void:
	if playing:
		if router:
			router.offer("video_screen", "退出播放", 0.0, "Esc", 0, true)
		camera_director.apply_cinematic(
			camera.position.lerp(CAMERA_POSITION, minf(delta * 5.0, 1.0)),
			CAMERA_TARGET,
			lerpf(camera.fov, 44.0, minf(delta * 5.0, 1.0))
		)
		return
	if not world.archive_root.visible:
		return
	var distance := Vector2(player.position.x, player.position.z).distance_to(INTERACTION_POINT)
	if distance <= REACH and router:
		router.offer("video_screen", "播放奶蛙影像", distance, "E")

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if playing:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_stop_video()
		return
	if event.is_action_pressed("interact") and _can_start():
		get_viewport().set_input_as_handled()
		_start_video()

func _can_start() -> bool:
	var distance := Vector2(player.position.x, player.position.z).distance_to(INTERACTION_POINT)
	return world.archive_root.visible and distance <= REACH and (router == null or router.can_interact("video_screen"))

func _start_video() -> void:
	if playing or video.stream == null:
		return
	playing = true
	player.velocity = Vector3.ZERO
	saved_camera_transform = camera.transform
	saved_camera_fov = camera.fov
	scanline_was_visible = scanline != null and scanline.visible
	label_visibility.clear()
	for label in screen_labels:
		label_visibility[label] = label.visible
		label.visible = false
	if scanline:
		scanline.visible = false
	video_surface.visible = true
	video.play()

func _stop_video() -> void:
	if not playing:
		return
	playing = false
	video.stop()
	video_surface.visible = false
	if scanline:
		scanline.visible = scanline_was_visible
	for label in screen_labels:
		label.visible = bool(label_visibility.get(label, true))
	camera_director.reset()
	camera.transform = saved_camera_transform
	camera.fov = saved_camera_fov

func is_playing() -> bool:
	return playing
