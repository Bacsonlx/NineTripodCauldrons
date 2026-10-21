"""Author a modular Godot map once; subsequent edits belong to the Godot scene."""
import argparse
import json
import math
from pathlib import Path
import random
import re

root=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
if args.output.exists(): raise SystemExit('拒绝覆盖已有场景；生成到新路径后审阅合并。')
source=(root/'output/level-design/tanggu-world-20261021/before/godot/scenes/tanggu_first_level_map.tscn').read_text()
data=json.loads((root/'tools/level_design/tanggu_reference_layout.json').read_text())
frames=json.loads((root/'godot/assets/world/atlas.json').read_text())
resources={'prop':('PackedScene','res://scenes/world/environment_prop.tscn'),'surface':('Script','res://scripts/world/terrain_surface.gd')}
for key in [*frames,'gate']:
 resources[key]=('Texture2D',f'res://assets/world/{key}.tres')
for key in ['forest','path','stone','water']:
 resources['tile_'+key]=('Texture2D',f'res://assets/world/{key}.png')
ids={key:str(i+3) for i,key in enumerate(resources)}
lines=[f'[gd_scene load_steps={len(resources)+3} format=3]',
'[ext_resource type="Script" path="res://scripts/world/first_level_map.gd" id="1"]',
'[ext_resource type="Script" path="res://scripts/world/map_item.gd" id="2"]']
for key,(kind,path) in resources.items():lines.append(f'[ext_resource type="{kind}" path="{path}" id="{ids[key]}"]')
blocks=re.split(r'(?=\[node )',source)[1:]
converted={'ReturnGate':('gate',183,0),'Stele':('stele',110,0),'Altar':('altar',155,0),'GreatRootBody':('root',930,180)}
retired={'Court1InnerWall','Court1SouthPillar','Court2WestWall','Court2NorthWall','Court3NorthWall','Court3InnerWall','Court3SouthWall'}
for block in blocks:
 name=re.search(r'\[node name="([^"]+)"',block)[1]
 if name in retired:continue
 if name=='PlayerSpawn':block=re.sub(r'position = Vector2\([^\n]+','position = Vector2(540, 2380)',block)
 if name=='ArtPlate' or name=='Foreground' or 'parent="Foreground"' in block:continue
 if name in converted:
  texture,width,offset=converted[name]
  block=re.sub(r'\[node[^\n]+\]',f'[node name="{name}" parent="." instance=ExtResource("{ids["prop"]}")]',block,count=1)
  block=block.replace('script = ExtResource("2")\n','').rstrip()+f'\ntexture_asset = ExtResource("{ids[texture]}")\nrender_width = {width}.0\n'
  if offset:block+=f'art_offset = Vector2(0, {offset})\n'
 lines.append(block.rstrip())
 if name in ['Stele','Altar','ReturnGate']:
  point=next(o['p'] for o in data['obstacles'] if o['name']==name)
  key={'Stele':'stele','Altar':'altar','ReturnGate':'gate'}[name]
  anchor=data['landmarks'][key]
  lines.extend(['',f'[node name="InteractionAnchor" type="Marker2D" parent="{name}"]',f'position = Vector2({(anchor[0]-point[0])*3}, {(anchor[1]-point[1])*3})'])

def vec(p):return f'Vector2({p[0]:.3f}, {p[1]:.3f})'
def poly(points):return 'PackedVector2Array('+', '.join(f'{v:.3f}' for p in points for v in p)+')'
def ground(name,points,texture,z=-50):
 lines.extend(['',f'[node name="{name}" type="Polygon2D" parent="Ground"]',f'z_index = {z}',f'polygon = {poly(points)}',f'uv = {poly(points)}',f'texture = ExtResource("{ids["tile_"+texture]}")','texture_repeat = 2','texture_filter = 2'])
lines+=['','[node name="Ground" type="Node2D" parent="."]',f'script = ExtResource("{ids["surface"]}")',f'path_texture = ExtResource("{ids["tile_path"]}")']
ground('Forest',[[0,0],[4608,0],[4608,3072],[0,3072]],'forest',-100)
river=[[0,0],[575,0],[655,210],[690,450],[600,650],[330,1000],[370,1250],[545,1600],[480,1900],[450,2100],[260,2420],[140,2550],[280,2850],[630,3072],[0,3072]]
ground('River',river,'water',-90)
floors={name:[(x*3,y*3) for x,y in points] for name,points in data['floors'].items()}
for name,points in floors.items():ground(name,points,'path')
count=0
props=[]
def prop(name,key,p,width,solid=False,size=(60,32),kind='wall',stage=None,flat=False,offset=(0,0)):
 global count
 count+=1
 if solid:
  for cx,cy,rx,ry in [(1134,2232,435,270),(2607,1878,405,251),(3675,1545,495,307),(2400,438,540,335)]:
   radius=math.hypot((p[0]-cx)/rx,(p[1]-cy)/ry)
   if 0<radius<1.08:p=(cx+(p[0]-cx)*1.12/radius,cy+(p[1]-cy)*1.12/radius)
 lines.extend(['',f'[node name="World_{name}" parent="." instance=ExtResource("{ids["prop"]}")]',f'position = {vec(p)}',f'category = "{"obstacle" if solid else "ground"}"',f'obstacle_kind = "{kind}"',f'size = {vec(size)}',f'texture_asset = ExtResource("{ids[key]}")',f'render_width = {width:.3f}',f'body_height = {160.0 if key.startswith("tree") else 100.0}'])
 if stage is not None:lines.append(f'opens_after_encounter = {stage}')
 if flat:lines.append('flat = true')
 if offset!=(0,0):lines.append(f'art_offset = {vec(offset)}')
 props.append({'name':name,'asset':key,'position':p,'width':width,'solid':solid})

def inside(point,polygon):
 x,y=point; result=False
 for (ax,ay),(bx,by) in zip(polygon,polygon[1:]+polygon[:1]):
  if (ay>y)!=(by>y) and x<(bx-ax)*(y-ay)/(by-ay)+ax:result=not result
 return result

def on_floor(p):return any(inside(p,poly) for poly in floors.values())
def distance(p,a,b):
 dx,dy=b[0]-a[0],b[1]-a[1]; t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/(dx*dx+dy*dy)))
 return math.dist(p,(a[0]+t*dx,a[1]+t*dy))
edges=[(a,b) for polygon in floors.values() for a,b in zip(polygon,polygon[1:]+polygon[:1])]
def floor_distance(p):return min(distance(p,a,b) for a,b in edges)
# Large stone floors remain separate, independently movable assets at native-resolution scale.
for index,(cx,cy,width) in enumerate([(378,744,870),(869,626,810),(1225,515,990),(800,146,1080)]):
 height=width*frames['court']['region'][3]/frames['court']['region'][2]
 prop(f'CourtFloor{index+1}','court',(cx*3,cy*3+height/2),width,flat=True)
for key,p in [('camp1',(625,669)),('camp2',(1027,387)),('camp3',(1382,147))]:
 prop(key,'camp',(p[0]*3,p[1]*3),240)
 for part,point,size in [('LeftPole',(-90,-10),(16,16)),('RightPole',(90,-45),(16,16)),('Bedding',(0,-65),(90,35))]:
  lines.extend(['',f'[node name="{part}" type="Node2D" parent="World_{key}"]','script = ExtResource("2")','category = "obstacle"','obstacle_kind = "wall"',f'position = {vec(point)}',f'size = {vec(size)}','body_height = 80.0'])
for index,p in enumerate([(170,823),(448,153),(1295,178)]):
 prop(f'Gateway{index+1}','gateway',(p[0]*3,p[1]*3),240)
 if index==0:lines.extend(['mirror_art = true','depth_offset = -150'])
 for part,point in [('LeftPost',(-72,-8)),('RightPost',(72,-60))]:
  lines.extend(['',f'[node name="{part}" type="Node2D" parent="World_Gateway{index+1}"]','script = ExtResource("2")','category = "obstacle"','obstacle_kind = "wall"',f'position = {vec((-point[0],point[1]) if index==0 else point)}','size = Vector2(28, 24)','body_height = 220.0'])
# The boundary walls stop at real route connections; each piece is an editable scene instance.
wall_count=0
for name in ['第一庭院','第二庭院','第三庭院','终场石台','碑林','回血祭坛']:
 polygon=floors[name]
 for a,b in zip(polygon,polygon[1:]+polygon[:1]):
  length=math.dist(a,b); dx,dy=(b[0]-a[0])/length,(b[1]-a[1])/length
  nx,ny=dy,-dx
  m=((a[0]+b[0])/2,(a[1]+b[1])/2)
  if not inside((m[0]-nx*8,m[1]-ny*8),polygon):nx,ny=-nx,-ny
  for j in range(max(1,round(length/125))):
   t=(j+.5)/max(1,round(length/125)); p=(a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t)
   if on_floor((p[0]+nx*60,p[1]+ny*60)):continue
   p=(p[0]+nx*48,p[1]+ny*48)
   wall_count+=1
   key='pillar' if abs(dy)>abs(dx)*1.6 else 'wall_east' if dx*dy>0 else 'wall_west'
   prop(f'Boundary{wall_count}',key,p,58 if key=='pillar' else 150,solid=True,size=(34,26),kind='wall')
for index,entry in enumerate(data['obstacles'][:3]):
 x,y=entry['p']; w,h=entry['size']; span=max(w,h)*3; n=math.ceil(span/65)
 for j in range(n):
  d=-span/2+(j+.5)*span/n
  prop(f'Seal{index+1}_{j}','wall_east',(x*3+(d if w>h else 0),y*3+(d if h>w else 0)),115,stage=index)
# Static forest dressing is authored once and saved as nodes, not generated at runtime.
rng=random.Random(1021)
for y in range(120,3050,185):
 for x in range(120,4550,185):
  p=(x+rng.uniform(-55,55),y+rng.uniform(-55,55))
  if on_floor(p) or inside(p,river) or floor_distance(p)<110:continue
  if 1600<p[0]<2600 and 800<p[1]<1650:continue
  key='tree_red' if rng.random()<.25 else 'tree_green'
  prop(f'Tree{count}',key,p,rng.uniform(260,345),solid=True,size=(48,32),kind='tree')
for index in range(300):
 p=(rng.uniform(80,4530),rng.uniform(80,3000))
 if on_floor(p) or inside(p,river):continue
 if 1700<p[0]<2500 and 850<p[1]<1550:continue
 key='ferns' if index%3 else 'grass'
 prop(f'Understory{index}',key,p,rng.uniform(85,145))
for index in range(65):
 y=50+index*46; near=min(river[1:-1],key=lambda p:abs(p[1]-y))
 p=(near[0]+rng.uniform(-30,80),y)
 if on_floor(p):continue
 prop(f'ShoreRock{index}','rocks',p,rng.uniform(140,220),solid=True,size=(45,28),kind='wall')
for index,p in enumerate([(300,350),(379,358),(279,372)]):prop(f'SteleGroup{index}','stele',(p[0]*3,p[1]*3),110,solid=True,size=(30,26),kind='wall')
for index,p in enumerate([(237,722),(526,683),(719,620),(981,584),(1093,435),(1347,447),(618,119),(944,154),(675,227),(888,228),(1288,733)]):
 prop(f'FirePillar{index}','pillar',(p[0]*3,p[1]*3),60,solid=True,size=(28,24),kind='brazier')
args.output.write_text('\n'.join(lines)+'\n')
print(json.dumps({'props':count,'boundary_walls':wall_count,'world':[4608,3072],'output':str(args.output)}))
