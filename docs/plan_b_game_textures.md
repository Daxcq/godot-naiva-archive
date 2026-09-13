# 方案 B：精选游戏纹理 + Blender 定制处理

适合 3D 小游戏的赛博朋克材质 - 有质感但不写实

## 🎯 精选资源推荐（512-1024 分辨率）

### 地板材质

#### 选项 1：科幻金属网格地板
- **来源**: OpenGameArt
- **链接**: https://opengameart.org/content/scifi-floor-texture
- **描述**: 金属网格地板，已经是深色调
- **分辨率**: 1024x1024
- **许可**: CC0
- **适合度**: ⭐⭐⭐⭐⭐
- **处理**: 调成青蓝色，添加发光网格线

#### 选项 2：六边形科幻地板
- **来源**: itch.io
- **链接**: https://kronbits.itch.io/freebie-hex-tiles
- **描述**: 六边形瓷砖地板纹理包
- **分辨率**: 512x512
- **许可**: CC0
- **适合度**: ⭐⭐⭐⭐⭐
- **处理**: 改色调，添加边缘发光

#### 选项 3：电路板地板
- **来源**: OpenGameArt  
- **搜索**: "circuit board texture seamless"
- **描述**: 电路板图案，科技感强
- **分辨率**: 512-1024
- **适合度**: ⭐⭐⭐⭐
- **处理**: 深色化，添加霓虹线条

### 墙壁材质

#### 选项 1：科幻墙板
- **来源**: itch.io
- **链接**: https://fertile-soil-productions.itch.io/modular-scifi-base-grey-boxed
- **描述**: 模块化科幻墙板纹理
- **分辨率**: 1024x1024
- **许可**: CC0
- **适合度**: ⭐⭐⭐⭐⭐
- **处理**: 深色化，添加青/品红灯条

#### 选项 2：工业面板
- **来源**: OpenGameArt
- **搜索**: "industrial panel texture"
- **描述**: 工业风格墙面板
- **分辨率**: 1024x1024
- **适合度**: ⭐⭐⭐⭐
- **处理**: 调色到深蓝，添加磨损

#### 选项 3：扫描线墙壁（自制）
- **工具**: 任意图像编辑器
- **尺寸**: 512x512
- **颜色**: 深色底 + 青色横线
- **适合度**: ⭐⭐⭐⭐
- **耗时**: 5 分钟

### 备选平台（如果上面链接失效）

1. **Kenney Prototype Textures**
   - 链接: https://kenney.nl/assets/prototype-textures
   - 完全免费 CC0
   - 适合快速原型

2. **itch.io 搜索**
   - https://itch.io/game-assets/free/tag-textures
   - 标签: cyberpunk, sci-fi, neon
   - 大量独立开发者素材

3. **Quaternius Low Poly Textures**
   - https://quaternius.com/
   - Ultimate Low Poly 系列
   - 风格化，适合小游戏

## 🎨 Blender 处理流程

### 第一步：准备工作

1. **下载纹理**
   - 保存到: `D:\桌面\raw_textures\game_textures\`
   - 解压（如果是 ZIP）

2. **打开 Blender**
   - 新建项目
   - 切换到 Shading 工作区

### 第二步：调色到赛博朋克色调

#### 调色配方

**地板 - 深青蓝调**
```
原色 → HSV Adjustment:
- Hue: 向青色偏移 (+180° 到 +200°)
- Saturation: 降低到 0.3-0.5
- Value: 降低到 0.1-0.2（深色化）
```

**墙壁 - 深紫蓝调**
```
原色 → HSV Adjustment:
- Hue: 向紫色偏移 (+240° 到 +260°)
- Saturation: 0.2-0.4
- Value: 0.05-0.15（更深）
```

#### Blender 节点设置

```
Image Texture 
    ↓
Hue/Saturation/Value Node
    ↓
ColorRamp (可选，增强对比)
    ↓
Principled BSDF
```

### 第三步：添加发光元素（避免太干净）

#### 方法 A：在 Blender 中添加

1. **复制纹理节点**
2. **添加 ColorRamp**
   - 只提取高光区域
   - 黑色: 0.0, 白色: 0.8
3. **连接到 Emission**
   - Emission Color: 青色 (0, 1, 1) 或品红 (1, 0, 1)
   - Emission Strength: 2.0-5.0

```
Image Texture
    ↓
ColorRamp (提取高光)
    ↓
Color Ramp (映射到霓虹色)
    ↓
Emission (发光)
```

#### 方法 B：在图像编辑器中添加

**Photoshop/GIMP 流程**:
1. 打开纹理
2. 新建图层
3. 用画笔工具绘制发光线条:
   - 颜色: #00FFFF (青) 或 #FF00FF (品红)
   - 硬度: 0-50%
   - 不透明度: 60-80%
4. 图层模式: Add / Screen
5. 导出为 PNG

### 第四步：添加"不完美"（避免 AI 味）

**增加真实感的技巧**:

1. **磨损和刮痕**
   - 用 Noise Texture 驱动
   - 混合到 Roughness
   - 局部增加粗糙度

2. **污渍**
   - 添加第二层 Image Texture
   - 使用 Grunge 贴图
   - Mix Mode: Overlay, 不透明度 20-30%

3. **不均匀发光**
   - Emission 不要纯色
   - 加入微弱噪声
   - 一些区域更亮，制造"闪烁"感

4. **边缘变化**
   - 不要完美平铺
   - 边缘稍微模糊
   - 或添加细微的接缝

### 第五步：导出设置

**导出为 PNG**:
- 分辨率: 512x512 或 1024x1024（不要降低）
- 格式: PNG
- 色彩空间: sRGB
- 位深度: 8-bit

**命名规范**:
```
floor_scifi_albedo.png
floor_scifi_emission.png
wall_panel_albedo.png
wall_panel_emission.png
```

## 🚀 快速处理脚本（Blender Python）

保存为 `blender_color_adjust.py`，在 Blender Scripting 工作区运行:

```python
import bpy

# 调色到青蓝色（地板）
def create_cyberpunk_floor_material(image_path, material_name):
    mat = bpy.data.materials.new(name=material_name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    
    nodes.clear()
    
    # 图像纹理
    tex_node = nodes.new(type='ShaderNodeTexImage')
    tex_node.image = bpy.data.images.load(image_path)
    tex_node.location = (-600, 0)
    
    # HSV 调整 - 青蓝色调
    hsv_node = nodes.new(type='ShaderNodeHueSaturation')
    hsv_node.inputs['Hue'].default_value = 0.55  # 青色偏移
    hsv_node.inputs['Saturation'].default_value = 0.4  # 降低饱和度
    hsv_node.inputs['Value'].default_value = 0.15  # 深色化
    hsv_node.location = (-400, 0)
    
    # BSDF
    bsdf = nodes.new(type='ShaderNodeBsdfPrincipled')
    bsdf.inputs['Metallic'].default_value = 0.8
    bsdf.inputs['Roughness'].default_value = 0.3
    bsdf.location = (-200, 0)
    
    # 输出
    output = nodes.new(type='ShaderNodeOutputMaterial')
    output.location = (0, 0)
    
    # 连接
    links.new(tex_node.outputs['Color'], hsv_node.inputs['Color'])
    links.new(hsv_node.outputs['Color'], bsdf.inputs['Base Color'])
    links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])
    
    # 发光效果
    color_ramp = nodes.new(type='ShaderNodeValToRGB')
    color_ramp.location = (-400, -300)
    color_ramp.color_ramp.elements[0].position = 0.7
    color_ramp.color_ramp.elements[1].position = 1.0
    
    links.new(tex_node.outputs['Color'], color_ramp.inputs['Fac'])
    
    emission_color = nodes.new(type='ShaderNodeRGB')
    emission_color.outputs[0].default_value = (0, 1, 1, 1)  # 青色
    emission_color.location = (-200, -300)
    
    mix_shader = nodes.new(type='ShaderNodeMixShader')
    mix_shader.location = (0, -150)
    
    emission = nodes.new(type='ShaderNodeEmission')
    emission.inputs['Strength'].default_value = 3.0
    emission.location = (-200, -450)
    
    links.new(emission_color.outputs[0], emission.inputs['Color'])
    links.new(color_ramp.outputs['Color'], mix_shader.inputs['Fac'])
    links.new(bsdf.outputs['BSDF'], mix_shader.inputs[1])
    links.new(emission.outputs['Emission'], mix_shader.inputs[2])
    links.new(mix_shader.outputs['Shader'], output.inputs['Surface'])
    
    return mat

# 使用示例
image_path = "D:/桌面/raw_textures/game_textures/floor_texture.png"
material = create_cyberpunk_floor_material(image_path, "CyberpunkFloor")

# 创建预览平面
bpy.ops.mesh.primitive_plane_add(size=4)
plane = bpy.context.active_object
if plane.data.materials:
    plane.data.materials[0] = material
else:
    plane.data.materials.append(material)

print("材质已创建并应用到平面")
```

## 📊 处理时间估算

| 步骤 | 时间 | 说明 |
|-----|------|------|
| 下载纹理 | 10-20 分钟 | 4-6 个纹理 |
| Blender 调色 | 20-30 分钟 | 每个纹理 5 分钟 |
| 添加发光 | 15-20 分钟 | Emission 节点 |
| 添加磨损 | 10-15 分钟 | 可选 |
| 导出 | 5 分钟 | 批量导出 |
| **总计** | **1-2 小时** | 首次，熟练后 30 分钟 |

## ✅ 最终检查清单

导入 Godot 前检查:

- [ ] 颜色符合青/品红/深蓝色调
- [ ] 有发光元素（Emission）
- [ ] 有细节变化（不是纯色）
- [ ] 文件大小合理（< 2 MB/张）
- [ ] 命名规范（_albedo, _emission）
- [ ] 512-1024 分辨率

## 🎯 期望效果

**最终材质应该有**:
- ✅ 赛博朋克色调（不是自然色）
- ✅ 发光细节（霓虹感）
- ✅ 适度磨损（真实感）
- ✅ 性能友好（< 1024 分辨率）
- ✅ 风格统一（和项目已有的霓虹光匹配）

**避免**:
- ❌ 太干净（AI 生成感）
- ❌ 太写实（照片质感）
- ❌ 颜色太亮（刺眼）
- ❌ 文件太大（> 5 MB）

## 下一步

1. 我给你具体的下载链接
2. 你下载 4-6 个基础纹理
3. 我提供 Blender 脚本帮你批量处理
4. 导入 Godot 并创建材质资源
