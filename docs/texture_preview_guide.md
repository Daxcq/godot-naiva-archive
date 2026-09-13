# 纹理预览使用说明

## 🎨 查看处理后的纹理效果

### 方法 1：使用纹理预览场景（推荐）

1. **打开 Godot 编辑器**
   - 双击 `project.godot` 或用 Godot 打开项目

2. **打开预览场景**
   - 在 FileSystem 面板中找到 `res://scenes/texture_preview.tscn`
   - 双击打开

3. **运行场景**
   - 按 **F6** 运行当前场景
   - 或点击编辑器顶部的 "▶ 运行场景" 按钮

4. **查看纹理**
   - **Space（空格）**: 下一个纹理
   - **Tab**: 切换地板/墙壁
   - **ESC**: 退出

你会看到：
- 一个 8x8 的大平面显示纹理
- 左上角显示当前纹理名称
- 启用了 Glow 效果，可以看到发光细节

---

### 方法 2：直接在 FileSystem 中预览

1. **打开 Godot 编辑器**

2. **导航到纹理目录**
   - FileSystem 面板 → `res://assets/textures/`
   - `floors/` - 地板纹理
   - `walls/` - 墙壁纹理

3. **点击纹理文件**
   - 点击任意 `.png` 文件
   - 右侧 Inspector 面板会显示预览

4. **查看缩略图**
   - 每个纹理都有一个 `_thumb.png` 缩略图
   - 256x256 大小，方便快速预览

---

### 方法 3：在主场景中应用

1. **打开主场景**
   - `res://main.tscn` 或 `res://scenes/archive_space.tscn`

2. **选择地板或墙壁节点**
   - 在场景树中找到 `MeshInstance3D` 节点

3. **应用材质**
   - 在 Inspector 中找到 `Material Override`
   - 点击 `[empty]` → `New StandardMaterial3D`
   - 展开材质设置
   - `Albedo` → `Texture` → 点击 `[empty]`
   - 选择 `Load` → 浏览到 `res://assets/textures/floors/` 或 `walls/`
   - 选择一个纹理

4. **调整 UV 缩放**（可选）
   - 在材质中找到 `UV1` → `Scale`
   - 设置 `X: 4, Y: 4` 让纹理重复平铺

5. **运行游戏**
   - 按 **F5** 运行主场景
   - 查看实际效果

---

## 📋 已处理的纹理列表

### 地板纹理（floors/）

| 文件名 | 色调 | 特点 | 推荐用途 |
|-------|------|------|---------|
| `floor_scifi_ship.png` | 青色 | 科幻飞船地板，带发光 | 主走廊地板 |
| `floor_scifi_desert.png` | 深蓝 | 沙漠风格，深色调 | 记忆场景地板 |

### 墙壁纹理（walls/）

| 文件名 | 色调 | 特点 | 推荐用途 |
|-------|------|------|---------|
| `wall_scifi_ship_0.png` | 品红 | 飞船墙板，发光线条 | 档案馆主墙壁 |
| `wall_scifi_ship_3.png` | 深蓝 | 简洁墙板 | 侧墙、通道 |
| `wall_scifi_ship_5.png` | 青色 | 科技感强 | 装饰墙、重点区域 |
| `wall_cyberpunk_panel.png` | 品红 | 2K 高质量，细节丰富 | 重要场景、近景墙壁 |

---

## 🎯 推荐搭配

### 档案馆主走廊
- **地板**: `floor_scifi_ship.png` (青色，反光)
- **墙壁**: `wall_scifi_ship_0.png` (品红，对比)
- **效果**: 经典赛博朋克青/品红对比

### 记忆场景：霓虹夜市
- **地板**: `floor_scifi_desert.png` (深蓝)
- **墙壁**: `wall_cyberpunk_panel.png` (品红，高细节)
- **效果**: 深邃夜色 + 霓虹面板

### 记忆场景：深夜街镇
- **地板**: `floor_scifi_ship.png` (青色)
- **墙壁**: `wall_scifi_ship_3.png` (深蓝，简洁)
- **效果**: 统一深色调，宁静氛围

### 记忆场景：数据公园
- **地板**: `floor_scifi_desert.png` (深蓝)
- **墙壁**: `wall_scifi_ship_5.png` (青色，科技)
- **效果**: 数字化、电子感

---

## ⚙️ 材质参数建议

### 地板材质设置
```gdscript
var floor_mat = StandardMaterial3D.new()
floor_mat.albedo_texture = preload("res://assets/textures/floors/floor_scifi_ship.png")
floor_mat.metallic = 0.8        # 高反光
floor_mat.roughness = 0.2       # 接近镜面
floor_mat.uv1_scale = Vector3(4, 4, 1)  # 重复 4x4 次
```

### 墙壁材质设置
```gdscript
var wall_mat = StandardMaterial3D.new()
wall_mat.albedo_texture = preload("res://assets/textures/walls/wall_scifi_ship_0.png")
wall_mat.metallic = 0.3         # 低反光
wall_mat.roughness = 0.6        # 哑光
wall_mat.uv1_scale = Vector3(2, 2, 1)   # 重复 2x2 次
```

---

## 🔧 如果效果不理想

### 纹理太暗
- 在场景中添加更多光源（`OmniLight3D` 或 `SpotLight3D`）
- 或调整 `WorldEnvironment` → `Ambient Light Energy`

### 纹理太亮
- 降低光源的 `Light Energy`
- 或在材质中调整 `Albedo Color` 的亮度

### 看不到发光效果
- 确保场景中有 `WorldEnvironment`
- 启用 `Environment` → `Glow Enabled`
- 调整 `Glow Intensity` 到 1.5-2.0

### 纹理太小/太大
- 调整材质的 `UV1 Scale`
- 增大数值 = 纹理重复更多次（看起来更小）
- 减小数值 = 纹理重复更少次（看起来更大）

### 像素风格太明显
如果你觉得 512x512 升采样后像素感太强，可以：
1. 重新运行处理脚本，将 `target_size=512` 改为 `1024`
2. 或在 Godot 中，纹理的 `.import` 文件中启用 `filter=true`

---

## 下一步

看完效果后，告诉我：
1. ✅ 色调满意吗？（青/品红/深蓝）
2. ✅ 发光效果明显吗？
3. ✅ 像素风格合适吗？还是需要更平滑？
4. 🎨 需要调整哪些参数？

我可以根据你的反馈调整处理脚本并重新生成！
