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

def legs(col, row, box, mask, offset):
    # Bronze belt buckle lies at the top of every lower-body pose.
    left, top = offset
    samples = [(x, y) for y in range(min(28, mask.height)) for x in range(mask.width) if mask.getpixel((x,y))]
    belt_y = min(y for x,y in samples)
    belt_xs = [x for x,y in samples if y <= belt_y + 8]
    ax = left + (min(belt_xs) + max(belt_xs))/2
    return ax, top + belt_y + 5 + 30/0.235

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
describe('idle','child-idle-legs-v1.png',[0,543,1086,1629,2172],[0,724],lambda c,r,b,m,o: ((b[0]+b[2])/2,b[1]+8+30/0.07))
describe('run','child-run-legs-v1.png',[140,470,770,1110,1400],[[0,150,281,419,542,680,827,1024],[0,150,282,419,543,681,828,1024],[0,151,282,419,542,680,828,1024],[0,154,283,419,542,677,827,1024]],legs)
describe('enemy','shadow-puppet-v2.png',[0,245,480,710,911,1208,1420,1659],[0,249,490,714,948],lambda c,r,b,m,o: ([122,360,600,830,1055,1305,1550][c],[230,470,696,930][r]))
result['enemy']['frames'] = [result['enemy']['frames'][facing*7+action] for action in range(7) for facing in range(4)]
result['enemy']['scale'] = 0.46
describe('skills','child-skills-upper-v1.png',[0,353,630,954,1254],[[0,360,667,908,1254],[0,360,668,924,1254],[0,360,674,919,1254],[0,367,676,940,1254]],upper)
# Prop layout is intentionally irregular; these splits were checked on the actual output.
describe('props','tanggu-props-v1.png',[0,486,1055,1536],[0,540,1024],lambda c,r,b,m,o: ((b[0]+b[2])/2,b[3]-4))
result['failed']['scale'] = 58 / max(f['height'] for f in result['failed']['frames'])
(root/'atlases.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('Wrote inspected atlas regions:', {k:len(v['frames']) for k,v in result.items()})
