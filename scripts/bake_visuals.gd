extends SceneTree

## 无头烘焙入口。重跑即可刷新烘焙产物：
##   E:\Godot\Godot_v4.6.3-stable_win64.exe --headless --path . \
##     --script res://scripts/bake_visuals.gd
## 产物落在 res://scenes/baked/，入库随仓库走。
## 编辑器内的一键重烘 + 挂载进场景见 scripts/editor_bake_visuals.gd。

const VB := preload("res://scripts/visual_baker.gd")

func _init() -> void:
	var built: PackedStringArray = VB.rebuild_all()
	print("[bake] 完成，共 %d 项：%s" % [built.size(), ", ".join(built)])
	quit()
