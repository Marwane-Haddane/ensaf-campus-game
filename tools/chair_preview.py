"""QA renders: original E9 chair (left) vs game-ready chair (right). Never saves the .blend.

blender -b <v9-final.blend> --python tools/chair_preview.py -- <out_dir>
"""
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from campus_chairs import CHAIR_PREFIX, build_game_chair, colourway, tri_count  # noqa: E402

out = Path(sys.argv[sys.argv.index('--') + 1])
out.mkdir(parents=True, exist_ok=True)
src_obj = next(o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith(CHAIR_PREFIX)
               and 'crimson' in colourway(o.data).lower())

scene = bpy.data.scenes.new('ChairQA')
bpy.context.window.scene = scene if bpy.context.window else scene
bpy.context.window_manager.windows[0].scene = scene if bpy.context.window_manager.windows else scene
orig = bpy.data.objects.new('orig', src_obj.data)
scene.collection.objects.link(orig)
bpy.context.view_layer.update()
game_mesh = build_game_chair(src_obj.data, 'SM_E9_AuditoriumChair_QA')
game = bpy.data.objects.new('game', game_mesh)
scene.collection.objects.link(game)
orig.location = (-0.45, 0, 0)
game.location = (0.45, 0, 0)
for o in (orig, game):
    o.rotation_euler = src_obj.rotation_euler.copy()
    o.rotation_euler.x = 0
    o.rotation_euler.y = 0

scene.render.engine = 'BLENDER_WORKBENCH'
sh = scene.display.shading
sh.light = 'STUDIO'
sh.color_type = 'MATERIAL'
sh.show_cavity = True
sh.show_shadows = True
scene.render.resolution_x = 1400
scene.render.resolution_y = 800
scene.display.render_aa = '16'
wire = len(sys.argv) > sys.argv.index('--') + 2
cd = bpy.data.cameras.new('cam')
cd.lens = 50
cam = bpy.data.objects.new('cam', cd)
scene.collection.objects.link(cam)
scene.camera = cam
target = Vector((0, 0, 0.55))
for name, (az, el, dist) in {'front': (0, 10, 3.0), 'back34': (150, 18, 3.0), 'side': (90, 5, 3.0),
                             'play_distance': (20, 12, 9.0), 'rear_high': (8, 30, 2.2)}.items():
    a, e = math.radians(az), math.radians(el)
    cam.location = target + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * dist
    cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = str(out / f'chair_{name}.png')
    bpy.ops.render.render(write_still=True)
print('CHAIR_QA tris', tri_count(src_obj.data), '->', tri_count(game_mesh), 'mats', [m.name for m in game_mesh.materials])
