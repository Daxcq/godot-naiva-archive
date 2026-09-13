import bpy
from mathutils import Euler
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[1] / "assets" / "character" / "yellow_character.glb"
OUTPUT = SOURCE.with_name("yellow_character_animated.glb")
BLEND_OUTPUT = SOURCE.with_name("yellow_character_animated.blend")
FPS = 30


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))


def rig_meshes(armature):
    meshes = [
        obj for obj in bpy.context.scene.objects
        if obj.type == "MESH" and obj.name != "Icosphere"
    ]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        world = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = world
        for modifier in list(obj.modifiers):
            obj.modifiers.remove(modifier)
        obj.vertex_groups.clear()
        obj.select_set(True)
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")


def make_action(armature, name, end_frame, poses):
    action = bpy.data.actions.new(name)
    armature.animation_data_create()
    armature.animation_data.action = action
    for frame, pose in poses:
        bpy.context.scene.frame_set(frame)
        for bone in armature.pose.bones:
            bone.rotation_mode = "XYZ"
            bone.rotation_euler = Euler((0.0, 0.0, 0.0), "XYZ")
            bone.location = (0.0, 0.0, 0.0)
        for bone_name, rotation in pose.items():
            bone = armature.pose.bones.get(bone_name)
            if bone is None:
                raise RuntimeError(f"Missing bone: {bone_name}")
            bone.rotation_euler = Euler(rotation, "XYZ")
        for bone in armature.pose.bones:
            bone.keyframe_insert("rotation_euler", frame=frame, group=bone.name)
            bone.keyframe_insert("location", frame=frame, group=bone.name)
    action.frame_range = (1, end_frame)
    action.use_frame_range = True
    action.frame_start = 1
    action.frame_end = end_frame
    return action


def pose(**kwargs):
    return kwargs


def build_actions(armature):
    actions = []
    actions.append(make_action(armature, "idle", 49, [
        (1, pose(spine=(0.00, 0.00, 0.00), head=(0.00, 0.00, 0.00))),
        (13, pose(spine=(0.025, 0.00, 0.00), head=(-0.015, 0.00, 0.00))),
        (25, pose(spine=(0.00, 0.00, 0.00), head=(0.00, 0.00, 0.00))),
        (37, pose(spine=(-0.025, 0.00, 0.00), head=(0.015, 0.00, 0.00))),
        (49, pose(spine=(0.00, 0.00, 0.00), head=(0.00, 0.00, 0.00))),
    ]))

    actions.append(make_action(armature, "walk", 31, [
        (1, pose(L_thigh=(0.48, 0.00, 0.00), R_thigh=(-0.48, 0.00, 0.00),
                 L_shin=(-0.10, 0.00, 0.00), R_shin=(0.18, 0.00, 0.00),
                 L_foot=(-0.08, 0.00, 0.00), R_foot=(0.06, 0.00, 0.00),
                 L_arm=(-0.30, 0.00, 0.00), R_arm=(0.30, 0.00, 0.00))),
        (8, pose(L_thigh=(0.18, 0.00, 0.00), R_thigh=(-0.18, 0.00, 0.00),
                 L_shin=(0.02, 0.00, 0.00), R_shin=(0.08, 0.00, 0.00),
                 L_arm=(-0.12, 0.00, 0.00), R_arm=(0.12, 0.00, 0.00))),
        (16, pose(L_thigh=(-0.48, 0.00, 0.00), R_thigh=(0.48, 0.00, 0.00),
                  L_shin=(0.18, 0.00, 0.00), R_shin=(-0.10, 0.00, 0.00),
                  L_foot=(0.06, 0.00, 0.00), R_foot=(-0.08, 0.00, 0.00),
                  L_arm=(0.30, 0.00, 0.00), R_arm=(-0.30, 0.00, 0.00))),
        (23, pose(L_thigh=(-0.18, 0.00, 0.00), R_thigh=(0.18, 0.00, 0.00),
                  L_shin=(0.08, 0.00, 0.00), R_shin=(0.02, 0.00, 0.00),
                  L_arm=(0.12, 0.00, 0.00), R_arm=(-0.12, 0.00, 0.00))),
        (31, pose(L_thigh=(0.48, 0.00, 0.00), R_thigh=(-0.48, 0.00, 0.00),
                  L_shin=(-0.10, 0.00, 0.00), R_shin=(0.18, 0.00, 0.00),
                  L_foot=(-0.08, 0.00, 0.00), R_foot=(0.06, 0.00, 0.00),
                  L_arm=(-0.30, 0.00, 0.00), R_arm=(0.30, 0.00, 0.00))),
    ]))

    actions.append(make_action(armature, "run", 22, [
        (1, pose(spine=(0.14, 0.00, 0.00), head=(-0.08, 0.00, 0.00),
                 L_thigh=(0.82, 0.00, 0.00), R_thigh=(-0.82, 0.00, 0.00),
                 L_shin=(-0.22, 0.00, 0.00), R_shin=(0.36, 0.00, 0.00),
                 L_arm=(-0.58, 0.00, 0.00), R_arm=(0.58, 0.00, 0.00))),
        (6, pose(spine=(0.14, 0.00, 0.00), head=(-0.08, 0.00, 0.00),
                 L_thigh=(-0.82, 0.00, 0.00), R_thigh=(0.82, 0.00, 0.00),
                 L_shin=(0.36, 0.00, 0.00), R_shin=(-0.22, 0.00, 0.00),
                 L_arm=(0.58, 0.00, 0.00), R_arm=(-0.58, 0.00, 0.00))),
        (12, pose(spine=(0.14, 0.00, 0.00), head=(-0.08, 0.00, 0.00),
                  L_thigh=(0.82, 0.00, 0.00), R_thigh=(-0.82, 0.00, 0.00),
                  L_shin=(-0.22, 0.00, 0.00), R_shin=(0.36, 0.00, 0.00),
                  L_arm=(-0.58, 0.00, 0.00), R_arm=(0.58, 0.00, 0.00))),
        (17, pose(spine=(0.14, 0.00, 0.00), head=(-0.08, 0.00, 0.00),
                  L_thigh=(-0.82, 0.00, 0.00), R_thigh=(0.82, 0.00, 0.00),
                  L_shin=(0.36, 0.00, 0.00), R_shin=(-0.22, 0.00, 0.00),
                  L_arm=(0.58, 0.00, 0.00), R_arm=(-0.58, 0.00, 0.00))),
        (22, pose(spine=(0.14, 0.00, 0.00), head=(-0.08, 0.00, 0.00),
                  L_thigh=(0.82, 0.00, 0.00), R_thigh=(-0.82, 0.00, 0.00),
                  L_shin=(-0.22, 0.00, 0.00), R_shin=(0.36, 0.00, 0.00),
                  L_arm=(-0.58, 0.00, 0.00), R_arm=(0.58, 0.00, 0.00))),
    ]))

    actions.append(make_action(armature, "jump", 25, [
        (1, pose(L_thigh=(-0.25, 0.00, 0.00), R_thigh=(0.25, 0.00, 0.00),
                 L_shin=(0.42, 0.00, 0.00), R_shin=(0.42, 0.00, 0.00),
                 L_arm=(0.20, 0.00, 0.00), R_arm=(-0.20, 0.00, 0.00))),
        (7, pose(L_thigh=(0.55, 0.00, 0.00), R_thigh=(-0.55, 0.00, 0.00),
                 L_shin=(-0.05, 0.00, 0.00), R_shin=(-0.05, 0.00, 0.00),
                 L_arm=(-0.40, 0.00, 0.00), R_arm=(0.40, 0.00, 0.00))),
        (16, pose(L_thigh=(0.15, 0.00, 0.00), R_thigh=(-0.15, 0.00, 0.00),
                  L_shin=(0.70, 0.00, 0.00), R_shin=(0.70, 0.00, 0.00),
                  L_arm=(-0.55, 0.00, 0.00), R_arm=(0.55, 0.00, 0.00))),
        (25, pose(L_thigh=(0.15, 0.00, 0.00), R_thigh=(-0.15, 0.00, 0.00),
                  L_shin=(0.70, 0.00, 0.00), R_shin=(0.70, 0.00, 0.00),
                  L_arm=(-0.55, 0.00, 0.00), R_arm=(0.55, 0.00, 0.00))),
    ]))

    actions.append(make_action(armature, "fall", 16, [
        (1, pose(L_thigh=(0.15, 0.00, 0.00), R_thigh=(-0.15, 0.00, 0.00),
                 L_shin=(0.70, 0.00, 0.00), R_shin=(0.70, 0.00, 0.00),
                 L_arm=(-0.55, 0.00, 0.00), R_arm=(0.55, 0.00, 0.00))),
        (16, pose(L_thigh=(0.05, 0.00, 0.00), R_thigh=(-0.05, 0.00, 0.00),
                  L_shin=(0.40, 0.00, 0.00), R_shin=(0.40, 0.00, 0.00),
                  L_arm=(-0.25, 0.00, 0.00), R_arm=(0.25, 0.00, 0.00))),
    ]))

    actions.append(make_action(armature, "land", 10, [
        (1, pose(L_thigh=(0.05, 0.00, 0.00), R_thigh=(-0.05, 0.00, 0.00),
                 L_shin=(0.40, 0.00, 0.00), R_shin=(0.40, 0.00, 0.00),
                 L_arm=(-0.25, 0.00, 0.00), R_arm=(0.25, 0.00, 0.00))),
        (5, pose(L_thigh=(-0.30, 0.00, 0.00), R_thigh=(0.30, 0.00, 0.00),
                 L_shin=(0.60, 0.00, 0.00), R_shin=(0.60, 0.00, 0.00),
                 L_arm=(0.15, 0.00, 0.00), R_arm=(-0.15, 0.00, 0.00))),
        (10, pose(L_thigh=(0.00, 0.00, 0.00), R_thigh=(0.00, 0.00, 0.00),
                  L_shin=(0.00, 0.00, 0.00), R_shin=(0.00, 0.00, 0.00),
                  L_arm=(0.00, 0.00, 0.00), R_arm=(0.00, 0.00, 0.00))),
    ]))
    return actions


def export(armature):
    armature.animation_data.action = bpy.data.actions.get("idle")
    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT),
        export_format="GLB",
        use_selection=False,
        export_yup=True,
        export_apply=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_frame_range=False,
        export_force_sampling=True,
        export_skins=True,
        export_def_bones=True,
        export_anim_single_armature=True,
        export_optimize_animation_size=False,
        export_materials="EXPORT",
    )


clear_scene()
armature = bpy.data.objects.get("MilkFrog_Rig")
if armature is None or armature.type != "ARMATURE":
    raise RuntimeError("MilkFrog_Rig armature not found")

for action in list(bpy.data.actions):
    bpy.data.actions.remove(action)
rig_meshes(armature)
actions = build_actions(armature)
export(armature)
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_OUTPUT))
print(f"EXPORTED {OUTPUT}")
print(f"SAVED {BLEND_OUTPUT}")
print("ACTIONS", [action.name for action in actions])
