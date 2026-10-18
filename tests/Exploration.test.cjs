const { test } = require('node:test');
const assert = require('node:assert/strict');
const { TrainingRoom } = require('../.test-build/TrainingRoom.js');
const { TANGGU } = require('../.test-build/Tanggu.js');
const idle={moveX:0,moveY:0,aim:{x:1000,y:300},fire:false,pointerInside:true};
const advance=(r,t,input=idle)=>{for(let n=0;n<t-0.00001;n+=0.01)r.update(input,Math.min(0.01,t-n));};
const press=r=>{r.update({...idle,interact:false},0);r.update({...idle,interact:true},0);};
const at=(spawn,extra={})=>new TrainingRoom({...TANGGU,spawn,encounters:[],...extra});

test('靠近残碑按F阅读，长按不反复开关，游戏时间冻结，释放再按关闭且可重读',()=>{
 const r=at({x:840,y:365});
 advance(r,0.2,{...idle,pierce:true});
 const before=r.snapshot;
 assert.equal(before.interaction?.id,'stele');
 press(r);
 assert.equal(r.snapshot.reading,true);assert.equal(r.snapshot.exploration.steleRead,true);
 advance(r,1,{...idle,interact:true,moveX:1,fire:true,rain:true});
 assert.equal(r.snapshot.reading,true);
 assert.deepEqual(r.snapshot.player,before.player);
 assert.deepEqual(r.snapshot.arrows,before.arrows);
 assert.deepEqual(r.snapshot.cooldowns,before.cooldowns);
 press(r);assert.equal(r.snapshot.reading,false);
 press(r);assert.equal(r.snapshot.reading,true);
 r.reset();assert.equal(r.snapshot.reading,true,'阅读暂停中R不能重试');
 r.closeReading();r.reset();assert.equal(r.snapshot.exploration.steleRead,false);
});

test('互动只选可达最近对象，不隔墙、不越80距离，未激活敌人不阻止阅读',()=>{
 assert.equal(at({x:758,y:365}).snapshot.interaction,null);
 const blocked=at({x:840,y:425},{obstacles:[{x:840,y:395,halfWidth:45,halfHeight:6,height:40,kind:'wall'}]});
 press(blocked);assert.equal(blocked.snapshot.interaction,null);assert.equal(blocked.snapshot.reading,false);
 const nearest=at({x:840,y:365},{exploration:[{id:'stele',x:800,y:365},{id:'altar',x:880,y:365}],obstacles:[]});
 assert.equal(nearest.snapshot.interaction.id,'stele');press(nearest);assert.equal(nearest.snapshot.reading,true);
 const inactive=at({x:840,y:365},{encounters:[{x:2000,y:800,enemies:[{x:2100,y:800}]}]});
 press(inactive);assert.equal(inactive.snapshot.reading,true);
});

test('已激活影偶禁止互动且不冻结战斗；暂停中F不补发；阅读失焦后关闭仍需手动恢复',()=>{
 const combat=at({x:840,y:365},{encounters:[{x:840,y:365,enemies:[{x:910,y:365}]}]});
 combat.update(idle,0.01);press(combat);assert.equal(combat.snapshot.reading,false);
 assert.match(combat.snapshot.feedback.text,/清除/);const timer=combat.snapshot.enemies[0].timer;
 advance(combat,0.1);assert.notEqual(combat.snapshot.enemies[0].timer,timer);
 const r=at({x:840,y:365});r.setPaused(true);press(r);assert.equal(r.snapshot.reading,false);
 r.setPaused(false);advance(r,0.1,{...idle,interact:true});assert.equal(r.snapshot.reading,false);
 press(r);assert.equal(r.snapshot.reading,true);
 r.setPaused(true);r.closeReading();assert.equal(r.snapshot.paused,true);
 advance(r,1,{...idle,moveX:1,fire:true,interact:true});assert.equal(r.snapshot.reading,false);
 r.setPaused(false);r.update(idle,0);assert.equal(r.snapshot.arrows.length,0);
});

function hurtThenClear(health){
 const r=at({x:1660,y:1240},{obstacles:[],encounters:[{x:1660,y:1240,enemies:[{x:1710,y:1240}]}]});
 for(let i=0;i<2000&&r.snapshot.health>health;i++)r.update(idle,0.01);
 assert.equal(r.snapshot.health,health);
 advance(r,0.13);r.update({...idle,aim:{x:1710,y:1196},pierce:true},0);
 advance(r,0.3,{...idle,aim:{x:1710,y:1196}});
 for(let i=0;i<200&&!['complete','failed'].includes(r.snapshot.status);i++)r.update({...idle,aim:{x:1710,y:1196},fire:true},0.01);
 assert.equal(r.snapshot.status,'complete');assert.equal(r.snapshot.health,health);
 r.update(idle,0);return r;
}
test('祭坛满血不消耗；自然受伤清敌后只恢复一次40点并封顶，R全部复原',()=>{
 const full=at({x:1660,y:1240});press(full);
 assert.equal(full.snapshot.exploration.altarUsed,false);assert.equal(full.snapshot.feedback.text,'无需恢复');
 for(const [before,after] of [[80,100],[20,60]]){
  const r=hurtThenClear(before);press(r);
  assert.equal(r.snapshot.health,after);assert.equal(r.snapshot.exploration.altarUsed,true);
  assert.equal(r.snapshot.feedback.healed,true);press(r);assert.equal(r.snapshot.health,after);
  r.reset();assert.equal(r.snapshot.health,100);assert.deepEqual(r.snapshot.exploration,{steleRead:false,altarUsed:false,gateOpen:false});
 }
});

test('栅门只能内侧安全F开启；关闭挡移动/箭/闪避，开启同步放行并保持到R',()=>{
 const outside=at({x:1865,y:1000});press(outside);assert.equal(outside.snapshot.exploration.gateOpen,false);
 assert.match(outside.snapshot.feedback.text,/内侧/);
 const r=at({x:1865,y:1100});advance(r,0.3,{...idle,moveY:-1,dodge:true});
 assert.ok(r.snapshot.player.y>=1071);r.update(idle,0);press(r);
 assert.equal(r.snapshot.exploration.gateOpen,false);assert.ok(r.snapshot.gateOpening>0);
 advance(r,0.3);assert.equal(r.snapshot.exploration.gateOpen,true);
 advance(r,0.4,{...idle,moveY:-1,aim:{x:1865,y:900},fire:true});
 assert.ok(r.snapshot.player.y<1030);assert.ok(r.snapshot.arrows.some(a=>a.y<1005));
 assert.equal(r.snapshot.status,'running');r.reset();assert.equal(r.snapshot.exploration.gateOpen,false);
 const fighting=at({x:1865,y:1100},{encounters:[{x:1865,y:1100,enemies:[{x:1900,y:1150}]}]});
 fighting.update(idle,0);press(fighting);assert.equal(fighting.snapshot.exploration.gateOpen,false);
});

test('阅读中断闪避位移但保留冷却，关闭后没有新输入不会滑行',()=>{
 const r=at({x:840,y:365});r.update({...idle,dodge:true,moveX:1},0);press(r);
 assert.equal(r.snapshot.reading,true);assert.equal(r.snapshot.dodge,0);
 assert.equal(r.snapshot.cooldowns.dodge,1);r.closeReading();const x=r.snapshot.player.x;
 advance(r,0.4);assert.equal(r.snapshot.player.x,x);
});

test('三组所有影偶从正式出生点激活后均能正常追击，不困在灯火或实体内部',()=>{
 const spawns=[{x:650,y:850},{x:1290,y:720},{x:1840,y:750}];
 TANGGU.encounters.forEach((group,i)=>{
  const r=new TrainingRoom({...TANGGU,spawn:spawns[i],encounters:[{...spawns[i],enemies:group.enemies}]});
  advance(r,0.25);
  r.snapshot.enemies.forEach((e,j)=>assert.ok(Math.hypot(e.x-group.enemies[j].x,e.y-group.enemies[j].y)>1,`第${i+1}组第${j+1}只应能离开出生点`));
 });
});
