class CDP {
 constructor(socket){this.socket=socket;this.id=0;this.pending=new Map();this.handlers=new Map();socket.addEventListener('message',e=>{const m=JSON.parse(e.data);if(m.id){const p=this.pending.get(m.id);if(p){clearTimeout(p.timer);this.pending.delete(m.id);m.error?p.reject(Error(JSON.stringify(m.error))):p.resolve(m.result);}}else for(const fn of this.handlers.get(m.method)||[])fn(m.params);});}
 static async connect(port){const list=await(await fetch(`http://127.0.0.1:${port}/json/list`)).json();const t=list.find(x=>x.type==='page')||list[0];const socket=new WebSocket(t.webSocketDebuggerUrl);await new Promise((r,j)=>{socket.addEventListener('open',r,{once:true});socket.addEventListener('error',j,{once:true});});return new CDP(socket);}
 on(name,fn){if(!this.handlers.has(name))this.handlers.set(name,new Set());this.handlers.get(name).add(fn);return()=>this.handlers.get(name)?.delete(fn);}
 send(method,params={}){return new Promise((resolve,reject)=>{const id=++this.id;const timer=setTimeout(()=>{this.pending.delete(id);reject(Error(method+' timeout'));},15000);this.pending.set(id,{resolve,reject,timer});this.socket.send(JSON.stringify({id,method,params}));});}
 async eval(expression){const r=await this.send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;}
 async key(code,down){const names={Space:[' ',32],Escape:['Escape',27]};const [key,v]=names[code]||[code.slice(3).toLowerCase(),code.charCodeAt(3)];await this.send('Input.dispatchKeyEvent',{type:down?'keyDown':'keyUp',code,key,windowsVirtualKeyCode:v,nativeVirtualKeyCode:v});}
 async press(code){await this.key(code,true);await this.key(code,false);}
 async mouse(type,x,y,buttons=0){await this.send('Input.dispatchMouseEvent',{type,x,y,button:type==='mouseMoved'?'none':'left',buttons,clickCount:type==='mouseMoved'?0:1});}
 close(){for(const p of this.pending.values()){clearTimeout(p.timer);p.reject(Error('CDP closed'));}this.pending.clear();this.socket.close();}
}
module.exports={CDP,wait:ms=>new Promise(r=>setTimeout(r,ms))};
