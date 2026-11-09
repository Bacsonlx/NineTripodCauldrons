import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT/'output/art/CHR-001/2026-11-05-back-proportion-v1'
OUT.mkdir(parents=True,exist_ok=True)
SOURCE = ROOT/'assets/characters/action-redraw-v1/back-proportion-v1'
RUNTIME = ROOT/'godot/assets/characters/action-redraw-v1'
upper_sheet = Image.open(SOURCE/'upper-source.png').convert('RGBA')
idle_sheet = Image.open(ROOT/'assets/characters/action-redraw-v1/back-full-body-v2/hero-back-full.png').convert('RGBA')
walk_sheet = Image.open(ROOT/'assets/characters/action-redraw-v1/back-walk-v1/hero-back-walk.png').convert('RGBA')
size = (768,1024)
root = (384,960)
upper_scale = 0.106
upper_roots = [(270,610),(282,613),(278,612),(276,610)]
records=[]


def compose(index, walking):
    phase=0 if walking else index
    source=walk_sheet if walking else idle_sheet
    width,height=(384,512) if walking else (543,724)
    old_root=(180,450) if walking else (272,700)
    belt=241 if walking else 460
    ratio=0.1485/0.12 if walking else 1.0
    source_index=index if walking or index in [1,2] else 1
    left,top=source_index%4*width,source_index//4*height if walking else 0
    original=source.crop((left,top,left+width,top+height))
    lower=Image.new('RGBA',original.size)
    lower.paste(original.crop((0,belt,width,height)),(0,belt))
    ownership=ImageDraw.Draw(lower)
    if walking:
        ownership.polygon([(0,belt),(110,belt),(110,320),(85,340),(0,340)],fill=(0,0,0,0))
    else:
        ownership.rectangle((425,belt,542,570),fill=(0,0,0,0))
    result=Image.new('RGBA',size)
    layer=lower.resize((round(width*ratio),round(height*ratio)),Image.Resampling.LANCZOS)
    base=(round(root[0]-old_root[0]*ratio),round(root[1]-old_root[1]*ratio))
    result.alpha_composite(layer,base)
    upper=upper_sheet.crop((phase*543,0,(phase+1)*543,724))
    if phase in [0,3]:
        ImageDraw.Draw(upper).rectangle((460,0,542,350),fill=(0,0,0,0))
    factor=upper_scale/0.12
    upper=upper.resize((round(543*factor),round(724*factor)),Image.Resampling.LANCZOS)
    seam=root[1]+(belt-old_root[1])*ratio
    if walking: seam+=12.0
    result.alpha_composite(upper,(round(root[0]-upper_roots[phase][0]*factor),round(seam-upper_roots[phase][1]*factor)))
    result.save(OUT/f'{"walk" if walking else "idle"}-{index}.png')
    head_top=[75,120,110,90][phase]
    head_rect=[round(root[0]+(120-upper_roots[phase][0])*factor),round(seam+(head_top-upper_roots[phase][1])*factor),round(330*factor),round(330*factor)]
    records.append({'walk':walking,'frame':index,'waist_px':seam,'root':root,'head_rect':head_rect})
    return result


idle=[compose(idx,False) for idx in range(4)]
walk=[compose(idx,True) for idx in range(8)]
for name,frames,rows in [('hero-back-full',idle,1),('hero-back-walk',walk,2)]:
    sheet=Image.new('RGBA',(size[0]*4,size[1]*rows))
    for idx,frame in enumerate(frames): sheet.paste(frame,(idx%4*size[0],idx//4*size[1]))
    sheet.save(OUT/f'{name}.png')
    sheet.save(SOURCE/f'{name}.png')
    sheet.save(RUNTIME/f'{name}.png')
(OUT/'geometry.json').write_text(json.dumps(records,indent=2))
canvas=Image.new('RGBA',(800,420),'#ddd7ca')
for idx,frame in enumerate([idle[0],walk[0]]):
    res=frame.resize((round(768*.08*5),round(1024*.08*5)),Image.Resampling.LANCZOS)
    canvas.alpha_composite(res,(round(200+idx*400-384*.08*5),round(350-960*.08*5)))
canvas.convert('RGB').save(OUT/'preview.png')
metadata={}
for name,frames in [('hero-back-full',idle),('hero-back-walk',walk)]:
    waist=[entry['waist_px'] for entry in records if entry['walk']==(name=='hero-back-walk')]
    heads=[entry['head_rect'] for entry in records if entry['walk']==(name=='hero-back-walk')]
    metadata[name]={'size':list(size),'columns':4,'root':list(root),'scale':0.12,'waist_y':waist,'head_rects':heads,'frame_count':len(frames),'source':str((SOURCE/f'{name}.png').relative_to(ROOT)),'anchor_kind':'shared unchanged rule foot origin; original lower-body world scale retained'}
    if name=='hero-back-walk': metadata[name]['distance_per_frame']=22.0
(SOURCE/'clips.json').write_text(json.dumps(metadata,indent=2)+'\n')
clips_path=RUNTIME/'clips.json'
clips=json.loads(clips_path.read_text());clips.update(metadata)
clips_path.write_text(json.dumps(clips,indent=2)+'\n')
record={'date':'2026-11-05','art_source':'host_image + existing lower-body frames','tool':'image_gen.imagegen','model':'not returned','cost':'not returned','upper_scale':upper_scale,'upper_roots':upper_roots,'composition':'New generated upper layer; existing lower bodies at unchanged world scale. Idle/recover reuse existing draw standing lower body to avoid old low-bow overlap. Walking upper overlaps waist by 12 canonical pixels (0.96 world units). Old bow/scarf ownership masks are defined above.','references':{},'outputs':{},'user_confirmation':'User authorized proportion calibration; generated revision visual approval pending'}
for name,path in [('back_idle',ROOT/'assets/characters/action-redraw-v1/back-full-body-v2/hero-back-full.png'),('back_walk',ROOT/'assets/characters/action-redraw-v1/back-walk-v1/hero-back-walk.png'),('front_reference',ROOT/'godot/assets/generated/upperDown.png'),('selected_upper',SOURCE/'upper-source.png')]:
    record['references'][name]={'path':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
provenance_path=SOURCE.parent/'provenance.json'
provenance=json.loads(provenance_path.read_text())
for name in metadata:
    image_path=SOURCE/f'{name}.png'
    digest=hashlib.sha256(image_path.read_bytes()).hexdigest()
    runtime_path=str((RUNTIME/f'{name}.png').relative_to(ROOT))
    record['outputs'][name]={'sha256':digest,'geometry':metadata[name]}
    provenance['sources']=[entry for entry in provenance['sources'] if entry['runtime']!=runtime_path]
    provenance['sources'].append({'source':str(image_path.relative_to(ROOT)),'runtime':runtime_path,'sha256':digest,'art_source':'host_image + existing','revision':'proportion-v1: calibrated upper and existing registered lower'})
(SOURCE/'generation.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
(OUT/'generation.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
provenance_path.write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+'\n')
previews=[]
for frame in walk:
    view=Image.new('RGBA',(800,420),'#ddd7ca')
    for idx,pose in enumerate([idle[0],frame]):
        resized=pose.resize((round(768*.08*5),round(1024*.08*5)),Image.Resampling.LANCZOS)
        view.alpha_composite(resized,(round(200+idx*400-384*.08*5),round(350-960*.08*5)))
    previews.append(view.convert('RGB'))
previews[0].save(OUT/'idle-walk.gif',save_all=True,append_images=previews[1:],duration=100,loop=0)
