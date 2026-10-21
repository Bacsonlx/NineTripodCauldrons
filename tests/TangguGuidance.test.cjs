const {test}=require('node:test');
const assert=require('node:assert/strict');
const {TANGGU,tangguGuidance}=require('../.test-build/Tanggu.js');
const {TrainingRoom}=require('../.test-build/TrainingRoom.js');

test('汤谷主路、两支路与捷径按通路区域给出地标名，支路重叠处优先显示探索区域',()=>{
 for(const [point,name] of [[{x:400,y:820},'扶桑残径'],[{x:1430,y:720},'断垣之道'],[{x:2110,y:750},'日鸟石庭'],[{x:840,y:365},'碑林幽径'],[{x:1080,y:760},'碑林幽径'],[{x:1660,y:1240},'祭火林地'],[{x:1865,y:1100},'祭火林地']])assert.equal(tangguGuidance(point,0,false).region,name);
 assert.equal(tangguGuidance({x:0,y:0},0,false).region,'汤谷');
});

test('下一地标使用遭遇自身名称和实际遭遇数，完成后允许回头探索',()=>{
 const room=new TrainingRoom(TANGGU);assert.equal(room.snapshot.totalEncounters,TANGGU.encounters.length);
 TANGGU.encounters.forEach((g,i)=>assert.equal(tangguGuidance(TANGGU.spawn,i,false).landmark,`下一地标 · ${g.landmark}`));
 assert.equal(tangguGuidance(TANGGU.spawn,3,true).landmark,'主路已肃清 · 可回头探索');
});

test('三组战斗地标位于石材庭院，铺路折线的所有分段均由通路覆盖',()=>{
 for(const g of TANGGU.encounters)assert.ok(TANGGU.walkableAreas.some(a=>a.material==='stone'&&g.x>=a.left&&g.x<=a.right&&g.y>=a.top&&g.y<=a.bottom));
 for(let i=1;i<TANGGU.mainRoute.length;i++)for(let step=0;step<=20;step++){
  const a=TANGGU.mainRoute[i-1],b=TANGGU.mainRoute[i],x=a.x+(b.x-a.x)*step/20,y=a.y+(b.y-a.y)*step/20;
  assert.ok(TANGGU.walkableAreas.some(r=>x>=r.left&&x<=r.right&&y>=r.top&&y<=r.bottom));
 }
});
