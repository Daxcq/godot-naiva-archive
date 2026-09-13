# 档案馆场景布置完成指南

## ✅ 已创建的文件

### 1. 自动布置场景
**`scenes/archive_with_props.tscn`** - 完整的档案馆场景
- ✅ 地板（青色纹理，6x6 重复）
- ✅ 墙壁（品红纹理，3x3 重复）
- ✅ 天花板
- ✅ 动态加载道具（货架、箱子、桌椅）
- ✅ 赛博朋克光照（6个青色 + 1个品红点光源）
- ✅ Glow 后处理效果

### 2. 道具布置脚本
**`scenes/archive_with_props.gd`** - 运行时动态加载道具
- 自动实例化 FBX 模型
- 智能布局算法
- 随机旋转增加真实感

### 3. 编辑器脚本（高级）
**`tools/setup_archive_props.gd`** - 编辑器内批量布置
- 用于修改现有场景
- 添加道具到场景树
- 保存为场景文件

---

## 🎮 运行场景查看效果

### 方法 1：直接运行新场景（推荐）

1. **打开 Godot 编辑器**
   ```
   双击 D:\桌面\godot-naiva-archive\project.godot
   ```

2. **打开场景**
   ```
   FileSystem 面板 → scenes/archive_with_props.tscn
   双击打开
   ```

3. **运行场景**
   ```
   按 F6（运行当前场景）
   或点击顶部 "▶ 运行场景" 按钮
   ```

4. **查看效果**
   - 场景会自动加载所有道具
   - 青色地板 + 品红墙壁
   - 8个高货架排列两侧
   - 箱子堆叠在角落
   - 3组桌椅工作区
   - 7个点光源（6青+1品红）

---

## 📐 场景布局说明

### 主走廊（Z: 0 到 -40）

```
           [-8, 货架]    [+8, 货架]
               │            │
    箱子 ───┐  │            │  ┌─── 箱子
            │  │            │  │
           货架 ────────── 货架
                  走廊
           货架   桌椅    货架  ← -5
           
           货架 ────────── 货架
                           
           货架   桌椅    货架  ← -15
           
           货架 ────────── 货架
                           
           货架   桌椅    货架  ← -25
           
           货架 ────────── 货架
                  品红光
    箱子 ───┘            └─── 箱子  ← -35
```

### 道具坐标列表

**货架（8个）**
- 左侧: (-8, 0, 0/10/20/30) - 朝向右侧
- 右侧: (8, 0, 0/10/20/30) - 朝向左侧

**箱子堆叠（6+4个）**
- 前角落: (±15, 0, 5) 单层 + (±15, 1.2, 5) 双层
- 后角落: (±10, 0, -38)
- 圆桶: (±5, 0, 3), (±12, 0, -35)

**桌椅（3组）**
- 工作区1: 桌(-3, 0, -5) + 椅(-3, 0, -3.5)
- 工作区2: 桌(3, 0, -15) + 椅(3, 0, -13.5)
- 工作区3: 桌(-3, 0, -25) + 椅(-3, 0, -23.5)

**点光源（7个）**
- 青色光: (±8, 4, -5/-15/-25) 照亮货架
- 品红光: (0, 4, -35) 走廊尽头

---

## 🎨 调整场景

### 修改道具数量/位置

编辑 `scenes/archive_with_props.gd`：

```gdscript
# 在 setup_shelves() 中修改货架位置
var positions = [
    Vector3(-8, 0, 0),    # 添加更多坐标
    Vector3(-8, 0, -10),
    # ... 添加你的位置
]
```

### 更换道具模型

```gdscript
# 将 WideTall 货架改为 WideShort
var shelf_path = "res://assets/models/props/Prop_Shelves_WideShort.fbx"

# 将 Crate_Large 改为 Locker
var crate_path = "res://assets/models/props/Prop_Locker.fbx"
```

### 调整光照

在场景树中选择光源节点，修改 Inspector：

```
OmniLight3D:
  light_energy: 1.5 → 2.0  (更亮)
  omni_range: 8.0 → 12.0   (照射更远)
  light_color: 调整颜色
```

### 启用/禁用 Glow

选择 `WorldEnvironment` 节点：

```
Environment → Glow:
  Enabled: true/false
  Intensity: 1.5 (发光强度)
  Strength: 1.2 (发光扩散)
```

---

## 🔧 应用赛博朋克纹理到道具

### 方法 1：手动替换（单个道具）

1. **运行场景**后，在场景树中找到道具节点
   - 展开 `ArchiveProps` → 选择一个货架

2. **找到 MeshInstance3D 子节点**
   - 可能在多层嵌套中

3. **在 Inspector 中**
   - Surface Material Override → 展开
   - Albedo → Texture → Load
   - 浏览到 `res://assets/textures/props_processed/`
   - 选择 `T_Props_Batch1_BaseColor.png`（青色）

4. **调整材质参数**
   ```
   Albedo Color: (1, 1, 1, 1)
   Metallic: 0.3
   Roughness: 0.6
   ```

### 方法 2：批量替换（编辑器脚本）

创建 `tools/apply_cyberpunk_materials.gd`：

```gdscript
@tool
extends EditorScript

func _run():
    var root = get_scene()
    var props_container = root.get_node("ArchiveProps")
    
    # 加载处理后的纹理
    var cyan_texture = load("res://assets/textures/props_processed/T_Props_Batch1_BaseColor.png")
    
    # 递归查找所有 MeshInstance3D
    apply_to_meshes(props_container, cyan_texture)
    
    print("✓ 材质替换完成")

func apply_to_meshes(node: Node, texture: Texture2D):
    if node is MeshInstance3D:
        var material = StandardMaterial3D.new()
        material.albedo_texture = texture
        material.albedo_color = Color.WHITE
        material.metallic = 0.3
        material.roughness = 0.6
        node.material_override = material
        print("  ✓ 应用到: " + node.name)
    
    for child in node.get_children():
        apply_to_meshes(child, texture)
```

**运行方法：**
1. File → Run Script
2. 选择 `tools/apply_cyberpunk_materials.gd`
3. 所有道具自动应用青色纹理

---

## 📊 性能优化建议

### 当前配置
- 19 个道具模型（FBX 动态加载）
- 10 个处理后纹理（1-6 MB）
- 7 个动态点光源（带阴影）
- Glow 后处理

### 如果帧率低于 60fps

1. **减少光源阴影**
   ```gdscript
   # 在 archive_with_props.tscn 中
   OmniLight3D.shadow_enabled = false
   ```

2. **降低 Glow 质量**
   ```
   WorldEnvironment → Environment:
     Glow Quality: High → Medium
   ```

3. **使用场景实例化代替 FBX**
   - 右键 FBX → New Inherited Scene
   - 调整材质后保存为 `.tscn`
   - 脚本中加载 `.tscn` 而不是 `.fbx`

4. **添加遮挡剔除**
   - 大型道具添加 `OccluderInstance3D`
   - 简化碰撞体

---

## 🎯 下一步计划

### 优先级 A：查看效果
- [x] 运行 `archive_with_props.tscn`
- [ ] 截图/录屏查看赛博朋克氛围
- [ ] 调整光照到满意效果

### 优先级 B：应用纹理
- [ ] 手动替换 1-2 个道具纹理测试效果
- [ ] 满意后批量替换所有道具
- [ ] 添加 Emissive 发光纹理

### 优先级 C：扩展场景
- [ ] 添加玩家控制器（第一人称）
- [ ] 添加互动功能（查看档案）
- [ ] 添加音效和背景音乐
- [ ] 添加粒子特效（灰尘、全息投影）

---

## 📝 故障排查

### 问题：道具没有显示

**原因**：FBX 模型路径错误或未导入

**解决方案**：
1. 检查 FileSystem 面板中 `assets/models/props/` 是否有 `.fbx` 文件
2. 查看 Console 输出的错误信息
3. 确认模型已生成 `.fbx.import` 文件

### 问题：纹理全是灰色

**原因**：FBX 默认材质未替换

**解决方案**：
1. 运行批量替换脚本（方法 2）
2. 或手动替换单个道具材质（方法 1）

### 问题：场景太暗

**解决方案**：
1. 增加 `DirectionalLight3D.light_energy` 到 1.5-2.0
2. 增加点光源的 `light_energy` 到 2.0-2.5
3. 调整 `WorldEnvironment.ambient_light_energy` 到 0.8-1.0

### 问题：FPS 很低

**解决方案**：
1. 禁用部分光源阴影
2. 减少 Glow 强度
3. 降低道具数量
4. 使用场景实例化优化

---

## 🎉 完成检查清单

- [x] 19 个 3D 道具模型已导入
- [x] 10 个赛博朋克纹理已处理
- [x] 地板墙壁纹理已应用
- [x] 自动布置场景已创建
- [x] 光照系统已配置
- [x] Glow 后处理已启用
- [ ] 运行场景查看效果 ← **你现在在这里**
- [ ] 应用赛博朋克纹理到道具
- [ ] 微调光照和材质参数
- [ ] 添加玩家控制器

---

## 📖 相关文档

- **道具模型清单**：`docs/scifi_kit_guide.md`
- **完成总结**：`docs/scifi_kit_summary.md`
- **纹理预览指南**：`docs/texture_preview_guide.md`

立即运行 `archive_with_props.tscn` 查看完整的赛博朋克档案馆效果！🎮✨
