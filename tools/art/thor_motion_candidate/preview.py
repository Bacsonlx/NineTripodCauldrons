"""Review actual Godot transforms with existing, unchanged RGBA parts (not GPU capture)."""
import base64,io,json
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'output/art/BOS-001/2026-10-23-combat-focus-v3'
frames=json.loads((OUT/'poses.json').read_text())
meta=json.loads((ROOT/'godot/assets/boss/thor-puppet-v1/parts.json').read_text())['parts']
images={}
for name,p in meta.items():
 x,y,w,h=p['region'];images[name]=Image.open(ROOT/'godot/assets/boss/thor-puppet-v1'/p['file']).convert('RGBA').crop((x,y,x+w,y+h))
def render(f,wide=False):
 size=(560,560); zoom=.55 if wide else 1.4
 image=Image.new('RGBA',size,'#303b3b');d=ImageDraw.Draw(image)
 for x in range(0,560,35):d.line((x,0,x,560),fill='#3b4645')
 for y in range(0,560,35):d.line((0,y,560,y),fill='#3b4645')
 cx,cy=280,(360 if wide else 490); rx,ry=(420,520) if wide else f['origin']
 fx=cx+(f['origin'][0]-rx)*zoom;fy=cy+(f['origin'][1]-ry)*zoom
 d.ellipse((fx-26,fy-7,fx+26,fy+7),fill='#171f20')
 if wide:
  d.line((cx+(120-rx)*zoom,cy,cx+(720-rx)*zoom,cy),fill='#7b9391',width=2)
  if f['hammer']:
   x=cx+(f['hammer']['x']-rx)*zoom;y=cy+(f['hammer']['y']-ry)*zoom
   d.ellipse((x-8,y-4,x+8,y+4),outline='#c8e4e3',width=2)
 for p in sorted(f['parts'],key=lambda p:p['z']):
  a,b=[v*zoom for v in p['x']];c,e=[v*zoom for v in p['y']];ox,oy=p['offset'];px,py=p['origin']
  tx=cx+(px-rx)*zoom+a*ox+c*oy;ty=cy+(py-ry)*zoom+b*ox+e*oy;det=a*e-b*c
  inverse=(e/det,-c/det,(c*ty-e*tx)/det,-b/det,a/det,(b*tx-a*ty)/det)
  image.alpha_composite(images[p['name']].transform(size,Image.Transform.AFFINE,inverse,Image.Resampling.BICUBIC))
 d.text((14,12),f"{f['variant']} / {f['mode']} / {f['phase']} / {f['time']:.2f}s",fill='#f0dfb4')
 d.text((14,34),'OFFLINE COMPOSITE - not a GPU screenshot',fill='#a5bdb5')
 return image
for mode in ['swing','throw','lightning']:
 groups=[[f for f in frames if f['variant']==v and f['mode']==mode] for v in ['baseline','candidate']]
 for wide in ([False,True] if mode=='throw' else [False]):
  combined=[]
  for old,new in zip(*groups):
   im=Image.new('RGB',(1120,560));im.paste(render(old,wide),(0,0));im.paste(render(new,wide),(560,0));combined.append(im)
  name=mode+('-path' if wide else '')
  combined[0].save(OUT/(name+'.webp'),save_all=True,append_images=combined[1:],duration=20,loop=0,lossless=False,quality=88,method=4)
  samples={'swing':[0,.55,.8,.92,1.1,1.92],'throw':[0,.6,1,1.3,3.2,3.9],'lightning':[0,.4,.6,1.6,3.04,4]}[mode]
  sheet=Image.new('RGB',(560*6,560*2))
  for col,t in enumerate(samples):
   for row,seq in enumerate(groups):sheet.paste(render(seq[min(round(t/.02),len(seq)-1)],wide),(col*560,row*560))
  sheet.save(OUT/(name+'-contact.png'))
encoded={}
for n,img in images.items():
 buf=io.BytesIO();img.save(buf,format='PNG');encoded[n]='data:image/png;base64,'+base64.b64encode(buf.getvalue()).decode()
html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>索尔三招 · 人体动作链对照</title>
<style>body{margin:28px auto;max-width:1180px;background:#182222;color:#e8e6dc;font:16px system-ui;padding:0 18px}h1{font-size:28px}p{line-height:1.7;color:#c6ccc6}button,select{font:inherit;padding:8px 14px;margin:4px;background:#364746;color:inherit;border:1px solid #6b8179;border-radius:5px}input{width:100%;margin:18px 0}canvas{width:100%;height:auto}small{color:#acbeb8}.labels{display:grid;grid-template-columns:1fr 1fr;text-align:center;font-size:18px;margin:14px 0} .bar{display:flex;gap:6px;flex-wrap:wrap}</style>
<h1>索尔三招 · 脚底承重 → 腰胯 → 肩肘 → 持锤</h1><p>同一套 PNG、同一规则快照、同一显示倍率。左为当前默认动作，右为新的单方向候选。新候选没有替换默认动作。镜头与 Boss 额外 25% 体量已单独调整。</p>
<div class="bar"><select id="mode"><option value="swing">横锤 · 蓄力／发力／缓冲／回位</option><option value="throw">掷锤 · 举锤／出手／等待／接回</option><option value="lightning">落雷 · 压膝／引雷／回位</option></select><button id="play">暂停</button><button id="prev">上一帧</button><button id="next">下一帧</button><select id="speed"><option value="1">正常速度</option><option value="0.5">半速</option><option value="0.25">四分之一速度</option></select><select id="view"><option value="body">身体近景</option><option value="wide">完整锤路（掷锤）</option></select></div>
<input id="scrub" type="range" min="0" step="1" aria-label="逐帧进度"><small id="status"></small><div class="labels"><span>当前默认动作</span><span>人体动作链候选</span></div><canvas width="1120" height="560" id="canvas"></canvas>
<p>横锤将过顶拉拽改为身体侧方蓄力、转髋挥出和屈膝收力；投掷分开蓄力、送肩、随挥与接锤缓冲；落雷由下盘压低到向上伸展，肩肘不跨反折方向。动作时长、飞锤地面路线和命中规则不变。</p>
<p>画面由 Godot 实际节点变换与未修改的素材离线合成，不是实机截图，也不证明最终动作已获认可。身体近景会让离手飞锤出画，可切“完整锤路”检查去回与接锤。未补画四向或大幅透视转身。</p><script>
const frames=FRAMES,sources=SOURCES;const images={};for(const [n,src]of Object.entries(sources)){images[n]=new Image();images[n].src=src}
const cvs=document.querySelector('#canvas'),ctx=cvs.getContext('2d'),mode=document.querySelector('#mode'),speed=document.querySelector('#speed'),view=document.querySelector('#view'),slider=document.querySelector('#scrub'),status=document.querySelector('#status');let playing=true,index=0,elapsed=0,last=0;
function group(v){return frames.filter(f=>f.variant===v&&f.mode===mode.value)}
function drawFrame(f,left){ctx.save();ctx.beginPath();ctx.rect(left,0,560,560);ctx.clip();const wide=view.value==='wide'&&mode.value==='throw',zoom=wide?.55:1.4,cx=left+280,cy=wide?360:490,[rx,ry]=wide?[420,520]:f.origin;ctx.fillStyle='#303b3b';ctx.fillRect(left,0,560,560);ctx.strokeStyle='#3b4645';for(let x=left;x<left+560;x+=35){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,560);ctx.stroke()}for(let y=0;y<560;y+=35){ctx.beginPath();ctx.moveTo(left,y);ctx.lineTo(left+560,y);ctx.stroke()}ctx.fillStyle='#171f20';ctx.beginPath();ctx.ellipse(cx+(f.origin[0]-rx)*zoom,cy+(f.origin[1]-ry)*zoom,26,7,0,0,Math.PI*2);ctx.fill();
if(wide){ctx.strokeStyle='#7b9391';ctx.beginPath();ctx.moveTo(cx+(120-rx)*zoom,cy);ctx.lineTo(cx+(720-rx)*zoom,cy);ctx.stroke();if(f.hammer){ctx.beginPath();ctx.ellipse(cx+(f.hammer.x-rx)*zoom,cy+(f.hammer.y-ry)*zoom,8,4,0,0,Math.PI*2);ctx.stroke()}}
for(const p of [...f.parts].sort((a,b)=>a.z-b.z)){ctx.setTransform(p.x[0]*zoom,p.x[1]*zoom,p.y[0]*zoom,p.y[1]*zoom,cx+(p.origin[0]-rx)*zoom,cy+(p.origin[1]-ry)*zoom);const im=images[p.name];if(im.complete)ctx.drawImage(im,...p.offset)}ctx.setTransform(1,0,0,1,0,0);ctx.fillStyle='#f0dfb4';ctx.font='15px system-ui';ctx.fillText(f.phase+' · '+f.time.toFixed(2)+' 秒',left+14,24);ctx.restore()}
function tick(t){if(playing){elapsed+=Math.min(100,t-last)*Number(speed.value);if(elapsed>=20){index=(index+Math.floor(elapsed/20))%group('baseline').length;elapsed%=20}}last=t;const a=group('baseline'),b=group('candidate');index=Math.min(index,a.length-1);slider.max=a.length-1;slider.value=index;status.textContent=`${index+1} / ${a.length} · ${a[index].time.toFixed(2)} 秒 · 离线合成`;drawFrame(a[index],0);drawFrame(b[index],560);requestAnimationFrame(tick)}
mode.onchange=()=>{index=0;elapsed=0};slider.oninput=()=>{index=Number(slider.value);playing=false;document.querySelector('#play').textContent='播放'};document.querySelector('#play').onclick=()=>{playing=!playing;document.querySelector('#play').textContent=playing?'暂停':'播放'};document.querySelector('#prev').onclick=()=>{playing=false;index=Math.max(0,index-1)};document.querySelector('#next').onclick=()=>{playing=false;index=Math.min(group('baseline').length-1,index+1)};requestAnimationFrame(tick);
</script>'''
(OUT/'preview.html').write_text(html.replace('FRAMES',json.dumps(frames)).replace('SOURCES',json.dumps(encoded)))
print('Wrote 3 skill comparisons, complete throw path, contact sheets and self-contained frame viewer')
