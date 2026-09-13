"""
简化版材质下载脚本 - 直接从 Poly Haven 下载
使用 Poly Haven 的直接下载链接
"""

import sys
import os
from pathlib import Path
import urllib.request
import zipfile
import json

# 设置输出编码为 UTF-8
if sys.platform == 'win32':
    import codecs
    sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer, 'strict')
    sys.stderr = codecs.getwriter('utf-8')(sys.stderr.buffer, 'strict')

PROJECT_ROOT = Path(__file__).parent.parent
RAW_TEXTURES_DIR = PROJECT_ROOT.parent / "raw_textures"

# 使用 Poly Haven 实际存在的材质
TEXTURES = [
    {
        "name": "concrete_floor_worn",
        "url": "https://dl.polyhaven.org/file/ph-assets/Textures/zip/4k/concrete_floor_worn_001_4k.zip",
        "type": "floor"
    },
    {
        "name": "rusty_metal",
        "url": "https://dl.polyhaven.org/file/ph-assets/Textures/zip/4k/rusty_metal_02_4k.zip",
        "type": "wall"
    },
    {
        "name": "metal_plates",
        "url": "https://dl.polyhaven.org/file/ph-assets/Textures/zip/4k/metal_plates_4k.zip",
        "type": "wall"
    },
    {
        "name": "concrete_wall",
        "url": "https://dl.polyhaven.org/file/ph-assets/Textures/zip/4k/concrete_wall_006_4k.zip",
        "type": "wall"
    }
]

def download_file(url, save_path):
    """下载文件并显示进度"""
    print(f"  下载中...")

    try:
        def report_progress(block_num, block_size, total_size):
            if total_size > 0:
                downloaded = block_num * block_size
                percent = min(downloaded * 100 / total_size, 100)
                print(f"\r  进度: {percent:.1f}%", end='')

        urllib.request.urlretrieve(url, save_path, report_progress)
        print()  # 换行
        return True
    except Exception as e:
        print(f"\n  下载失败: {e}")
        return False

def extract_zip(zip_path, extract_to):
    """解压 zip 文件"""
    print(f"  解压中...")
    try:
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            zip_ref.extractall(extract_to)
        return True
    except Exception as e:
        print(f"  解压失败: {e}")
        return False

def main():
    print("=" * 60)
    print("材质下载工具")
    print("=" * 60)

    # 创建目录
    RAW_TEXTURES_DIR.mkdir(parents=True, exist_ok=True)

    success_count = 0
    failed_count = 0

    for i, texture in enumerate(TEXTURES, 1):
        print(f"\n[{i}/{len(TEXTURES)}] {texture['name']}")
        print("-" * 60)

        # 创建材质目录
        texture_dir = RAW_TEXTURES_DIR / "poly_haven" / texture['name']
        texture_dir.mkdir(parents=True, exist_ok=True)

        zip_path = texture_dir / f"{texture['name']}.zip"

        # 下载
        if download_file(texture['url'], zip_path):
            # 解压
            if extract_zip(zip_path, texture_dir):
                # 删除 zip
                zip_path.unlink()

                # 保存元数据
                metadata = {
                    "name": texture['name'],
                    "type": texture['type'],
                    "source": "poly_haven",
                    "url": texture['url']
                }

                with open(texture_dir / "metadata.json", 'w', encoding='utf-8') as f:
                    json.dump(metadata, f, indent=2, ensure_ascii=False)

                print(f"  完成: {texture_dir}")
                success_count += 1
            else:
                failed_count += 1
        else:
            failed_count += 1

    # 总结
    print("\n" + "=" * 60)
    print("下载完成")
    print("=" * 60)
    print(f"\n成功: {success_count} 个")
    print(f"失败: {failed_count} 个")
    print(f"\n保存位置: {RAW_TEXTURES_DIR}")

    if success_count > 0:
        print("\n下一步:")
        print("  python tools/organize_textures.py")

    return failed_count == 0

if __name__ == "__main__":
    try:
        success = main()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n\n已取消")
        sys.exit(1)
