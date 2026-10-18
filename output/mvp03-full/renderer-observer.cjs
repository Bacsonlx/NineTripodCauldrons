const {CDP}=require('./cdp-helper.cjs');
(async()=>{const p=await CDP.connect(9365);try{
 const scripts=[];p.on('Debugger.scriptParsed',s=>scripts.push(s));await p.send('Debugger.enable');
 const script=scripts.find(s=>s.url.endsWith('/main_window/index.js'));if(!script)throw Error('Game renderer script missing');
 const {scriptSource}=await p.send('Debugger.getScriptSource',{scriptId:script.scriptId});
 const offset=scriptSource.indexOf('this.updateHUD(');if(offset<0)throw Error('Scene observation point missing');
 const lineNumber=scriptSource.slice(0,offset).split('\n').length-1;
 const columnNumber=offset-scriptSource.lastIndexOf('\n',offset)-1;
 const stopped=new Promise(r=>p.on('Debugger.paused',r));
 const bp=await p.send('Debugger.setBreakpointByUrl',{url:script.url,lineNumber,columnNumber});
 const paused=await Promise.race([stopped,new Promise((_,j)=>setTimeout(()=>j(Error('Scene not advancing')),8000))]);
 const expression=`window.__jiudingRead = () => ({state:this.room.snapshot,view:{x:this.cameras.main.scrollX,y:this.cameras.main.scrollY,zoom:this.cameras.main.zoom,width:this.scale.width,height:this.scale.height},visual:{legs:{texture:this.legs.texture.key,frame:this.legs.frame.name,x:this.legs.x,y:this.legs.y,scale:this.legs.scaleX},upper:{texture:this.torso.texture.key,frame:this.torso.frame.name,x:this.torso.x,y:this.torso.y}},objects:{children:this.children.list.length,arrowViews:this.arrows.size,enemyViews:this.enemies.size}})`;
 const ev=await p.send('Debugger.evaluateOnCallFrame',{callFrameId:paused.callFrames[0].callFrameId,expression});if(ev.exceptionDetails)throw Error(JSON.stringify(ev.exceptionDetails));
 await p.send('Debugger.removeBreakpoint',{breakpointId:bp.breakpointId});await p.send('Debugger.resume');await p.send('Debugger.disable');
 console.log(await p.eval('({player:window.__jiudingRead().state.player,objects:window.__jiudingRead().objects,view:window.__jiudingRead().view})'));
 }finally{p.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
