"""首次创建可编辑首关场景；已存在时停止，后续布局由 Godot 编辑器维护。"""
import json
import math
from pathlib import Path

root = Path(__file__).resolve().parents[2]
destination = root / "godot/scenes/tanggu_first_level_map.tscn"
if destination.exists():
    raise SystemExit("首关地图已存在，保留编辑器结果；请直接编辑场景。")
source = json.loads((root / "output/level-design/tanggu-first-level-v0.1/map.json").read_text())
lines = ['[gd_scene load_steps=4 format=3]',
         '[ext_resource type="Script" path="res://scripts/world/map_definition.gd" id="1"]',
         '[ext_resource type="Script" path="res://scripts/world/map_item.gd" id="2"]',
         '[ext_resource type="Script" path="res://scripts/world/first_level_landmark.gd" id="3"]',
         '[node name="TangguFirstLevelMap" type="Node2D"]', 'script = ExtResource("1")',
         'world_size = Vector2(5600, 3600)',
         'floor_polygon = PackedVector2Array(0, 0, 5600, 0, 5600, 3600, 0, 3600)']


def value(item):
    if isinstance(item, tuple):
        return f"Vector2({item[0]:.3f}, {item[1]:.3f})"
    return json.dumps(item, ensure_ascii=False)


def node(name, category, position, parent=".", **properties):
    lines.extend([f'[node name="{name}" type="Node2D" parent="{parent}"]',
                  'script = ExtResource("2")', f'position = {value(position)}',
                  f'category = "{category}"'])
    lines.extend(f"{key} = {value(item)}" for key, item in properties.items())


node("PlayerSpawn", "spawn", (550, 2930))
for area in source["nodes"]:
    if area["kind"] == "gate":
        continue
    node("Floor_" + area["id"], "road", (area["x"], area["y"]),
         size=(1280 if area["id"]=="boss" else area["w"], area["h"]), label=area["name"], region=area["name"],
         terrain_material="stone" if area["kind"] in ("combat", "boss", "exit") else "path", priority=2)
    if area["kind"] in ("camp", "boss", "exit"):
        lines.extend([f'[node name="Landmark_{area["id"]}" type="Node2D" parent="."]',
                      'script = ExtResource("3")', f'position = {value((area["x"],area["y"]))}',
                      f'title = {value(area["name"])}',
                      f'subtitle = {value("营地位置" if area["kind"] == "camp" else "终场空间" if area["kind"] == "boss" else "战后离场空间")}',
                      f'radius = {220 if area["kind"] == "boss" else 80}'])

# 内侧门采用现有南侧开启合同；回程路径在门南侧折返，避免横向门误用 y 方向规则。
for route in source["routes"]:
    points = route["points"]
    if route["from"] == "c1" and route["to"] == "stele":
        points = [[2240,2940],[2240,2310],[2090,2030],[1720,1860],[1450,1760]]
    elif route["from"] == "heal" and route["to"] == "gate":
        points = [[4570,2490],[4430,2930],[3840,3440],[2680,3440],[2680,3260]]
    elif route["from"] == "gate":
        points = [[2680,3260],[2680,3040],[2450,2940],[2240,2940]]
    for index, (a, b) in enumerate(zip(points, points[1:])):
        # 短道路矩形拼接，保持 Inspector 可编辑，不新增运行时多边形碰撞体系。
        steps = max(1, math.ceil(math.dist(a,b)/150))
        for step in range(steps+1):
            t = step/steps
            node(f"Path_{route['from']}_{route['to']}_{index}_{step}", "road",
                 (a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t),
                 size=(280,280), label="主路" if route["kind"]=="main" else "探索通路",
                 region="汤谷通路", priority=0)
    if route["kind"] == "main":
        for index, (x,y) in enumerate(points):
            # 三处战斗内的铺路不穿实体；道路连通本身不依赖这一条装饰线。
            node(f"Route_{route['from']}_{index}", "route", (x,y))

node("Camp1NorthThreshold","road",(2370,2790),size=(120,130),label="营地北出口",region="第一营地",priority=1)

for index, (x,y,w,h,_rotation) in enumerate(source["obstacles"]):
    node(f"Cover{index+1}", "obstacle", (x,y), size=(w,h),
         body_height=95, obstacle_kind="wall")

for index, area in enumerate(a for a in source["nodes"] if a["kind"]=="combat"):
    name = f"Encounter{index+1}"
    node(name,"encounter",(area["x"],area["y"]),label=area["name"])
    for enemy, (x,y,role) in enumerate(area["enemies"]):
        node(f"Enemy{enemy+1}","enemy",(x-area["x"],y-area["y"]),parent=name,
             appearance="wood" if role=="elite" else role)

for index, (x,y,w,h) in enumerate([(1970,2870,36,460),(3400,2030,40,700),(4690,780,560,50)]):
    node(f"EncounterSeal{index+1}","obstacle",(x,y),size=(w,h),
         body_height=120,obstacle_kind="wall",opens_after_encounter=index)

for name,kind,position,size,point in [
    ("Stele","stele",(1450,1690),(80,52),(1450,1810)),
    ("HealingAltar","altar",(4570,2390),(100,70),(4570,2530)),
    ("ReturnGate","gate",(2680,3260),(320,45),(2680,3340)),
]:
    node(name,"obstacle",position,size=size,body_height=115,obstacle_kind=kind)
    node(name+"Interaction","interaction",point,interaction_id=kind)

destination.write_text("\n".join(lines).replace("\n[node", "\n\n[node")+"\n")
print("首关场景首次生成：",destination)
