from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import numpy as np,json,math
P=Path(__file__).resolve().parent;ROOT=P.parents[1];data=json.loads((P/'trace.json').read_text());images={};font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',19)
def render(sample):
 w,h,z=620,420,1.8;canvas=Image.new('RGBA',(w,h),'#29302b')
 d=ImageDraw.Draw(canvas)
 for x in range(-100,1500,80):d.line((x,0,x-200,h),fill='#333c31')
 for y in range(30,h,60):d.line((0,y,w,y),fill='#333c31')
 for p in sorted(sample['layers'],key=lambda x:x['z']):
  path=p['file']
  if path not in images:images[path]=Image.open(ROOT/'godot'/path.removeprefix('res://')).convert('RGBA')
  x,y,fw,fh=p['region'];im=images[path].crop((x,y,x+fw,y+fh))
  col=p['color'];a=np.asarray(im).astype(float)*np.array(col);im=Image.fromarray(np.uint8(np.clip(a,0,255)))
  kx,ky=p['scale'][0]*z,p['scale'][1]*z
  if abs(kx*ky)<1e-10:continue
  c,s=math.cos(p['rotation']),math.sin(p['rotation']);px=(p['position'][0]-330)*z;py=(p['position'][1]-420)*z
  ax,ay=-p['offset'][0],-p['offset'][1]
  im=im.transform((w,h),Image.Transform.AFFINE,(c/kx,s/kx,ax-c/kx*px-s/kx*py,-s/ky,c/ky,ay+s/ky*px-c/ky*py),resample=Image.Resampling.BICUBIC)
  canvas=Image.alpha_composite(canvas,im)
 return canvas.convert('RGB')
for action,frames in data.items():
 imgs=[render(sample) for sample in frames[::2]]
 for i,im in enumerate(imgs):ImageDraw.Draw(im).text((16,12),action.upper()+' / '+str(i*2+1)+' / 72',font=font,fill='#e8cc7d')
 imgs[0].save(P/(action+'.gif'),save_all=True,append_images=imgs[1:],duration=[30,30,40]*12,loop=0,optimize=False)
 film=Image.new('RGB',(1860,420))
 for i,tick in enumerate({'normal':[12,16,22],'pierce':[8,14,20],'rain':[20,30,42],'dodge':[2,6,12]}[action]):film.paste(render(frames[tick]),(i*620,0))
 film.save(P/(action+'-phases.png'))
print('Rendered four actual-node sample previews; not native screenshots')
