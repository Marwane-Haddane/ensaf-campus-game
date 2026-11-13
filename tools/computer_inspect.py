import struct,json,pathlib
p=pathlib.Path(r'C:\1Project\Vr --- cyber\ensaf-campus-v4-project\ENSA-Fes-Campus-v4\3D-modeling\3d models\cyber\gamer_setup_pack.glb')
b=p.read_bytes(); n,t=struct.unpack_from('<II',b,12);j=json.loads(b[20:20+n]);
print('ASSET',json.dumps(j.get('asset'),indent=2));print('EXTENSIONS',j.get('extensionsUsed'));print('SCENES',j.get('scenes'))
for i,v in enumerate(j.get('nodes',[])): print('NODE',i,json.dumps(v))
for i,v in enumerate(j.get('meshes',[])):
 print('MESH',i, v.get('name'),[(p.get('material'),j['accessors'][p['attributes']['POSITION']].get('min'),j['accessors'][p['attributes']['POSITION']].get('max')) for p in v['primitives']])
for i,v in enumerate(j.get('materials',[])):print('MAT',i,json.dumps(v))
for i,v in enumerate(j.get('images',[])):print('IMAGE',i,json.dumps(v))
