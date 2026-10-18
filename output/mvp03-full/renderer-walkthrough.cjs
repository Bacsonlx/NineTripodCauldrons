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
 let result={surface:'isolated actual-package renderer; desktop window API stub only; not native acceptance'};
 try{
  await p.mouse('mouseMoved',640,360);if((await read()).state.paused)await p.press('Escape');await p.press('KeyR');await wait(80);
  p.on('Page.screencastFrame',e=>{const file=`frame-${String(index++).padStart(5,'0')}.jpg`;fs.writeFileSync(raw+'/'+file,Buffer.from(e.data,'base64'));frames.push({file,timestamp:e.metadata.timestamp});p.send('Page.screencastFrameAck',{sessionId:e.sessionId}).catch(()=>{});});
  await p.send('Page.startScreencast',{format:'jpeg',quality:68,maxWidth:1280,maxHeight:720,everyNthFrame:6});
  await shot('02-start');await walk(650,850);
  // Receive one normal enemy swing, never edit health; healing later uses this real damage.
  const injury=Date.now();while((await sample()).state.health===100&&Date.now()-injury<7000)await wait(40);
  assert.ok((await read()).state.health<100,'normal enemy must cause real injury');await shot('03-injured');
  await combat(0,[[650,1000],[970,1000],[970,770],[650,850]]);
  for(const xy of [[950,820],[1080,820],[1080,340],[840,365]])await walk(...xy);
  await shot('04-stele-prompt');await p.press('KeyF');await wait(90);assert.equal((await read()).state.reading,true,'short F tap must open reading');
  await shot('05-reading');const frozen=(await read()).state;await p.key('KeyF',true);await wait(80);await p.key('KeyF',false);
  // The prior release means this is a deliberate second press: closes, then read again.
  await wait(80);assert.equal((await read()).state.reading,false);await p.key('KeyF',true);await wait(250);assert.equal((await read()).state.reading,true);await p.key('KeyF',false);
  const heldRead=(await read()).state;await wait(180);assert.deepEqual((await read()).state.cooldowns,heldRead.cooldowns);await p.press('Escape');await wait(80);assert.equal((await read()).state.reading,false);
  // E retains rain use after closing; reading input doesn't leak into shooting.
  while((await read()).state.cooldowns.rain>0)await wait(60);
  const before=(await read()).state;assert.equal(before.arrows.length,0);assert.equal(before.cooldowns.rain,0);await aim(await read(),880,365);await p.press('KeyE');await wait(100);assert.ok((await read()).state.cooldowns.rain>0);await shot('06-rain-after-reading');
  for(const xy of [[1080,365],[1080,790],[1240,760],[1430,720]])await walk(...xy);
  await combat(1,[[1620,760],[1620,560],[1290,560],[1290,760]]);
  for(const xy of [[1550,760],[1550,1250],[1660,1240]])await walk(...xy);
  const health=(await read()).state.health;await shot('07-altar-before');await p.press('KeyF');await wait(90);const healed=(await read()).state;
  assert.equal(healed.health,Math.min(100,health+40));assert.equal(healed.exploration.altarUsed,true);await shot('08-altar-used');await p.press('KeyF');await wait(90);assert.equal((await read()).state.health,healed.health);
  for(const xy of [[1800,1250],[1865,1130],[1865,1100]])await walk(...xy);
  await shot('09-gate-closed');await p.press('KeyF');await wait(90);assert.ok((await read()).state.gateOpening>0);await shot('10-gate-opening');await wait(260);assert.equal((await read()).state.exploration.gateOpen,true);await shot('11-gate-open');
  for(const xy of [[1865,990],[1865,820]])await walk(...xy);
  await combat(2,[[1840,950],[2360,950],[2360,620],[1840,620]]);assert.equal((await read()).state.status,'complete');await shot('12-complete');
  // Completed route remains explorable; retrace to the stele and open it again.
  for(const xy of [[1840,720],[1550,720],[1240,760],[1080,760],[1080,340],[840,365]])await walk(...xy);
  await p.press('KeyF');await wait(90);assert.equal((await read()).state.reading,true);await shot('13-post-complete-reading');await p.press('Escape');await wait(80);await p.press('KeyR');await wait(80);
  const reset=(await read()).state;assert.deepEqual(reset.exploration,{steleRead:false,altarUsed:false,gateOpen:false});assert.equal(reset.health,100);assert.equal(reset.encounter,0);assert.equal(reset.arrows.length,0);assert.equal(reset.rains.length,0);assert.equal(reset.reading,false);await shot('14-reset');
  result={...result,passed:true,healing:{before:health,after:healed.health},reset:reset.exploration,errors};
 }catch(e){result={...result,passed:false,error:e.message,errors};await shot('failure');throw e;}
 finally{await stop();await p.send('Page.stopScreencast');fs.writeFileSync(dir+'/frames.json',JSON.stringify(frames));fs.writeFileSync(dir+'/walkthrough.json.gz',zlib.gzipSync(JSON.stringify(samples)));fs.writeFileSync(dir+'/summary.json',JSON.stringify({...result,seconds:(Date.now()-started)/1000,samples:samples.length},null,2));p.close();console.log(result);}
})().catch(e=>{console.error(e);process.exitCode=1;});
