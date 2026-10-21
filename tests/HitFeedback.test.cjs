const {test}=require('node:test');
const assert=require('node:assert/strict');
const {HitFeedback}=require('../.test-build/HitFeedback.js');
const {TrainingRoom,ROOM}=require('../.test-build/TrainingRoom.js');
const frame=(runId,effects=[],extra={})=>({runId,effects,paused:false,status:'running',...extra});
const hit=(id,enemy=1)=>({id,enemy,target:null,x:450,y:649,angle:0,kind:'normal',remaining:0.15,damage:15,damagePosition:{x:455,y:700}});

test('同一命中快照重复读取不重复播放，飘字位置来自命中记录而非当前敌人坐标',()=>{
 const f=new HitFeedback(),s=frame(0,[hit(0)]);
 const first=f.update(s,0);assert.equal(first.numbers.length,1);assert.equal(first.numbers[0].damage,15);
 assert.equal(first.numbers[0].x,447);assert.equal(first.numbers[0].y,600);
 const again=f.update(s,0.1);assert.equal(again.numbers.length,1);assert.equal(again.bursts.length,1);
 assert.ok(Math.abs(again.numbers[0].age-0.1)<0.00001);
 assert.equal(f.update(s,0.6).numbers.length,0);
 assert.equal(f.update(s,0).numbers.length,0,'旧事件过期后也不能重新播放');
});

test('房间多次重试后低序号命中自动重新播放，无需调用显示reset且旧反馈清空',()=>{
 const layout={...ROOM,pillars:[],targets:[],encounters:[{x:400,y:440,enemies:[{x:455,y:440}]}]};
 const room=new TrainingRoom(layout),f=new HitFeedback();
 const input={moveX:0,moveY:0,aim:{x:1000,y:389},fire:false,pointerInside:true};
 for(let run=0;run<5;run++){
  let state=room.snapshot;
  assert.equal(f.update(state,0).numbers.length,0);
  room.update(input,0);room.update({...input,fire:true},0);
  for(let i=0;i<50&&!room.snapshot.effects.length;i++)room.update(input,0.01);
  state=room.snapshot;assert.equal(state.effects[0].id,0);
  assert.equal(f.update(state,0).numbers[0].damage,15);
  room.reset();assert.equal(room.snapshot.runId,run+1);
 }
});

test('暂停及失败冻结反馈寿命，恢复后自然结束；碰撞火花不产生正伤害数字',()=>{
 const f=new HitFeedback();f.update(frame(0,[hit(0)]),0);
 const paused=f.update(frame(0,[],{paused:true}),1);assert.equal(paused.numbers[0].age,0);
 assert.equal(f.update(frame(0,[],{status:'failed'}),1).numbers[0].age,0);
 assert.equal(f.update(frame(0),0.66).numbers.length,0);
 const wall={...hit(1),enemy:undefined,damage:0,damagePosition:null};
 const state=f.update(frame(0,[wall]),0);assert.equal(state.numbers.length,0);assert.equal(state.bursts.length,1);
});

test('多目标箭雨超过32个飘字时只复用32个槽位，结束后新命中仍能播放',()=>{
 const f=new HitFeedback(),s=f.update(frame(0,Array.from({length:40},(_,i)=>hit(i,i%12))),0);
 assert.equal(s.numbers.length,32);assert.equal(new Set(s.numbers.map(n=>n.slot)).size,32);
 f.update(frame(0),0.7);
 const next=f.update(frame(0,[hit(40)]),0);assert.equal(next.numbers.length,1);assert.ok(next.numbers[0].slot<32);
});
