import re

with open('assets/antigravity/zombie/models/pistol_hands.tscn', 'r', encoding='utf-8') as f:
    content = f.read()

for m in re.finditer(r'\[node name="([^"]+)"[^\]]*\]', content):
    node_header = m.group(0)
    start = m.end()
    end = content.find('[node', start)
    if end == -1: end = len(content)
    body = content[start:end]
    if any(k in node_header for k in ['Camera', 'Armature', 'Object_12', 'Object_82', 'Object_83']):
        print(node_header)
        for line in body.splitlines():
            if 'transform' in line or 'position' in line or 'rotation' in line:
                print('  ', line)
