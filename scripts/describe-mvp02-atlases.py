"""Describe inspected sprite regions without editing the generated PNG pixels (requires Pillow)."""
import json
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1] / 'assets' / 'mvp02'
result = {}

def describe(name, file, xs, ys, anchor):
    image = Image.open(root / file)
    alpha = image.getchannel('A')
    frames = []
    row_count = len(ys[0]) - 1 if isinstance(ys[0],list) else len(ys) - 1
    for row in range(row_count):
        for col, (left, right) in enumerate(zip(xs, xs[1:])):
            bounds_y = ys[col] if isinstance(ys[0],list) else ys
            top, bottom = bounds_y[row:row+2]
            mask = alpha.crop((left, top, right, bottom)).point(lambda a: 255 if a > 160 else 0)
            bounds = mask.getbbox()
            if bounds is None:
                raise ValueError(f'Empty frame: {file} {row} {col}')
            x, y, r, b = bounds
            x += left; y += top; r += left; b += top
            # Keep feathered edges, with a strictly separate region for every sprite.
            x = max(left, x - 3); y = max(top, y - 3)
            r = min(right, r + 3); b = min(bottom, b + 3)
            ax, ay = anchor(col, row, (x, y, r, b), mask, (left, top))
            frames.append(dict(name=f'{name}-{row}-{col}', x=x, y=y, width=r-x, height=b-y,
                               originX=(ax-x)/(r-x), originY=(ay-y)/(b-y)))
    result[name] = dict(source=file, size=list(image.size), frames=frames)

def upper(col, row, box, mask, offset):
    # Individually inspected belt centers; the floating scarf is not a waist anchor.
    anchors = [
        [(185,310),(476,310),(770,311),(1100,313)],
        [(229,619),(474,622),(772,621),(1100,625)],
        [(217,886),(477,896),(769,885),(1103,895)],
        [(222,1157),(477,1156),(771,1156),(1102,1155)],
    ]
    return anchors[row][col]

describe('failed','child-failed-v1.png',[0,568,1100,1671,2172],[0,724],lambda c,r,b,m,o: ((b[0]+b[2])/2,b[3]-3))
def lower_anchor(col, row, box, mask, offset):
    left, top = offset
    strong = mask.getbbox()
    belt_top = strong[1]
    xs = [x for y in range(belt_top, belt_top + 14) for x in range(mask.width) if mask.getpixel((x,y))]
    return left + (min(xs) + max(xs))/2, box[3]-3

describe('lower','child-lower-unified-v2.png',[0,300,524,784,1024],[0,205,390,576,772,970,1174,1415],lower_anchor)
for f in result['lower']['frames']:
    # Upper-body origin is the lower edge of its belt. Hide the lower image's
    # duplicate belt and join the continuous tunic hem at that exact edge.
    belt_bottom = f['y'] + 3 + 22
    foot = f['y'] + f['originY'] * f['height']
    origin_x = f['originX'] * f['width']
    bottom = f['y'] + f['height']
    f['y'] = belt_bottom - 2
    f['height'] = bottom - f['y']
    f['originX'] = origin_x / f['width']
    f['originY'] = (foot-f['y'])/f['height']
    f['scale'] = 30 / (foot-belt_bottom)
result['lower']['runFramesPerDirection'] = 6
describe('enemy','shadow-puppet-v2.png',[0,245,480,710,911,1208,1420,1659],[0,249,490,714,948],lambda c,r,b,m,o: ([122,360,600,830,1055,1305,1550][c],[230,470,696,930][r]))
result['enemy']['frames'] = [result['enemy']['frames'][facing*7+action] for action in range(7) for facing in range(4)]
result['enemy']['scale'] = 0.46

def enemy_foot(col, row, box, mask, offset):
    left, top = offset
    foot_y = box[3]-3
    xs = [x for y in range(max(0,foot_y-top-18),min(mask.height,foot_y-top+1)) for x in range(mask.width) if mask.getpixel((x,y))]
    return left+(min(xs)+max(xs))/2, foot_y

for key, file in [('enemyPaper','shadow-paper-v2.png'),('enemyWood','shadow-wood-v2.png')]:
    describe(key,file,[0,245,480,710,911,1208,1420,1659],[0,249,490,714,948],enemy_foot)
    result[key]['frames'] = [result[key]['frames'][facing*7+action] for action in range(7) for facing in range(4)]
    result[key]['scale'] = 85/max(f['height'] for f in result[key]['frames'][:4])
describe('skills','child-skills-upper-v1.png',[0,353,630,954,1254],[[0,360,667,908,1254],[0,360,668,924,1254],[0,360,674,919,1254],[0,367,676,940,1254]],upper)
# Prop layout is intentionally irregular; these splits were checked on the actual output.
describe('props','tanggu-props-v1.png',[0,486,1055,1536],[0,540,1024],lambda c,r,b,m,o: ((b[0]+b[2])/2,b[3]-4))
result['failed']['scale'] = 58 / max(f['height'] for f in result['failed']['frames'])
(root/'atlases.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('Wrote inspected atlas regions:', {k:len(v['frames']) for k,v in result.items()})
