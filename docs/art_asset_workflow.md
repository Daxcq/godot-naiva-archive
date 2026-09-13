# 美术资源准备工作流程

## 项目风格定位
- **核心风格**: 霓虹赛博朋克、网络记忆档案馆
- **色调**: 青色/品红霓虹光对比、电子夜色氛围
- **技术标准**: Godot 4.6、GL兼容模式、面数控制在 20k-25k/模型

## 资源需求清单

### 1. 场景环境道具
- [ ] 档案柜 (2016/2020/2024 三个年代款式)
  - 年代标牌
  - 索引卡系统
  - 发光把手
  - 磨损材质效果
  - 散落档案纸张
- [ ] 霓虹灯具
  - 吊灯(品红/青色)
  - 出口指示灯(橙色)
  - 故障屏幕补光
- [ ] 街机机台 (贪吃蛇/俄罗斯方块/打砖块)
- [ ] 霓虹海报墙
- [ ] 地面/墙面材质

### 2. 角色模型
- [ ] 三个档案员 NPC (对应三个档案柜)
- [ ] 玩家角色优化(如需替换现有的 yellow_character)

### 3. 记忆场景资产
- [ ] 霓虹夜市场景元素
- [ ] 深夜街镇场景元素
- [ ] 数据公园场景元素

## 资源获取渠道

### 免费资源平台
1. **Sketchfab** (https://sketchfab.com)
   - 搜索关键词: cyberpunk, neon, archive, cabinet, arcade
   - 筛选: 可下载、CC授权
   
2. **Poly Haven** (https://polyhaven.com)
   - 高质量PBR材质和HDRI
   - 完全免费、CC0授权

3. **Quaternius** (https://quaternius.com)
   - 低多边形风格资产包
   - 适合stylized风格

4. **Kenney Assets** (https://kenney.nl)
   - 游戏素材包
   - CC0授权

5. **OpenGameArt** (https://opengameart.org)
   - 社区资源库

### 付费资源平台(高质量)
1. **Unreal Marketplace** - Megascans资产
2. **TurboSquid**
3. **CGTrader**
4. **ArtStation Marketplace**

## Blender 处理流程

### 第一步: 导入与检查
```python
# 检查模型信息的 Blender Python 脚本
import bpy

obj = bpy.context.active_object
if obj and obj.type == 'MESH':
    mesh = obj.data
    print(f"模型: {obj.name}")
    print(f"顶点数: {len(mesh.vertices)}")
    print(f"面数: {len(mesh.polygons)}")
    print(f"材质数: {len(obj.material_slots)}")
```

### 第二步: 减面优化
**目标面数**: 20,000 - 25,000 面/模型

1. **Decimate 修改器**
   - 选择模型 → 添加 Modifier → Decimate
   - 模式: Collapse
   - Ratio: 根据原始面数调整(通常 0.1-0.3)
   - 保持: UV 边界、锐边、材质边界

2. **手动优化**(可选)
   - 隐藏面删除
   - 对称几何体合并
   - 不可见细节简化

### 第三步: 材质处理
1. **纹理降采样**
   - BaseColor/Diffuse: 2048x2048 → 1024x1024
   - Normal/Roughness: 1024x1024 → 512x512
   - 格式: PNG(带透明) 或 JPEG(不透明)

2. **PBR 材质整合**
   - 确保使用 Principled BSDF
   - 打包纹理: File → External Data → Pack Resources

3. **霓虹发光材质**
   - Emission 强度: 2.0-5.0
   - 颜色: 青色 #00FFFF 或品红 #FF00FF

### 第四步: 坐标系转换
**关键设置**:
- Up Axis: Y (Godot 使用 Y-up)
- Forward: -Z
- Scale: 适当缩放(Godot 单位 = 米)

**在 Blender 中设置**:
1. 模型原点放在底部中心(脚底)
2. 旋转: 面向 -Z 轴方向
3. 应用所有变换: Ctrl+A → All Transforms

### 第五步: 导出 GLB
**导出设置** (File → Export → glTF 2.0):
```
格式: GLB (单文件二进制)
Include:
  ✓ Selected Objects (如果只导出选中)
Transform:
  ✓ +Y Up
Geometry:
  ✓ Apply Modifiers
  ✓ UVs
  ✓ Normals
  ✓ Tangents
  ✓ Vertex Colors (如有)
Material:
  ✓ Export Materials
  Images: Automatic
Compression:
  ✓ Compress (可选,进一步减小文件)
```

## 导入 Godot 流程

### 1. 文件放置
```
D:\桌面\godot-naiva-archive\
  assets\
    environment\      # 环境道具
      cabinet_2016.glb
      neon_light_cyan.glb
      arcade_machine.glb
    character\        # 角色(已有)
      archivist_01.glb
    materials\        # 共享材质/纹理
      neon_cyan.tres
```

### 2. 首次导入
**命令行方式** (生成 .import 文件):
```powershell
cd "D:\桌面\godot-naiva-archive"
godot --headless --path . --import --quit-after 200
```

### 3. 导入设置检查
找到 `<模型>.glb.import` 文件,确认:
```ini
[params]
gltf/embedded_image_handling=0  # 0=保持内嵌, 1=解包(会产生散落PNG)
meshes/ensure_tangents=true
meshes/generate_lods=true
meshes/create_shadow_meshes=true
meshes/light_baking=0
```

### 4. 场景中使用
```gdscript
# 实例化导入的模型
var cabinet_scene = preload("res://assets/environment/cabinet_2016.glb")
var cabinet_instance = cabinet_scene.instantiate()
add_child(cabinet_instance)
cabinet_instance.position = Vector3(0, 0, 0)
```

## 质量检查清单

### 模型检查
- [ ] 面数在 20k-25k 范围内
- [ ] 文件大小 < 5MB
- [ ] 原点位置正确(底部中心)
- [ ] 朝向正确(Godot Y-up)
- [ ] 无错误的法线翻转
- [ ] UV 展开正确

### 材质检查
- [ ] 纹理已内嵌到 GLB
- [ ] 贴图尺寸合理(≤2K)
- [ ] 发光材质强度适当
- [ ] 材质数量合理(≤5个/模型)

### 性能检查
- [ ] 在编辑器中运行流畅(60fps)
- [ ] 多个实例同时显示不掉帧
- [ ] Draw Calls 数量合理

### 视觉检查
- [ ] 符合赛博朋克霓虹风格
- [ ] 与现有资产风格统一
- [ ] 霓虹光照效果正确

## 批量处理脚本示例

### Blender 批量减面脚本
```python
import bpy
import os

# 目标面数
TARGET_FACES = 24000

# 处理所有网格
for obj in bpy.data.objects:
    if obj.type == 'MESH':
        # 选择对象
        bpy.context.view_layer.objects.active = obj
        
        # 计算减面比例
        current_faces = len(obj.data.polygons)
        ratio = TARGET_FACES / current_faces if current_faces > TARGET_FACES else 1.0
        
        # 添加 Decimate 修改器
        if ratio < 1.0:
            mod = obj.modifiers.new(name="Decimate", type='DECIMATE')
            mod.ratio = ratio
            mod.use_collapse_triangulate = True
            
            # 应用修改器
            bpy.ops.object.modifier_apply(modifier="Decimate")
            
            print(f"{obj.name}: {current_faces} → {len(obj.data.polygons)} 面")
```

### Godot 批量导入检查脚本
```gdscript
# res://scripts/check_assets.gd
extends SceneTree

func _init():
    var assets_dir = "res://assets/"
    check_directory(assets_dir)
    quit()

func check_directory(path: String):
    var dir = DirAccess.open(path)
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            var full_path = path + file_name
            if dir.current_is_dir():
                check_directory(full_path + "/")
            elif file_name.ends_with(".glb"):
                check_model(full_path)
            file_name = dir.get_next()

func check_model(path: String):
    var scene = load(path)
    if scene:
        var instance = scene.instantiate()
        var mesh_instances = find_mesh_instances(instance)
        
        var total_faces = 0
        for mi in mesh_instances:
            if mi.mesh:
                total_faces += mi.mesh.get_faces().size() / 3
        
        print("%s: %d 面" % [path, total_faces])
        instance.queue_free()

func find_mesh_instances(node: Node) -> Array:
    var result = []
    if node is MeshInstance3D:
        result.append(node)
    for child in node.get_children():
        result.append_array(find_mesh_instances(child))
    return result
```

运行检查:
```powershell
godot --headless --script res://scripts/check_assets.gd
```

## 常见问题排查

### Q: 模型导入后在 Godot 中躺平了?
**A:** Blender 导出时未设置 Y-up。重新导出并勾选 `+Y Up`。

### Q: 模型太大/太小?
**A:** 在 Blender 中调整缩放,应用变换(Ctrl+A → Scale),再重新导出。
Godot 单位: 1 unit = 1 meter,角色通常 1.7-1.8 units 高。

### Q: 纹理变成散落的 PNG 文件?
**A:** `.glb.import` 文件中 `gltf/embedded_image_handling=1` 改为 `0`,删除 `.import` 文件,重新导入。

### Q: 霓虹材质不发光?
**A:** 在 Godot 中检查材质:
- Emission Enabled: true
- Emission Color: 设置霓虹色
- Emission Energy: 2.0-5.0

### Q: 性能差,帧率低?
**A:** 
1. 检查面数 (Debug → Visible Information → Vertices/Primitives)
2. 减少 OmniLight3D/SpotLight3D 阴影数量
3. 使用 LOD (Level of Detail)
4. 开启遮挡剔除

## 项目特定优化建议

根据 `project.godot`:
- **渲染器**: gl_compatibility (兼容性优先)
- **分辨率**: 1280x720
- **重力**: 18.0 (加快下落)

**优化方向**:
1. 档案柜等静态物体可以合并网格减少 Draw Calls
2. 霓虹灯使用 Baked Lightmap 烘焙间接光照
3. 远处物体使用低模 LOD
4. 海报墙使用 billboard/sprite 而非 3D 模型

## 参考资源
- Godot 导入 3D 模型文档: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/index.html
- Blender to Godot 最佳实践: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/model_export_considerations.html
- 赛博朋克风格参考: ArtStation #cyberpunk #neon
