"""AI-authored Thor pilot: rebuild editable Godot tracks, without touching live Boss."""
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).parent
parts = json.loads((HERE / 'bindings.json').read_text())['parts']
clips = json.loads((HERE / 'clips.json').read_text())
paths = {}

def node_path(name):
    if name not in paths:
        parent = parts[name]['parent']
        paths[name] = (node_path(parent) + '/' if parent else '') + name
    return paths[name]

def number(value):
    return f'{value:.7f}'.rstrip('0').rstrip('.') or '0'

def vector(value):
    return f'Vector2({number(value[0])}, {number(value[1])})'

out = ['[gd_scene format=3]', '', '[ext_resource type="Script" path="res://scripts/presentation/thor_rig_pilot.gd" id="script"]']
for name in parts:
    out.append(f'[ext_resource type="Texture2D" path="res://assets/boss/thor-puppet-v1/{name}.tres" id="{name}"]')
# All properties have explicit baseline keys in every clip, so random seeking is deterministic.
properties = sorted({prop for clip in clips.values() for prop in clip['tracks']})
for name, clip in clips.items():
    out += ['', f'[sub_resource type="Animation" id="{name}"]', f'resource_name = "{name}"', f'length = {number(clip["length"])}']
    if name == 'idle':
        out.append('loop_mode = 1')
    for i, prop in enumerate(properties):
        part, field = prop.split(':')
        base = parts[part]['pivot']
        parent = parts[part]['parent']
        if parent:
            base = [a-b for a,b in zip(base,parts[parent]['pivot'])]
        keys = clip['tracks'].get(prop, [[0, [0,0] if field == 'position' else 0]])
        values = [vector([base[j]+v[j] for j in (0,1)]) if field == 'position' else number(math.radians(v)) for _,v in keys]
        out += [f'tracks/{i}/type = "value"', f'tracks/{i}/path = NodePath("{node_path(part)}:{field}")', f'tracks/{i}/interp = 1', f'tracks/{i}/loop_wrap = false', f'tracks/{i}/keys = {{', '"times": PackedFloat32Array('+', '.join(number(t) for t,_ in keys)+'),', '"transitions": PackedFloat32Array('+', '.join('1' for _ in keys)+'),', '"update": 0,', '"values": ['+', '.join(values)+']', '}']
out += ['', '[sub_resource type="AnimationLibrary" id="library"]', '_data = {', ',\n'.join(f'&"{n}": SubResource("{n}")' for n in clips), '}', '', '[node name="ThorRigPilot" type="Node2D"]', 'script = ExtResource("script")']
# Topological insertion keeps every parent defined before its children.
pending = list(parts)
done = set()
while pending:
    for name in pending[:]:
        p = parts[name]
        if p['parent'] and p['parent'] not in done:
            continue
        parent = node_path(p['parent']) if p['parent'] else '.'
        pos = p['pivot']
        if p['parent']:
            pos = [a-b for a,b in zip(pos, parts[p['parent']]['pivot'])]
        out += ['', f'[node name="{name}" type="Node2D" parent="{parent}"]', f'position = {vector(pos)}', '', f'[node name="Art" type="Sprite2D" parent="{node_path(name)}"]', f'texture = ExtResource("{name}")', 'centered = false', f'offset = {vector(p["sprite_offset"])}', f'rotation = {number(p["sprite_rotation"])}', f'scale = {vector([p["sprite_scale"]]*2)}', f'z_index = {p["z"]}', 'texture_filter = 4']
        pending.remove(name)
        done.add(name)
out += ['', '[node name="AnimationPlayer" type="AnimationPlayer" parent="."]', 'callback_mode_process = 2', 'libraries = {&"": SubResource("library")}', '']
(ROOT / 'godot/scenes/prototypes/thor_rig_pilot.tscn').write_text('\n'.join(out))
print('Rebuilt thor_rig_pilot.tscn from bindings.json + clips.json')
