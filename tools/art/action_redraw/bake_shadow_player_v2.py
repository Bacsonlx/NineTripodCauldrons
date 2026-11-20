"""Bake annotated painted puppet parts; pivots, grips and strings are anatomical.

No video generator or runtime skeleton. Existing painted leg/bow sources are reused.
"""
import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance
from bake_shadow_player import place, height, cell, ik

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT/'assets/characters/child-shadow-v2/parts'
OLD = ROOT/'assets/characters/child-shadow-v1/parts'
OUT = ROOT/'output/art/CHR-001/2026-11-14-direct-v2'
SIZE, COUNT, SCALE = 256, 16, 0.75
FOOT, WAIST = (128,224), (128,174)
META = json.loads((SOURCE/'landmarks.json').read_text())
TORSOS, ARMS, LEGS = [], {}, []
BOW = None


def blank(): return Image.new('RGBA',(SIZE,SIZE))
def add(a,b): return (a[0]+b[0],a[1]+b[1])
def sub(a,b): return (a[0]-b[0],a[1]-b[1])
def mix(a,b,t): return (a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t)
def flip(p,f): return (256-p[0],p[1]) if f==2 else p


def segment(canvas,part,start,end,shade=1):
    """Map annotated proximal/distal joint centers, never the alpha-bbox center."""
    image,p,q = part
    if shade!=1:
        alpha=image.getchannel('A'); image=ImageEnhance.Brightness(image).enhance(shade); image.putalpha(alpha)
    sx,sy=q[0]-p[0],q[1]-p[1]; dx,dy=end[0]-start[0],end[1]-start[1]
    original=math.hypot(sx,sy); length=math.hypot(dx,dy)
    if length<0.01: return
    # An arm segment may foreshorten; its transverse thickness stays constant.
    along=length/original; across=0.027 if original>300 else 1
    ux,uy=sx/original,sy/original; vx,vy=-uy,ux
    tx,ty=dx/length,dy/length; nx,ny=-ty,tx
    a=along*tx*ux+across*nx*vx; b=along*tx*uy+across*nx*vy
    c=along*ty*ux+across*ny*vx; d=along*ty*uy+across*ny*vy
    ox=start[0]-a*p[0]-b*p[1]; oy=start[1]-c*p[0]-d*p[1]
    det=a*d-b*c
    transformed=image.convert('RGBa').transform(canvas.size,Image.Transform.AFFINE,
        (d/det,-b/det,(b*oy-d*ox)/det,-c/det,a/det,(c*ox-a*oy)/det),Image.Resampling.BICUBIC).convert('RGBA')
    canvas.alpha_composite(transformed)


def arm(canvas,shoulder,hand,kind,bend,shade=1,relaxed=False):
    if relaxed: elbow=mix(shoulder,hand,.52)
    else: elbow,_,_=ik(shoulder,hand,22,22,bend)
    segment(canvas,ARMS['upper'],shoulder,elbow,shade)
    segment(canvas,ARMS[kind],elbow,hand,shade)
    return elbow


def setup():
    sheet=Image.open(SOURCE/'torsos.png').convert('RGBA')
    for info in META['torsos']:
        box=info['box']; image=sheet.crop(box)
        waist=sub(info['waist'],box[:2])
        top=image.getchannel('A').point(lambda x:255 if x>16 else 0).getbbox()[1]
        factor=80/(waist[1]-top)
        # Profiles straighten shoulder over pelvis using their marked anatomy.
        lean=0
        if 'shoulder' in info:
            s=info['shoulder']; w=info['waist']; lean=(s[0]-w[0])/(w[1]-s[1])
        a,d=factor,factor; b=lean*factor
        x=WAIST[0]-factor*waist[0]-b*waist[1]; y=WAIST[1]-factor*waist[1]
        registered=image.convert('RGBa').transform((SIZE,SIZE),Image.Transform.AFFINE,
            (1/a,-b/(a*d),(b*y/d-x)/a,0,1/d,-y/d),Image.Resampling.BICUBIC).convert('RGBA')
        TORSOS.append(registered)
    sheet=Image.open(SOURCE/'arms.png').convert('RGBA')
    for key,info in META['arms'].items():
        box=info['box']; ARMS[key]=(sheet.crop(box),sub(info['start'],box[:2]),sub(info['end'],box[:2]))
    side=Image.open(OLD/'side.png').convert('RGBA'); vertical=Image.open(OLD/'vertical.png').convert('RGBA')
    for source,index in [(side,2),(vertical,2),(side,2),(vertical,3)]:
        leg=height(cell(source,index),60)
        LEGS.append(leg.resize((round(leg.width*.65),60),Image.Resampling.LANCZOS))
    global BOW
    BOW=height(cell(side,3),60)


def lower(facing,phase=None,crouch=0,move=None):
    image=blank(); side=facing in [0,2]; move=facing if move is None else move
    bob=0 if phase is None else -1.5*abs(math.sin(phase*2*math.pi))
    hips=[(125,170+bob+crouch),(131,170+bob+crouch)] if side else [(121,170+bob+crouch),(135,170+bob+crouch)]
    contacts=[]; leg=LEGS[facing]
    for i,hip in enumerate(hips):
        if phase is None: foot=(hip[0],224); contact=True
        else:
            t=(phase+i*.5)%1
            # Half-cycle support, then swing. The support foot moves backward
            # by 48 source pixels, matching 48 world units over the full cycle.
            if t<.5: stride=24-48*t/.5; lift=0; contact=True
            else:
                u=(t-.5)/.5; stride=-24+48*u; lift=13*math.sin(math.pi*u); contact=False
            sign=-1 if move in [2,3] else 1
            foot=(hip[0]+stride*sign,224-lift) if move in [0,2] else (hip[0],224+stride*sign*.18-lift)
            if facing==2: foot=(2*hip[0]-foot[0],foot[1])
        # Knee and ankle are independent; shoes keep their soles parallel to ground.
        if phase is None: knee=(hip[0],hip[1]+24-crouch*.5)
        else: knee,_,_=ik(hip,(foot[0],foot[1]-7),27,25,-1 if side else (1 if i==0 else -1))
        w,h=leg.size
        thigh=(leg.crop((0,0,w,34)),(w/2,0),(w/2,30))
        shin=(leg.crop((0,26,w,54)),(w/2,4),(w/2,25))
        shoe=leg.crop((0,48,w,h))
        shade=.88 if i==0 else 1
        segment(image,thigh,hip,knee,shade)
        segment(image,shin,knee,(foot[0],foot[1]-7),shade)
        place(image,shoe,(w/2,12),foot)
        contacts.append(contact)
    if facing==2: image=image.transpose(Image.Transpose.FLIP_LEFT_RIGHT).transform((SIZE,SIZE),Image.Transform.AFFINE,(1,0,-1,0,1,0))
    return image,[128,174+bob+crouch],contacts


def bow_geometry(canvas,grip,nock,facing,angle,arrow):
    """Upright bow plane for front/back; grip and limb tips share one transform."""
    w,h=BOW.size
    # Source center grip is the actual wrapped handle; tips are separate landmarks.
    pivot=META['bow']['grip']
    c,s=math.cos(angle),math.sin(angle)
    if facing in [1,3]:
        a,b,c2,d=.20,0,(.16 if facing==1 else -.16),1
    else: a,b,c2,d=c,-s,s,c
    tx=grip[0]-a*pivot[0]-b*pivot[1]; ty=grip[1]-c2*pivot[0]-d*pivot[1]
    det=a*d-b*c2
    warped=BOW.convert('RGBa').transform((SIZE,SIZE),Image.Transform.AFFINE,
        (d/det,-b/det,(b*ty-d*tx)/det,-c2/det,a/det,(c2*tx-a*ty)/det),Image.Resampling.BICUBIC).convert('RGBA')
    canvas.alpha_composite(warped)
    tip_source=META['bow']['tips']
    tips=[(a*x+b*y+tx,c2*x+d*y+ty) for x,y in tip_source]
    rest=mix(tips[0],tips[1],.5)
    string=nock if arrow else rest
    ImageDraw.Draw(canvas).line([tips[0],string,tips[1]],fill=(72,53,35,255),width=1)
    return tips,rest


def upper(facing,action,phase):
    image=blank(); side=facing in [0,2]; unarmed=action.endswith('-unarmed'); action=action.removesuffix('-unarmed')
    shoulder_bow=(126,152) if side else ((146,152) if facing==1 else (110,152))
    shoulder_draw=(130,152) if side else ((110,152) if facing==1 else (146,152))
    rest_bow=(140,184) if side else ((148,184) if facing==1 else (108,184))
    rest_draw=(128,190) if side else ((108,190) if facing==1 else (148,190))
    grip,nock=rest_bow,rest_draw; angle=0; arrow=False; tip=(0,0)
    draw_strength=0; is_shot=action in ['attack','pierce','rain']
    relaxed=not is_shot or phase in [0,7]
    if is_shot:
        k=min(7,phase)
        strength=[0,.55,.85,1,1,.92,.50,0][k]
        if action=='rain':
            full_grip=(153,116) if side else (128,118)
            full_nock=(134,136) if side else ((126,139) if facing==1 else (130,139))
            angle=-.80
        elif side: full_grip,full_nock=(169,141),(134,130)
        elif facing==1: full_grip,full_nock=(124,158),(124,131)
        else: full_grip,full_nock=(116,117),(139,140)
        grip=mix(rest_bow,full_grip,strength); nock=mix(rest_draw,full_nock,strength)
        arrow=k in [1,2,3]
        if k in [4,5]: nock=add(nock,(-8,-1) if side else ((-6,-3) if facing==1 else (6,2)))
        if action!='rain' and side: angle=math.atan2(full_grip[1]-full_nock[1],full_grip[0]-full_nock[0])
        angle*=strength
        if side: tip=add(grip,(17*math.cos(angle),17*math.sin(angle)))
        elif action=='rain': tip=(128,87)
        else: tip=(grip[0],grip[1]+(34 if facing==1 else -49))
        draw_strength=strength
    elif action=='run':
        swing=math.sin(phase/COUNT*2*math.pi)*4
        grip=add(grip,(swing,0)); nock=add(nock,(-swing,0))
    elif action in ['hurt','dodge']:
        grip=add(grip,(0,-8)); nock=add(nock,(0,-4))
    # BACK weapons/arrow are correctly occluded by the same head/torso.
    weapons=blank(); tips,rest=bow_geometry(weapons,grip,nock,facing,angle,arrow)
    if arrow:
        # A single shaft passes exactly through the marked arrow rest above grip.
        arrow_rest=(grip[0],grip[1]-2)
        if side:
            direction=sub(tip,nock); length=math.hypot(*direction); u=(direction[0]/length,direction[1]/length)
            tip=add(arrow_rest,(u[0]*17,u[1]*17))
            # The nock drives the string; the arrow axis uses this same line.
            axis=sub(arrow_rest,nock); length=math.hypot(*axis); u=(axis[0]/length,axis[1]/length)
            tip=add(arrow_rest,(u[0]*17,u[1]*17))
        else:
            axis=sub(arrow_rest,nock); length=math.hypot(*axis); u=(axis[0]/length,axis[1]/length)
            tip=add(arrow_rest,(u[0]*(30 if facing==3 else 26),u[1]*(30 if facing==3 else 26)))
        ink=ImageDraw.Draw(weapons); ink.line([nock,tip],fill=(87,61,36,255),width=1)
        dx,dy=tip[0]-nock[0],tip[1]-nock[1]; length=max(.01,math.hypot(dx,dy)); ux,uy=dx/length,dy/length
        ink.polygon([tip,(tip[0]-ux*4-uy*1.6,tip[1]-uy*4+ux*1.6),(tip[0]-ux*4+uy*1.6,tip[1]-uy*4-ux*1.6)],fill=(105,103,85,255))
    # Anatomical left arm is far for right profile, near for left profile.
    far_bow=facing==0 or facing==3
    eb=arm(image,shoulder_bow,grip,'relaxed' if unarmed else 'bow',1,.90,relaxed) if far_bow else None
    if facing in [2,3]: ed=arm(image,shoulder_draw,nock,'draw' if is_shot else 'relaxed',1 if facing==3 else -1,.90,relaxed)
    if facing==3 and not unarmed: image.alpha_composite(weapons)
    torso=TORSOS[facing]
    if facing==2: torso=torso.transform((SIZE,SIZE),Image.Transform.AFFINE,(-1,0,256,0,1,0))
    image.alpha_composite(torso)
    if not far_bow: eb=arm(image,shoulder_bow,grip,'relaxed' if unarmed else 'bow',1,relaxed=relaxed)
    if facing in [0,1]: ed=arm(image,shoulder_draw,nock,'draw' if is_shot else 'relaxed',-1,relaxed=relaxed)
    if facing!=3 and not unarmed:
        image.alpha_composite(weapons)
        # Repaint the supporting fingers above the wrapped grip: the bow is
        # held inside the palm rather than pasted across the hand afterwards.
        part,p,q=ARMS['bow']; hand=part.copy()
        ImageDraw.Draw(hand).rectangle((0,0,p[0]+(q[0]-p[0])*.77,hand.height),fill=(0,0,0,0))
        segment(image,(hand,p,q),eb,grip)
    if facing==2:
        image=image.transform((SIZE,SIZE),Image.Transform.AFFINE,(-1,0,256,0,1,0))
    # Small grounded reactions; do not put a constant forward lean on idle/run.
    if action in ['hurt','dodge']:
        temp=blank(); angle=(-.07 if action=='hurt' else .08)*math.sin(phase/(3 if action=='hurt' else 7)*math.pi)
        place(temp,image,WAIST,WAIST,angle); image=temp
    info={'bowHand':flip(grip,facing),'drawHand':flip(nock,facing),'bowShoulder':flip(shoulder_bow,facing),
          'drawShoulder':flip(shoulder_draw,facing),'bowElbow':flip(eb,facing),'drawElbow':flip(ed,facing),
          'bowTips':[flip(p,facing) for p in tips],'arrowTip':flip(tip,facing),'arrowVisible':arrow,
          'bowPlane':'vertical-foreshortened' if not side else 'profile','drawStrength':draw_strength}
    return image,info


def main():
    args=argparse.ArgumentParser();args.add_argument('--publish',action='store_true'); publish=args.parse_args().publish
    dest=ROOT/'godot/assets/characters/child-shadow-v2' if publish else OUT/'candidate'
    dest.mkdir(parents=True,exist_ok=True); review=OUT/'review';review.mkdir(exist_ok=True)
    setup(); clips={};qa=[]
    families=[('idle-lower',1),('run-lower',16),('dodge-lower',8),('idle-upper',1),('run-upper',16),
              ('idle-unarmed-upper',1),('run-unarmed-upper',16),('attack-upper',8),('pierce-upper',8),
              ('rain-upper',8),('hurt-upper',4),('dodge-upper',8),('failed',8)]
    for family,count in families:
        rows=16 if family=='run-lower' else 4; frames=[]; anchors=[]; contacts=[]; semantics=[]
        for row in range(rows):
            facing=row//4 if rows==16 else row; move=row%4 if rows==16 else facing
            for frame in range(count):
                if family.endswith('lower'):
                    im,seam,contact=lower(facing,frame/count if 'run' in family else None,5*math.sin(frame/7*math.pi) if 'dodge' in family else 0,move)
                    info={}
                else:
                    im,info=upper(facing,family.removesuffix('-upper'),frame); seam=list(WAIST); contact=[]
                    if family=='failed':
                        low,_,_=lower(facing,None,5); low.alpha_composite(im); im=blank()
                        place(im,low,FOOT,(128-22*frame/7,224-12*frame/7),math.sin(frame/7*math.pi/2)*1.25)
                frames.append(im); anchors.append(seam);contacts.append(contact);semantics.append(info)
                bbox=im.getchannel('A').point(lambda x:255 if x>16 else 0).getbbox()
                qa.append({'clip':family,'facing':facing,'move':move,'frame':frame,'bbox':bbox,'edge_ok':bbox is not None and min(bbox[0],bbox[1],SIZE-bbox[2],SIZE-bbox[3])>=3})
        boxes=[im.getchannel('A').getbbox() for im in frames]
        crop=(max(0,min(b[0] for b in boxes)-4),max(0,min(b[1] for b in boxes)-4),min(SIZE,max(b[2] for b in boxes)+4),min(SIZE,max(b[3] for b in boxes)+4))
        w,h=crop[2]-crop[0],crop[3]-crop[1]; atlas=Image.new('RGBA',(w*count,h*rows))
        for i,im in enumerate(frames): atlas.alpha_composite(im.crop(crop),((i%count)*w,(i//count)*h))
        name='shadow-'+family;atlas.save(dest/(name+'.png'))
        data={'size':[w,h],'columns':count,'perDirection':count,'movementRows':4 if rows==16 else 1,'root':[128-crop[0],224-crop[1]],'scale':SCALE,
              'waistLine':[p[1]-crop[1] for p in anchors],'waistPoints':[[p[0]-crop[0],p[1]-crop[1]] for p in anchors],'contact':contacts,
              'poseSource':'painted-parts-with-anatomical-landmarks-v2','semantics':semantics}
        if family.endswith('upper'):
            full_poses=[upper(f,family.removesuffix('-upper'),min(3,count-1))[1] for f in range(4)]
            tips=[p['arrowTip'] for p in full_poses]
            data['grips']=[{'x':(x-128)*.5,'y':(y-224)*.5} for x,y in tips]
            data['arrowLengths']=[math.dist(p['arrowTip'],p['drawHand'])*.5 for p in full_poses]
            data['attachments']={key:[[point[0]-crop[0],point[1]-crop[1]] for point in values] for key,values in {
                'head':[(128,116)]*len(frames),'body':[(128,158)]*len(frames),'back':[(128,145)]*len(frames),
                'hand':[info['drawHand'] for info in semantics]}.items()}
        clips[name]=data
        # Show all 8 action phases and every direction at a fixed viewing scale.
        preview=Image.new('RGBA',(SIZE*count,SIZE*4),'#d4cebe')
        composites=[]
        for f in range(4):
            seq=[]
            for k in range(count):
                i=((f*4+f) if rows==16 else f)*count+k; im=frames[i].copy()
                if family.endswith('upper'):
                    low,_,_=lower(f);low.alpha_composite(im);im=low
                elif family.endswith('lower'):
                    up,_=upper(f,'idle',0); place(im,up,(0,0),(0,anchors[i][1]-174))
                preview.alpha_composite(im,(k*SIZE,f*SIZE));seq.append(im)
            composites.append(seq)
        preview.convert('RGB').save(review/(family+'.png'))
        if family in ['run-upper','attack-upper','rain-upper']:
            animation=[]
            for k in range(count):
                strip=Image.new('RGBA',(SIZE*4,SIZE),'#d4cebe')
                for f in range(4): strip.alpha_composite(composites[f][k],(f*SIZE,0))
                animation.append(strip)
            animation[0].save(review/(family+'.webp'),save_all=True,append_images=animation[1:],duration=70 if count==16 else 95,loop=0,lossless=True)
    (dest/'clips.json').write_text(json.dumps(clips,indent=2)+'\n')
    failures=[q for q in qa if not q['edge_ok']]
    (OUT/'bake-qa.json').write_text(json.dumps({'art_source':'host-image painted parts; annotated offline articulation','cells':qa,'edge_failures':failures},indent=2)+'\n')
    if failures: raise SystemExit(str(failures[:3]))
    print(f'Baked {len(clips)} clips, {len(qa)} directional samples to {dest}; edge failures 0')

if __name__=='__main__':main()
