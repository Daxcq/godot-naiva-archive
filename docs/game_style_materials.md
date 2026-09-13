# 3D 小游戏材质方案

适合霓虹赛博朋克风格的 3D 小游戏（非写实）

## 🎨 推荐方案：程序化 + 简单纹理

### 方案 A：纯色材质 + Shader（最佳）

**优点**：
- 性能最优
- 风格统一
- 霓虹光效突出
- 文件体积小
- 适合 WebGL/移动端

**实现**：
```gdscript
# 档案馆地板 - 深色镜面
var floor_mat = StandardMaterial3D.new()
floor_mat.albedo_color = Color(0.05, 0.08, 0.12, 1.0)
floor_mat.metallic = 0.9
floor_mat.roughness = 0.2
floor_mat.emission_enabled = true
floor_mat.emission = Color(0.0, 0.15, 0.2, 1.0)
floor_mat.emission_energy_multiplier = 0.3

# 墙壁 - 深色哑光
var wall_mat = StandardMaterial3D.new()
wall_mat.albedo_color = Color(0.03, 0.05, 0.08, 1.0)
wall_mat.metallic = 0.0
wall_mat.roughness = 0.95
```

### 方案 B：极简几何纹理（推荐）

**适合的纹理类型**：
1. **网格线条** - 电子感
2. **六边形瓷砖** - 科幻感
3. **扫描线** - 赛博朋克经典
4. **电路板图案** - 简洁高对比

**分辨率**: 512x512 或 1024x1024（不需要 4K）

**色调**: 深蓝/紫/黑，配合霓虹光

## 🔍 推荐的纹理资源

### 1. Kenney Assets（游戏专用，完全免费）
- 🔗 https://kenney.nl/assets?q=2d
- **特点**: 
  - 专为游戏设计
  - 低分辨率，性能优
  - 风格统一
  - CC0 授权

**推荐包**：
- **Prototype Textures** - 纯色网格材质
- **Abstract Platformer** - 简洁几何

### 2. OpenGameArt（游戏美术社区）
- 🔗 https://opengameart.org/art-search-advanced?keys=cyberpunk
- 搜索: "cyberpunk", "sci-fi", "neon", "grid"
- 筛选: Textures, CC0/CC-BY

### 3. Quaternius（Low Poly 专家）
- 🔗 https://quaternius.com/index.html
- **Ultimate Low Poly Dungeon** 包含简洁材质
- 风格化，适合小游戏

### 4. itch.io Game Assets
- 🔗 https://itch.io/game-assets/free/tag-textures
- 标签: cyberpunk, sci-fi, low-poly
- 大量独立开发者的游戏素材

### 5. 自制简单纹理（5分钟搞定）

用任意图像编辑器创建：

**网格纹理**（512x512）：
- 黑色背景 #020308
- 青色线条 #00FFFF，2px 粗细
- 每 64px 画一条横线和竖线
- 导出 PNG

**六边形瓷砖**：
- 使用在线工具: https://www.pycheung.com/checker/
- 或 Blender Generate > Voronoi Texture

## 📦 具体推荐材质

### 地板材质

**选项 1: 网格地板**
```
深色底 + 发光网格线
实现: 纯色材质 + Shader 绘制网格
或下载: Kenney Prototype Textures
```

**选项 2: 六边形瓷砖**
```
搜索: "hexagon tile seamless" 
平台: OpenGameArt, itch.io
分辨率: 512x512 足够
```

**选项 3: 纯镜面地板**
```gdscript
# 不用纹理，纯反光
floor_mat.metallic = 1.0
floor_mat.roughness = 0.1
# 反射霓虹灯光
```

### 墙壁材质

**选项 1: 扫描线墙壁**
```
水平扫描线 + 深色背景
512x512 PNG
青色/品红扫描线
```

**选项 2: 电路板图案**
```
搜索: "circuit board seamless low res"
平台: itch.io, OpenGameArt
```

**选项 3: 纯色 + Emission 条纹**
```gdscript
# Shader 绘制发光条纹
shader_type spatial;
uniform vec3 line_color : source_color = vec3(0.0, 1.0, 1.0);
void fragment() {
    float line = step(0.95, fract(UV.y * 20.0));
    EMISSION = line_color * line * 2.0;
}
```

## 🛠️ 快速实现步骤

### 第一步：创建基础材质（不用纹理）

```gdscript
# tools/create_basic_materials.gd
extends SceneTree

func _init():
    # 地板材质 - 深色镜面
    var floor_mat = StandardMaterial3D.new()
    floor_mat.albedo_color = Color(0.05, 0.08, 0.12, 1.0)
    floor_mat.metallic = 0.9
    floor_mat.roughness = 0.2
    floor_mat.emission_enabled = true
    floor_mat.emission = Color(0.0, 0.15, 0.2, 1.0)
    floor_mat.emission_energy_multiplier = 0.3
    
    ResourceSaver.save(floor_mat, "res://assets/materials/floor_mirror.tres")
    print("✓ 地板材质: floor_mirror.tres")
    
    # 墙壁材质 - 深色哑光
    var wall_mat = StandardMaterial3D.new()
    wall_mat.albedo_color = Color(0.03, 0.05, 0.08, 1.0)
    wall_mat.metallic = 0.0
    wall_mat.roughness = 0.95
    
    ResourceSaver.save(wall_mat, "res://assets/materials/wall_dark.tres")
    print("✓ 墙壁材质: wall_dark.tres")
    
    # 霓虹发光材质 - 青色
    var neon_cyan_mat = StandardMaterial3D.new()
    neon_cyan_mat.albedo_color = Color(0.0, 0.3, 0.35, 1.0)
    neon_cyan_mat.emission_enabled = true
    neon_cyan_mat.emission = Color(0.0, 1.0, 1.0, 1.0)
    neon_cyan_mat.emission_energy_multiplier = 3.0
    
    ResourceSaver.save(neon_cyan_mat, "res://assets/materials/neon_cyan.tres")
    print("✓ 霓虹材质: neon_cyan.tres")
    
    # 霓虹发光材质 - 品红
    var neon_magenta_mat = StandardMaterial3D.new()
    neon_magenta_mat.albedo_color = Color(0.35, 0.0, 0.3, 1.0)
    neon_magenta_mat.emission_enabled = true
    neon_magenta_mat.emission = Color(1.0, 0.0, 1.0, 1.0)
    neon_magenta_mat.emission_energy_multiplier = 3.0
    
    ResourceSaver.save(neon_magenta_mat, "res://assets/materials/neon_magenta.tres")
    print("✓ 霓虹材质: neon_magenta.tres")
    
    print("\n已创建 4 个基础材质到 assets/materials/")
    print("可以直接在场景中使用")
    
    quit()
```

运行：
```powershell
godot --headless --script tools/create_basic_materials.gd
```

### 第二步：（可选）添加简单网格 Shader

```gdscript
# assets/shaders/grid_floor.gdshader
shader_type spatial;

uniform vec3 grid_color : source_color = vec3(0.0, 1.0, 1.0);
uniform float grid_scale : hint_range(1.0, 50.0) = 10.0;
uniform float line_width : hint_range(0.01, 0.2) = 0.05;

void fragment() {
    vec2 grid_uv = UV * grid_scale;
    vec2 grid = abs(fract(grid_uv - 0.5) - 0.5) / fwidth(grid_uv);
    float line = min(grid.x, grid.y);
    float grid_mask = 1.0 - min(line, 1.0);
    
    ALBEDO = vec3(0.05, 0.08, 0.12);
    EMISSION = grid_color * grid_mask * 0.5;
    METALLIC = 0.8;
    ROUGHNESS = 0.3;
}
```

应用到地板：
```gdscript
var floor_shader_mat = ShaderMaterial.new()
floor_shader_mat.shader = preload("res://assets/shaders/grid_floor.gdshader")
floor_mesh.material_override = floor_shader_mat
```

## ⚡ 性能对比

| 方案 | Draw Calls | 内存占用 | 加载时间 | 适配性 |
|-----|-----------|---------|---------|-------|
| 纯色材质 | 最少 | <1 MB | 瞬间 | ✓✓✓ |
| 512x512 纹理 | 少 | ~5 MB | <1s | ✓✓✓ |
| 1024x1024 纹理 | 中 | ~10 MB | 1-2s | ✓✓ |
| 4K PBR 写实 | 多 | ~50 MB | 5-10s | ✓ |

**3D 小游戏推荐**: 纯色 + Shader 或 512x512 简单纹理

## 🎯 总结

### ❌ 不推荐（之前的方案）
- Poly Haven 4K 写实 PBR 材质
- 高分辨率混凝土/金属纹理
- 复杂的物理材质

### ✅ 推荐（适合小游戏）
1. **纯色材质** - 立即可用，0 下载
2. **Shader 网格/扫描线** - 程序化，轻量
3. **512px 简单纹理** - Kenney/OpenGameArt
4. **风格化几何图案** - 六边形/电路板

### 立即行动

我可以现在帮你：

1. **运行脚本创建 4 个基础材质**（纯色，0 下载）
2. **创建网格地板 Shader**（发光网格线）
3. **提供 Kenney/itch.io 具体下载链接**
4. **或者你想先看看现有场景，评估是否需要纹理**

你想选哪个？
