# 材质自动化下载与导入指南

本指南将帮你自动下载、处理并导入材质到 Godot 项目。

## 📋 流程概览

```
1. 下载材质 (Python)
   ↓
2. 整理材质 (Python)
   ↓
3. 处理材质 (Blender)
   ↓
4. 导入 Godot (GDScript)
```

## 🚀 快速开始

### 第一步: 下载材质

```powershell
cd "D:\桌面\godot-naiva-archive"
python tools/download_textures.py
```

**下载内容**:
- Poly Haven: 混凝土地板、锈蚀金属板、金属板、混凝土墙 (4K)
- ambientCG: 混凝土墙、金属面板 (4K)

**保存位置**: `D:\桌面\raw_textures\`

**预计时间**: 5-10 分钟 (取决于网速)

### 第二步: 整理材质

```powershell
python tools/organize_textures.py
```

**功能**:
- 将下载的材质规范化命名
- 按类型分类 (floors/walls/metal)
- 复制到项目 assets/textures 目录

**输出目录**:
```
assets/
  textures/
    floors/
      concrete_floor_001/
        concrete_floor_001_albedo.png
        concrete_floor_001_normal.png
        concrete_floor_001_roughness.png
        concrete_floor_001_ao.png
    walls/
      concrete_wall/
        ...
    metal/
      rusty_metal_sheet/
        ...
```

### 第三步: Blender 处理 (可选)

如果你需要在 Blender 中预览材质或创建 .blend 文件:

```powershell
# 设置环境变量
$env:GODOT_PROJECT_ROOT = "D:\桌面\godot-naiva-archive"

# 运行 Blender 脚本 (后台模式)
blender --background --python tools/blender_process_materials.py
```

**输出**: `assets/materials/<材质名称>.blend`

**注意**: 这一步是可选的。Godot 可以直接使用 PNG 纹理而无需 Blender 预处理。

### 第四步: 导入到 Godot

```powershell
cd "D:\桌面\godot-naiva-archive"

# 方式 1: 使用脚本自动创建材质资源
godot --headless --script tools/godot_import_materials.gd

# 方式 2: 在编辑器中手动导入
# 1. 用 Godot 编辑器打开项目
# 2. 纹理会自动生成 .import 文件
# 3. 手动创建 StandardMaterial3D 资源并设置纹理
```

**输出**: `assets/materials/<材质名称>.tres`

## 📁 最终目录结构

```
godot-naiva-archive/
  assets/
    textures/           # 原始纹理文件
      floors/
        concrete_floor_001/
          concrete_floor_001_albedo.png
          concrete_floor_001_normal.png
          concrete_floor_001_roughness.png
          concrete_floor_001_ao.png
          metadata.json
          material_info.json
      walls/
        concrete_wall_023/
          ...
      metal/
        rusty_metal_sheet/
          ...
    materials/          # Godot 材质资源
      concrete_floor_001.tres
      concrete_wall_023.tres
      rusty_metal_sheet.tres
  tools/
    download_textures.py
    organize_textures.py
    blender_process_materials.py
    godot_import_materials.gd
raw_textures/           # 临时下载目录 (项目外)
  poly_haven/
  ambientcg/
```

## 🎨 在场景中使用材质

### 方法 1: 在编辑器中应用

1. 在场景树中选择 `MeshInstance3D` 节点
2. 在 Inspector 中找到 `Material Override`
3. 点击 `Load` 加载材质: `res://assets/materials/concrete_floor_001.tres`

### 方法 2: 通过脚本应用

```gdscript
extends MeshInstance3D

func _ready():
    # 加载材质
    var floor_material = preload("res://assets/materials/concrete_floor_001.tres")
    
    # 应用到网格
    material_override = floor_material
```

### 方法 3: 在代码中动态加载

```gdscript
@onready var floor_mesh = $FloorMeshInstance3D

func _ready():
    var material_path = "res://assets/materials/concrete_floor_001.tres"
    var material = load(material_path) as StandardMaterial3D
    
    if material:
        floor_mesh.material_override = material
```

## ⚙️ 材质调整

如果需要调整材质参数,打开 `.tres` 文件:

```gdscript
# 调整 UV 缩放 (平铺次数)
material.uv1_scale = Vector3(8, 8, 1)  # 重复 8x8 次

# 调整粗糙度
material.roughness = 0.6

# 调整基础颜色
material.albedo_color = Color(0.2, 0.2, 0.2, 1.0)

# 添加霓虹发光效果
material.emission_enabled = true
material.emission = Color(0.0, 1.0, 1.0, 1.0)  # 青色
material.emission_energy_multiplier = 3.0
```

## 🔧 故障排除

### 问题 1: 下载失败 "Connection error"

**解决**:
```powershell
# 检查网络连接
ping polyhaven.com

# 使用代理 (如果需要)
$env:HTTP_PROXY = "http://your-proxy:port"
$env:HTTPS_PROXY = "http://your-proxy:port"
python tools/download_textures.py
```

### 问题 2: Python 模块缺失

**解决**:
```powershell
pip install requests
```

### 问题 3: Godot 纹理显示为粉红色

**原因**: `.import` 文件未生成或路径错误

**解决**:
```powershell
# 重新导入所有资源
godot --headless --path . --import --quit-after 200
```

### 问题 4: Normal 贴图没有凹凸效果

**原因**: Normal 贴图未标记为 Non-Color

**解决**:
1. 找到 `<材质>_normal.png.import` 文件
2. 修改: `compress/normal_map=1`
3. 重新启动 Godot 或右键纹理 → Reimport

### 问题 5: 材质太暗或太亮

**调整**:
```gdscript
# 在 Godot 中调整 albedo_color
material.albedo_color = Color(0.5, 0.5, 0.5, 1.0)  # 提高亮度
```

或在场景中添加更多光源:
```gdscript
var omni_light = OmniLight3D.new()
omni_light.light_energy = 2.0
omni_light.position = Vector3(0, 3, 0)
add_child(omni_light)
```

## 📊 下载的材质列表

| 材质名称 | 来源 | 类型 | 分辨率 | 用途 |
|---------|------|------|--------|------|
| concrete_floor_001 | Poly Haven | 地板 | 4K | 档案馆主地板 |
| rusty_metal_sheet | Poly Haven | 墙壁 | 4K | 工业金属墙板 |
| metal_plate | Poly Haven | 墙壁 | 4K | 档案柜金属板 |
| concrete_wall | Poly Haven | 墙壁 | 4K | 混凝土墙壁 |
| concrete_wall_023 | ambientCG | 墙壁 | 4K | 混凝土墙壁变体 |
| metal_panels_001 | ambientCG | 墙壁 | 4K | 金属面板 |

## 🎯 性能优化建议

1. **使用 Mipmaps**
   - 所有纹理默认开启 Mipmaps
   - 远处自动降低分辨率,减少锯齿

2. **压缩纹理**
   - `.import` 文件中 `compress/mode=2` (VRAM 压缩)
   - 平衡质量与性能

3. **UV 平铺**
   - 使用 `uv1_scale` 重复纹理
   - 避免使用巨大的单张贴图

4. **LOD (Level of Detail)**
   - 远处物体使用简化材质
   - 移除 Normal/AO 贴图

## 📚 相关文档

- [完整材质推荐清单](docs/recommended_assets.md)
- [墙壁与地板材质推荐](docs/wall_floor_materials.md)
- [美术资源工作流程](docs/art_asset_workflow.md)

## 🆘 需要帮助?

如果遇到问题:
1. 检查本文档的故障排除部分
2. 查看 `docs/` 目录中的详细文档
3. 检查 `.import` 文件和材质设置

## 下一步

材质导入完成后,你可以:
1. 在场景中应用材质到 MeshInstance3D
2. 调整 UV 缩放和材质参数
3. 添加霓虹发光效果 (Emission)
4. 设置场景光照 (OmniLight3D / DirectionalLight3D)
5. 测试性能 (Debug → Visible Information → FPS)
