"""One-time room authoring. Refuses to overwrite editor-owned room scenes."""
import argparse
import math
from pathlib import Path

ROOMS={
 'entry':('汤谷入口','safe',[('court1','entry',1270,550)],0),
 'court1':('日鸟石庭','combat',[('entry','court1',170,550),('stele','court1',1270,370),('altar','court1',1270,700)],3),
 'stele':('碑林遗径','explore',[('court1','stele',170,550),('court2','stele',1270,550)],0),
 'altar':('祭火营地','safe',[('court1','altar',170,550),('court2','altar',1270,550)],0),
 'court2':('扶桑残庭','combat',[('stele','court2',170,370),('altar','court2',170,700),('court3','court2',1270,550)],4),
 'court3':('赤日祭庭','combat',[('court2','court3',170,550),('end','court3',1270,550)],5),
 'end':('汤谷出口','safe',[('court3','end',170,550)],0),
}
POLYGON='140, 280, 300, 170, 1140, 170, 1300, 280, 1300, 790, 1140, 900, 300, 900, 140, 790'
ASSETS=['tree_green','tree_red','rocks','ferns','grass','wall_east','wall_west','pillar','court','stele','altar','camp','gateway','root']

def build(key):
 title,task,doors,count=ROOMS[key]
 lines=['[gd_scene load_steps=22 format=3]']
 for ident,kind,path in [('map','Script','scripts/world/room_map.gd'),('item','Script','scripts/world/map_item.gd'),('prop','PackedScene','scenes/world/environment_prop.tscn'),('portal','PackedScene','scenes/world/room_portal.tscn'),('surface','Script','scripts/world/terrain_surface.gd'),('forest','Texture2D','assets/world/forest.png'),('path','Texture2D','assets/world/path.png')]+[(a,'Texture2D','assets/world/'+a+'.tres') for a in ASSETS]:
  lines.append(f'[ext_resource type="{kind}" path="res://{path}" id="{ident}"]')
 lines += [f'[node name="{key}" type="Node2D"]','script = ExtResource("map")',f'room_id = "{key}"',f'room_title = "{title}"',f'objective = "{task}"','world_size = Vector2(1440,1040)','floor_polygon = PackedVector2Array(0,0,1440,0,1440,1040,0,1040)']
 lines += ['[node name="Ground" type="Node2D" parent="."]','script = ExtResource("surface")','path_texture = ExtResource("path")']
 for n,poly,tex,z in [('Forest','0,0,1440,0,1440,1040,0,1040','forest',-100),('RoomFloor',POLYGON,'path',-50)]:
  lines += [f'[node name="{n}" type="Polygon2D" parent="Ground"]',f'z_index = {z}',f'polygon = PackedVector2Array({poly})',f'texture = ExtResource("{tex}")','texture_repeat = 2']
 lines += ['[node name="Walkable" type="Node2D" parent="."]','visible = false','[node name="Floor" type="Polygon2D" parent="Walkable"]',f'polygon = PackedVector2Array({POLYGON})']
 def item(name,x,y,category,size='40,30',parent='.',extra=()):
  lines.extend([f'[node name="{name}" type="Node2D" parent="{parent}"]',f'position = Vector2({x},{y})','script = ExtResource("item")',f'category = "{category}"',f'size = Vector2({size})',*extra])
 def prop(name,x,y,asset,width,category='ground',size='40,30',extra=()):
  lines.extend([f'[node name="{name}" parent="." instance=ExtResource("prop")]',f'position = Vector2({x},{y})',f'category = "{category}"',f'size = Vector2({size})',f'texture_asset = ExtResource("{asset}")',f'render_width = {float(width)}',*extra])
 item('Metrics',720,535,'road','1160,730',extra=[f'region = "{title}"'])
 item('PlayerSpawn',400 if key=='entry' else 310,650 if key=='entry' else 525,'spawn')
 width=1000 if task=='combat' else 850
 prop('CourtFloor',720,550+width*960/1546/2,'court',width,extra=['flat = true'])
 if count:
  item('Encounter',650,550,'encounter',extra=[f'label = "{title}"'])
  for n in range(count):
   item('Enemy'+str(n),80+(n%3)*100,-80+(n//3)*150,'enemy',parent='Encounter',extra=[f'appearance = "{["bird","paper","wood"][n%3]}"'])
 if key=='stele':
  prop('Stele',720,200,'stele',180,'obstacle','56,42',extra=['obstacle_kind = "stele"','body_height = 170.0'])
  item('ReadStele',0,85,'interaction',parent='Stele',extra=['interaction_id = "stele"'])
 if key=='altar':
  prop('Altar',720,200,'altar',190,'obstacle','100,50',extra=['obstacle_kind = "altar"','body_height = 100.0'])
  item('Heal',0,105,'interaction',parent='Altar',extra=['interaction_id = "altar"'])
  prop('Camp',1030,350,'camp',220)
  for n,(x,y,w,h) in enumerate([(-76,0,26,24),(83,-18,26,24),(5,-15,100,40)]):
   item('CampFoot'+str(n),x,y,'obstacle',f'{w},{h}',parent='Camp')
 if key=='entry':
  prop('StartArch',300,740,'gateway',220,extra=['mirror_art = true','depth_offset = -120'])
  item('LeftPost',65,-5,'obstacle','34,30',parent='StartArch')
  item('RightPost',-65,-50,'obstacle','34,30',parent='StartArch')
 for n in range(18):
  side=n%2; row=n//2
  x=45 if side==0 else 1395; y=60+row*120
  prop('Tree'+str(n),x,y,'tree_red' if (n+len(key))%5==0 else 'tree_green',260+12*(n%4),'obstacle','42,30',extra=['obstacle_kind = "tree"'])
 for n in range(8):
  x=360+(n%4)*235; y=130 if n<4 else 950
  prop('Boundary'+str(n),x,y,'wall_east' if n%2 else 'wall_west',180,'obstacle','75,24',extra=['obstacle_kind = "wall"'])
 for n in range(12):
  x=170+(n%6)*225; y=95 if n<6 else 1020
  prop('Groundcover'+str(n),x,y,'grass' if n%2 else 'ferns',145)
 for n,(x,y) in enumerate([(330,260),(1110,845)]):
  prop('FirePillar'+str(n),x,y,'pillar',58,'obstacle','28,24',extra=['obstacle_kind = "brazier"','body_height = 150.0'])
 if key=='end': prop('FusangRoot',1050,380,'root',410,'obstacle','210,80',extra=['obstacle_kind = "root"','body_height = 250.0'])
 lines.append('[node name="Doors" type="Node2D" parent="."]')
 for target,back,x,y in doors:
  name=target; sign=1 if x<720 else -1
  lines += [f'[node name="{name}" parent="Doors" instance=ExtResource("portal")]',f'position = Vector2({x},{y})',f'portal_id = "{name}"',f'target_room = "{target}"',f'target_portal = "{back}"',f'target_title = "{ROOMS[target][0]}"']
  if sign<0:
   lines += [f'[node name="Frame" parent="Doors/{name}" index="0"]','mirror_art = true',f'[node name="LeftPost" parent="Doors/{name}" index="2"]','position = Vector2(65,-5)',f'[node name="RightPost" parent="Doors/{name}" index="3"]','position = Vector2(-65,-50)']
  for marker,index,offset in [('Approach',4,100),('Arrival',5,140)]:
   lines += [f'[node name="{marker}" parent="Doors/{name}" index="{index}"]',f'position = Vector2({sign*offset},-25)']
  lines.append(f'[editable path="Doors/{name}"]')
 return '\n'.join(lines)+'\n'

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
 args.output.mkdir(parents=True,exist_ok=False)
 for key in ROOMS: (args.output/(key+'.tscn')).write_text(build(key))
 print('Authored seven editable rooms:',args.output)
