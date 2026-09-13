extends SceneTree

const MODEL := "res://assets/character/yellow_character_animated.glb"
const REQUIRED := ["idle", "walk", "run", "jump", "fall", "land"]

func _initialize() -> void:
	var packed := load(MODEL) as PackedScene
	assert(packed != null, "无法加载动画 GLB: %s" % MODEL)
	var instance := packed.instantiate()
	root.add_child(instance)
	var player := _find_animation_player(instance)
	assert(player != null, "GLB 中找不到 AnimationPlayer")
	var found: Array[String] = []
	for library_name in player.get_animation_library_list():
		var library := player.get_animation_library(library_name)
		for animation_name in library.get_animation_list():
			found.append(animation_name)
	print("AnimationPlayer: ", player.name)
	print("Animations: ", found)
	var library := player.get_animation_library("")
	for name in REQUIRED:
		assert(found.has(name), "缺少动作: %s" % name)
		var animation := library.get_animation(name)
		assert(animation != null and animation.length > 0.0, "动作无有效时长: %s" % name)
	print("RESULT: PASS Godot 已读取全部 6 个动作")
	quit()

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var hit := _find_animation_player(child)
		if hit != null:
			return hit
	return null
