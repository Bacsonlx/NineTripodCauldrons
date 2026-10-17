// Developer acceptance tool; no runtime dependencies and no gameplay/focus overrides.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const args = process.argv.slice(2);
const option = (key, fallback) => args.includes(key) ? args[args.indexOf(key)+1] : fallback;
const port = Number(option('--port',9335));
const seconds = Number(option('--seconds',60));
const delay = Number(option('--delay',10));
const output = path.resolve(option('--out','frame-timing.json'));
if (args.includes('--help')) {
  console.log('node capture-frame-timing.cjs --port 9335 --seconds 60 --delay 10 --out frame-timing.json');
  process.exit(0);
}
if (!Number.isFinite(seconds)||seconds<1||seconds>600||!Number.isFinite(delay)||delay<0||delay>120) throw new Error('Invalid duration');

(async()=>{
  const targets = await(await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  const target = targets.find(t=>t.type==='page'&&t.title.includes('九鼎'));
  if(!target)throw new Error('未找到九鼎游戏窗口，请先使用 --remote-debugging-port 参数启动游戏');
  const socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve,reject)=>{socket.addEventListener('open',resolve,{once:true});socket.addEventListener('error',reject,{once:true});});
  let sequence=0;
  const pending=new Map();
  let traceComplete;
  socket.addEventListener('message',event=>{
    const message=JSON.parse(event.data);
    if(message.id){const p=pending.get(message.id);if(p){clearTimeout(p.timeout);pending.delete(message.id);message.error?p.reject(new Error(message.error.message)):p.resolve(message.result);}}
    else if(message.method==='Tracing.tracingComplete')traceComplete?.(message.params);
  });
  const send=(method,params={})=>new Promise((resolve,reject)=>{
    const id=++sequence;
    const timeout=setTimeout(()=>{pending.delete(id);reject(new Error(`${method} timeout`));},15000);
    pending.set(id,{resolve,reject,timeout});socket.send(JSON.stringify({id,method,params}));
  });
  const evaluate=async expression=>{
    const response=await send('Runtime.evaluate',{expression,returnByValue:true});
    if(response.exceptionDetails)throw new Error(response.exceptionDetails.text);
    return response.result.value;
  };
  let tracing=false;
  try {
    await send('Performance.enable');
    await send('Tracing.start',{categories:'benchmark,cc,viz,disabled-by-default-devtools.timeline.frame',transferMode:'ReturnAsStream'});
    tracing=true;
    await evaluate(`(()=>{
      if(!document.getElementById('version')?.textContent.includes('MVP-02'))throw new Error('该窗口不是 MVP-02');
      if(window.__jiudingTiming)throw new Error('已有采样正在运行，请等待或重新启动游戏');
      const result={done:false,valid:true,interruptions:[],intervals:[],start:null,end:null,viewport:{css:[innerWidth,innerHeight],dpr:devicePixelRatio,canvas:[document.querySelector('canvas').width,document.querySelector('canvas').height]}};
      window.__jiudingTiming=result;
      let recording=false;
      const invalid=reason=>{if(!recording)return;result.valid=false;if(!result.interruptions.includes(reason))result.interruptions.push(reason);};
      const blur=()=>invalid('真实失焦');
      const key=e=>{if(e.code==='Escape'||e.code==='KeyR')invalid('暂停或重试中断');};
      const resize=()=>invalid('窗口大小或全屏切换');
      window.addEventListener('blur',blur);window.addEventListener('keydown',key);window.addEventListener('resize',resize);
      const finish=()=>{if(result.done)return;result.end=performance.now();result.done=true;window.removeEventListener('blur',blur);window.removeEventListener('keydown',key);window.removeEventListener('resize',resize);};
      setTimeout(()=>{
        recording=true;
        let previous;
        function frame(now){
          if(result.done)return;
          if(!document.hasFocus()||document.visibilityState!=='visible')invalid('未保持前台可见');
          if(!document.getElementById('status').hidden)invalid('暂停、失败或加载提示可见');
          if(result.start===null)result.start=now;
          if(previous!==undefined)result.intervals.push(now-previous);
          previous=now;
          if(now-result.start>=${seconds*1000})finish();else requestAnimationFrame(frame);
        }
        requestAnimationFrame(frame);
        setTimeout(()=>{if(!result.done){invalid('未采满连续帧');finish();}},${seconds*1000+2000});
      },${delay*1000});
    })()`);
    console.log(`${delay} 秒后开始；请将真实游戏置于前台，连续操作 ${seconds} 秒。失焦、暂停、失败或重试会保留为无效记录。`);
    const memory=[];
    let data;
    const deadline=Date.now()+(delay+seconds+15)*1000;
    while(Date.now()<deadline){
      await new Promise(r=>setTimeout(r,1000));
      data=await evaluate('window.__jiudingTiming');
      if(memory.length===0||Date.now()-memory.at(-1).time>=10000){const metrics=await send('Performance.getMetrics');memory.push({time:Date.now(),metrics:metrics.metrics.filter(m=>['JSHeapUsedSize','JSHeapTotalSize','Nodes','Documents'].includes(m.name))});}
      if(data.done)break;
    }
    if(!data?.done)throw new Error('采样超时；不能将未完成记录认定为通过');
    const traceReady=new Promise(resolve=>{traceComplete=resolve;});
    await send('Tracing.end');tracing=false;
    const trace=await traceReady;
    const tracePath=output.replace(/\.json$/i,'')+'.trace.json';
    fs.mkdirSync(path.dirname(output),{recursive:true});
    const fd=fs.openSync(tracePath,'w');
    try{while(true){const part=await send('IO.read',{handle:trace.stream});fs.writeSync(fd,part.base64Encoded?Buffer.from(part.data,'base64'):part.data);if(part.eof)break;}}finally{fs.closeSync(fd);await send('IO.close',{handle:trace.stream});}
    const sum=data.intervals.reduce((a,b)=>a+b,0);
    const averageFPS=data.intervals.length*1000/sum;
    const percentUnder20=data.intervals.filter(ms=>ms<=20).length/Math.max(1,data.intervals.length)*100;
    const summary={valid:data.valid&&sum>=seconds*1000,averageFPS,percentUnder20,sampledMilliseconds:sum,acceptance:'须结合 compositor trace、有效操作与平台记录复核；回调指标不自动等于验收通过',rafThresholdMet:data.valid&&sum>=seconds*1000&&averageFPS>=58&&percentUnder20>=95};
    fs.writeFileSync(output,JSON.stringify({device:{platform:os.platform(),arch:os.arch(),os:os.release(),cpu:os.cpus()[0]?.model,memoryBytes:os.totalmem()},conditions:{seconds,delay,traceEnabled:true,measurement:'requestAnimationFrame 显示回调间隔；附原始 Chromium compositor trace 复核，非 JS 单段执行耗时；未覆写焦点或丢弃慢帧'},...data,memory,summary,trace:path.basename(tracePath)},null,2)+'\n');
    await evaluate('delete window.__jiudingTiming');
    console.log(JSON.stringify({output,tracePath,...summary},null,2));
  } finally {
    if(tracing)await send('Tracing.end').catch(()=>{});
    await evaluate('delete window.__jiudingTiming').catch(()=>{});
    socket.close();
  }
})().catch(error=>{console.error(error.message);process.exitCode=1;});
