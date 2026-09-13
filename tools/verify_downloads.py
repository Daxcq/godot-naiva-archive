"""
验证下载的材质文件
检查必要的贴图是否存在
"""

import sys
from pathlib import Path

if sys.platform == 'win32':
    import codecs
    sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer, 'strict')

PROJECT_ROOT = Path(__file__).parent.parent
RAW_TEXTURES_DIR = PROJECT_ROOT.parent / "raw_textures" / "poly_haven"

REQUIRED_MAPS = ["diff", "nor", "rough"]  # 最少需要这三个
OPTIONAL_MAPS = ["ao", "disp", "metal"]

def check_texture_dir(texture_dir: Path):
    """检查材质目录"""
    print(f"\n检查: {texture_dir.name}")

    if not texture_dir.exists():
        print(f"  [X] 目录不存在")
        return False

    # 查找图片文件
    images = list(texture_dir.glob("*.png")) + \
             list(texture_dir.glob("*.jpg")) + \
             list(texture_dir.glob("*.jpeg"))

    if not images:
        print(f"  [X] 未找到图片文件")
        return False

    print(f"  [✓] 找到 {len(images)} 个文件")

    # 检查必要贴图
    found_maps = set()
    for img in images:
        name_lower = img.stem.lower()
        for map_type in REQUIRED_MAPS + OPTIONAL_MAPS:
            if map_type in name_lower:
                found_maps.add(map_type)

    missing_required = set(REQUIRED_MAPS) - found_maps

    if missing_required:
        print(f"  [X] 缺少必要贴图: {', '.join(missing_required)}")
        print(f"      (diff=颜色, nor=法线, rough=粗糙度)")
        return False

    print(f"  [✓] 必要贴图完整")

    if found_maps & set(OPTIONAL_MAPS):
        print(f"  [✓] 额外贴图: {', '.join(found_maps & set(OPTIONAL_MAPS))}")

    return True

def main():
    print("=" * 60)
    print("材质下载验证工具")
    print("=" * 60)

    if not RAW_TEXTURES_DIR.exists():
        print(f"\n[X] 下载目录不存在: {RAW_TEXTURES_DIR}")
        print("\n请先创建目录并手动下载材质:")
        print(f"  New-Item -ItemType Directory -Force -Path \"{RAW_TEXTURES_DIR}\"")
        print("\n然后参考 docs/manual_download_guide.md 下载材质")
        return False

    expected_textures = [
        "concrete_floor_02",
        "rusty_metal_02",
        "metal_plates",
        "concrete_wall_008"
    ]

    success_count = 0

    for texture_name in expected_textures:
        texture_dir = RAW_TEXTURES_DIR / texture_name
        if check_texture_dir(texture_dir):
            success_count += 1

    print("\n" + "=" * 60)
    print("验证完成")
    print("=" * 60)
    print(f"\n通过: {success_count}/{len(expected_textures)}")

    if success_count == len(expected_textures):
        print("\n[✓] 所有材质已就绪!")
        print("\n下一步:")
        print("  python tools/organize_textures.py")
        return True
    else:
        print("\n[!] 部分材质缺失或不完整")
        print("\n请参考 docs/manual_download_guide.md 完成下载")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
