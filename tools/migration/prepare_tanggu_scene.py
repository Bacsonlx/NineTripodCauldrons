"""One-time migration of the frozen layout to editor-owned Godot nodes."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
source = root / "godot/tests/fixtures/tanggu.json"
target = root / "godot/scenes/tanggu_map.tscn"
if target.exists():
    raise SystemExit("tanggu_map.tscn already exists; preserve editor-authored changes")
layout = json.loads(source.read_text())
lines = ['[gd_scene load_steps=3 format=3]', '', '[ext_resource type="Script" path="res://scripts/world/map_definition.gd" id="1"]', '[ext_resource type="Script" path="res://scripts/world/map_item.gd" id="2"]', '', '[node name="TangguMap" type="Node2D"]', 'script = ExtResource("1")']

def node(name, category, point, parent=".", **fields):
    lines.extend(['', f'[node name="{name}" type="Node2D" parent="{parent}"]', 'script = ExtResource("2")', f'position = Vector2({point["x"]}, {point["y"]})', f'category = "{category}"'])
    for key, value in fields.items():
        literal = f"Vector2({value[0]}, {value[1]})" if isinstance(value, tuple) else json.dumps(value, ensure_ascii=False)
        lines.append(f"{key} = {literal}")

node("PlayerSpawn", "spawn", layout["spawn"])
for index, area in enumerate(layout["walkableAreas"]):
    node(f"Road{index+1}", "road", {"x":(area["left"]+area["right"])/2,"y":(area["top"]+area["bottom"])/2}, size=(area["right"]-area["left"],area["bottom"]-area["top"]), label=area["name"], region=area["region"], terrain_material=area["material"], priority=area["priority"])
for index, item in enumerate(layout["obstacles"]):
    fields = {"size":(item["halfWidth"]*2,item["halfHeight"]*2),"body_height":item["height"],"obstacle_kind":item["kind"]}
    if "markerOffsetY" in item: fields["marker_offset_y"]=item["markerOffsetY"]
    node(f"Obstacle{index+1}","obstacle",item,**fields)
for index, group in enumerate(layout["encounters"]):
    name=f"Encounter{index+1}"
    node(name,"encounter",group,label=group["landmark"])
    for number, enemy in enumerate(group["enemies"]): node(f"Enemy{number+1}","enemy",{"x":enemy["x"]-group["x"],"y":enemy["y"]-group["y"]},parent=name,appearance=enemy["appearance"])
for item in layout["exploration"]: node(item["id"].title()+"Interaction","interaction",item,interaction_id=item["id"])
for index, item in enumerate(layout["pillars"]): node(f"Pillar{index+1}","pillar",item)
for index, item in enumerate(layout["mainRoute"]): node(f"Route{index+1}","route",item)
for index, item in enumerate(layout["groundPatches"]): node(f"Ground{index+1}","ground",item,size=(item["width"],item["height"]))
target.write_text("\n".join(lines)+"\n")
print(target.relative_to(root))
