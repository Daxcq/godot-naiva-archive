"""
批量处理 Sci-Fi Kit 道具纹理
应用赛博朋克配色（青/品红/深蓝）
"""

import sys
import io
from pathlib import Path
from PIL import Image, ImageEnhance
import numpy as np

# 修复 Windows 控制台编码
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

# 路径配置
PROPS_TEXTURES = Path("D:/桌面/godot-naiva-archive/assets/textures/props")
OUTPUT_DIR = Path("D:/桌面/godot-naiva-archive/assets/textures/props_processed")

# 确保输出目录存在
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# 赛博朋克配色方案（复用之前的成功配置）
COLOR_SCHEMES = {
    "cyan": {
        "hue_shift": 180,
        "saturation": 1.5,
        "brightness": 1.2,
        "glow_color": (0, 255, 255),
    },
    "magenta": {
        "hue_shift": 300,
        "saturation": 1.3,
        "brightness": 1.0,
        "glow_color": (255, 0, 255),
    },
    "blue": {
        "hue_shift": 220,
        "saturation": 1.2,
        "brightness": 0.8,
        "glow_color": (0, 128, 255),
    }
}

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
            # 确保值在 0-255 范围内
            r = max(0, min(255, r))
            g = max(0, min(255, g))
            b = max(0, min(255, b))
            result[y, x] = [r, g, b]

    return Image.fromarray(result.astype('uint8'))

def add_glow_effect(image, glow_color, intensity=0.3):
    """添加发光效果"""
    img_array = np.array(image.convert('RGB'))
    gray = np.mean(img_array, axis=2)

    threshold = 150
    glow_mask = np.clip((gray - threshold) / (255 - threshold), 0, 1)

    glow_layer = np.zeros_like(img_array)
    for i in range(3):
        glow_layer[:, :, i] = glow_color[i] * glow_mask * intensity

    result = np.clip(img_array + glow_layer, 0, 255).astype('uint8')
    return Image.fromarray(result)

def process_texture(input_path, color_scheme_name):
    """处理单个纹理"""
    print(f"处理: {input_path.name}")

    try:
        img = Image.open(input_path)

        # 只处理 BaseColor 纹理
        if "BaseColor" not in input_path.name:
            print(f"  跳过（非 BaseColor）")
            return False

        print(f"  原始尺寸: {img.size}")

        # 应用赛博朋克配色
        color_scheme = COLOR_SCHEMES[color_scheme_name]
        img = apply_cyberpunk_color(img, color_scheme)
        print(f"  ✓ 应用配色: {color_scheme_name}")

        # 添加发光效果
        img = add_glow_effect(img, color_scheme['glow_color'], intensity=0.4)
        print(f"  ✓ 添加发光效果")

        # 保存
        output_path = OUTPUT_DIR / input_path.name
        img.save(output_path, 'PNG')
        print(f"  ✓ 已保存: {output_path.name}")

        return True

    except Exception as e:
        print(f"  ❌ 处理失败: {e}")
        return False

def main():
    print("=" * 60)
    print("Sci-Fi Kit 道具纹理处理工具")
    print("=" * 60)

    # 检查 PIL
    try:
        import PIL
        print(f"✓ PIL/Pillow 版本: {PIL.__version__}")
    except ImportError:
        print("❌ 未安装 Pillow")
        print("请运行: pip install Pillow")
        return False

    # 获取所有 BaseColor 纹理
    textures = list(PROPS_TEXTURES.glob("*BaseColor.png"))

    if not textures:
        print(f"\n❌ 未找到纹理文件")
        print(f"检查路径: {PROPS_TEXTURES}")
        return False

    print(f"\n找到 {len(textures)} 个 BaseColor 纹理")
    print("-" * 60)

    # 分配配色方案
    # Props -> 青色
    # Enemies -> 品红（虽然不用敌人，但纹理可能有用）
    # Guns -> 深蓝（同样不用武器）

    success_count = 0

    for texture_path in textures:
        # 根据文件名选择配色
        if "Props" in texture_path.name:
            scheme = "cyan"
        elif "Enemies" in texture_path.name:
            scheme = "magenta"
        else:
            scheme = "blue"

        if process_texture(texture_path, scheme):
            success_count += 1
        print()

    print("=" * 60)
    print(f"处理完成！成功: {success_count}/{len(textures)}")
    print("=" * 60)
    print(f"\n处理后的纹理保存在: {OUTPUT_DIR}")

    print("\n下一步:")
    print("  1. 在 Godot 中打开项目")
    print("  2. 模型会自动导入（.fbx.import）")
    print("  3. 手动替换模型材质中的纹理为处理后的版本")
    print("  4. 或使用脚本批量更新材质")

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
