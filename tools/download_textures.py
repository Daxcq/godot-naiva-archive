"""
自动下载 Poly Haven 和 ambientCG 材质的脚本
适用于霓虹赛博朋克档案馆项目
"""

import os
import sys
import requests
import zipfile
from pathlib import Path
from typing import Dict, List
import json

# 项目根目录
PROJECT_ROOT = Path(__file__).parent.parent
RAW_TEXTURES_DIR = PROJECT_ROOT.parent / "raw_textures"
ASSETS_TEXTURES_DIR = PROJECT_ROOT / "assets" / "textures"

# Poly Haven 材质列表 (使用实际存在的资源 ID)
POLY_HAVEN_TEXTURES = [
    {
        "name": "concrete_floor",
        "poly_haven_id": "concrete_floor_02",
        "resolution": "4k",
        "type": "floor"
    },
    {
        "name": "rusty_metal",
        "poly_haven_id": "rusty_metal_02",
        "resolution": "4k",
        "type": "wall"
    },
    {
        "name": "metal_plates",
        "poly_haven_id": "metal_plates",
        "resolution": "4k",
        "type": "wall"
    },
    {
        "name": "concrete_wall",
        "poly_haven_id": "concrete_wall_008",
        "resolution": "4k",
        "type": "wall"
    }
]

# ambientCG 材质列表
AMBIENTCG_TEXTURES = [
    {
        "name": "concrete_wall_023",
        "ambientcg_id": "Concrete023",
        "resolution": "4K",
        "type": "wall"
    },
    {
        "name": "metal_panels_001",
        "ambientcg_id": "Metal034",
        "resolution": "4K",
        "type": "wall"
    }
]


class TextureDownloader:
    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        })

    def download_poly_haven_texture(self, texture_info: Dict) -> bool:
        """下载 Poly Haven 材质"""
        asset_id = texture_info["poly_haven_id"]
        resolution = texture_info["resolution"]
        name = texture_info["name"]

        print(f"\n下载 Poly Haven 材质: {name} ({asset_id})")

        # Poly Haven API endpoint
        api_url = f"https://api.polyhaven.com/files/{asset_id}"

        try:
            # 获取下载链接
            print(f"  获取材质信息...")
            response = self.session.get(api_url)
            response.raise_for_status()
            data = response.json()

            # 查找 zip 包下载链接
            if "Textures" not in data:
                print(f"  ❌ 未找到材质数据")
                return False

            textures = data["Textures"]

            # 查找指定分辨率的 zip
            zip_url = None
            for res_key, res_data in textures.items():
                if resolution in res_key.lower():
                    if "zip" in res_data:
                        zip_url = res_data["zip"]["url"]
                        break

            if not zip_url:
                print(f"  ⚠️  未找到 {resolution} 分辨率的 zip 包，尝试其他分辨率...")
                # 尝试任意可用的 zip
                for res_data in textures.values():
                    if isinstance(res_data, dict) and "zip" in res_data:
                        zip_url = res_data["zip"]["url"]
                        break

            if not zip_url:
                print(f"  ❌ 无法找到下载链接")
                return False

            # 创建保存目录
            save_dir = RAW_TEXTURES_DIR / "poly_haven" / name
            save_dir.mkdir(parents=True, exist_ok=True)

            zip_path = save_dir / f"{name}.zip"

            # 下载 zip
            print(f"  下载材质包...")
            print(f"  URL: {zip_url}")

            response = self.session.get(zip_url, stream=True)
            response.raise_for_status()

            total_size = int(response.headers.get('content-length', 0))
            downloaded = 0

            with open(zip_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
                        downloaded += len(chunk)
                        if total_size > 0:
                            progress = (downloaded / total_size) * 100
                            print(f"\r  进度: {progress:.1f}%", end='')

            print(f"\n  解压材质包...")
            with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                zip_ref.extractall(save_dir)

            # 删除 zip 文件
            zip_path.unlink()

            print(f"  ✅ 下载完成: {save_dir}")

            # 保存元数据
            metadata = {
                "source": "poly_haven",
                "asset_id": asset_id,
                "resolution": resolution,
                "type": texture_info["type"],
                "download_url": zip_url
            }

            with open(save_dir / "metadata.json", 'w', encoding='utf-8') as f:
                json.dump(metadata, f, indent=2, ensure_ascii=False)

            return True

        except Exception as e:
            print(f"  ❌ 下载失败: {e}")
            return False

    def download_ambientcg_texture(self, texture_info: Dict) -> bool:
        """下载 ambientCG 材质"""
        asset_id = texture_info["ambientcg_id"]
        resolution = texture_info["resolution"]
        name = texture_info["name"]

        print(f"\n下载 ambientCG 材质: {name} ({asset_id})")

        # ambientCG 下载 URL 格式
        base_url = f"https://ambientcg.com/get?file={asset_id}_{resolution}-PNG.zip"

        try:
            # 创建保存目录
            save_dir = RAW_TEXTURES_DIR / "ambientcg" / name
            save_dir.mkdir(parents=True, exist_ok=True)

            zip_path = save_dir / f"{name}.zip"

            print(f"  下载材质包...")
            print(f"  URL: {base_url}")

            response = self.session.get(base_url, stream=True, allow_redirects=True)
            response.raise_for_status()

            total_size = int(response.headers.get('content-length', 0))
            downloaded = 0

            with open(zip_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
                        downloaded += len(chunk)
                        if total_size > 0:
                            progress = (downloaded / total_size) * 100
                            print(f"\r  进度: {progress:.1f}%", end='')

            print(f"\n  解压材质包...")
            with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                zip_ref.extractall(save_dir)

            # 删除 zip 文件
            zip_path.unlink()

            print(f"  ✅ 下载完成: {save_dir}")

            # 保存元数据
            metadata = {
                "source": "ambientcg",
                "asset_id": asset_id,
                "resolution": resolution,
                "type": texture_info["type"],
                "download_url": base_url
            }

            with open(save_dir / "metadata.json", 'w', encoding='utf-8') as f:
                json.dump(metadata, f, indent=2, ensure_ascii=False)

            return True

        except Exception as e:
            print(f"  ❌ 下载失败: {e}")
            return False

    def run(self):
        """执行下载流程"""
        print("=" * 60)
        print("材质自动下载工具")
        print("=" * 60)

        # 创建目录
        RAW_TEXTURES_DIR.mkdir(parents=True, exist_ok=True)

        results = {
            "poly_haven": {"success": [], "failed": []},
            "ambientcg": {"success": [], "failed": []}
        }

        # 下载 Poly Haven 材质
        print("\n【阶段 1/2】下载 Poly Haven 材质")
        print("-" * 60)
        for texture in POLY_HAVEN_TEXTURES:
            success = self.download_poly_haven_texture(texture)
            if success:
                results["poly_haven"]["success"].append(texture["name"])
            else:
                results["poly_haven"]["failed"].append(texture["name"])

        # 下载 ambientCG 材质
        print("\n【阶段 2/2】下载 ambientCG 材质")
        print("-" * 60)
        for texture in AMBIENTCG_TEXTURES:
            success = self.download_ambientcg_texture(texture)
            if success:
                results["ambientcg"]["success"].append(texture["name"])
            else:
                results["ambientcg"]["failed"].append(texture["name"])

        # 打印总结
        print("\n" + "=" * 60)
        print("下载完成")
        print("=" * 60)

        total_success = len(results["poly_haven"]["success"]) + len(results["ambientcg"]["success"])
        total_failed = len(results["poly_haven"]["failed"]) + len(results["ambientcg"]["failed"])

        print(f"\n✅ 成功: {total_success} 个材质")
        print(f"❌ 失败: {total_failed} 个材质")

        if results["poly_haven"]["failed"] or results["ambientcg"]["failed"]:
            print("\n失败的材质:")
            for name in results["poly_haven"]["failed"]:
                print(f"  - Poly Haven: {name}")
            for name in results["ambientcg"]["failed"]:
                print(f"  - ambientCG: {name}")

        print(f"\n材质保存位置: {RAW_TEXTURES_DIR}")
        print("\n下一步:")
        print("  1. 运行 organize_textures.py 整理材质到项目目录")
        print("  2. 运行 blender_process_materials.py 在 Blender 中处理材质")
        print("  3. 导入到 Godot")

        return total_failed == 0


if __name__ == "__main__":
    downloader = TextureDownloader()
    success = downloader.run()
    sys.exit(0 if success else 1)
