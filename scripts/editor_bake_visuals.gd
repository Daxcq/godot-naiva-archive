@tool
extends EditorScript

## 编辑器一键烘焙：把程序化生成的纯视觉 3D 物打包成 .tscn，
## 并把烘焙实例挂进当前场景的 ArchiveArchitecture 下保存。
## 之后在场景面板里就能直接选中、挪动、微调这些物体（不再是隐形生成物）。
##
## 用法：编辑器打开 main.tscn → 脚本编辑器打开本文件 → 文件 → 运行（Ctrl+Shift+X）。
## 重新生成了视觉物想更新烘焙产物时，重跑一次即可（自动替换旧实例）。

func _run() -> void:
	var vb := preload("res://scripts/visual_baker.gd")
	var built: PackedStringArray = vb.rebuild_all()
	print("[VisualBaker] 重新烘焙完成：%s" % ", ".join(built))

	var scene := EditorInterface.get_edited_scene_root()
	if scene == null:
		push_warning("[VisualBaker] 请先在编辑器里打开 main.tscn 再运行本工具")
		return
	var arch := scene.get_node_or_null("ArchiveArchitecture")
	if arch == null:
		push_warning("[VisualBaker] 当前场景里没有 ArchiveArchitecture 节点")
		return

	for key in ["atmosphere", "posters"]:
		var path: String = "%s/%s.tscn" % [vb.BAKED_DIR, key]
		if not ResourceLoader.exists(path):
			print("[VisualBaker] 跳过 %s（没有烘焙产物）" % key)
			continue
		var old := arch.get_node_or_null(NodePath(vb.node_name(key)))
		if old != null:
			arch.remove_child(old)
			old.free()
		var inst := (load(path) as PackedScene).instantiate()
		inst.name = vb.node_name(key)
		arch.add_child(inst)
		inst.owner = scene
		print("[VisualBaker] 已挂载 %s 到 %s" % [inst.name, arch.name])

	EditorInterface.save_scene()
	print("[VisualBaker] 场景已保存——烘焙物现在可以直接在场景面板里编辑了")
