// Real keyboard/mouse input + read-only scene snapshots. Run against local extracted renderer fixture.
const fs=require('node:fs'),assert=require('node:assert/strict'),zlib=require('node:zlib');
const {CDP,wait}=require('./cdp-helper.cjs');
(async()=>{
 const p=await CDP.connect(9365),dir='output/mvp03-full',raw='out/validation/mvp03-full-recording';fs.mkdirSync(raw,{recursive:true});
 const frames=[],samples=[],errors=[],held=new Set();let firing=false,index=0;const started=Date.now();
 p.on('Runtime.exceptionThrown',e=>errors.push(e));await p.send('Runtime.enable');
 await p.send('Emulation.setDeviceMetricsOverride',{width:1280,height:720,deviceScaleFactor:1,mobile:false});
 const read=()=>p.eval('window.__jiudingRead()');
 const keys=async wanted=>{for(const k of [...held])if(!wanted.includes(k)){await p.key(k,false);held.delete(k)}for(const k of wanted)if(!held.has(k)){await p.key(k,true);held.add(k)}};
 const aim=async(s,x,y)=>p.mouse('mouseMoved',(x-s.view.x)*s.view.zoom,(y-s.view.y)*s.view.zoom,firing?1:0);
 const fire=async on=>{if(on!==firing){await p.mouse(on?'mousePressed':'mouseReleased',640,360,on?1:0);firing=on;}};
 const sample=async()=>{const s=await read();samples.push({ms:Date.now()-started,state:s.state});if(s.state.status==='failed')throw Error('Player failed');return s;};
 const stop=async()=>{await keys([]);await fire(false);};
 const shot=async name=>{const r=await p.send('Page.captureScreenshot',{format:'jpeg',quality:88});fs.writeFileSync(dir+'/'+name+'.jpg',Buffer.from(r.data,'base64'));};
 const walk=async(x,y)=>{const start=Date.now();while(Date.now()-start<9000){const s=await sample(),dx=x-s.state.player.x,dy=y-s.state.player.y;if(Math.hypot(dx,dy)<8){await keys([]);return;}const want=[];if(Math.abs(dx)>4)want.push(dx>0?'KeyD':'KeyA');if(Math.abs(dy)>4)want.push(dy>0?'KeyS':'KeyW');await keys(want);await wait(35);}throw Error('Cannot walk to '+x+','+y);};
 const combat=async(group,route)=>{let step=0,lastDodge=0;const start=Date.now();while(Date.now()-start<50000){const s=await sample(),q=s.state;if(q.encounter>group){await stop();return;}if(q.paused)throw Error('Combat paused');
   const [x,y]=route[step],dx=x-q.player.x,dy=y-q.player.y;if(Math.hypot(dx,dy)<16)step=(step+1)%route.length;
   const want=[];if(Math.abs(dx)>7)want.push(dx>0?'KeyD':'KeyA');if(Math.abs(dy)>7)want.push(dy>0?'KeyS':'KeyW');await keys(want);
   const e=q.enemies.filter(e=>!['dead','inactive'].includes(e.phase)).sort((a,b)=>Math.hypot(a.x-q.player.x,a.y-q.player.y)-Math.hypot(b.x-q.player.x,b.y-q.player.y))[0];
   if(e){await aim(s,e.x,e.y-44);await fire(q.hurt<=0);if(q.hurt<=0&&!q.skill&&q.dodge<=0){if(q.cooldowns.rain===0){await aim(s,e.x,e.y);await p.press('KeyE');}else if(q.cooldowns.pierce===0)await p.press('KeyQ');else if(Date.now()-lastDodge>1700&&q.cooldowns.dodge===0){await p.press('Space');lastDodge=Date.now();}}}
   await wait(45);
 }throw Error('Combat '+group+' did not clear');};

try {
await p.send('Emulation.setDeviceMetricsOverride',{width:1280,height:720,deviceScaleFactor:1,mobile:false});if((await read()).state.paused)await p.press('Escape');await p.press('KeyR');await wait(80);
await walk(650,850);await combat(0,[[650,950],[950,950],[950,810],[650,810]]);
for(const xy of [[950,820],[1080,820],[1240,760],[1430,720]])await walk(...xy);
await combat(1,[[1620,760],[1620,560],[1290,560],[1290,760]]);
for(const xy of [[1550,720],[1800,720],[1865,820]])await walk(...xy);
await combat(2,[[1840,950],[2360,950],[2360,620],[1840,620]]);
const q=(await read()).state;assert.equal(q.status,'complete');assert.deepEqual(q.exploration,{steleRead:false,altarUsed:false,gateOpen:false});await shot('16-main-route-only');
fs.writeFileSync(dir+'/main-only-summary.json',JSON.stringify({surface:'isolated renderer, not native acceptance',passed:true,seconds:(Date.now()-started)/1000,encounter:q.encounter,health:q.health,exploration:q.exploration,errors},null,2));
await p.press('KeyR');
}finally{await stop();p.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
