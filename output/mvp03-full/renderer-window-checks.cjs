const fs=require('fs'),assert=require('node:assert/strict'),{CDP,wait}=require('./cdp-helper.cjs');
(async()=>{const p=await CDP.connect(9365),held=new Set(),read=()=>p.eval('window.__jiudingRead()');let blank;
const keys=async w=>{for(const k of [...held])if(!w.includes(k)){await p.key(k,false);held.delete(k)}for(const k of w)if(!held.has(k)){await p.key(k,true);held.add(k)}};
const shot=async name=>{const r=await p.send('Page.captureScreenshot',{format:'jpeg',quality:86});fs.writeFileSync('output/mvp03-full/'+name+'.jpg',Buffer.from(r.data,'base64'))};
const result={surface:'isolated Chromium; not native desktop window acceptance',viewport:[],focus:'not yet tested'};
try{
await p.send('Emulation.setDeviceMetricsOverride',{width:1280,height:720,deviceScaleFactor:1,mobile:false});await p.press('KeyR');await wait(80);
for(const [x,y] of [[400,1047],[940,1047],[940,990],[1020,990],[1020,800],[1080,800],[1080,340],[840,365]]){
 const started=Date.now();while(Date.now()-started<10000){const q=(await read()).state,dx=x-q.player.x,dy=y-q.player.y;if(Math.hypot(dx,dy)<5)break;const w=[];if(Math.abs(dx)>2)w.push(dx>0?'KeyD':'KeyA');if(Math.abs(dy)>2)w.push(dy>0?'KeyS':'KeyW');await keys(w);await wait(35);}await keys([]);assert.ok(Math.hypot((await read()).state.player.x-x,(await read()).state.player.y-y)<6,'walk to stele');}
assert.equal((await read()).state.enemies.some(e=>e.phase!=='inactive'),false,'unawakened enemies allow safe reading; no progress skip claimed');
for(const [width,height] of [[800,450],[1920,720]]){
 await p.send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});await wait(80);await p.press('KeyF');await wait(80);assert.equal((await read()).state.reading,true);
 const panel=await p.eval('(()=>{const r=document.querySelector(".inscription").getBoundingClientRect();return {left:r.left,top:r.top,right:r.right,bottom:r.bottom,width:innerWidth,height:innerHeight}})()');
 assert.ok(panel.left>=0&&panel.top>=0&&panel.right<=width&&panel.bottom<=height);await shot(`viewport-${width}x${height}-reading`);await p.press('Escape');await wait(80);
 const prompt=await p.eval('(()=>{const r=document.querySelector("#interaction").getBoundingClientRect();return {left:r.left,top:r.top,right:r.right,bottom:r.bottom}})()');assert.ok(prompt.left>=0&&prompt.top>=0&&prompt.right<=width&&prompt.bottom<=height);result.viewport.push({width,height,panel,prompt});await shot(`viewport-${width}x${height}-prompt`);
}
await p.press('KeyF');await wait(80);assert.equal((await read()).state.reading,true);
await p.eval("window.__focusEvents=[];window.addEventListener('blur',()=>window.__focusEvents.push('blur'));true");
const original=(await p.send('Target.getTargetInfo')).targetInfo.targetId;
blank=(await p.send('Target.createTarget',{url:'about:blank',background:false})).targetId;await p.send('Target.activateTarget',{targetId:blank});await wait(150);await p.send('Target.closeTarget',{targetId:blank});blank=null;await p.send('Target.activateTarget',{targetId:original});await wait(150);
await p.press('Escape');await wait(100);const closed=(await read()).state;assert.equal(closed.reading,false);const events=await p.eval('window.__focusEvents');
if(events.includes('blur')){assert.equal(closed.paused,true,'real blur must remain paused after closing reading');await shot('15-focus-still-paused');result.focus='real browser blur and independent pause passed';}else result.focus='not exercised: headless target switch did not emit window blur';
if(closed.paused)await p.press('Escape');await wait(80);assert.equal((await read()).state.paused,false);await p.press('KeyR');result.viewportPassed=true;result.passed=events.includes('blur');result.overall=result.passed?'passed':'partial: viewport passed; focus event not exercised';
}catch(e){result.passed=false;result.error=e.message;throw e;}finally{await keys([]);if(blank)await p.send('Target.closeTarget',{targetId:blank});fs.writeFileSync('output/mvp03-full/window-checks.json',JSON.stringify(result,null,2));p.close();console.log(result);}
})().catch(e=>{console.error(e);process.exitCode=1});
