"""Render an offline composition from exported Godot placements; not a GPU screenshot."""
import base64
import json
import math
from pathlib import Path
import subprocess
import sys
import html

root=Path(__file__).resolve().parents[2]
out=Path(sys.argv[1]) if len(sys.argv)>1 else root/'output/level-design/tanggu-world-20261021'
data=json.loads((out/'composition.json').read_text())
world_w,world_h=data['size']
paths={item['image'] for item in data['ground']+data['sprites']}
ids={path:f'image{i}' for i,path in enumerate(sorted(paths))}
sizes={part['image']:part['sheetSize'] for part in data['sprites']}
svg=[f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 {world_w} {world_h}" width="{world_w}" height="{world_h}"><defs>']
for path,identifier in ids.items():
    source=root/'godot'/path.removeprefix('res://')
    encoded=base64.b64encode(source.read_bytes()).decode()
    w,h=sizes.get(path,[627,627])
    svg.append(f'<image id="{identifier}" width="{w}" height="{h}" xlink:href="data:image/png;base64,{encoded}"/>')
for index,part in enumerate(data['ground']):
    # Terrain extraction produces four 627-pixel tiles, rendered 1:1 in world units.
    svg.append(f'<pattern id="ground{index}" patternUnits="userSpaceOnUse" width="627" height="627"><use xlink:href="#{ids[part["image"]]}"/></pattern>')
if 'terrainBlend' in data:
    for index,(a,b,normal) in enumerate(data['terrainBlend']['edges']):
        width=data['terrainBlend']['width']*0.85
        mid=[(a[i]+b[i])/2 for i in range(2)]
        svg.append(f'<linearGradient id="fade{index}" gradientUnits="userSpaceOnUse" x1="{mid[0]}" y1="{mid[1]}" x2="{mid[0]+normal[0]*width}" y2="{mid[1]+normal[1]*width}"><stop offset="0" stop-color="white"/><stop offset="1" stop-color="white" stop-opacity="0"/></linearGradient>')
for tint in {tuple(part.get('tint',[1,1,1])) for part in data['sprites']} | {tuple(part['color'][:3]) for part in data.get('contacts',[])}:
    key='_'.join(str(v) for v in tint)
    r,g,b=tint
    svg.append(f'<filter id="tint{key}" color-interpolation-filters="sRGB"><feColorMatrix type="matrix" values="{r} 0 0 0 0 0 {g} 0 0 0 0 0 {b} 0 0 0 0 0 1 0"/></filter>')
svg.append('<pattern id="contactSoil" patternUnits="userSpaceOnUse" width="627" height="627"><use xlink:href="#'+ids['res://assets/world/forest.png']+'"/></pattern>')
svg.append('</defs>')
for index,part in sorted(enumerate(data['ground']),key=lambda pair:pair[1]['z']):
    points=' '.join(','.join(str(v) for v in vertex) for vertex in part['points'])
    if part.get('name') not in ['Forest','River'] and 'terrainBlend' in data: continue
    svg.append(f'<polygon points="{points}" fill="url(#ground{index})"/>')
if 'terrainBlend' in data:
    svg.append(f'<defs><mask id="roadBlend" maskUnits="userSpaceOnUse" x="0" y="0" width="{world_w}" height="{world_h}">')
    for index,(a,b,normal) in enumerate(data['terrainBlend']['edges']):
        width=data['terrainBlend']['width']*0.85
        points=' '.join(f'{x},{y}' for x,y in [a,b,[b[i]+normal[i]*width for i in range(2)],[a[i]+normal[i]*width for i in range(2)]])
        svg.append(f'<polygon points="{points}" fill="url(#fade{index})"/>')
    for part in data['ground']:
        if part.get('name') in ['Forest','River']: continue
        points=' '.join(','.join(str(v) for v in vertex) for vertex in part['points'])
        svg.append(f'<polygon points="{points}" fill="white"/>')
    svg.append('</mask></defs>')
    path_index=next(i for i,part in enumerate(data['ground']) if part.get('name') not in ['Forest','River'])
    svg.append(f'<rect width="{world_w}" height="{world_h}" fill="url(#ground{path_index})" mask="url(#roadBlend)"/>')
# Contacts come from the actual native Polygon2D meshes. SVG approximates vertex alpha.
for part in sorted(data['sprites']+data.get('contacts',[]),key=lambda item:item['z']):
    if 'points' in part:
        center=part['points'][-1];r,g,b,alpha=part['color']
        tint='_'.join(str(v) for v in [r,g,b])
        edge=part['points'][0];side=part['points'][8]
        matrix=f"{edge[0]-center[0]} {edge[1]-center[1]} {side[0]-center[0]} {side[1]-center[1]} {center[0]} {center[1]}"
        key=f"contact{len(svg)}"
        points=' '.join(f'{p[0]},{p[1]}' for p in part['points'][:-1])
        xs=[p[0] for p in part['points']];ys=[p[1] for p in part['points']]
        bounds=f'x="{min(xs)}" y="{min(ys)}" width="{max(xs)-min(xs)}" height="{max(ys)-min(ys)}"'
        svg.append(f'<defs><radialGradient id="{key}" gradientUnits="userSpaceOnUse" cx="0" cy="0" r="1" gradientTransform="matrix({matrix})"><stop offset="0" stop-color="white" stop-opacity="{alpha}"/><stop offset="1" stop-color="white" stop-opacity="0"/></radialGradient><mask id="{key}mask" maskUnits="userSpaceOnUse" {bounds}><polygon points="{points}" fill="url(#{key})"/></mask></defs>')
        fill='url(#contactSoil)' if part['image'] else 'white'
        svg.append(f'<polygon points="{points}" fill="{fill}" filter="url(#tint{tint})" mask="url(#{key}mask)"/>')
        continue
    x,y=part['position'];w,h=part['size'];rx,ry,rw,rh=part['region']
    transform=f'translate({2*rx+rw},0) scale(-1,1)' if part.get('mirror') else ''
    if 'pose' in part:
        matrix=' '.join(str(v) for v in part['pose'])
        tint='_'.join(str(v) for v in part['tint'])
        dx,dy=part.get('rect',[-rw/2,-rh])
        opacity=part.get('opacity',1)
        svg.append(f'<g opacity="{opacity}" transform="matrix({matrix})" filter="url(#tint{tint})"><svg x="{dx}" y="{dy}" width="{rw}" height="{rh}" viewBox="{rx} {ry} {rw} {rh}" overflow="hidden"><use transform="{transform}" xlink:href="#{ids[part["image"]]}"/></svg></g>')
    else:
        svg.append(f'<svg x="{x}" y="{y}" width="{w}" height="{h}" viewBox="{rx} {ry} {rw} {rh}" overflow="hidden"><use transform="{transform}" xlink:href="#{ids[part["image"]]}"/></svg>')
for label in data.get('labels',[]):
    for index,line in enumerate(label['text'].split('\n')):
        x,y=label['position']
        svg.append(f'<text x="{x}" y="{y+label["size"]*(index*1.4+1)}" font-family="sans-serif" font-size="{label["size"]}" fill="#{label["color"]}" stroke="#111b12" stroke-width="3" paint-order="stroke">{html.escape(line)}</text>')
svg.append('</svg>')
(out/'composition.svg').write_text('\n'.join(svg))
subprocess.run(['rsvg-convert','--unlimited',str(out/'composition.svg'),'-o',str(out/'composition.png')],check=True)
if len(sys.argv)==1: (out/'index.html').write_text('''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>汤谷 · 独立资产地图</title><style>body{margin:0;background:#141b16;color:#e9ddbf;font:16px/1.65 system-ui}main{padding:24px;max-width:1700px;margin:auto}h1{font-size:25px;margin:0}p{color:#b7baa7}img{width:100%;height:auto;display:block}a{color:#f7c77b}</style><main><h1>汤谷 · 独立资产搭建地图</h1><p>以下画面按实际 Godot 场景节点的纹理、位置与深度离线组装。地面、圆庭、建筑、树木和岩岸均为独立资源；没有使用完整地图底图。接地透明渐变为 SVG 近似，此图不是 Godot GPU 实机截图。</p><a href="composition.png">查看 4608×3072 原尺寸</a> · <a href="../tanggu-grounding-20261021/index.html">环境融合前后对照</a><p>此页保留连续地图制作记录；当前默认已改为<a href="../tanggu-rooms-20261021/index.html">七房间互通地图</a>。</p><img src="composition.png" alt="汤谷独立资产地图组装预览"></main></html>''')
print(out/'composition.png')
