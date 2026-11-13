"""Export a runtime-only copy of the final campus. Never save the source .blend.

Run once with Blender 4.3 --background --threads 4 --python this_file.
All geometry changes exist only in memory. Linked chairs remain linked in glTF.
"""
import bpy
import json
import math
import struct
import time
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / '3D-modeling' / 'campus-design-v9' / 'ensaf-campus-v9-final.blend'
OUT = ROOT / 'campus-game' / 'assets'
OUT.mkdir(parents=True, exist_ok=True)
START = time.time()
SOURCE_STAT = (SOURCE.stat().st_size, SOURCE.stat().st_mtime_ns)


def log(*items):
    print('[CAMPUS_EXPORT]', round(time.time() - START, 1), *items, flush=True)


def godot(point):
    return [round(float(point[0]), 5), round(float(point[2]), 5), round(-float(point[1]), 5)]


def bounds(obj):
    corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    corners_g = [godot(corner) for corner in corners]
    return {
        'blender_min': [round(min(p[i] for p in corners), 5) for i in range(3)],
        'blender_max': [round(max(p[i] for p in corners), 5) for i in range(3)],
        'godot_min': [min(p[i] for p in corners_g) for i in range(3)],
        'godot_max': [max(p[i] for p in corners_g) for i in range(3)],
    }


def role(obj):
    name = obj.name.lower()
    if any(term in name for term in ('seat ', 'chair', 'desk', 'table', 'sofa', 'armchair')):
        return 'furniture', False
    if any(term in name for term in ('glass', 'glazing', 'window pane')):
        return 'glass', False
    if any(term in name for term in ('door leaf', 'open second auditorium rear door', 'reception door opened')):
        return 'door', False
    if any(term in name for term in ('tree', 'palm', 'shrub', 'foliage', 'leaves', 'lawn', 'planting', 'grass', 'canopy leaf')):
        return 'landscape', False
    if any(term in name for term in ('diffuser', 'light', 'lamp', 'sconce', 'bulb', 'blind', 'handle', 'lever',
                                     'piping', 'joint', 'nosing', 'roller', 'monitor', 'screen', 'sign',
                                     'solar', 'panel seam', 'ventilation', 'condenser', 'grille', 'roof seam')):
        return 'detail', False
    if any(term in name for term in ('floor', 'stair', 'step', 'tread', 'tier', 'aisle', 'landing', 'ramp',
                                     'plaza', 'pavement', 'paving', 'paved', 'path', 'road', 'site base',
                                     'walkway', 'terrace', 'deck', 'threshold', 'carpet', 'approach', 'ground')):
        return 'walkable', True
    if any(term in name for term in ('wall', 'roof', 'column', 'pier', 'slab', 'structural', 'foundation',
                                     'perimeter', 'lintel', 'frame', 'balustrade', 'rail', 'parapet',
                                     'facade', 'cladding', 'massing', 'building', 'stone block', 'coping',
                                     'proscenium', 'acoustic panel', 'backdrop', 'ceiling')):
        return 'architecture', True
    return 'detail', False


bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene = bpy.context.scene
scene.render.threads_mode = 'FIXED'
scene.render.threads = 4
bpy.context.view_layer.update()
log('Loaded source', len(scene.objects), 'objects')

excluded = []
objects = []
for obj in list(scene.objects):
    reason = None
    if obj.type not in {'MESH', 'CURVE', 'FONT', 'SURFACE'}:
        reason = 'non_geometry'
    elif obj.hide_render or obj.hide_get() or not obj.visible_get():
        reason = 'hidden_or_obsolete_study'
    elif any(term in obj.name.lower() for term in ('reference picture', 'reference image', 'reference plane', 'picture plane', 'temporary', 'cutter')):
        reason = 'reference_or_temporary'
    elif any('reception room study' in col.name.lower() for col in obj.users_collection):
        reason = 'unplaced_legacy_reception_study'
    if reason:
        excluded.append({'name': obj.name, 'type': obj.type, 'reason': reason})
    else:
        objects.append(obj)

initial_inventory = []
for obj in objects:
    initial_inventory.append({'name': obj.name, 'type': obj.type, 'collections': [c.name for c in obj.users_collection],
                              'vertices': len(obj.data.vertices) if obj.type == 'MESH' else 0,
                              'polygons': len(obj.data.polygons) if obj.type == 'MESH' else 0,
                              'modifiers': [m.type for m in obj.modifiers], **bounds(obj)})
(OUT / 'source-inventory.json').write_text(json.dumps({'objects': initial_inventory, 'excluded': excluded}, indent=2), encoding='utf-8')
log('Selected', len(objects), 'geometry objects; excluded', len(excluded))

# Remove unrelated data before evaluating the runtime meshes. No disk source writes.
keep = {obj.as_pointer() for obj in objects}
for obj in list(bpy.data.objects):
    if obj.as_pointer() not in keep:
        bpy.data.objects.remove(obj, do_unlink=True)

# Simple PBR constants remove unsupported procedural texture graphs and baking.
material_records = []
used_materials = {mat for obj in objects for mat in obj.data.materials if mat}
for mat in used_materials:
    color = tuple(mat.diffuse_color)
    roughness, metallic, transmission, ior = .7, 0., 0., 1.45
    emission, emission_strength = (0., 0., 0., 1.), 0.
    if mat.use_nodes:
        bsdf = next((node for node in mat.node_tree.nodes if node.type == 'BSDF_PRINCIPLED'), None)
        if bsdf:
            color = tuple(bsdf.inputs['Base Color'].default_value)
            # Authored diffuse values are usually the intended tone when color is procedural.
            if bsdf.inputs['Base Color'].is_linked:
                color = tuple(mat.diffuse_color)
            roughness = float(bsdf.inputs['Roughness'].default_value)
            metallic = float(bsdf.inputs['Metallic'].default_value)
            transmission = float(bsdf.inputs['Transmission Weight'].default_value)
            ior = float(bsdf.inputs['IOR'].default_value)
            emission = tuple(bsdf.inputs['Emission Color'].default_value)
            emission_strength = float(bsdf.inputs['Emission Strength'].default_value)
    is_glass = transmission > .2 or any(t in mat.name.lower() for t in ('glass', 'glazing'))
    alpha = .24 if is_glass and ('clear' in mat.name.lower() or transmission > .9) else (.38 if is_glass else color[3])
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    output = nodes.new('ShaderNodeOutputMaterial')
    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.inputs['Base Color'].default_value = (color[0], color[1], color[2], alpha)
    bsdf.inputs['Roughness'].default_value = max(.08, roughness)
    bsdf.inputs['Metallic'].default_value = min(metallic, .2) if is_glass else metallic
    bsdf.inputs['Alpha'].default_value = alpha
    bsdf.inputs['IOR'].default_value = ior
    # Blend alpha works reliably in realtime renderers without refraction buffers.
    bsdf.inputs['Transmission Weight'].default_value = 0.
    bsdf.inputs['Emission Color'].default_value = emission
    bsdf.inputs['Emission Strength'].default_value = min(1., emission_strength)
    mat.node_tree.links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])
    mat.diffuse_color = (color[0], color[1], color[2], alpha)
    mat.surface_render_method = 'DITHERED'
    mat.use_backface_culling = False
    material_records.append({'name': mat.name, 'color_linear': list(color[:3]), 'alpha': alpha,
                             'roughness': max(.08, roughness), 'metallic': metallic, 'glass': is_glass})
log('Simplified', len(used_materials), 'materials without texture baking')

# Cache evaluated geometry so linked mesh users still share one glTF mesh.
depsgraph = bpy.context.evaluated_depsgraph_get()
mesh_cache = {}
optimizations = []
for index, obj in enumerate(objects):
    key = (obj.data.as_pointer(), tuple((m.type, m.name) for m in obj.modifiers))
    if obj.type != 'MESH' or obj.modifiers:
        if key not in mesh_cache:
            evaluated = obj.evaluated_get(depsgraph)
            mesh_cache[key] = bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=False, depsgraph=depsgraph)
        mesh = mesh_cache[key]
        # Replacement via object copy is needed for font/curve object types.
        if obj.type != 'MESH':
            old_name = obj.name
            replacement = bpy.data.objects.new(old_name + ' runtime', mesh)
            for collection in obj.users_collection:
                collection.objects.link(replacement)
            replacement.matrix_world = obj.matrix_world.copy()
            bpy.data.objects.remove(obj, do_unlink=True)
            replacement.name = old_name
            obj = replacement
            objects[index] = obj
        else:
            obj.modifiers.clear()
            obj.data = mesh
    if index % 250 == 0:
        log('Evaluated meshes', index, '/', len(objects))

bpy.context.view_layer.update()
unique_meshes = {}
for obj in objects:
    unique_meshes.setdefault(obj.data.as_pointer(), []).append(obj)
for linked in unique_meshes.values():
    obj = linked[0]
    mesh = obj.data
    before = len(mesh.vertices)
    is_roof = obj.name.startswith('E9 unified smooth stone roof')
    is_chair = obj.name.startswith('E9 auditorium row ')
    ratio = .10 if is_roof and before > 100000 else (.40 if is_chair and before > 2000 else None)
    if ratio is None:
        continue
    # Work on a copy and reattach all users after one decimation operation.
    copied = mesh.copy()
    obj.data = copied
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    modifier = obj.modifiers.new('Runtime collapse simplification', 'DECIMATE')
    modifier.decimate_type = 'COLLAPSE'
    modifier.ratio = ratio
    modifier.use_collapse_triangulate = True
    log('Decimating', obj.name, 'vertices', before, 'ratio', ratio)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    for user in linked:
        user.data = obj.data
    optimizations.append({'name': obj.name, 'linked_users': len(linked), 'vertices_before': before,
                          'vertices_after': len(obj.data.vertices), 'collapse_ratio': ratio})
    log('Simplified', obj.name, 'to', len(obj.data.vertices), 'vertices for', len(linked), 'linked users')

bpy.context.view_layer.update()
nodes = []
for obj in objects:
    classification, collision = role(obj)
    obj['campus_role'] = classification
    obj['campus_collision'] = collision
    obj['campus_source_name'] = obj.name
    obj['campus_walkable'] = classification == 'walkable'
    nodes.append({'name': obj.name, 'role': classification, 'collision_candidate': collision,
                  'walkable': classification == 'walkable', 'vertices': len(obj.data.vertices),
                  'triangles': sum(len(poly.vertices)-2 for poly in obj.data.polygons),
                  'mesh': obj.data.name, 'materials': [m.name if m else None for m in obj.data.materials],
                  'collections': [c.name for c in obj.users_collection], **bounds(obj)})

spawns_blender = {
    'plaza': [-27., 85., 1.25],
    'e_foyer': [-36., 104.5, 1.91],
    'e_rear_aisle': [-37., 107.95, 1.924],
    'd_entrance': [-5.8, 102.9, 2.80],
}
spawn_ground = {'plaza': .27, 'e_foyer': .91, 'e_rear_aisle': .924, 'd_entrance': 1.80}
spawns = {name: {'godot_player_center': godot(position), 'blender_player_center': position,
                 'godot_ground_y': spawn_ground[name], 'center_height_above_ground': 1.0}
          for name, position in spawns_blender.items()}

bpy.ops.object.select_all(action='DESELECT')
for obj in objects:
    obj.select_set(True)
log('Exporting GLB', len(objects), 'nodes;', len({o.data.as_pointer() for o in objects}), 'unique meshes')
bpy.ops.export_scene.gltf(
    filepath=str(OUT / 'campus.glb'),
    export_format='GLB',
    use_selection=True,
    export_yup=True,
    export_apply=False,
    export_extras=True,
    export_cameras=False,
    export_lights=False,
    export_animations=False,
    export_materials='EXPORT',
    export_image_format='AUTO',
    export_texcoords=False,
    export_normals=True,
    export_tangents=False,
    export_vertex_color='NONE',
    export_attributes=False,
    export_draco_mesh_compression_enable=False,
)

manifest = {
    'source': str(SOURCE), 'source_unchanged': SOURCE_STAT == (SOURCE.stat().st_size, SOURCE.stat().st_mtime_ns),
    'asset': 'campus.glb', 'asset_bytes': (OUT/'campus.glb').stat().st_size,
    'coordinate_convention': 'Blender (x,y,z) -> Godot (x,z,-y); metres',
    'geometry_objects': len(objects), 'unique_meshes': len({o.data.as_pointer() for o in objects}),
    'instanced_triangles': sum(n['triangles'] for n in nodes),
    'optimizations': optimizations, 'material_simplification': 'Constant Principled PBR; glass via alpha blend; no procedural texture baking',
    'materials': sorted(material_records, key=lambda m:m['name']),
    'spawns': spawns, 'nodes': nodes, 'excluded': excluded,
    'export_seconds': round(time.time()-START, 2),
}
(OUT/'asset-manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
assert manifest['source_unchanged'], 'Source file changed unexpectedly'
assert any(n['name'].startswith('E9 unified smooth stone roof') for n in nodes)
assert any(n['name'] == 'E9 rear entrance cross aisle' for n in nodes)
assert any(n['name'] == 'D7 polished lower hall floor' for n in nodes)
log('DONE', manifest['asset_bytes'], 'bytes', manifest['geometry_objects'], 'objects', manifest['instanced_triangles'], 'instanced triangles')
