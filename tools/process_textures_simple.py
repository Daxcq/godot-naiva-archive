"""
简化版纹理处理脚本 - 不需要 Blender
使用 Python PIL/Pillow 直接处理
"""

import sys
from pathlib import Path
from PIL import Image, ImageEnhance, ImageFilter
import numpy as np

# 路径配置
RAW_TEXTURES = Path("D:/桌面/raw_textures/game_textures")
OUTPUT_DIR = Path("D:/桌面/godot-naiva-archive/assets/textures")

# 确保输出目录存在
(OUTPUT_DIR / "floors").mkdir(parents=True, exist_ok=True)
(OUTPUT_DIR / "walls").mkdir(parents=True, exist_ok=True)

# 赛博朋克配色（HSV 调整）- 提高亮度版本
COLOR_SCHEMES = {
    "cyan_floor": {
        "hue_shift": 180,  # 青色偏移
        "saturation": 1.5,
        "brightness": 1.2,  # 提高亮度 0.4 → 1.2
        "glow_color": (0, 255, 255),  # RGB 青色
    },
    "magenta_wall": {
        "hue_shift": 300,  # 品红偏移
        "saturation": 1.3,
        "brightness": 1.0,  # 提高亮度 0.3 → 1.0
        "glow_color": (255, 0, 255),  # RGB 品红
    },
    "blue_wall": {
        "hue_shift": 220,  # 深蓝偏移
        "saturation": 1.2,
        "brightness": 0.8,  # 提高亮度 0.25 → 0.8
        "glow_color": (0, 128, 255),  # RGB 蓝色
    }
}

def upscale_nearest(image, target_size):
    """使用最近邻插值升采样（保持像素风格）"""
    return image.resize((target_size, target_size), Image.NEAREST)

def rgb_to_hsv(r, g, b):
    """RGB 转 HSV"""
    r, g, b = r/255.0, g/255.0, b/255.0
    max_c = max(r, g, b)
    min_c = min(r, g, b)
    delta = max_c - min_c

    # Hue
    if delta == 0:
        h = 0
    elif max_c == r:
        h = 60 * (((g - b) / delta) % 6)
    elif max_c == g:
        h = 60 * (((b - r) / delta) + 2)
    else:
        h = 60 * (((r - g) / delta) + 4)

    # Saturation
    s = 0 if max_c == 0 else delta / max_c

    # Value
    v = max_c

    return h, s, v

def hsv_to_rgb(h, s, v):
    """HSV 转 RGB"""
    c = v * s
    x = c * (1 - abs((h / 60) % 2 - 1))
    m = v - c

    if 0 <= h < 60:
        r, g, b = c, x, 0
    elif 60 <= h < 120:
        r, g, b = x, c, 0
    elif 120 <= h < 180:
        r, g, b = 0, c, x
    elif 180 <= h < 240:
        r, g, b = 0, x, c
    elif 240 <= h < 300:
        r, g, b = x, 0, c
    else:
        r, g, b = c, 0, x

    r, g, b = (r + m) * 255, (g + m) * 255, (b + m) * 255
    return int(r), int(g), int(b)

def apply_cyberpunk_color(image, color_scheme):
    """应用赛博朋克配色"""
    img_array = np.array(image.convert('RGB'))
    height, width = img_array.shape[:2]
    result = np.zeros_like(img_array)

    hue_shift = color_scheme['hue_shift']
    sat_mult = color_scheme['saturation']
    bright_mult = color_scheme['brightness']

    for y in range(height):
        for x in range(width):
            r, g, b = img_array[y, x]
            h, s, v = rgb_to_hsv(r, g, b)

            # 调整
            h = (h + hue_shift) % 360
            s = min(s * sat_mult, 1.0)
            v = v * bright_mult

            r, g, b = hsv_to_rgb(h, s, v)
            result[y, x] = [r, g, b]

    return Image.fromarray(result.astype('uint8'))

def add_glow_effect(image, glow_color, intensity=0.3):
    """添加发光效果"""
    # 转换为 numpy 数组
    img_array = np.array(image.convert('RGB'))

    # 提取亮度
    gray = np.mean(img_array, axis=2)

    # 创建发光遮罩（只有亮区域发光）
    threshold = 150
    glow_mask = np.clip((gray - threshold) / (255 - threshold), 0, 1)

    # 创建发光层
    glow_layer = np.zeros_like(img_array)
    for i in range(3):
        glow_layer[:, :, i] = glow_color[i] * glow_mask * intensity

    # 混合
    result = np.clip(img_array + glow_layer, 0, 255).astype('uint8')

    return Image.fromarray(result)

def process_texture(input_path, output_name, color_scheme_name, texture_type):
    """处理单个纹理"""
    print(f"\n处理: {input_path.name}")

    # 加载图片
    img = Image.open(input_path)
    original_size = img.size

    print(f"  原始尺寸: {original_size}")

    # 升采样小图片
    if img.width <= 64:
        img = upscale_nearest(img, 512)
        print(f"  升采样到: 512x512 (像素风格)")

    # 应用赛博朋克配色
    color_scheme = COLOR_SCHEMES[color_scheme_name]
    img = apply_cyberpunk_color(img, color_scheme)
    print(f"  ✓ 应用配色: {color_scheme_name}")

    # 添加发光效果
    img = add_glow_effect(img, color_scheme['glow_color'], intensity=0.4)
    print(f"  ✓ 添加发光效果")

    # 保存
    output_path = OUTPUT_DIR / texture_type / f"{output_name}.png"
    img.save(output_path, 'PNG')
    print(f"  ✓ 已保存: {output_path}")

    # 创建缩略图预览
    thumb = img.copy()
    thumb.thumbnail((256, 256), Image.NEAREST)
    thumb_path = OUTPUT_DIR / texture_type / f"{output_name}_thumb.png"
    thumb.save(thumb_path, 'PNG')

def main():
    print("=" * 60)
    print("赛博朋克纹理处理工具（简化版）")
    print("=" * 60)

    # 检查 PIL
    try:
        import PIL
        print(f"✓ PIL/Pillow 版本: {PIL.__version__}")
    except ImportError:
        print("❌ 未安装 Pillow")
        print("请运行: pip install Pillow")
        return False

    # 处理地板纹理
    floor_files = [
        ("scifi/floor_ship.png", "floor_scifi_ship", "cyan_floor"),
        ("scifi/floor_desert.png", "floor_scifi_desert", "blue_wall"),
    ]

    print("\n【处理地板纹理】")
    print("-" * 60)
    for file_name, output_name, scheme in floor_files:
        input_path = RAW_TEXTURES / file_name
        if input_path.exists():
            try:
                process_texture(input_path, output_name, scheme, "floors")
            except Exception as e:
                print(f"  ❌ 处理失败: {e}")

    # 处理墙壁纹理
    wall_files = [
        ("scifi/wall_ship_0.png", "wall_scifi_ship_0", "magenta_wall"),
        ("scifi/wall_ship_3.png", "wall_scifi_ship_3", "blue_wall"),
        ("scifi/wall_ship_5.png", "wall_scifi_ship_5", "cyan_floor"),
        ("cyberpunk_panel_8k.png", "wall_cyberpunk_panel", "magenta_wall"),
    ]

    print("\n【处理墙壁纹理】")
    print("-" * 60)
    for file_name, output_name, scheme in wall_files:
        input_path = RAW_TEXTURES / file_name
        if input_path.exists():
            try:
                process_texture(input_path, output_name, scheme, "walls")
            except Exception as e:
                print(f"  ❌ 处理失败: {e}")

    print("\n" + "=" * 60)
    print("处理完成!")
    print("=" * 60)
    print(f"\n纹理已保存到: {OUTPUT_DIR}")
    print("\n文件列表:")
    for category in ["floors", "walls"]:
        category_path = OUTPUT_DIR / category
        if category_path.exists():
            files = list(category_path.glob("*.png"))
            if files:
                print(f"\n  {category}/ ({len(files)} 个文件)")
                for f in sorted(files):
                    if not f.name.endswith("_thumb.png"):
                        print(f"    - {f.name}")

    print("\n下一步:")
    print("  1. 在 Godot 中打开项目")
    print("  2. 纹理会自动生成 .import 文件")
    print("  3. 在场景中应用到 MeshInstance3D")

    return True

if __name__ == "__main__":
    try:
        success = main()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n\n已取消")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ 错误: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
