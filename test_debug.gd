extends SceneTree
var scene: Node3D

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	create_timer(60.0).timeout.connect(func(): quit(1))
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	var gallery := scene.get_node("PresentDayGallery") as Node3D
	gallery.visible = false
	scene.archive_root.visible = true
	var interaction = scene.archive_interaction
	var router = scene.get_node_or_null("InteractionRouter")
	interaction.set_active(true)
	scene.archive_npc.set_active(false)
	scene.player.position = Vector3(-4.5, 0.65, 0)
	for frame in range(15):
		await process_frame
	print("[capture] focus=", router.focus_id)
	interaction.set_active(true)
	scene.archive_npc.set_active(false)
	interaction.set_active(true)
	scene.player.position = Vector3(-1.0, 0.65, -1.7)
	interaction.interact()
	for frame in range(80):
		interaction.tick(1.0 / 60.0)
	print("[seen] state=", interaction.get_node_state("seen_2016"))
	scene.player.position = Vector3(11.4, 0.65, -1.7)
	interaction.interact()
	interaction.choose_beat(2)
	for frame in range(120):
		interaction.tick(1.0 / 60.0)
	print("[beat] state=", interaction.get_node_state("imitated_2020"))
	scene.player.position = Vector3(23.8, 0.65, -1.7)
	interaction.interact()
	interaction.tick(interaction.pause_window + 0.1)
	interaction.interact()
	interaction.interact()
	print("[covered] count=", interaction.main_count())
	var endings: Array[String] = []
	interaction.ending_chosen.connect(func(kind: String): endings.append(kind))
	scene.player.position = Vector3(36, 0.65, 0)
	print("[pre-save] at_exit=", interaction._at_exit(), " focus=", router.focus_id, " can_show=", interaction._can_show())
	interaction.interact()
	print("[save] done=", interaction.ending_done, " endings=", endings)
	interaction.ending_done = false
	interaction.set_active(true)
	print("[pre-Q] focus=", router.focus_id, " can_show=", interaction._can_show(), " at_exit=", interaction._at_exit(), " count=", interaction.main_count())
	var release := InputEventKey.new()
	release.keycode = KEY_Q
	release.pressed = true
	interaction._unhandled_input(release)
	print("[Q] done=", interaction.ending_done, " endings=", endings)
	quit(0)