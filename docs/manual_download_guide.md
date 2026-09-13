# 材质手动下载指南

由于 Poly Haven 的 API 和直接下载链接可能变化，这里提供手动下载的详细步骤。

## 📥 推荐材质下载列表

访问以下链接，在浏览器中手动下载：

### 1. 混凝土地板
**Concrete Floor 02**
- 🔗 链接: https://polyhaven.com/a/concrete_floor_02
- 📦 下载: 点击 "Download" 按钮
- ⚙️ 设置: Resolution: 4K, Format: PNG, Maps: All
- 💾 保存到: `D:\桌面\raw_textures\poly_haven\concrete_floor_02\`

### 2. 锈蚀金属
**Rusty Metal 02**
- 🔗 链接: https://polyhaven.com/a/rusty_metal_02
- 📦 下载: Resolution: 4K, Format: PNG
- 💾 保存到: `D:\桌面\raw_textures\poly_haven\rusty_metal_02\`

### 3. 金属板
**Metal Plates**
- 🔗 链接: https://polyhaven.com/a/metal_plates
- 📦 下载: Resolution: 4K, Format: PNG
- 💾 保存到: `D:\桌面\raw_textures\poly_haven\metal_plates\`

### 4. 混凝土墙
**Concrete Wall 008**
- 🔗 链接: https://polyhaven.com/a/concrete_wall_008
- 📦 下载: Resolution: 4K, Format: PNG
- 💾 保存到: `D:\桌面\raw_textures\poly_haven\concrete_wall_008\`

## 🎯 快速下载步骤

1. **创建下载目录**
```powershell
New-Item -ItemType Directory -Force -Path "D:\桌面\raw_textures\poly_haven"
```

2. **访问 Poly Haven 网站**
   - 打开浏览器访问 https://polyhaven.com/textures
   - 搜索上面列出的材质名称

3. **下载材质**
   - 点击材质进入详情页
   - 点击右侧的 "Download" 按钮
   - 选择:
     - Resolution: **4K** (4096x4096)
     - Format: **PNG** (或 JPG for Albedo)
     - 点击 **ZIP** 下载完整贴图包

4. **解压文件**
   - 解压下载的 ZIP 文件到对应目录
   - 例如: `concrete_floor_02_4k.zip` 解压到 `D:\桌面\raw_textures\poly_haven\concrete_floor_02\`

## 📂 期望的目录结构

下载并解压后，目录应该是这样的:

```
D:\桌面\raw_textures\
  poly_haven\
    concrete_floor_02\
      concrete_floor_02_diff_4k.png      (或 Color/Albedo)
      concrete_floor_02_nor_gl_4k.png    (Normal)
      concrete_floor_02_rough_4k.png     (Roughness)
      concrete_floor_02_disp_4k.png      (Displacement)
      concrete_floor_02_ao_4k.png        (AO)
    rusty_metal_02\
      rusty_metal_02_diff_4k.png
      rusty_metal_02_nor_gl_4k.png
      rusty_metal_02_rough_4k.png
      ...
    metal_plates\
      ...
    concrete_wall_008\
      ...
```

## ✅ 验证下载

下载完成后，运行验证脚本检查文件:

```powershell
cd "D:\桌面\godot-naiva-archive"
python tools/verify_downloads.py
```

## 🔄 下一步

下载完成后，运行整理脚本:

```powershell
python tools/organize_textures.py
```

这会将材质整理到项目的 `assets/textures/` 目录。

## 💡 备选方案

如果 Poly Haven 下载困难，可以使用这些备选平台:

### ambientCG (推荐备选)
- 🔗 https://ambientcg.com/
- 搜索: "Concrete", "Metal"
- 下载格式: PNG, 4K
- 完全免费 CC0

### 3dtextures.me
- 🔗 https://3dtextures.me/
- 分类清晰
- CC0 授权

### ShareTextures
- 🔗 https://www.sharetextures.com/
- 最高 4K
- CC0 授权

## 🆘 遇到问题?

### 问题: Poly Haven 需要登录?
不需要登录即可下载免费材质。如果提示登录，直接关闭弹窗即可继续下载。

### 问题: 下载速度慢?
- Poly Haven 服务器在国外，可能较慢
- 可以使用备选平台 ambientCG 或 3dtextures.me
- 或者使用下载管理器(如 IDM, Free Download Manager)

### 问题: 找不到具体的材质?
如果具体的材质 ID 不存在(如 concrete_floor_02)，在 Poly Haven 上搜索类似的:
- 搜索 "concrete floor"
- 选择任意一个工业/磨损风格的混凝土地板
- 下载即可

材质的具体名称不重要，重要的是**风格匹配**(赛博朋克/工业风)和**质量**(4K PBR 贴图)。
