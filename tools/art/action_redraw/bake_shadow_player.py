"""Bake painted puppet parts into registered player layers; no runtime skeleton.

Art is painted from the accepted CHR-001 identity. This is offline articulation of
existing raster parts, not generated video or hand-drawn replacement art.
"""
import hashlib
import json
import math
from pathlib import Path
import shutil

from PIL import Image, ImageDraw, ImageEnhance

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'assets/characters/child-shadow-v1'
DEST = ROOT / 'godot/assets/characters/child-shadow-v1'
REVIEW = ROOT / 'output/art/CHR-001/2026-11-13-integrated-v1/review'
SIZE = 256
FOOT = (128, 224)
WAIST = (128, 174)
SCALE = 0.75
COUNT = 16


def cell(image, index):
    w, h = image.size
    # Both 1254px source sheets have a clear horizontal gap at y=645;
    # the front tunic ends at y=626, so an equal grid would lose edge padding.
    top, bottom = (0, 645) if index < 2 else (645, h)
    part = image.crop((index % 2 * w // 2, top, (index % 2 + 1) * w // 2, bottom))
    box = part.getchannel('A').point(lambda a: 255 if a > 16 else 0).getbbox()
    if box is None or min(box[0], box[1], part.width-box[2], part.height-box[3]) < 8:
        raise ValueError(f'Part {index} empty or cut by cell edge')
    return part.crop(box)


def height(image, pixels):
    return image.convert('RGBa').resize((round(image.width * pixels / image.height), pixels),
                                        Image.Resampling.LANCZOS).convert('RGBA')


def place(canvas, image, pivot, point, angle=0.0):
    c, s = math.cos(angle), math.sin(angle)
    tx, ty = point[0]-c*pivot[0]+s*pivot[1], point[1]-s*pivot[0]-c*pivot[1]
    transformed = image.convert('RGBa').transform(canvas.size, Image.Transform.AFFINE,
        (c, s, -c*tx-s*ty, -s, c, s*tx-c*ty), Image.Resampling.BICUBIC).convert('RGBA')
    canvas.alpha_composite(transformed)


def ik(origin, target, a, b, bend):
    dx, dy = target[0]-origin[0], target[1]-origin[1]
    length = max(abs(a-b)+0.01, min(math.hypot(dx, dy), a+b-0.01))
    heading = math.atan2(dy, dx)
    angle = heading + bend*math.acos(max(-1, min(1, (a*a+length*length-b*b)/(2*a*length))))
    joint = (origin[0]+a*math.cos(angle), origin[1]+a*math.sin(angle))
    return joint, angle, math.atan2(target[1]-joint[1], target[0]-joint[0])


def limb(canvas, image, origin, target, bend, horizontal=False, shade=1.0):
    if shade != 1:
        alpha = image.getchannel('A')
        image = ImageEnhance.Brightness(image).enhance(shade)
        image.putalpha(alpha)
    if horizontal:
        split, pad = round(image.width*0.56), 3
        first = image.crop((0, 0, split+pad, image.height))
        second = image.crop((split-pad, 0, image.width, image.height))
        a, b = split-2, image.width-split-2
        joint, t1, t2 = ik(origin, target, a, b, bend)
        place(canvas, first, (2, image.height/2), origin, t1)
        place(canvas, second, (pad, image.height/2), joint, t2)
    else:
        split, pad = image.height//2, 4
        first = image.crop((0, 0, image.width, split+pad))
        second = image.crop((0, split-pad, image.width, image.height))
        joint, t1, t2 = ik(origin, target, split, image.height-split-2, bend)
        place(canvas, first, (image.width/2, 0), origin, t1-math.pi/2)
        place(canvas, second, (image.width/2, pad), joint, t2-math.pi/2)


def blank():
    return Image.new('RGBA', (SIZE, SIZE))


def mirror(image, facing):
    # Mirror about the semantic root x=128, not the alpha bounding box.
    return image.transform(image.size, Image.Transform.AFFINE, (-1, 0, 256, 0, 1, 0)) if facing == 2 else image


def lower_frame(leg, facing, phase=None, crouch=0, move_facing=None):
    out = blank()
    side = facing in [0, 2]
    move_facing = facing if move_facing is None else move_facing
    bob = 0 if phase is None else -1.5*abs(math.sin(phase*2*math.pi))
    hips = [(124, 166+bob+crouch), (132, 166+bob+crouch)] if side else [(118, 166+bob+crouch), (138, 166+bob+crouch)]
    contacts = []
    for index, hip in enumerate(hips):
        if phase is None:
            target = (hip[0] + (3 if side else (-2 if index == 0 else 2)), 224)
            contact = True
        else:
            t = (phase + index*0.5) % 1
            if t < 0.2:
                stride, lift, contact = 18-36*t/0.2, 0, True
            else:
                u = (t-0.2)/0.8
                stride, lift, contact = -18+36*u, 14*math.sin(math.pi*u), False
            # Facing owns the body identity; translation owns stride direction.
            # Aiming right while moving left therefore runs backwards, without
            # turning the pelvis and shoes 180 degrees away from the torso.
            sign = -1 if move_facing in [2, 3] else 1
            target = (hip[0]+stride*sign, 224-lift) if move_facing in [0, 2] else (hip[0]+(-2 if index == 0 else 2), 224+stride*sign*0.20-lift)
            if facing == 2:
                target = (2*hip[0]-target[0], target[1])
        limb(out, leg, hip, target, -1 if side else (1 if index == 0 else -1), shade=0.86 if index == 0 else 1)
        contacts.append(contact)
    return mirror(out, facing), [128, 174+bob+crouch], contacts


def upper_frame(torso, arm, bow, facing, action, phase):
    out = blank()
    side = facing in [0, 2]
    front = facing == 1
    unarmed = action.endswith('-unarmed')
    action = action.removesuffix('-unarmed')
    shoulders = [(124, 148), (133, 150)] if side else [(115, 153), (141, 153)]
    if side:
        support, draw, angle = (141, 187), (139, 190), -0.12
    else:
        support, draw, angle = (109, 190), (147, 190), 0.0
    arrow = False
    aim = (188, 140) if side else ((128, 184) if front else (128, 94))
    if action in ['attack', 'pierce', 'rain']:
        key = min(phase, 7)
        strength = [0, 0.45, 0.8, 1, 1, 0.8, 0.35, 0][key]
        if action == 'rain':
            target_support, target_draw, raised = (136, 118), (127, 143), -math.pi/2
            aim = (136, 89)
        elif side:
            target_support, target_draw, raised = (165, 145), (137 if key < 4 else 131, 140), 0.0
        elif front:
            target_support, target_draw, raised = (128, 159), (128, 142), math.pi/2
        else:
            target_support, target_draw, raised = (128, 119), (128, 136), -math.pi/2
        support = tuple(a+(b-a)*strength for a, b in zip(support, target_support))
        draw = tuple(a+(b-a)*strength for a, b in zip(draw, target_draw))
        angle += (raised-angle)*strength
        arrow = key in [1, 2, 3]
    elif action == 'run':
        swing = math.sin(phase/COUNT*2*math.pi)*7
        support = (support[0]+swing, support[1]-abs(swing)*0.2)
        draw = (draw[0]-swing, draw[1])
        angle += swing*0.015
    elif action in ['hurt', 'dodge']:
        support, draw = ((145, 160), (126, 157)) if side else ((144, 158), (112, 157))
    limb(out, arm, shoulders[0], support, -1, horizontal=True, shade=0.85)
    pivot = (torso.width/2, torso.height-14)
    place(out, torso, pivot, WAIST)
    limb(out, arm, shoulders[1], draw, 1 if side else -1, horizontal=True)
    bow_pivot = (bow.width*0.78, bow.height/2)
    if not unarmed: place(out, bow, bow_pivot, support, angle)
    c, s = math.cos(angle), math.sin(angle)
    tips = [(support[0]+c*(-bow.width*0.60)-s*y, support[1]+s*(-bow.width*0.60)+c*y)
            for y in [-bow.height/2+2, bow.height/2-2]]
    ink = ImageDraw.Draw(out)
    string_point = draw if arrow else (support[0]-c*bow.width*0.65, support[1]-s*bow.width*0.65)
    if not unarmed: ink.line([tips[0], string_point, tips[1]], fill=(65, 48, 31, 255), width=1)
    if arrow:
        ink.line([draw, aim], fill=(83, 56, 30, 255), width=1)
        dx, dy = aim[0]-draw[0], aim[1]-draw[1]
        length = max(1, math.hypot(dx, dy)); ux, uy = dx/length, dy/length
        ink.polygon([aim, (aim[0]-ux*5-uy*2, aim[1]-uy*5+ux*2),
                     (aim[0]-ux*5+uy*2, aim[1]-uy*5-ux*2)], fill=(102, 99, 80, 255))
    if action in ['hurt', 'dodge']:
        animated = blank()
        lean = math.sin(phase/(3 if action == 'hurt' else 7)*math.pi)
        place(animated, out, WAIST, WAIST, (-0.12 if action == 'hurt' else 0.20)*lean)
        out = animated
    return mirror(out, facing), ((256-aim[0], aim[1]) if facing == 2 else aim), ((256-draw[0],draw[1]) if facing == 2 else draw)


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)
    side = Image.open(SOURCE/'parts/side.png').convert('RGBA')
    vertical = Image.open(SOURCE/'parts/vertical.png').convert('RGBA')
    torsos = [height(cell(side, 0), 92), height(cell(vertical, 0), 92),
              height(cell(side, 0), 92), height(cell(vertical, 1), 92)]
    legs = [height(cell(side, 2), 60), height(cell(vertical, 2), 60),
            height(cell(side, 2), 60), height(cell(vertical, 3), 60)]
    arm = cell(side, 1)
    arm = arm.convert('RGBa').resize((44, round(44*arm.height/arm.width)), Image.Resampling.LANCZOS).convert('RGBA')
    bow = height(cell(side, 3), 66)
    clips, qa = {}, []
    families = [('idle-lower', 1), ('run-lower', COUNT), ('dodge-lower', 8),
                ('idle-upper', 1), ('run-upper', COUNT), ('idle-unarmed-upper',1), ('run-unarmed-upper',COUNT), ('attack-upper', 8),
                ('pierce-upper', 8), ('rain-upper', 8), ('hurt-upper', 4), ('dodge-upper', 8), ('failed', 8)]
    for family, count in families:
        rows = 16 if family == 'run-lower' else 4
        waist, anchors, frames, contact_flags, hands = [], [], [], [], []
        for row in range(rows):
            facing = row//4 if rows == 16 else row
            move_facing = row%4 if rows == 16 else facing
            for frame in range(count):
                if family.endswith('lower'):
                    image, seam, contact = lower_frame(legs[facing], facing, frame/count if 'run' in family else None,
                                                       6*math.sin(frame/7*math.pi) if 'dodge' in family else 0, move_facing)
                else:
                    action = family.removesuffix('-upper')
                    image, arrow_tip, hand = upper_frame(torsos[facing], arm, bow, facing, action, frame)
                    hands.append(hand)
                    seam, contact = list(WAIST), []
                    if action == 'failed':
                        low, _, _ = lower_frame(legs[facing], facing, None, 8)
                        low.alpha_composite(image)
                        image = blank()
                        place(image, low, FOOT, (128-24*frame/7, 224-12*frame/7), math.sin(frame/7*math.pi/2)*1.30)
                waist.append(seam[1]); anchors.append(seam); frames.append(image)
                contact_flags.append(contact)
                bounds = image.getchannel('A').point(lambda a: 255 if a > 16 else 0).getbbox()
                qa.append({'clip':family, 'facing':facing, 'move_facing':move_facing, 'frame':frame, 'bbox':bounds,
                           'edge_ok':bounds is not None and min(bounds[0], bounds[1], SIZE-bounds[2], SIZE-bounds[3]) >= 3})
        name = 'shadow-'+family
        boxes = [image.getchannel('A').getbbox() for image in frames]
        crop = (max(0,min(b[0] for b in boxes)-4), max(0,min(b[1] for b in boxes)-4),
                min(SIZE,max(b[2] for b in boxes)+4), min(SIZE,max(b[3] for b in boxes)+4))
        cw, ch = crop[2]-crop[0], crop[3]-crop[1]
        atlas = Image.new('RGBA',(cw*count,ch*rows))
        for index,image in enumerate(frames):
            atlas.alpha_composite(image.crop(crop),((index%count)*cw,(index//count)*ch))
        atlas.save(DEST/(name+'.png'))
        clips[name] = {'size':[cw, ch], 'columns':count, 'perDirection':count,
                       'movementRows':4 if rows == 16 else 1,
                       'root':[FOOT[0]-crop[0],FOOT[1]-crop[1]], 'scale':SCALE,
                       'waistLine':[y-crop[1] for y in waist],
                       'waistPoints':[[x-crop[0],y-crop[1]] for x,y in anchors],
                       'integratedSlots':['feet','weapon'] if 'upper' in family or family=='failed' else ['feet'],
                       'contact':contact_flags}
        if 'upper' in family:
            tips = [upper_frame(torsos[f], arm, bow, f, family.removesuffix('-upper'), min(3,count-1))[1] for f in range(4)]
            clips[name]['grips'] = [{'x':(x-128)*0.5, 'y':(y-224)*0.5} for x, y in tips]
            clips[name]['attachments'] = {
                'head': [[128-crop[0],116-crop[1]] for _ in frames],
                'body': [[128-crop[0],158-crop[1]] for _ in frames],
                'hand': [[x-crop[0],y-crop[1]] for x,y in hands],
                'back': [[128-crop[0],142-crop[1]] for _ in frames]}
        review = Image.new('RGBA', (SIZE*4, SIZE*4), '#d4cbbb')
        for f in range(4):
            for col in range(4):
                index = min(count-1, round(col*(count-1)/3))
                image = frames[(f*4+f if rows == 16 else f)*count+index].copy()
                if 'upper' in family:
                    low, _, _ = lower_frame(legs[f], f)
                    low.alpha_composite(image); image=low
                elif 'lower' in family:
                    up, _, _ = upper_frame(torsos[f], arm, bow, f, 'idle', 0)
                    image.alpha_composite(up)
                review.alpha_composite(image, (col*SIZE,f*SIZE))
        review.convert('RGB').save(REVIEW/(family+'.png'))
        if 'run' in family:
            samples=[]
            for index in range(count):
                canvas=Image.new('RGBA',(SIZE*4,SIZE),'#d4cbbb')
                for f in range(4):
                    low,seam,_=lower_frame(legs[f],f,index/count)
                    up,_,_=upper_frame(torsos[f],arm,bow,f,'run',index)
                    layer=blank();place(layer,up,(0,0),(0,seam[1]-WAIST[1]))
                    low.alpha_composite(layer);canvas.alpha_composite(low,(f*SIZE,0))
                samples.append(canvas)
            samples[0].save(REVIEW/'run-four-directions.webp',save_all=True,append_images=samples[1:],duration=65,loop=0,lossless=True)
    (DEST/'clips.json').write_text(json.dumps(clips,indent=2)+'\n')
    (REVIEW.parent/'bake-qa.json').write_text(json.dumps({'art_source':'existing painted parts; offline articulated transforms',
        'mode':'baked raster animation; not generated video', 'cells':qa, 'edge_failures':sum(not q['edge_ok'] for q in qa)},indent=2)+'\n')
    if any(not q['edge_ok'] for q in qa):
        raise SystemExit('Baked frames touch canvas edge; see bake-qa.json')
    print(f'Baked {len(clips)} clips / {len(qa)} directional frames without edge clipping')


if __name__ == '__main__':
    main()
