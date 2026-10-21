const {test}=require('node:test');
const assert=require('node:assert/strict');
const {PlayerControls}=require('../.test-build/PlayerControls.js');
const {TrainingRoom}=require('../.test-build/TrainingRoom.js');
const {TANGGU}=require('../.test-build/Tanggu.js');
const aim={x:1000,y:768};
function advance(c,t,inside=true){for(let i=0;i<t-0.00001;i+=0.01)c.update(aim,inside,Math.min(0.01,t-i));}
const tap=(c,key)=>{c.keyDown(key);c.keyUp(key);};

test('同帧前按下又松开的F只互动一次，长按与系统重复不反复开关残碑',()=>{
 const room=new TrainingRoom({...TANGGU,spawn:{x:840,y:365},encounters:[],obstacles:[]}),c=new PlayerControls(room);
 tap(c,'KeyF');c.update(aim,true,0.01);assert.equal(room.snapshot.reading,true);
 advance(c,0.2);assert.equal(room.snapshot.reading,true);
 c.keyDown('KeyF',true);c.update(aim,true,0.01);assert.equal(room.snapshot.reading,true);
 tap(c,'KeyF');c.update(aim,true,0.01);assert.equal(room.snapshot.reading,false);
 c.keyDown('KeyF');advance(c,0.2);assert.equal(room.snapshot.reading,true);
});

test('失焦叠加阅读后Esc只关闭阅读，仍暂停；恢复不续射，新的点按立即生效',()=>{
 const room=new TrainingRoom({...TANGGU,spawn:{x:840,y:365},encounters:[],obstacles:[]}),c=new PlayerControls(room);
 tap(c,'KeyF');c.update(aim,true,0);c.interrupt(true);
 c.keyDown('Escape');assert.equal(room.snapshot.reading,false);assert.equal(room.snapshot.paused,true);
 c.keyDown('KeyD');c.pointerDown(true);advance(c,0.1);assert.equal(room.snapshot.player.moving,false);
 c.keyDown('Escape');advance(c,0.1);assert.equal(room.snapshot.arrows.length,0);
 c.pointerDown(true);c.pointerUp();advance(c,0.1);assert.equal(room.snapshot.arrows.length,1);
});

test('视口变化取消前摇但不暂停，清除移动与技能脉冲且不退款冷却',()=>{
 const room=new TrainingRoom({...TANGGU,encounters:[]}),c=new PlayerControls(room);
 c.keyDown('KeyQ');c.keyDown('KeyD');c.update(aim,true,0.01);
 assert.ok(room.snapshot.cooldowns.pierce>0);
 c.interrupt();const x=room.snapshot.player.x;advance(c,0.3);
 assert.equal(room.snapshot.paused,false);assert.equal(room.snapshot.player.x,x);assert.equal(room.snapshot.arrows.length,0);
 assert.ok(room.snapshot.cooldowns.pierce>0);
});

test('鼠标离开只取消攻击，不清除WASD；回来按住不会续射，新点击可射箭',()=>{
 const room=new TrainingRoom({...TANGGU,encounters:[]}),c=new PlayerControls(room);
 c.keyDown('KeyD');c.pointerDown(true);c.update(aim,true,0.01);c.pointerLeave();
 advance(c,0.1,false);const x=room.snapshot.player.x;advance(c,0.2,true);
 assert.ok(room.snapshot.player.x>x);assert.equal(room.snapshot.arrows.length,0);
 advance(c,0.15);
 c.pointerDown(true);c.pointerUp();advance(c,0.1);assert.equal(room.snapshot.arrows.length,1);
});

test('暂停时按F/R和技能不积压，R重试清空移动和所有点按状态',()=>{
 const room=new TrainingRoom({...TANGGU,encounters:[]}),c=new PlayerControls(room);
 c.keyDown('Escape');for(const key of ['KeyF','KeyR','KeyQ','KeyE','Space'])tap(c,key);
 c.keyDown('Escape');advance(c,0.1);assert.equal(room.snapshot.runId,0);assert.equal(room.snapshot.cooldowns.pierce,0);
 c.keyDown('KeyD');c.pointerDown(true);advance(c,0.2);c.keyDown('KeyR');advance(c,0.1);
 assert.equal(room.snapshot.runId,1);assert.equal(room.snapshot.player.x,TANGGU.spawn.x);assert.equal(room.snapshot.arrows.length,0);
});
