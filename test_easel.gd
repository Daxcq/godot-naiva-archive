extends Node

var world: Node
var frames := 0

func _ready() -> void:
	world = preload("res://main.tscn").instantiate()
	add_child(world)

func _process(_delta: float) -> void:
	frames += 1
	if frames == 5:
		var gallery := world.get_node("PresentDayGallery") as Node3D
		gallery.visible = false
		world.archive_root.visible = true
		world.archive_interaction.set_active(true)
		world.archive_npc.set_active(false)
		world.archive_entrance_npc.set_active(false)
		if world.gallery_easel != null:
			world.gallery_easel.set_active(true)
		world.opening.phase = "done"
		world.story_phase = 2
		var title_card: Control = world.get_node_or_null("Interface/TitleCard")
		if title_card != null:
			title_card.visible = false
			title_card.set_process(false)
		world.player.position = Vector3(21.9, 0.65, 0.2)
	if frames == 55:
		get_viewport().get_texture().get_image().save_png("C:/Users/wb198/AppData/Local/Temp/opencode/easel_wall.png")
		get_tree().quit()