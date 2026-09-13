# Sci-Fi Kit 道具导入指南

## 📦 已导入的内容

### 3D 模型（19个）

**货架类（4个）**
- `Prop_Shelves_ThinShort.fbx` - 窄短货架
- `Prop_Shelves_ThinTall.fbx` - 窄高货架
- `Prop_Shelves_WideShort.fbx` - 宽短货架
- `Prop_Shelves_WideTall.fbx` - 宽高货架

**箱子/容器类（9个）**
- `Prop_Barrel1.fbx` - 圆桶 1
- `Prop_Barrel2_Closed.fbx` - 圆桶 2（关闭）
- `Prop_Barrel2_Open.fbx` - 圆桶 2（打开）
- `Prop_Chest.fbx` - 箱子
- `Prop_Crate.fbx` - 板条箱
- `Prop_Crate_Large.fbx` - 大板条箱
- `Prop_Crate_Tarp.fbx` - 带篷布板条箱
- `Prop_Crate_Tarp_Large.fbx` - 带篷布大板条箱
- `Prop_Locker.fbx` - 储物柜

**桌椅类（4个）**
- `Prop_Chair.fbx` - 椅子
- `Prop_Desk_L.fbx` - L型桌子
- `Prop_Desk_Medium.fbx` - 中型桌子
- `Prop_Desk_Small.fbx` - 小桌子

**其他道具（2个）**
- `Prop_KeyCard.fbx` - 门卡
- `Prop_Mug.fbx` - 马克杯

### 纹理文件

**原始纹理**（36个，在 `assets/textures/props/`）
- BaseColor（基础颜色）
- Normal（法线贴图）
- ORM（Occlusion/Roughness/Metallic 合并贴图）
- Emissive（发光贴图）

**处理后的纹理**（6个，在 `assets/textures/props_processed/`）
- 已应用赛博朋克配色（青/品红/深蓝）
- 已添加发光效果
- 文件列表：
  - `T_Props_Batch1_BaseColor.png` - 道具批次1（青色）
  - `T_Props_Batch2_BaseColor.png` - 道具批次2（青色）
  - `T_Enemies_BaseColor.png` - 敌人纹理（品红，可用于装饰）
  - `T_Enemies_Large_BaseColor.png` - 大型敌人纹理（品红）
  - `T_Guns_Batch1_BaseColor.png` - 武器批次1（深蓝，可用于装饰）
  - `T_Guns_Batch2_BaseColor.png` - 武器批次2（深蓝）

---

## 🎮 使用方法

### 方法 1：预览所有道具模型

1. **打开 Godot 编辑器**

2. **运行预览场景**
   ```
   场景: res://scenes/props_preview.tscn
   快捷键: F6（运行当前场景）
   ```

3. **控制说明**
   - **Space（空格）**: 下一个道具
   - **Backspace**: 上一个道具
   - **ESC**: 退出

4. **查看效果**
   - 模型会自动居中显示
   - 左上角显示模型名称和编号
   - 双色光源（青色 + 品红）营造赛博朋克氛围

---

### 方法 2：在主场景中使用道具

#### 步骤 1：添加道具到场景

1. **打开主场景**
   ```
   res://scenes/archive_space.tscn
   ```

2. **拖拽模型到场景**
   - FileSystem 面板 → `res://assets/models/props/`
   - 选择一个 `.fbx` 文件
   - 拖拽到场景树或 3D 视口中

3. **调整位置**
   - 使用移动工具（W）调整位置
   - 使用旋转工具（E）调整朝向
   - 使用缩放工具（R）调整大小

#### 步骤 2：应用赛博朋克材质

模型默认使用原始纹理，需要手动替换为处理后的赛博朋克纹理：

1. **选中场景中的道具节点**

2. **展开到 MeshInstance3D 子节点**

3. **在 Inspector 中找到 Material**
   - 可能在 `Surface Material Override` 或嵌入的材质中

4. **找到 Albedo Texture**
   - 点击纹理预览
   - 点击 `Load` 按钮
   - 浏览到 `res://assets/textures/props_processed/`
   - 选择对应的处理后纹理

5. **调整材质参数**（推荐值）
   ```gdscript
   Albedo Color: (1, 1, 1, 1)  # 白色，不改变纹理颜色
   Metallic: 0.3               # 轻微金属感
   Roughness: 0.6              # 哑光表面
   Emission Enabled: true      # 启用自发光
   Emission: 选择对应的 Emissive 纹理
   Emission Energy: 1.5        # 发光强度
   ```

---

### 方法 3：批量替换材质（高级）

如果需要批量替换多个道具的材质，可以使用脚本：

```gdscript
extends EditorScript

func _run():
    # 获取场景根节点
    var root = get_scene()
    
    # 递归查找所有 MeshInstance3D
    process_node(root)
    
    print("✓ 材质替换完成")

func process_node(node):
    if node is MeshInstance3D:
        replace_material(node)
    
    for child in node.get_children():
        process_node(child)

func replace_material(mesh_instance: MeshInstance3D):
    var material = mesh_instance.get_active_material(0)
    if material == null:
        return
    
    # 检查是否使用 Props 纹理
    var albedo = material.albedo_texture
    if albedo == null:
        return
    
    var texture_path = albedo.resource_path
    if "Props" not in texture_path:
        return
    
    # 替换为处理后的纹理
    var new_path = texture_path.replace("/props/", "/props_processed/")
    var new_texture = load(new_path)
    
    if new_texture != null:
        material.albedo_texture = new_texture
        print("✓ 替换: " + mesh_instance.name)
```

**使用方法：**
1. 保存上述代码为 `res://tools/replace_props_materials.gd`
2. 在 Godot 编辑器中：`File → Run Script`
3. 选择该脚本运行

---

## 🎨 档案馆场景布置建议

### 主走廊区域

**货架布局**
```
使用：Prop_Shelves_WideTall.fbx（4个）
位置：走廊两侧，对称排列
间距：2-3 米
作用：存放档案文件、记忆容器
```

**桌椅工作区**
```
使用：Prop_Desk_Medium.fbx + Prop_Chair.fbx（2-3组）
位置：货架之间的空地
作用：玩家查阅档案的工作台
```

### 存储区域

**箱子堆叠**
```
使用：Prop_Crate.fbx, Prop_Crate_Large.fbx
位置：角落、墙边
堆叠：2-3 层高
作用：营造仓库感，遮挡空间
```

**容器分散**
```
使用：Prop_Barrel1.fbx, Prop_Locker.fbx
位置：走廊端点、转角处
作用：打破单调，增加探索点
```

### 细节点缀

**桌面道具**
```
使用：Prop_Mug.fbx, Prop_KeyCard.fbx
位置：桌子表面
作用：增加生活感，可交互物品
```

---

## ⚙️ 性能优化建议

### 实例化重复道具

对于大量重复的道具（如货架），使用场景实例化而不是重复导入：

1. **创建道具场景**
   - 右键 FBX 文件 → `New Inherited Scene`
   - 调整好材质和参数
   - 保存为 `.tscn` 场景（如 `shelf_cyan.tscn`）

2. **实例化场景**
   - 拖拽 `.tscn` 到主场景中（而不是 `.fbx`）
   - 所有实例共享材质，节省内存

### LOD（细节层次）

如果场景中道具很多，考虑添加 LOD：

```gdscript
# 在道具节点上
var lod_distance = 10.0  # 米

func _process(_delta):
    var camera = get_viewport().get_camera_3d()
    if camera == null:
        return
    
    var distance = global_position.distance_to(camera.global_position)
    
    if distance > lod_distance:
        visible = false  # 远处隐藏
    else:
        visible = true
```

### 遮挡剔除

启用遮挡剔除以提高性能：

1. 在场景中添加 `OccluderInstance3D`
2. 为大型道具（货架、墙壁）创建简化的遮挡体
3. Godot 会自动隐藏被遮挡的物体

---

## 🔧 故障排查

### 模型不显示
- 检查模型是否在摄像机视野内
- 检查材质是否正确分配
- 检查光源是否充足

### 纹理全白/全黑
- 确保使用处理后的纹理（`props_processed/` 目录）
- 检查 `Albedo Color` 是否为白色 (1, 1, 1)
- 确保场景中有光源

### 模型太暗
- 增加 `DirectionalLight3D` 的 `Light Energy`
- 添加 `OmniLight3D` 作为补光
- 调整 `WorldEnvironment` 的 `Ambient Light`

### 看不到发光效果
- 确保 `WorldEnvironment` 启用了 Glow
- 检查材质的 `Emission Enabled` 是否打开
- 增加 `Emission Energy` 值

---

## 📋 文件清单

```
godot-naiva-archive/
├── assets/
│   ├── models/
│   │   └── props/              # 19 个 FBX 模型
│   └── textures/
│       ├── props/              # 36 个原始纹理
│       └── props_processed/    # 6 个处理后纹理
├── scenes/
│   ├── props_preview.tscn      # 道具预览场景
│   └── props_preview.gd        # 预览脚本
└── tools/
    └── process_props_textures.py  # 纹理处理脚本
```

---

## 下一步

1. ✅ **预览道具** - 运行 `props_preview.tscn`
2. ✅ **应用纹理** - 墙壁地板纹理已处理完成
3. 🎯 **布置场景** - 在主场景中添加货架、箱子等道具
4. 🎨 **调整材质** - 替换为赛博朋克处理后的纹理
5. 💡 **优化光照** - 调整光源和 Glow 效果

如果需要更多道具或不同配色，可以重新运行 `process_props_textures.py` 并修改配色方案！
