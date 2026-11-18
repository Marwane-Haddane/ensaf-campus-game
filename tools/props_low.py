"""Low-preset versions of the two over-budget supplied props (roadmap item #7).

  blender -b --factory-startup --python tools/props_low.py

Inputs stay untouched; outputs go to assets/user_models/low/:

gamer_setup_pack_low.glb
    Only the 5 parts the game mounts (scripts/computer_prop.gd). Each part keeps its
    node name; its meshes are joined into one object with 2 materials:
    mt_low_body (flat colours baked to vertex colours) + mt_pc_led (emissive; the
    game restyles it by name). The monitor screen stays a separate object named
    sm_monitor_mt_monitor_screen_0 because the game looks it up. Decimated to ~3k tris.

server_rack_1_low.glb
    Same parts/materials; the four 17.5k-tri cable looms and the dense buttons/lights
    are decimated.
"""
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'assets' / 'user_models'
OUT = SRC / 'low'

PC_PARTS = ['sm_monitor', 'sm_pc', 'sm_keyboard', 'sm_mouse', 'sm_mousepad']
SCREEN = 'sm_monitor_mt_monitor_screen_0'
LED_MATERIALS = {'mt_pc_led', 'mt_fan_led', 'mt_keyboard_led', 'mt_mouse_led'}
# Matches the in-game restyle in computer_prop.gd, so Low looks like Medium.
COLOR_OVERRIDE = {'mt_case_boxmetal': (0.0090, 0.0395, 0.0482), 'mt_pc_glass': (0.20, 0.23, 0.28)}
PC_DECIMATE = 0.24
RACK_DECIMATE = {'cables': 0.04, 'button': 0.3, 'green_light': 0.3}


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def descendants(obj):
    out = []
    for child in obj.children:
        out.append(child)
        out.extend(descendants(child))
    return out


def base_color(material):
    bsdf = material.node_tree.nodes.get('Principled BSDF') if material and material.node_tree else None
    if bsdf is None:
        return (0.5, 0.5, 0.5)
    return tuple(bsdf.inputs['Base Color'].default_value[:3])


def apply_world(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    mw = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = mw


def decimate(obj, ratio):
    mod = obj.modifiers.new('Decimate', 'DECIMATE')
    mod.ratio = ratio
    mod.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


def low_pc():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SRC / 'gamer_setup_pack.glb'))
    body = bpy.data.materials.new('mt_low_body')
    body.use_nodes = True
    nt = body.node_tree
    attr = nt.nodes.new('ShaderNodeVertexColor'); attr.layer_name = 'Col'
    nt.links.new(attr.outputs['Color'], nt.nodes['Principled BSDF'].inputs['Base Color'])
    nt.nodes['Principled BSDF'].inputs['Roughness'].default_value = 0.6
    led = bpy.data.materials.get('mt_pc_led')
    keep = set()
    report = {}
    for part_name in PC_PARTS:
        part = bpy.data.objects[part_name]
        meshes = [o for o in descendants(part) if o.type == 'MESH' and o.name != SCREEN]
        before = sum(tris(o) for o in meshes)
        for obj in meshes:
            apply_world(obj)
            # Bake each source material's colour into vertex colours, then remap slots.
            mesh = obj.data
            col = mesh.color_attributes.new('Col', 'FLOAT_COLOR', 'CORNER')
            colors = []
            for poly in mesh.polygons:
                mat = mesh.materials[poly.material_index] if mesh.materials else None
                name = mat.name if mat else ''
                rgb = COLOR_OVERRIDE.get(name, base_color(mat))
                for _ in poly.loop_indices:
                    colors.extend((*rgb, 1.0))
            mesh.color_attributes['Col'].data.foreach_set('color', colors)
            is_led = [((mesh.materials[p.material_index].name if mesh.materials else '') in LED_MATERIALS) for p in mesh.polygons]
            mesh.materials.clear()
            mesh.materials.append(body)
            mesh.materials.append(led)
            mesh.polygons.foreach_set('material_index', [1 if flag else 0 for flag in is_led])
        bpy.ops.object.select_all(action='DESELECT')
        for obj in meshes:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = meshes[0]
        bpy.ops.object.join()
        joined = bpy.context.view_layer.objects.active
        decimate(joined, PC_DECIMATE)
        # Re-parent under the part empty with its name, so find_child(part) still works.
        joined.name = part_name + '_low'
        mw = joined.matrix_world.copy()
        joined.parent = part
        joined.matrix_world = mw
        keep.update({part, joined})
        if part_name == 'sm_monitor':
            keep.add(bpy.data.objects[SCREEN])
        report[part_name] = (before, tris(joined))
    # Keep the parts' ancestor chain (root transforms), drop everything else.
    for obj in list(keep):
        cursor = obj.parent
        while cursor:
            keep.add(cursor)
            cursor = cursor.parent
    for obj in list(bpy.data.objects):
        if obj not in keep:
            bpy.data.objects.remove(obj, do_unlink=True)
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT / 'gamer_setup_pack_low.glb'), export_format='GLB',
                              export_vertex_color='ACTIVE', export_materials='EXPORT', export_yup=True)
    print('PC_LOW', report, 'total', sum(v[1] for v in report.values()) + tris(bpy.data.objects[SCREEN]))


def low_rack():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SRC / 'server_rack_1.glb'))
    before = sum(tris(o) for o in bpy.data.objects if o.type == 'MESH')
    for obj in [o for o in bpy.data.objects if o.type == 'MESH']:
        names = {m.name for m in obj.data.materials if m}
        for material, ratio in RACK_DECIMATE.items():
            if material in names:
                decimate(obj, ratio)
    after = sum(tris(o) for o in bpy.data.objects if o.type == 'MESH')
    bpy.ops.export_scene.gltf(filepath=str(OUT / 'server_rack_1_low.glb'), export_format='GLB',
                              export_materials='EXPORT', export_yup=True)
    print('RACK_LOW', before, '->', after)


low_pc()
low_rack()
print('PROPS_LOW_DONE')
