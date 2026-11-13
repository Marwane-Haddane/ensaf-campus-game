import pathlib,struct,json
p=pathlib.Path(r'C:\1Project\Vr --- cyber\ensaf-campus-v4-project\ENSA-Fes-Campus-v4\3D-modeling\3d models\cyber\gamer_setup_pack.glb');b=p.read_bytes();n=struct.unpack_from('<I',b,12)[0];j=json.loads(b[20:20+n]);blob=b[28+n:]
p=j['meshes'][3]['primitives'][0];a=j['accessors'][p['attributes']['POSITION']];v=j['bufferViews'][a['bufferView']];start=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',12)
pts=[struct.unpack_from('<fff',blob,start+i*stride) for i in range(a['count'])]
print('Screen vertices',len(pts)); print('Closest to x zero', sorted(set(pts),key=lambda x:abs(x[0]))[:30])
