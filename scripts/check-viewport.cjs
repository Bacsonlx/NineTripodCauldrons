// Real Electron viewport regression: no page state or focus overrides.
const fs = require('node:fs');
const assert = require('node:assert/strict');
(async () => {
  const port = Number(process.argv[2] || 9345);
  const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  const target = targets.find(t => t.type === 'page' && t.title.includes('九鼎'));
  assert.ok(target, '九鼎 window must be running');
  const socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { socket.addEventListener('open', resolve, {once:true}); socket.addEventListener('error', reject, {once:true}); });
  let timeout;
  try {
    const result = await new Promise((resolve, reject) => {
      timeout = setTimeout(() => reject(new Error('Viewport inspection timed out')), 10000);
      socket.addEventListener('message', event => {
        const message = JSON.parse(event.data);
        if (message.id === 1) message.error || message.result.exceptionDetails ? reject(new Error(JSON.stringify(message))) : resolve(message.result.result.value);
      });
      socket.send(JSON.stringify({id:1,method:'Runtime.evaluate',params:{returnByValue:true,expression:`(()=>{const c=document.querySelector('canvas');const r=c.getBoundingClientRect();return {inner:[innerWidth,innerHeight],parent:[document.getElementById('game').clientWidth,document.getElementById('game').clientHeight],canvas:[c.width,c.height],css:[r.width,r.height],focus:document.hasFocus(),visibility:document.visibilityState}})()`}}));
    });
    console.log(result);
    if (process.argv[3]) fs.writeFileSync(process.argv[3], JSON.stringify(result,null,2)+'\n');
    assert.deepEqual(result.css,result.inner,'Canvas must fill actual viewport');
    assert.deepEqual(result.canvas,result.inner,'Internal canvas and camera size must match viewport');
  } finally { clearTimeout(timeout); socket.close(); }
})().catch(error => { console.error(error.message); process.exitCode=1; });
