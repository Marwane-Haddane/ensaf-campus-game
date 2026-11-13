"""Build the two skinned enemy assets from the original, unrigged GLBs.

Run in Blender background mode with -- <source directory> <output directory>.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector


def rig_enemy(source, output, winged):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    mesh = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH")
    transform = mesh.matrix_world.copy()
    mesh.parent = None
    mesh.matrix_world.identity()
    mesh.data.transform(transform)

    armature = bpy.data.armatures.new("EnemySkeleton")
    rig = bpy.data.objects.new("EnemyRig", armature)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    segments = {}

    def bone(name, head, tail, parent=None):
        edit = armature.edit_bones.new(name)
        edit.head, edit.tail = head, tail
        if parent:
            edit.parent = armature.edit_bones[parent]
        segments[name] = (Vector(head), Vector(tail))

    if winged:
        bone("body", (0, .08, .24), (0, -.21, .27))
        bone("head", (0, -.23, .26), (0, -.45, .25), "body")
        bone("tail", (0, .11, .19), (0, .44, .16), "body")
        for side in (-1, 1):
            suffix = str(side)
            bone("wing"+suffix, (side*.075, -.18, .27), (side*.27, -.12, .57), "body")
            bone("fore"+suffix, (side*.10, -.30, .20), (side*.15, -.38, .025), "body")
            bone("hind"+suffix, (side*.085, -.015, .21), (side*.095, -.025, .025), "body")
    else:
        bone("body", (0, .015, .51), (0, -.01, .79))
        bone("head", (0, -.01, .79), (0, -.025, .97), "body")
        for side in (-1, 1):
            suffix = str(side)
            shoulder, elbow, wrist = ((side*.087, -.005, .77),
                                       (side*.153, -.015, .63), (side*.244, -.018, .515))
            hip, knee, foot = ((side*.067, .02, .49),
                               (side*.067, .015, .246), (side*.053, .016, .045))
            bone("arm"+suffix, shoulder, elbow, "body")
            bone("fore"+suffix, elbow, wrist, "arm"+suffix)
            bone("thigh"+suffix, hip, knee, "body")
            bone("shin"+suffix, knee, foot, "thigh"+suffix)
    bpy.ops.object.mode_set(mode="OBJECT")

    def distance(point, name):
        head, tail = segments[name]
        axis = tail-head
        projection = max(0, min(1, (point-head).dot(axis)/axis.length_squared))
        return (point-head-axis*projection).length

    groups = {name: mesh.vertex_groups.new(name=name) for name in segments}
    for vertex in mesh.data.vertices:
        x, y, z = vertex.co
        side = str(1 if x >= 0 else -1)
        if winged:
            if z > .33 and abs(x) > .104 and y > -.30:
                names = ["wing"+side, "body"]
            elif y > .13:
                names = ["tail", "body"]
            elif z < .20 and abs(x) > .05:
                names = ["fore"+side, "body"] if y < -.19 else ["hind"+side, "body"]
            elif y < -.25:
                names = ["head", "body"]
            else:
                names = ["body", "head"]
        elif z > .78:
            names = ["head", "body"]
        elif abs(x) > .101 + max(0, .76-z)*.23 and z > .466:
            names = ["arm"+side, "fore"+side, "body"]
        elif z < .49:
            names = ["thigh"+side, "shin"+side]
            if z > .405:
                names.append("body")
        else:
            names = ["body"]
        distances = [(name, distance(vertex.co, name)) for name in names]
        closest = min(value for _, value in distances)
        weights = [(name, math.exp(-(value-closest)/.017)) for name, value in distances]
        total = sum(weight for _, weight in weights)
        for name, weight in weights:
            groups[name].add([vertex.index], weight/total, "REPLACE")

    mesh.parent = rig
    skin = mesh.modifiers.new("Enemy skin", "ARMATURE")
    skin.object = rig
    bpy.context.scene.render.fps = 30
    rig.animation_data_create()

    def rotate(name, x=0, y=0, z=0):
        pose = rig.pose.bones[name]
        rest = pose.bone.matrix_local.to_quaternion()
        rotation = (Quaternion((1, 0, 0), math.radians(x))
                    @ Quaternion((0, 1, 0), math.radians(y))
                    @ Quaternion((0, 0, 1), math.radians(z)))
        pose.rotation_quaternion = rest.inverted() @ rotation @ rest

    def pose(frame, stride=0, lift=0, lean=0, sweep=0, flare=0, fall=0, recoil=0):
        for part in rig.pose.bones:
            part.rotation_quaternion = Quaternion()
            part.location = Vector((0, 0, 0))
        rotate("body", lean, fall, sweep*.25)
        body = rig.pose.bones["body"]
        body.location = body.bone.matrix_local.to_quaternion().inverted() @ Vector(
            (0, recoil, lift - abs(fall)*(.0018 if winged else .005)))
        rotate("head", -lean*.45, 0, -sweep*.32)
        if winged:
            rotate("tail", 0, 0, stride*.7)
            for side in (-1, 1):
                suffix = str(side)
                rotate("wing"+suffix, 0, side*flare, side*flare*.2)
                rotate("fore"+suffix, side*stride - sweep*.45)
                rotate("hind"+suffix, -side*stride*.85)
        else:
            for side in (-1, 1):
                suffix = str(side)
                rotate("arm"+suffix, -side*stride*.73 - (sweep if side == 1 else sweep*.3),
                       side*14-side*abs(sweep)*.13, -sweep*.38 if side == 1 else 0)
                rotate("fore"+suffix, -10-abs(stride)*.35-sweep*.25)
                rotate("thigh"+suffix, side*stride)
                rotate("shin"+suffix, max(0, -side*stride*.86))
        for part in rig.pose.bones:
            part.keyframe_insert(data_path="rotation_quaternion", frame=frame)
        body.keyframe_insert(data_path="location", frame=frame)

    def clip(name, frames):
        action = bpy.data.actions.new(name)
        rig.animation_data.action = action
        for frame, parameters in frames:
            pose(frame, **parameters)
        rig.animation_data.action = None
        track = rig.animation_data.nla_tracks.new()
        track.name = name
        track.strips.new(name, 1, action)

    clip("Idle", [(1, {}), (25, {"lift": .01, "flare": -9}), (49, {})])
    for name, frames, stride in (("Walk", 34, 17), ("Run", 22, 27)):
        clip(name, [(1, {"stride": stride, "flare": 8}),
                    (frames//4, {"lift": .018, "flare": -5}),
                    (frames//2, {"stride": -stride, "flare": 8}),
                    (frames*3//4, {"lift": .018, "flare": -5}),
                    (frames, {"stride": stride, "flare": 8})])
    clip("Strike", [(1, {}), (14, {"lean": 13, "sweep": -22, "flare": -22}),
                    (20, {"lean": -19, "sweep": 62, "flare": 19, "recoil": -.052}),
                    (30, {"lean": -10, "sweep": 30, "flare": 10}), (46, {})])
    clip("Flinch", [(1, {}), (4, {"lean": 15, "sweep": -12, "flare": -16,
                                   "recoil": .036}), (12, {})])
    clip("Fall", [(1, {}), (9, {"lean": 8, "fall": 25, "flare": -18}),
                  (24, {"fall": 84, "flare": -45}), (32, {"fall": 84, "flare": -45})])
    bpy.context.scene.frame_set(1)
    bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB",
                              export_animation_mode="NLA_TRACKS")


if __name__ == "__main__":
    sources, output = map(Path, sys.argv[-2:])
    rig_enemy(sources/"low_poly_female_warrior_charctor.glb",
              output/"hooded_warrior.glb", False)
    rig_enemy(sources/"low_poly_lion_with_wings_warrior_character_model.glb",
              output/"winged_lion.glb", True)
