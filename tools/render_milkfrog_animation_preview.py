import bpy
from mathutils import Vector
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "assets" / "character" / "yellow_character_animated.glb"
OUT = ROOT / "artifacts" / "milkfrog_animation_preview.png"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(MODEL))
armature = bpy.data.objects.get("MilkFrog_Rig")
if armature is None:
    raise RuntimeError("MilkFrog_Rig not found")

camera_data = bpy.data.cameras.new("PreviewCamera")
camera = bpy.data.objects.new("PreviewCamera", camera_data)
bpy.context.scene.collection.objects.link(camera)
camera.location = (4.8, -8.5, 3.4)
camera.rotation_euler = (Vector((0.0, 0.0, 1.35)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera_data.type = "ORTHO"
camera_data.ortho_scale = 3.8
bpy.context.scene.camera = camera

light_data = bpy.data.lights.new("PreviewKey", "AREA")
light_data.energy = 900
light_data.shape = "DISK"
light_data.size = 5.0
light = bpy.data.objects.new("PreviewKey", light_data)
bpy.context.scene.collection.objects.link(light)
light.location = (3.0, -4.0, 6.0)
light.rotation_euler = (Vector((0.0, 0.0, 1.0)) - light.location).to_track_quat("-Z", "Y").to_euler()

fill_data = bpy.data.lights.new("PreviewFill", "AREA")
fill_data.energy = 400
fill_data.size = 4.0
fill = bpy.data.objects.new("PreviewFill", fill_data)
bpy.context.scene.collection.objects.link(fill)
fill.location = (-4.0, -2.0, 3.0)
fill.rotation_euler = (Vector((0.0, 0.0, 1.0)) - fill.location).to_track_quat("-Z", "Y").to_euler()

scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.render.resolution_x = 768
scene.render.resolution_y = 768
scene.render.resolution_percentage = 100
scene.render.film_transparent = False
scene.display.shading.light = "STUDIO"
scene.display.shading.studio_light = "paint.sl"
scene.display.shading.color_type = "MATERIAL"
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(OUT)

action_frames = {
    "idle": 25,
    "walk": 8,
    "run": 6,
    "jump": 16,
    "fall": 8,
    "land": 5,
}

OUT.parent.mkdir(exist_ok=True)
for name, frame in action_frames.items():
    action = bpy.data.actions.get(name)
    if action is None:
        raise RuntimeError(f"Missing action: {name}")
    armature.animation_data.action = action
    scene.frame_set(frame)
    scene.render.filepath = str(OUT.with_name(f"milkfrog_{name}.png"))
    bpy.ops.render.render(write_still=True)
print("RENDERED", ", ".join(action_frames))
