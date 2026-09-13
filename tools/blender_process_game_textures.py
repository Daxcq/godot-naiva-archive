"""
Blender 批处理脚本 - 处理下载的游戏纹理
适用于 64x64 像素艺术和 2K 面板纹理
"""

import bpy
import os
from pathlib import Path

# 路径配置
RAW_TEXTURES = Path("D:/桌面/raw_textures/game_textures")
OUTPUT_DIR = Path("D:/桌面/godot-naiva-archive/assets/textures")

# 确保输出目录存在
(OUTPUT_DIR / "floors").mkdir(parents=True, exist_ok=True)
(OUTPUT_DIR / "walls").mkdir(parents=True, exist_ok=True)

# 赛博朋克配色方案
COLOR_SCHEMES = {
    "cyan_floor": {
        "hue": 0.52,  # 青色
        "saturation": 0.6,
        "value": 0.15,  # 深色
        "emission_color": (0, 1, 1),  # 青色发光
        "emission_strength": 0.5
    },
    "magenta_wall": {
        "hue": 0.83,  # 品红
        "saturation": 0.5,
        "value": 0.12,
        "emission_color": (1, 0, 1),
        "emission_strength": 0.3
    },
    "blue_wall": {
        "hue": 0.6,  # 深蓝
        "saturation": 0.4,
        "value": 0.08,
        "emission_color": (0, 0.5, 1),
        "emission_strength": 0.2
    }
}

def clear_scene():
    """清空场景"""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

    for block in bpy.data.meshes:
        bpy.data.meshes.remove(block)
    for block in bpy.data.materials:
        bpy.data.materials.remove(block)
    for block in bpy.data.images:
        bpy.data.images.remove(block)

def upscale_texture(image_path, output_path, target_size=512):
    """
    升采样纹理（64x64 → 512x512）
    保持像素艺术风格，使用最近邻插值
    """
    img = bpy.data.images.load(str(image_path))

    # 设置为最近邻插值（保持像素风格）
    img.interpolation = 'Closest'

    # 保存原始尺寸
    original_size = (img.size[0], img.size[1])

    # 缩放
    img.scale(target_size, target_size)

    # 保存
    img.filepath_raw = str(output_path)
    img.file_format = 'PNG'
    img.save()

    print(f"  升采样: {original_size} → {target_size}x{target_size}")

    bpy.data.images.remove(img)

def create_cyberpunk_material(image_path, material_name, color_scheme):
    """创建赛博朋克风格材质"""
    mat = bpy.data.materials.new(name=material_name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links

    nodes.clear()

    # 图像纹理
    tex_node = nodes.new(type='ShaderNodeTexImage')
    tex_node.image = bpy.data.images.load(str(image_path))
    tex_node.image.interpolation = 'Closest'  # 像素艺术风格
    tex_node.location = (-800, 200)

    # HSV 调整
    hsv_node = nodes.new(type='ShaderNodeHueSaturation')
    hsv_node.inputs['Hue'].default_value = color_scheme['hue']
    hsv_node.inputs['Saturation'].default_value = color_scheme['saturation']
    hsv_node.inputs['Value'].default_value = color_scheme['value']
    hsv_node.location = (-600, 200)

    # Principled BSDF
    bsdf = nodes.new(type='ShaderNodeBsdfPrincipled')
    bsdf.inputs['Metallic'].default_value = 0.6
    bsdf.inputs['Roughness'].default_value = 0.4
    bsdf.location = (-200, 200)

    # 输出
    output = nodes.new(type='ShaderNodeOutputMaterial')
    output.location = (200, 200)

    # 基本连接
    links.new(tex_node.outputs['Color'], hsv_node.inputs['Color'])
    links.new(hsv_node.outputs['Color'], bsdf.inputs['Base Color'])
    links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])

    # 添加发光效果
    # 提取高光区域
    color_ramp = nodes.new(type='ShaderNodeValToRGB')
    color_ramp.location = (-600, -100)
    color_ramp.color_ramp.elements[0].position = 0.6
    color_ramp.color_ramp.elements[1].position = 0.9

    # RGB 转 BW
    rgb_to_bw = nodes.new(type='ShaderNodeRGBToBW')
    rgb_to_bw.location = (-800, -100)

    links.new(tex_node.outputs['Color'], rgb_to_bw.inputs['Color'])
    links.new(rgb_to_bw.outputs['Val'], color_ramp.inputs['Fac'])

    # 发光颜色
    emission_rgb = nodes.new(type='ShaderNodeRGB')
    emission_rgb.outputs[0].default_value = (*color_scheme['emission_color'], 1)
    emission_rgb.location = (-400, -250)

    # Emission Shader
    emission = nodes.new(type='ShaderNodeEmission')
    emission.inputs['Strength'].default_value = color_scheme['emission_strength']
    emission.location = (-200, -250)

    links.new(emission_rgb.outputs[0], emission.inputs['Color'])

    # Add Shader 混合
    add_shader = nodes.new(type='ShaderNodeAddShader')
    add_shader.location = (0, 0)

    # 使用 ColorRamp 控制混合
    mix_rgb = nodes.new(type='ShaderNodeMixRGB')
    mix_rgb.location = (-400, -100)
    links.new(emission_rgb.outputs[0], mix_rgb.inputs['Color1'])
    links.new(color_ramp.outputs['Color'], mix_rgb.inputs['Fac'])

    links.new(mix_rgb.outputs['Color'], emission.inputs['Color'])
    links.new(bsdf.outputs['BSDF'], add_shader.inputs[0])
    links.new(emission.outputs['Emission'], add_shader.inputs[1])
    links.new(add_shader.outputs['Shader'], output.inputs['Surface'])

    return mat

def render_preview(material, output_path):
    """渲染材质预览"""
    # 创建预览平面
    bpy.ops.mesh.primitive_plane_add(size=4, location=(0, 0, 0))
    plane = bpy.context.active_object

    if plane.data.materials:
        plane.data.materials[0] = material
    else:
        plane.data.materials.append(material)

    # 添加摄像机
    bpy.ops.object.camera_add(location=(0, -6, 3))
    camera = bpy.context.active_object
    camera.rotation_euler = (1.1, 0, 0)
    bpy.context.scene.camera = camera

    # 添加光源
    bpy.ops.object.light_add(type='SUN', location=(5, -5, 10))
    light = bpy.context.active_object
    light.data.energy = 2.0

    # 渲染设置
    bpy.context.scene.render.resolution_x = 512
    bpy.context.scene.render.resolution_y = 512
    bpy.context.scene.render.filepath = str(output_path)
    bpy.context.scene.render.image_settings.file_format = 'PNG'

    # 渲染
    bpy.ops.render.render(write_still=True)

    print(f"  预览已保存: {output_path}")

def process_texture(input_path, output_name, color_scheme_name, texture_type):
    """处理单个纹理"""
    print(f"\n处理: {input_path.name}")

    # 升采样（如果是 64x64）
    img = bpy.data.images.load(str(input_path))
    original_size = img.size[0]
    bpy.data.images.remove(img)

    if original_size <= 64:
        upscaled_path = RAW_TEXTURES / f"{input_path.stem}_512.png"
        upscale_texture(input_path, upscaled_path, 512)
        source_path = upscaled_path
    else:
        source_path = input_path

    # 创建材质
    color_scheme = COLOR_SCHEMES[color_scheme_name]
    material = create_cyberpunk_material(source_path, output_name, color_scheme)

    # 渲染预览
    preview_path = OUTPUT_DIR / texture_type / f"{output_name}_preview.png"
    render_preview(material, preview_path)

    # 导出调色后的纹理
    output_texture_path = OUTPUT_DIR / texture_type / f"{output_name}.png"

    # 烘焙纹理
    clear_scene()
    bpy.ops.mesh.primitive_plane_add(size=2)
    plane = bpy.context.active_object
    plane.data.materials.append(material)

    # UV 展开
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.uv.unwrap()
    bpy.ops.object.mode_set(mode='OBJECT')

    # 创建烘焙图像
    bake_image = bpy.data.images.new(output_name, width=512, height=512)

    # 设置为活动图像
    for mat_slot in plane.material_slots:
        mat = mat_slot.material
        if mat and mat.use_nodes:
            for node in mat.node_tree.nodes:
                if node.type == 'TEX_IMAGE':
                    node.select = True
                    mat.node_tree.nodes.active = node

    # 添加图像纹理节点用于烘焙
    mat = plane.material_slots[0].material
    nodes = mat.node_tree.nodes
    bake_node = nodes.new(type='ShaderNodeTexImage')
    bake_node.image = bake_image
    bake_node.select = True
    mat.node_tree.nodes.active = bake_node

    # 烘焙
    bpy.context.view_layer.objects.active = plane
    bpy.ops.object.bake(type='EMIT')

    # 保存烘焙结果
    bake_image.filepath_raw = str(output_texture_path)
    bake_image.file_format = 'PNG'
    bake_image.save()

    print(f"  ✓ 已保存: {output_texture_path}")

    clear_scene()

def main():
    print("=" * 60)
    print("Blender 赛博朋克纹理处理")
    print("=" * 60)

    # 处理地板纹理
    floor_files = [
        ("scifi/floor_ship.png", "floor_scifi_ship", "cyan_floor"),
        ("scifi/floor_desert.png", "floor_scifi_desert", "blue_wall"),
    ]

    print("\n【处理地板纹理】")
    for file_name, output_name, scheme in floor_files:
        input_path = RAW_TEXTURES / file_name
        if input_path.exists():
            process_texture(input_path, output_name, scheme, "floors")

    # 处理墙壁纹理（选择几个）
    wall_files = [
        ("scifi/wall_ship_0.png", "wall_scifi_ship_0", "magenta_wall"),
        ("scifi/wall_ship_3.png", "wall_scifi_ship_3", "blue_wall"),
        ("cyberpunk_panel_8k.png", "wall_cyberpunk_panel", "magenta_wall"),
    ]

    print("\n【处理墙壁纹理】")
    for file_name, output_name, scheme in wall_files:
        input_path = RAW_TEXTURES / file_name
        if input_path.exists():
            process_texture(input_path, output_name, scheme, "walls")

    print("\n" + "=" * 60)
    print("处理完成!")
    print(f"纹理已保存到: {OUTPUT_DIR}")
    print("\n下一步:")
    print("  在 Godot 中导入这些纹理")

if __name__ == "__main__":
    main()
