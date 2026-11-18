"""Bake the cream-entrance 3D text signs to flat alpha images for the Low preset.

  blender -b 3D-modeling/campus-design-v9/ensaf-campus-v9-final.blend --python tools/sign_decals_low.py

Read-only on the .blend (never saved). Writes assets/runtime_signs_low/<slug>.png and
manifest.json (world width/height of each image, Godot-space centre of the source text).
Only the three sign objects are rendered (orthographic, front view, transparent film).
"""
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'runtime_signs_low'
SIGNS = {
    'School sign large': 'sign_large',
    'School sign second': 'sign_second',
    'School sign affiliation': 'sign_affiliation',
}
PX_PER_M = 640  # ~6 px per cm: crisp at the distances the sign is read from
MARGIN = 0.04   # metres around the text


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    keep = {bpy.data.objects[name] for name in SIGNS}
    for obj in scene.objects:
        obj.hide_render = obj not in keep
    for obj in keep:
        obj.hide_render = False
    cam = bpy.data.objects.new('SignCam', bpy.data.cameras.new('SignCam'))
    scene.collection.objects.link(cam)
    cam.data.type = 'ORTHO'
    cam.rotation_euler = (math.radians(90), 0, 0)  # look along +Y at the -Y facing text
    sun = bpy.data.objects.new('SignSun', bpy.data.lights.new('SignSun', 'SUN'))
    scene.collection.objects.link(sun)
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(70), 0, math.radians(-20))  # from above-front, like the daytime sun
    scene.camera = cam
    scene.render.engine = 'BLENDER_EEVEE_NEXT'
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.resolution_percentage = 100
    if scene.world:
        scene.world.use_nodes = True
        bg = scene.world.node_tree.nodes.get('Background')
        if bg:
            bg.inputs['Strength'].default_value = 0.6
    manifest = {'version': 1, 'px_per_m': PX_PER_M, 'signs': {}}
    for name, slug in SIGNS.items():
        obj = bpy.data.objects[name]
        corners = [obj.matrix_world @ Vector(v) for v in obj.bound_box]
        mn = [min(c[i] for c in corners) for i in range(3)]
        mx = [max(c[i] for c in corners) for i in range(3)]
        width = (mx[0] - mn[0]) + 2 * MARGIN
        height = (mx[2] - mn[2]) + 2 * MARGIN
        center = [(mn[i] + mx[i]) * 0.5 for i in range(3)]
        cam.location = (center[0], mn[1] - 3.0, center[2])
        cam.data.ortho_scale = width
        scene.render.resolution_x = int(round(width * PX_PER_M / 4)) * 4
        scene.render.resolution_y = int(round(height * PX_PER_M / 4)) * 4
        for other in keep:
            other.hide_render = other is not obj
        scene.render.filepath = str(OUT / f'{slug}.png')
        bpy.ops.render.render(write_still=True)
        manifest['signs'][name] = {
            'image': f'{slug}.png',
            'width_m': width,
            'height_m': height,
            # Blender (x, y, z) -> Godot (x, z, -y); front face of the text.
            'godot_center': [center[0], center[2], -mn[1]],
        }
        print('SIGN', slug, round(width, 3), round(height, 3), scene.render.resolution_x, scene.render.resolution_y)
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2))
    print('SIGN_DECALS_DONE')


main()
