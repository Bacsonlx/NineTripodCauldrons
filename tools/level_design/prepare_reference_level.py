"""One-off scene authoring from art-pixel traces; never overwrite an editor-owned scene."""
import argparse
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
if args.output.exists():
    raise SystemExit('目标已存在；请生成到新路径并人工合并，保留编辑器修改。')
data = json.loads((root / 'tools/level_design/tanggu_reference_layout.json').read_text())
s = data['scale']
def vec(p): return f'Vector2({p[0]*s:g}, {p[1]*s:g})'
def poly(points): return 'PackedVector2Array('+', '.join(f'{v*s:g}' for p in points for v in p)+')'
lines = ['[gd_scene load_steps=5 format=3]',
'[ext_resource type="Script" path="res://scripts/world/first_level_map.gd" id="1"]',
'[ext_resource type="Script" path="res://scripts/world/map_item.gd" id="2"]',
'[ext_resource type="Texture2D" path="res://assets/first_level/tanggu-reference.png" id="3"]',
'[ext_resource type="Script" path="res://scripts/world/reference_occluder.gd" id="4"]',
'','[node name="TangguFirstLevelMap" type="Node2D"]','script = ExtResource("1")',
f'world_size = {vec(data["imageSize"])}',f'floor_polygon = {poly([[0,0],[1536,0],[1536,1024],[0,1024]])}',
'','[node name="ArtPlate" type="Sprite2D" parent="."]','z_index = -100','texture = ExtResource("3")','centered = false',f'scale = Vector2({s}, {s})','texture_filter = 2',
'','[node name="Walkable" type="Node2D" parent="."]']
for name, points in data['floors'].items():
    lines += ['',f'[node name="{name}" type="Polygon2D" parent="Walkable"]',f'polygon = {poly(points)}','color = Color(0.1, 0.8, 0.6, 0.2)']
    xs,ys=zip(*points)
    lines += ['',f'[node name="Region_{name}" type="Node2D" parent="."]','script = ExtResource("2")','category = "road"',f'label = "{name}"',f'region = "{name}"',f'position = {vec([(min(xs)+max(xs))/2,(min(ys)+max(ys))/2])}',f'size = {vec([max(xs)-min(xs),max(ys)-min(ys)])}']
def item(name, p, category, more=(), parent='.'):
    lines.extend(['',f'[node name="{name}" type="Node2D" parent="{parent}"]','script = ExtResource("2")',f'position = {vec(p)}',f'category = "{category}"',*more])
item('PlayerSpawn',data['spawn'],'spawn')
for i, encounter in enumerate(data['encounters']):
    name=f'Encounter{i+1}'
    item(name,encounter['center'],'encounter',[f'label = "{encounter["name"]}"'])
    for j,(x,y,appearance) in enumerate(encounter['enemies']):
        item(f'Enemy{j+1}',[x-encounter['center'][0],y-encounter['center'][1]],'enemy',[f'appearance = "{appearance}"'],name)
for obstacle in data['obstacles']:
    more=[f'obstacle_kind = "{obstacle["kind"]}"',f'size = {vec(obstacle["size"])}','body_height = 100.0']
    if 'stage' in obstacle: more.append(f'opens_after_encounter = {obstacle["stage"]}')
    item(obstacle['name'],obstacle['p'],'obstacle',more)
for name in ['stele','altar','gate']:
    item(f'Interact_{name}',data['landmarks'][name],'interaction',[f'interaction_id = "{name}"'])
route=[data['spawn'],data['encounters'][0]['center'],data['landmarks']['camp1'],data['encounters'][1]['center'],data['landmarks']['camp2'],data['encounters'][2]['center'],data['landmarks']['camp3'],data['landmarks']['boss'],data['landmarks']['exit']]
for i, p in enumerate(route): item(f'Route{i}',p,'route')
for name,p in data['landmarks'].items():
    lines += ['',f'[node name="Landmark_{name}" type="Marker2D" parent="."]',f'position = {vec(p)}']
lines += ['','[node name="Foreground" type="Node2D" parent="."]']
for mask in data['occluders']:
    lines += ['',f'[node name="{mask["name"]}" type="Polygon2D" parent="Foreground"]','script = ExtResource("4")',f'z_index = {mask["foot"]*s}',f'polygon = {poly(mask["polygon"])}','texture = ExtResource("3")','texture_filter = 2',f'uv = '+ 'PackedVector2Array('+', '.join(str(v) for p in mask['polygon'] for v in p)+')']
args.output.write_text('\n'.join(lines)+'\n')
print(args.output)
