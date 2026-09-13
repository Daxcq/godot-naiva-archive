class_name VisualBaker
extends RefCounted

## 程序化生成物 → 场景烘焙工具。
##
## 背景：档案馆大量 3D 物体是运行时代码生成的，编辑器场景面板里看不见、
## 没法直接拖动微调。本工具把"纯视觉、无状态"的生成物打包成普通 .tscn：
##   1. bake_visuals.gd（无头）/ editor_bake_visuals.gd（编辑器内）调
##      rebuild_all() 生成 res://scenes/baked/<key>.tscn；
##   2. 编辑器工具把烘焙实例挂进 main.tscn 的 ArchiveArchitecture 下，
##      此后在场景面板里可直接选中、挪动、改属性；
##   3. 运行时各生成器入口先调 try_mount()——烘焙实例已在场景里（或能从
##      tscn 加载）就跳过程序生成；删掉烘焙 tscn 则自动回落原生成逻辑。
##
## 约定：宿主 root 下烘焙实例统一命名 BakedVisuals_<key>。
## 新增可烘焙视觉物：在 rebuild_all() 加一个 _bake_xxx()，并在对应生成器
## 入口加 try_mount 跳过分支即可。

const BAKED_DIR := "res://scenes/baked"

static func node_name(key: String) -> String:
	return "BakedVisuals_" + key

## 宿主 root 下是否已挂着烘焙实例（编辑器挂载保存后走这里命中）。
static func baked_present(root: Node3D, key: String) -> bool:
	return root != null and root.get_node_or_null(NodePath(node_name(key))) != null

## 生成器入口用：烘焙场景文件存在就实例化挂到 root 并返回 true，
## 调用方据此跳过程序生成。两级兜底的第二级——即使编辑器里没挂过，
## 只要 tscn 在仓库里，运行时也能用上烘焙结果。
static func try_mount(root: Node3D, key: String) -> bool:
	if root == null:
		return false
	if baked_present(root, key):
		return true
	var path := "%s/%s.tscn" % [BAKED_DIR, key]
	if not ResourceLoader.exists(path):
		return false
	var packed := load(path) as PackedScene
	if packed == null:
		return false
	var inst := packed.instantiate()
	inst.name = node_name(key)
	root.add_child(inst)
	return true

## 重新烘焙全部条目，返回成功的 key 列表。无头脚本与编辑器工具共用。
static func rebuild_all() -> PackedStringArray:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BAKED_DIR))
	var built := PackedStringArray()
	if _bake_atmosphere():
		built.append("atmosphere")
	if _bake_posters():
		built.append("posters")
	return built

## 氛围层（archive_details.build_fx 产物：尘埃粒子、屏幕光锥、出口暖光）。
static func _bake_atmosphere() -> bool:
	var temp := Node3D.new()
	load("res://scripts/archive_details.gd").build_fx(temp, true)
	var product := temp.get_node_or_null("FX")
	var ok := _save_product(product, "atmosphere")
	temp.free()
	return ok

## 背墙霓虹海报（archive_posters）。只烘焙静态外观；
## 故障闪烁动画由运行时 _adopt_baked 接回（见 archive_posters.gd）。
static func _bake_posters() -> bool:
	var temp := Node3D.new()
	var posters: Node3D = load("res://scripts/archive_posters.gd").new()
	posters.setup(temp, true)
	var product := Node3D.new()
	product.name = "Posters"
	for child in posters.get_children():
		posters.remove_child(child)
		product.add_child(child)
	var ok := _save_product(product, "posters")
	temp.free()
	return ok

static func _save_product(product: Node, key: String) -> bool:
	if product == null:
		push_warning("[VisualBaker] %s：生成产物为空，跳过烘焙" % key)
		return false
	product.name = node_name(key)
	# pack 只收录 owner 指向打包根的节点，运行时生成的节点必须补设 owner。
	_set_owner_recursive(product, product)
	var packed := PackedScene.new()
	if packed.pack(product) != OK:
		push_warning("[VisualBaker] %s：pack 失败" % key)
		return false
	var path := "%s/%s.tscn" % [BAKED_DIR, key]
	var err := ResourceSaver.save(packed, path)
	if err != OK:
		push_warning("[VisualBaker] %s：保存失败 err=%d" % [key, err])
		return false
	print("[VisualBaker] 已烘焙 %s -> %s" % [key, path])
	return true

static func _set_owner_recursive(node: Node, owner: Node) -> void:
	if node != owner:
		node.owner = owner
	for child in node.get_children():
		_set_owner_recursive(child, owner)
