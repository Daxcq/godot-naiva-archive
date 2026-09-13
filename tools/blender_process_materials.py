"""
Blender 材质处理脚本
自动为下载的 PBR 材质创建 Blender 材质并导出
"""

import bpy
import os
import sys
import json
from pathlib import Path

# 项目路径
ASSETS_TEXTURES_DIR = Path(os.environ.get('GODOT_PROJECT_ROOT', '.')) / "assets" / "textures"
OUTPUT_DIR = Path(os.environ.get('GODOT_PROJECT_ROOT', '.')) / "assets" / "materials"


def clear_scene():
    """清空场景"""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

    # 清理未使用的数据
    for block in bpy.data.meshes:
        bpy.data.meshes.remove(block)
    for block in bpy.data.materials:
        bpy.data.materials.remove(block)
    for block in bpy.data.images:
        bpy.data.images.remove(block)


def create_pbr_material(material_name: str, texture_dir: Path):
    """创建 PBR 材质"""
    print(f"\n创建材质: {material_name}")

    # 创建材质
    mat = bpy.data.materials.new(name=material_name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links

    # 清空默认节点
    nodes.clear()

    # 创建 Principled BSDF
    bsdf = nodes.new(type='ShaderNodeBsdfPrincipled')
    bsdf.location = (0, 0)

    # 创建 Material Output
    output = nodes.new(type='ShaderNodeOutputMaterial')
    output.location = (300, 0)

    # 连接 BSDF 到输出
    links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])

    x_offset = -400
    y_offset = 0
    y_step = 300

    # 加载贴图
    textures = {}
    for img_file in texture_dir.glob("*.png"):
        map_type = None
        if "_albedo" in img_file.name or "_color" in img_file.name:
            map_type = "albedo"
        elif "_normal" in img_file.name:
            map_type = "normal"
        elif "_roughness" in img_file.name:
            map_type = "roughness"
        elif "_metallic" in img_file.name:
            map_type = "metallic"
        elif "_ao" in img_file.name:
            map_type = "ao"
        elif "_displacement" in img_file.name or "_height" in img_file.name:
            map_type = "displacement"

        if map_type:
            textures[map_type] = str(img_file)

    print(f"  找到贴图: {list(textures.keys())}")

    # Albedo / Base Color
    if "albedo" in textures:
        tex_node = nodes.new(type='ShaderNodeTexImage')
        tex_node.image = bpy.data.images.load(textures["albedo"])
        tex_node.image.colorspace_settings.name = 'sRGB'
        tex_node.location = (x_offset, y_offset)
        links.new(tex_node.outputs['Color'], bsdf.inputs['Base Color'])
        print(f"  ✅ Albedo")
        y_offset -= y_step

    # Normal
    if "normal" in textures:
        tex_node = nodes.new(type='ShaderNodeTexImage')
        tex_node.image = bpy.data.images.load(textures["normal"])
        tex_node.image.colorspace_settings.name = 'Non-Color'
        tex_node.location = (x_offset, y_offset)

        normal_map = nodes.new(type='ShaderNodeNormalMap')
        normal_map.location = (x_offset + 200, y_offset)

        links.new(tex_node.outputs['Color'], normal_map.inputs['Color'])
        links.new(normal_map.outputs['Normal'], bsdf.inputs['Normal'])
        print(f"  ✅ Normal")
        y_offset -= y_step

    # Roughness
    if "roughness" in textures:
        tex_node = nodes.new(type='ShaderNodeTexImage')
        tex_node.image = bpy.data.images.load(textures["roughness"])
        tex_node.image.colorspace_settings.name = 'Non-Color'
        tex_node.location = (x_offset, y_offset)
        links.new(tex_node.outputs['Color'], bsdf.inputs['Roughness'])
        print(f"  ✅ Roughness")
        y_offset -= y_step

    # Metallic
    if "metallic" in textures:
        tex_node = nodes.new(type='ShaderNodeTexImage')
        tex_node.image = bpy.data.images.load(textures["metallic"])
        tex_node.image.colorspace_settings.name = 'Non-Color'
        tex_node.location = (x_offset, y_offset)
        links.new(tex_node.outputs['Color'], bsdf.inputs['Metallic'])
        print(f"  ✅ Metallic")
        y_offset -= y_step
    else:
        # 默认非金属
        bsdf.inputs['Metallic'].default_value = 0.0

    # AO (通过 Mix 节点混合到 Base Color)
    if "ao" in textures:
        tex_node = nodes.new(type='ShaderNodeTexImage')
        tex_node.image = bpy.data.images.load(textures["ao"])
        tex_node.image.colorspace_settings.name = 'Non-Color'
        tex_node.location = (x_offset, y_offset)

        # 注意: AO 通常通过 Mix 节点与 Base Color 混合
        # 这里简化处理,直接连接到 BSDF 的 AO 输入(如果有)
        # Godot 会单独处理 AO 贴图
        print(f"  ✅ AO (需在 Godot 中单独设置)")
        y_offset -= y_step

    return mat


def export_material_blend(material_name: str, output_path: Path):
    """导出材质为 .blend 文件"""
    # 创建一个简单的平面应用材质
    bpy.ops.mesh.primitive_plane_add(size=2, location=(0, 0, 0))
    plane = bpy.context.active_object

    # 应用材质
    if plane.data.materials:
        plane.data.materials[0] = bpy.data.materials[material_name]
    else:
        plane.data.materials.append(bpy.data.materials[material_name])

    # 保存 .blend 文件
    bpy.ops.wm.save_as_mainfile(filepath=str(output_path))
    print(f"  导出到: {output_path}")

    # 清理
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()


def process_all_materials():
    """处理所有材质"""
    print("=" * 60)
    print("Blender 材质处理工具")
    print("=" * 60)

    if not ASSETS_TEXTURES_DIR.exists():
        print(f"\n❌ 未找到材质目录: {ASSETS_TEXTURES_DIR}")
        return False

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    processed_count = 0

    # 遍历所有材质目录
    for category_dir in ASSETS_TEXTURES_DIR.iterdir():
        if not category_dir.is_dir():
            continue

        print(f"\n【处理 {category_dir.name} 材质】")
        print("-" * 60)

        for material_dir in category_dir.iterdir():
            if not material_dir.is_dir():
                continue

            material_name = material_dir.name

            # 清空场景
            clear_scene()

            # 创建材质
            try:
                mat = create_pbr_material(material_name, material_dir)

                # 导出 .blend 文件
                output_path = OUTPUT_DIR / f"{material_name}.blend"
                export_material_blend(material_name, output_path)

                # 保存材质信息
                material_info = {
                    "name": material_name,
                    "blend_file": str(output_path),
                    "texture_dir": str(material_dir),
                    "category": category_dir.name
                }

                info_path = OUTPUT_DIR / f"{material_name}_info.json"
                with open(info_path, 'w', encoding='utf-8') as f:
                    json.dump(material_info, f, indent=2, ensure_ascii=False)

                processed_count += 1

            except Exception as e:
                print(f"  ❌ 处理失败: {e}")
                continue

    print("\n" + "=" * 60)
    print("处理完成")
    print("=" * 60)
    print(f"\n✅ 已处理 {processed_count} 个材质")
    print(f"\n材质保存位置: {OUTPUT_DIR}")

    print("\n下一步:")
    print("  在 Godot 中导入这些材质的纹理,并创建 StandardMaterial3D 资源")

    return processed_count > 0


if __name__ == "__main__":
    # 注意: 此脚本需要在 Blender 中运行
    # 用法: blender --background --python blender_process_materials.py

    if not bpy.app.background:
        print("警告: 建议在后台模式运行 Blender")
        print("用法: blender --background --python blender_process_materials.py")

    success = process_all_materials()

    # 如果在后台模式,退出 Blender
    if bpy.app.background:
        sys.exit(0 if success else 1)
