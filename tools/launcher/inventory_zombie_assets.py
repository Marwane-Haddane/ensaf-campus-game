"""Read-only inventory of user-supplied future-mode assets; never imports them."""
from pathlib import Path
import hashlib, json, struct, zipfile

project=Path(__file__).resolve().parents[2]
source=project.parent/'3D-modeling'/'3d models'/'zombie'
result={'mode':'zombie_rpg','availability':'coming_soon','source_directory':str(source),'imported_into_game':False,'assets':[]}
for path in sorted(source.iterdir()):
    if not path.is_file(): continue
    record={'file':path.name,'bytes':path.stat().st_size,'sha256':hashlib.file_digest(path.open('rb'),'sha256').hexdigest()}
    if path.suffix.lower()=='.glb':
        with path.open('rb') as file:
            magic,version,total=struct.unpack('<III',file.read(12))
            length,kind=struct.unpack('<II',file.read(8))
            data=json.loads(file.read(length).rstrip(b' \0'))
        record.update({'format':'glb','version':version,'asset_metadata':data.get('asset',{}),
                       'meshes':len(data.get('meshes',[])),'skins':len(data.get('skins',[])),
                       'animations':[clip.get('name',f'Animation {i}') for i,clip in enumerate(data.get('animations',[]))]})
    elif path.suffix.lower()=='.zip':
        with zipfile.ZipFile(path) as archive:
            names=archive.namelist()
            record['archive_entries']=len(names)
            record['model_files']=[name for name in names if name.lower().endswith(('.glb','.gltf','.fbx','.obj','.blend'))]
            record['licence_files']=[name for name in names if any(term in name.lower() for term in ['license','licence','readme','copyright'])]
    result['assets'].append(record)
target=project/'design'/'future_zombie_assets.json'
target.write_text(json.dumps(result,indent=2,ensure_ascii=False),encoding='utf-8')
for item in result['assets']: print(item['file'],item['bytes'],f"animations={len(item.get('animations',[]))}")
