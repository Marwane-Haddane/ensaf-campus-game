"""Trace the user-supplied emblem's color silhouette into real white SVG paths.
Input is a text mask read by System.Drawing; original artwork stays unchanged.
No raster data, external links, fonts or text elements are embedded in the SVG.
"""
from pathlib import Path
from collections import defaultdict
from math import hypot

root = Path(__file__).resolve().parents[2]
rows = (root / 'tools/launcher/emblem-mask.txt').read_text().splitlines()
points = {(x,y) for y,row in enumerate(rows) for x,c in enumerate(row) if c=='1'}
edges = defaultdict(list)
for x,y in points:
    if (x,y-1) not in points: edges[(x,y)].append((x+1,y))
    if (x+1,y) not in points: edges[(x+1,y)].append((x+1,y+1))
    if (x,y+1) not in points: edges[(x+1,y+1)].append((x,y+1))
    if (x-1,y) not in points: edges[(x,y+1)].append((x,y))

def simplify(vertices):
    # Preserve lines while removing strictly collinear intermediate pixel edges.
    out=[]
    for i,b in enumerate(vertices):
        a=vertices[i-1]; c=vertices[(i+1)%len(vertices)]
        if (b[0]-a[0])*(c[1]-b[1]) != (b[1]-a[1])*(c[0]-b[0]): out.append(b)
    return out

paths=[]
while edges:
    start=next(iter(edges)); current=start; vertices=[]
    while True:
        vertices.append(current)
        choices=edges[current]
        nxt=choices.pop()
        if not choices: del edges[current]
        current=nxt
        if current==start: break
    area=abs(sum(a[0]*b[1]-a[1]*b[0] for a,b in zip(vertices,vertices[1:]+vertices[:1])))/2
    if area<1.5: continue
    vertices=simplify(vertices)
    if len(vertices)<3: continue
    # Slight quadratic rounding removes stair-step harshness without redrawing
    # the supplied emblem or replacing its university identity with a shield.
    rounded=[]
    for i,b in enumerate(vertices):
        a=vertices[i-1]; c=vertices[(i+1)%len(vertices)]
        r=min(.35,hypot(b[0]-a[0],b[1]-a[1])*.25,hypot(c[0]-b[0],c[1]-b[1])*.25)
        def towards(q):
            length=hypot(q[0]-b[0],q[1]-b[1])
            return (b[0]+(q[0]-b[0])*r/length,b[1]+(q[1]-b[1])*r/length)
        rounded.append((towards(a),b,towards(c)))
    first=rounded[0][0]
    d=f'M{first[0]:.2f} {first[1]:.2f}'
    for pre,b,post in rounded:
        d+=f'L{pre[0]:.2f} {pre[1]:.2f}Q{b[0]} {b[1]} {post[0]:.2f} {post[1]:.2f}'
    paths.append(d+'Z')

x0=min(x for x,y in points)-8; y0=min(y for x,y in points)-8
x1=max(x for x,y in points)+9; y1=max(y for x,y in points)+9
svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="{x0} {y0} {x1-x0} {y1-y0}">
<title>White university emblem — vector recreation from the user's reference</title>
<path fill="#ffffff" fill-rule="evenodd" d="{''.join(paths)}"/>
</svg>\n'''
target=root/'assets/launcher/ensa-emblem-white.svg'
target.write_text(svg,encoding='utf-8')
print(f'WHITE_SVG_READY paths={len(paths)} bytes={target.stat().st_size}')
