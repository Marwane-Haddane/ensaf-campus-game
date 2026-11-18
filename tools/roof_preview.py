"""QA renders for the E9 stone roof: original vs game-ready, same camera, separate images.

blender -b <v9-final.blend> --python tools/roof_preview.py -- <out_dir>
Writes roof_<view>_orig.png and roof_<view>_game.png. Never saves the .blend.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from campus_roof import ROOF_PREFIX, build_game_roof  # noqa: E402

out = Path(sys.argv[sys.argv.index('--') + 1])
out.mkdir(parents=True, exist_ok=True)
src = next(o for o in bpy.data.objects if o.name.startswith(ROOF_PREFIX))

scene = bpy.data.scenes.new('RoofQA')
bpy.context.window_manager.windows[0].scene = scene
orig = bpy.data.objects.new('orig', src.data)
orig.matrix_world = src.matrix_world.copy()
scene.collection.objects.link(orig)
game = bpy.data.objects.new('game', src.data)
game.matrix_world = src.matrix_world.copy()
scene.collection.objects.link(game)
bpy.context.view_layer.update()
build_game_roof(game)

scene.render.engine = 'BLENDER_WORKBENCH'
sh = scene.display.shading
sh.light = 'STUDIO'
sh.color_type = 'SINGLE'
sh.single_color = (0.85, 0.78, 0.62)
sh.show_cavity = True
sh.show_shadows = True
sh.show_specular_highlight = True
scene.render.resolution_x = 1400
scene.render.resolution_y = 800
cd = bpy.data.cameras.new('cam')
cd.lens = 35
cam = bpy.data.objects.new('cam', cd)
scene.collection.objects.link(cam)
scene.camera = cam

corners = [orig.matrix_world @ Vector(c) for c in orig.bound_box]
ctr = sum(corners, Vector()) / 8
size = max((c - ctr).length for c in corners)
views = {'aerial': (35, 35, 2.4), 'ground_front': (0, 4, 2.0), 'ground_corner': (60, 6, 1.7),
         'ground_back': (200, 6, 1.9), 'eye_close_corner': (45, 3, 1.05)}
for name, (az, el, k) in views.items():
    a, e = math.radians(az), math.radians(el)
    cam.location = ctr + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * size * k
    cam.location.z = max(cam.location.z, 1.7)
    cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
    for label, show in (('orig', orig), ('game', game)):
        orig.hide_render = show is not orig
        game.hide_render = show is not game
        scene.render.filepath = str(out / f'roof_{name}_{label}.png')
        bpy.ops.render.render(write_still=True)
print('ROOF_QA done')
