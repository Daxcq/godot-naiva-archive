"""
整理下载的材质到项目目录
将 raw_textures 中的材质规范化命名并复制到 assets/textures
"""

import os
import shutil
import json
from pathlib import Path
from typing import Dict, List

PROJECT_ROOT = Path(__file__).parent.parent
RAW_TEXTURES_DIR = PROJECT_ROOT.parent / "raw_textures"
ASSETS_TEXTURES_DIR = PROJECT_ROOT / "assets" / "textures"

# 标准化的贴图后缀映射
TEXTURE_MAP_SUFFIXES = {
    # Poly Haven 命名
    "diff": "albedo",
    "col": "albedo",
    "color": "albedo",
    "basecolor": "albedo",
    "nor": "normal",
    "nrm": "normal",
    "normal_gl": "normal",
    "normal_dx": "normal",
    "rough": "roughness",
    "roughness": "roughness",
    "ao": "ao",
    "ambientocclusion": "ao",
    "disp": "displacement",
    "displacement": "displacement",
    "height": "displacement",
    "metal": "metallic",
    "metallic": "metallic",
    "metalness": "metallic",

    # ambientCG 命名
    "Color": "albedo",
    "NormalGL": "normal",
    "NormalDX": "normal",
    "Roughness": "roughness",
    "AmbientOcclusion": "ao",
    "Displacement": "displacement",
    "Metalness": "metallic",
}


class TextureOrganizer:
    def __init__(self):
        self.organized_count = 0

    def detect_map_type(self, filename: str) -> str:
        """从文件名检测贴图类型"""
        name_lower = filename.lower()

        for key, value in TEXTURE_MAP_SUFFIXES.items():
            if key.lower() in name_lower:
                return value

        return "unknown"

    def organize_texture_set(self, source_dir: Path, texture_name: str, texture_type: str):
        """整理一套纹理"""
        print(f"\n整理材质: {texture_name}")

        # 创建目标目录
        target_dir = ASSETS_TEXTURES_DIR / texture_type / texture_name
        target_dir.mkdir(parents=True, exist_ok=True)

        # 查找所有图片文件
        image_files = list(source_dir.glob("*.png")) + \
                     list(source_dir.glob("*.jpg")) + \
                     list(source_dir.glob("*.jpeg")) + \
                     list(source_dir.glob("*.exr"))

        if not image_files:
            print(f"  ⚠️  未找到图片文件")
            return False

        copied_maps = []

        for img_file in image_files:
            # 检测贴图类型
            map_type = self.detect_map_type(img_file.stem)

            if map_type == "unknown":
                print(f"  ⚠️  无法识别贴图类型: {img_file.name}")
                continue

            # 标准化文件名
            new_filename = f"{texture_name}_{map_type}{img_file.suffix}"
            target_path = target_dir / new_filename

            # 复制文件
            shutil.copy2(img_file, target_path)
            copied_maps.append(map_type)
            print(f"  ✅ {map_type}: {target_path.name}")

        if copied_maps:
            # 复制元数据
            metadata_file = source_dir / "metadata.json"
            if metadata_file.exists():
                shutil.copy2(metadata_file, target_dir / "metadata.json")

            # 创建材质信息文件
            material_info = {
                "name": texture_name,
                "type": texture_type,
                "maps": copied_maps,
                "source_dir": str(source_dir),
                "target_dir": str(target_dir)
            }

            with open(target_dir / "material_info.json", 'w', encoding='utf-8') as f:
                json.dump(material_info, f, indent=2, ensure_ascii=False)

            self.organized_count += 1
            return True

        return False

    def run(self):
        """执行整理流程"""
        print("=" * 60)
        print("材质整理工具")
        print("=" * 60)

        if not RAW_TEXTURES_DIR.exists():
            print(f"\n❌ 未找到原始材质目录: {RAW_TEXTURES_DIR}")
            print("请先运行 download_textures.py 下载材质")
            return False

        # 创建 assets/textures 目录结构
        for subdir in ["floors", "walls", "metal"]:
            (ASSETS_TEXTURES_DIR / subdir).mkdir(parents=True, exist_ok=True)

        # 整理 Poly Haven 材质
        poly_haven_dir = RAW_TEXTURES_DIR / "poly_haven"
        if poly_haven_dir.exists():
            print("\n【整理 Poly Haven 材质】")
            print("-" * 60)

            for texture_dir in poly_haven_dir.iterdir():
                if not texture_dir.is_dir():
                    continue

                metadata_file = texture_dir / "metadata.json"
                if metadata_file.exists():
                    with open(metadata_file, 'r', encoding='utf-8') as f:
                        metadata = json.load(f)
                        texture_type = metadata.get("type", "floors")
                else:
                    texture_type = "floors"

                self.organize_texture_set(texture_dir, texture_dir.name, texture_type)

        # 整理 ambientCG 材质
        ambientcg_dir = RAW_TEXTURES_DIR / "ambientcg"
        if ambientcg_dir.exists():
            print("\n【整理 ambientCG 材质】")
            print("-" * 60)

            for texture_dir in ambientcg_dir.iterdir():
                if not texture_dir.is_dir():
                    continue

                metadata_file = texture_dir / "metadata.json"
                if metadata_file.exists():
                    with open(metadata_file, 'r', encoding='utf-8') as f:
                        metadata = json.load(f)
                        texture_type = metadata.get("type", "walls")
                else:
                    texture_type = "walls"

                self.organize_texture_set(texture_dir, texture_dir.name, texture_type)

        # 打印总结
        print("\n" + "=" * 60)
        print("整理完成")
        print("=" * 60)
        print(f"\n✅ 已整理 {self.organized_count} 套材质")
        print(f"\n材质保存位置: {ASSETS_TEXTURES_DIR}")
        print("\n目录结构:")
        print(f"  {ASSETS_TEXTURES_DIR}/")
        print(f"    floors/     - 地板材质")
        print(f"    walls/      - 墙壁材质")
        print(f"    metal/      - 金属材质")

        print("\n下一步:")
        print("  运行 blender_process_materials.py 在 Blender 中创建材质预设")

        return self.organized_count > 0


if __name__ == "__main__":
    organizer = TextureOrganizer()
    success = organizer.run()
    exit(0 if success else 1)
