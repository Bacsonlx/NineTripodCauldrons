const { test } = require('node:test');
const assert = require('node:assert/strict');
const { TrainingRoom, ROOM } = require('../.test-build/TrainingRoom.js');

const idle = { moveX: 0, moveY: 0, aim: { x: 1000, y: 649 }, fire: false, pointerInside: true };
const arena = { ...ROOM, width: 1280, height: 900, floor: [{x:0,y:0},{x:1280,y:0},{x:1280,y:900},{x:0,y:900}], spawn: {x:400,y:700}, pillars: [], targets: [], obstacles: [], encounters: [{x:400,y:700,enemies:[{x:455,y:700}]}] };
function advance(room, seconds, input = idle) {
  for(let t=0;t<seconds-0.000001;t+=0.01)room.update(input,Math.min(0.01,seconds-t));
}
function fireUntilHit(room, kind = 'normal') {
  const previous=room.snapshot.hits;
  room.update(idle,0);
  room.update({...idle,fire:kind==='normal',pierce:kind==='pierce'},0);
  for(let i=0;i<80;i++){
    room.update(idle,0.01);
    if(room.snapshot.hits>previous)return room.snapshot;
  }
  assert.fail('arrow did not hit');
}

test('普通箭与Q分别造成15和40伤害，沿来箭方向击退14和36，且不取消敌方预警', () => {
  for(const [kind,damage,distance,duration] of [['normal',15,14,0.10],['pierce',40,36,0.14]]){
    const room=new TrainingRoom(arena);
    const hit=fireUntilHit(room,kind),enemy=hit.enemies[0],event=hit.effects.find(e=>e.enemy!==undefined);
    assert.equal(enemy.health,60-damage);
    assert.equal(event.damage,damage);
    assert.equal(event.kind,kind);
    assert.equal(enemy.phase,'warn');
    advance(room,duration);
    assert.ok(Math.abs(room.snapshot.enemies[0].x-enemy.x-Math.cos(event.angle)*distance)<0.01);
    assert.ok(Math.abs(room.snapshot.enemies[0].y-enemy.y-Math.sin(event.angle)*distance)<0.01);
    assert.equal(room.snapshot.enemies[0].phase,'warn');
    assert.ok(room.snapshot.enemies[0].timer<enemy.timer);
  }
});

test('击退遇到薄墙、关闭栅门或地图边缘均停止，长帧不会穿过实体', () => {
  for(const boundary of ['wall','gate','edge']){
    const layout={...arena,obstacles:boundary==='edge'?[]:[{x:490,y:700,halfWidth:1,halfHeight:80,height:100,kind:boundary}],floor:boundary==='edge'?[{x:0,y:0},{x:489,y:0},{x:489,y:900},{x:0,y:900}]:arena.floor};
    for(const coarse of [true,false]){
      const room=new TrainingRoom(layout);
      const hit=fireUntilHit(room,'pierce');
      if(coarse)room.update(idle,0.14);else advance(room,0.14);
      assert.ok(room.snapshot.enemies[0].x>hit.enemies[0].x);
      assert.ok(room.snapshot.enemies[0].x<=478);
    }
  }
});

test('致死箭飘字只报告剩余生命，不重复扣血；重试清除事件和击退状态', () => {
  const room=new TrainingRoom(arena);
  fireUntilHit(room,'pierce');
  advance(room,0.14);
  fireUntilHit(room);
  for(let i=0;i<100&&room.snapshot.enemies[0].health>0;i++)room.update({...idle,fire:true},0.01);
  assert.equal(room.snapshot.enemies[0].health,0);
  assert.equal(room.snapshot.enemies[0].phase,'dead');
  const fatal=room.snapshot.effects.find(e=>e.enemy!==undefined);
  assert.ok(fatal);
  assert.equal(fatal.damage,5);
  const count=room.snapshot.hits;
  advance(room,0.5,{...idle,fire:true});
  assert.equal(room.snapshot.hits,count);
  room.reset();
  assert.equal(room.snapshot.effects.length,0);
  assert.equal(room.snapshot.enemies[0].knockTime,0);
  assert.equal(room.snapshot.enemies[0].health,60);
});

test('命中墙体只有火花，无伤害飘字或小怪击退', () => {
  const room=new TrainingRoom({...arena,obstacles:[{x:436,y:700,halfWidth:2,halfHeight:15,height:100,kind:'wall'}]});
  room.update({...idle,fire:true},0);
  advance(room,0.09);
  assert.ok(room.snapshot.effects.length>0);
  assert.ok(room.snapshot.effects.every(e=>e.enemy===undefined&&e.damage===0));
  assert.equal(room.snapshot.enemies[0].health,60);
  assert.equal(room.snapshot.enemies[0].knockTime,0);
});

test('暂停冻结击退与反馈，恢复后继续，同一穿透箭对每只怪只产生一次伤害', () => {
  const room=new TrainingRoom(arena);
  fireUntilHit(room,'pierce');
  room.setPaused(true);
  const frozen=room.snapshot;
  advance(room,1);
  assert.deepEqual(room.snapshot,frozen);
  room.setPaused(false);
  advance(room,0.14);
  assert.equal(room.snapshot.enemies[0].health,20);
  assert.equal(room.snapshot.hits,1);
  assert.ok(room.snapshot.enemies[0].knockTime<0.000001);
});

test('箭雨每段各产生15点伤害反馈，沿落点向外击退且不合并成虚假大伤害', () => {
  const room=new TrainingRoom({...arena,encounters:[{x:400,y:700,enemies:[{x:680,y:700}]}]});
  room.update({...idle,rain:true,aim:{x:650,y:700}},0);
  advance(room,0.46);
  let state=room.snapshot;
  assert.equal(state.enemies[0].health,45);
  assert.equal(state.effects.find(e=>e.enemy!==undefined).damage,15);
  assert.ok(state.enemies[0].knockX<0);
  assert.ok(state.enemies[0].knockTime>0);
  advance(room,0.36);
  state=room.snapshot;
  assert.equal(state.enemies[0].health,15);
  assert.equal(state.hits,3);
  assert.ok(state.effects.every(e=>e.damage===15));
});
