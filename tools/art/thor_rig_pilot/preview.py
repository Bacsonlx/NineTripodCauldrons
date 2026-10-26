"""Composite actual exported transforms; source PNGs remain untouched."""
import base64
import io
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'output/art/BOS-001/2026-10-23-rig-pilot'
frames = json.loads((OUT / 'poses.json').read_text())
meta = json.loads((ROOT / 'godot/assets/boss/thor-puppet-v1/parts.json').read_text())['parts']
images = {}
for name, data in meta.items():
    x,y,w,h = data['region']
    images[name] = Image.open(ROOT / 'godot/assets/boss/thor-puppet-v1' / data['file']).convert('RGBA').crop((x,y,x+w,y+h))

def render(f, size=(480,480), zoom=1.6):
    image = Image.new('RGBA', size, '#303b3b')
    d = ImageDraw.Draw(image)
    for x in range(0,size[0],36): d.line((x,0,x,size[1]),fill='#3b4645')
    for y in range(0,size[1],36): d.line((0,y,size[0],y),fill='#3b4645')
    cx,cy = size[0]/2,420
    d.ellipse((cx-40,cy-10,cx+40,cy+10),fill='#171f20')
    for p in sorted(f['parts'],key=lambda p:p['z']):
        a,b = [v*zoom for v in p['x']]; c,e = [v*zoom for v in p['y']]
        ox,oy=p['offset']; px,py=p['origin']; rx,ry=f['origin']
        tx=cx+(px-rx)*zoom+a*ox+c*oy; ty=cy+(py-ry)*zoom+b*ox+e*oy
        det=a*e-b*c
        inverse=(e/det,-c/det,(c*ty-e*tx)/det,-b/det,a/det,(b*tx-a*ty)/det)
        image.alpha_composite(images[p['name']].transform(size,Image.Transform.AFFINE,inverse,Image.Resampling.BICUBIC))
    d.text((14,12),f"{f['variant']} / {f['mode']} / {f['phase']}",fill='#f0dfb4')
    d.text((14,32),'OFFLINE COMPOSITE - not a GPU screenshot',fill='#a5bdb5')
    return image

for mode in ['idle','swing']:
    sequence=[]
    for variant in ['baseline','pilot']:
        group=[f for f in frames if f['variant']==variant and f['mode']==mode]
        sequence.append([render(f) for f in group])
    combined=[]
    for old,new in zip(*sequence):
        im=Image.new('RGB',(960,480)); im.paste(old,(0,0)); im.paste(new,(480,0)); combined.append(im)
    combined[0].save(OUT / (mode+'.png'))
    combined[0].save(OUT / (mode+'.webp'),save_all=True,append_images=combined[1:],duration=20,loop=0,lossless=True)
    if mode=='swing':
        sheet=Image.new('RGB',(480*5,480*2))
        for row,seq in enumerate(sequence):
            for col,t in enumerate([0,.62,.8,.88,1.4]): sheet.paste(seq[round(t/.02)],(col*480,row*480))
        sheet.save(OUT / 'contact-sheet.png')
encoded={}
for n,img in images.items():
    buf=io.BytesIO(); img.save(buf,format='PNG'); encoded[n]='data:image/png;base64,'+base64.b64encode(buf.getvalue()).decode()
html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>索尔：AI 关节片段最小试点</title>
<style>body{margin:24px auto;max-width:1100px;background:#182222;color:#e8e6dc;font:16px system-ui}h1{font-size:26px}p{line-height:1.7;color:#c6ccc6}button,select{font:inherit;padding:8px 14px;margin-right:10px;background:#364746;color:inherit;border:1px solid #6b8179;border-radius:5px}input{width:100%;margin:18px 0}canvas{width:100%;height:auto}small{color:#acbeb8}.bar{display:flex;gap:8px;flex-wrap:wrap} @media(max-width:700px){body{margin:16px}}</style>
<h1>同一套形象 · AI 编辑关节与片段</h1><p>左：当前程序姿势（v5）。右：原生层级 + AnimationPlayer 候选。由 AI 调整枢轴、层级、关键帧与遮挡；你只需评审效果。单方向，仅待机和完整横锤，默认首关未替换。</p>
<div class="bar"><button id="play">暂停</button><button id="prev">上一帧</button><button id="next">下一帧</button><select id="mode"><option value="swing">完整横锤</option><option value="idle">待机</option></select><select id="speed"><option value="1">正常速度</option><option value="0.5">半速</option><option value="0.25">四分之一速度</option></select></div>
<input id="scrub" type="range" min="0" step="1" aria-label="逐帧进度"><small id="status"></small><canvas width="960" height="480" id="view"></canvas>
<p>这不是游戏 GPU 截图。画面使用 Godot 导出的实际全局变换与原始 PNG 离线合成，不验证原生纹理过滤、灯光或性能。待机采用隔离时间夹具；横锤采用真实近距战斗规则快照。接缝、动作时机和承重感仍需视觉评审。</p>
<p>修改方式：AI 编辑 <code>tools/art/thor_rig_pilot/bindings.json</code> 与 <code>clips.json</code> 后重建；场景本身也可在 Godot AnimationPlayer 中编辑。下次可直接描述“肩膀少抬一点”“挥锤更沉”，无需拖动关节。</p>
<script>const frames=FRAMES, sources=SOURCES;
const images={}; const cvs=document.querySelector('#view'),ctx=cvs.getContext('2d');const slider=document.querySelector('#scrub'),mode=document.querySelector('#mode'),speed=document.querySelector('#speed'),status=document.querySelector('#status');let playing=true,index=0,elapsed=0,last=0;
function group(v){return frames.filter(f=>f.variant===v&&f.mode===mode.value)}
function drawFrame(f,left){ctx.save();ctx.beginPath();ctx.rect(left,0,480,480);ctx.clip();ctx.fillStyle='#303b3b';ctx.fillRect(left,0,480,480);ctx.strokeStyle='#3b4645';for(let x=0;x<480;x+=36){ctx.beginPath();ctx.moveTo(left+x,0);ctx.lineTo(left+x,480);ctx.stroke()}for(let y=0;y<480;y+=36){ctx.beginPath();ctx.moveTo(left,y);ctx.lineTo(left+480,y);ctx.stroke()}ctx.fillStyle='#171f20';ctx.beginPath();ctx.ellipse(left+240,420,40,10,0,0,Math.PI*2);ctx.fill();for(const p of [...f.parts].sort((a,b)=>a.z-b.z)){ctx.save();ctx.translate(left+240+(p.origin[0]-f.origin[0])*1.6,420+(p.origin[1]-f.origin[1])*1.6);ctx.transform(p.x[0]*1.6,p.x[1]*1.6,p.y[0]*1.6,p.y[1]*1.6,0,0);ctx.drawImage(images[p.name],...p.offset);ctx.restore()}ctx.fillStyle='#f0dfb4';ctx.font='16px system-ui';ctx.fillText(f.variant==='pilot'?'AI 关节片段候选':'当前程序姿势 v5',left+14,25);ctx.restore()}
function draw(){const a=group('baseline'),b=group('pilot');index=Math.max(0,Math.min(index,b.length-1));slider.max=b.length-1;slider.value=index;drawFrame(a[index],0);drawFrame(b[index],480);status.textContent=`${(index*.02).toFixed(2)} 秒 · ${b[index].phase} · ${index+1}/${b.length} 帧`}
function pause(){playing=false;document.querySelector('#play').textContent='播放'}
document.querySelector('#play').onclick=()=>{playing=!playing;document.querySelector('#play').textContent=playing?'暂停':'播放'};
document.querySelector('#prev').onclick=()=>{pause();index--;draw()};document.querySelector('#next').onclick=()=>{pause();index++;draw()};slider.oninput=()=>{pause();index=+slider.value;draw()};mode.onchange=()=>{index=0;elapsed=0;draw()};
Promise.all(Object.entries(sources).map(([n,s])=>new Promise((resolve,reject)=>{const i=new Image();i.onload=()=>{images[n]=i;resolve()};i.onerror=reject;i.src=s}))).then(()=>{draw();requestAnimationFrame(function tick(t){if(last&&playing){elapsed+=(t-last)*+speed.value;while(elapsed>=20){index=(index+1)%group('pilot').length;elapsed-=20}draw()}last=t;requestAnimationFrame(tick)})});
</script></html>'''
(OUT/'preview.html').write_text(html.replace('FRAMES',json.dumps(frames)).replace('SOURCES',json.dumps(encoded)))
print('Saved self-contained preview, side-by-side webp and contact sheet')
