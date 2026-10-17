const { test } = require('node:test');
const assert = require('node:assert/strict');
const { TrainingRoom } = require('../.test-build/TrainingRoom.js');
const { TANGGU } = require('../.test-build/Tanggu.js');
const idle = { moveX: 0, moveY: 0, aim: { x: 1000, y: 768 }, fire: false, pointerInside: true };
function advance(room, seconds, input = idle) {
  for (let t = 0; t < seconds - 0.00001; t += 0.01) room.update(input, Math.min(0.01, seconds - t));
}

test('汤谷从安全起点进入扩大后的地图，松键立即停止且不会走出世界边缘', () => {
  const room = new TrainingRoom(TANGGU);
  assert.deepEqual({ x: room.snapshot.player.x, y: room.snapshot.player.y }, { x: 400, y: 820 });
  advance(room, 1, { ...idle, moveX: 1 });
  assert.ok(Math.abs(room.snapshot.player.x - 620) < 0.01);
  advance(room, 0.5);
  assert.ok(Math.abs(room.snapshot.player.x - 620) < 0.01);
  advance(room, 20, { ...idle, moveY: 1 });
  assert.ok(room.snapshot.player.y <= 1298);
});

const duel = { ...TANGGU, pillars: [], obstacles: [], encounters: [{ x: 400, y: 820, enemies: [{ x: 450, y: 820 }] }] };
test('影偶接触不伤人，预警后挥击一次，失败冻结并可从起点重试', () => {
  const room = new TrainingRoom(duel);
  advance(room, 0.01);
  assert.equal(room.snapshot.enemies[0].phase, 'warn');
  assert.equal(room.snapshot.health, 100);
  advance(room, 0.43);
  assert.equal(room.snapshot.health, 100);
  advance(room, 0.03);
  assert.equal(room.snapshot.health, 80);
  advance(room, 0.08);
  assert.equal(room.snapshot.health, 80);
  advance(room, 10);
  assert.equal(room.snapshot.status, 'failed');
  const frozen = room.snapshot;
  advance(room, 1, { ...idle, moveX: 1, fire: true });
  assert.deepEqual(room.snapshot, frozen);
  room.reset();
  assert.equal(room.snapshot.health, 100);
  assert.equal(room.snapshot.status, 'running');
  assert.equal(room.snapshot.enemies[0].phase, 'inactive');
});

test('闪避穿过影偶、挡在实体前，短暂无敌且不能同时射箭', () => {
  const room = new TrainingRoom({ ...duel, obstacles: [{ x: 535, y: 820, halfWidth: 10, halfHeight: 80, height: 100, kind: 'wall' }] });
  advance(room, 0.38);
  room.update({ ...idle, moveX: 1, dodge: true, fire: true }, 0);
  advance(room, 0.09, { ...idle, moveX: 1, fire: true });
  assert.equal(room.snapshot.health, 100);
  assert.equal(room.snapshot.arrows.length, 0);
  advance(room, 0.12, { ...idle, moveX: 1 });
  assert.ok(room.snapshot.player.x > 450);
  assert.ok(room.snapshot.player.x <= 513);
  assert.ok(room.snapshot.cooldowns.dodge > 0);
  room.reset();
  assert.equal(room.snapshot.cooldowns.dodge, 0);
});

test('Q 穿透多个影偶每只一次，并由中间实体阻断，按住不连发', () => {
  const line = { ...duel, encounters: [{ x: 400, y: 820, enemies: [{ x: 620, y: 820 }, { x: 800, y: 820 }] }] };
  const room = new TrainingRoom(line);
  room.update(idle, 0);
  advance(room, 0.65, { ...idle, pierce: true });
  assert.deepEqual(room.snapshot.enemies.map(e => e.health), [20, 20]);
  assert.ok(room.snapshot.cooldowns.pierce > 3);
  advance(room, 4.5, { ...idle, pierce: true, moveX: -1 });
  assert.equal(room.snapshot.cooldowns.pierce, 0);
  const blocked = new TrainingRoom({ ...line, obstacles: [{ x: 710, y: 820, halfWidth: 15, halfHeight: 22, height: 120, kind: 'wall' }] });
  blocked.update(idle, 0);
  advance(blocked, 0.7, { ...idle, pierce: true });
  assert.deepEqual(blocked.snapshot.enemies.map(e => e.health), [20, 60]);
});

test('E 锁定合法地面点，前摇无伤害，三段落箭；无效点不扣冷却', () => {
  const layout = { ...duel, obstacles: [{ x: 540, y: 820, halfWidth: 15, halfHeight: 25, height: 40, kind: 'root' }], encounters: [{ x: 400, y: 820, enemies: [{ x: 700, y: 820 }, { x: 760, y: 820 }] }] };
  const room = new TrainingRoom(layout);
  room.update(idle, 0);
  room.update({ ...idle, rain: true, aim: { x: 2500, y: 1400 } }, 0);
  assert.equal(room.snapshot.cooldowns.rain, 0);
  room.update(idle, 0);
  room.update({ ...idle, rain: true, aim: { x: 540, y: 820 } }, 0);
  assert.equal(room.snapshot.cooldowns.rain, 0);
  room.update(idle, 0);
  room.update({ ...idle, rain: true, aim: { x: 700, y: 820 } }, 0);
  assert.deepEqual(room.snapshot.rainPreview, { x: 700, y: 820 });
  advance(room, 0.44, { ...idle, aim: { x: 1500, y: 400 } });
  assert.deepEqual(room.snapshot.enemies.map(e => e.health), [60, 60]);
  advance(room, 0.04);
  assert.deepEqual(room.snapshot.enemies.map(e => e.health), [45, 45]);
  advance(room, 0.4);
  assert.deepEqual(room.snapshot.enemies.map(e => e.health), [15, 15]);
  assert.ok(room.snapshot.cooldowns.rain > 7);
});

test('影偶会绕过长残墙追击，不长期卡在直线路径上', () => {
  const room = new TrainingRoom({ ...duel, obstacles: [{ x: 650, y: 820, halfWidth: 24, halfHeight: 130, height: 120, kind: 'wall' }], encounters: [{ x: 400, y: 820, enemies: [{ x: 900, y: 820 }] }] });
  advance(room, 7);
  assert.ok(room.snapshot.enemies[0].x < 600);
});

test('三组按死亡推进，完成后仍可操作，重试清空全部技能和进度', () => {
  const full = new TrainingRoom(TANGGU);
  assert.deepEqual([0,1,2].map(g => full.snapshot.enemies.filter(e => e.group === g).length), [3,4,5]);
  const room = new TrainingRoom({ ...duel, encounters: [0,1,2].map(() => ({ x: 400, y: 820, enemies: [{ x: 620, y: 820 }] })) });
  room.update(idle, 0);
  assert.deepEqual(room.snapshot.enemies.map(e => e.phase), ['chase','inactive','inactive']);
  advance(room, 5.8, { ...idle, fire: true });
  assert.equal(room.snapshot.status, 'complete');
  assert.equal(room.snapshot.encounter, 3);
  const x = room.snapshot.player.x;
  advance(room, 0.1, { ...idle, moveX: 1 });
  assert.ok(room.snapshot.player.x > x);
  room.update({ ...idle, rain: true, aim: { x: 650, y: 820 } }, 0);
  for (let i = 0; i < 20; i++) room.reset();
  const state = room.snapshot;
  assert.equal(state.status,'running'); assert.equal(state.health,100); assert.equal(state.encounter,0);
  assert.equal(state.arrows.length,0); assert.equal(state.rains.length,0); assert.equal(state.effects.length,0);
  assert.equal(state.rainPreview,null); assert.deepEqual(state.cooldowns,{dodge:0,pierce:0,rain:0});
  assert.ok(state.enemies.every(e => e.phase === 'inactive' && e.health === 60));
});

test('受击取消未发箭雨且不退冷却，硬直中不能发起技能或闪避', () => {
  const room = new TrainingRoom(duel);
  advance(room, 0.38);
  room.update({ ...idle, rain: true, aim: { x: 450, y: 820 } },0);
  assert.equal(room.snapshot.cooldowns.rain,8);
  advance(room,0.09);
  assert.equal(room.snapshot.health,80);
  assert.equal(room.snapshot.rainPreview,null);
  assert.equal(room.snapshot.rains.length,0);
  assert.ok(room.snapshot.cooldowns.rain>7.8);
  room.update({...idle,pierce:true,dodge:true},0);
  assert.equal(room.snapshot.cooldowns.pierce,0);
  assert.equal(room.snapshot.cooldowns.dodge,0);
  advance(room,0.15);
  room.update({...idle,dodge:true},0);
  assert.equal(room.snapshot.cooldowns.dodge,1);
});

test('暂停取消未释放技能但保留冷却，已生效箭雨与敌人状态冻结，恢复后继续', () => {
  const room = new TrainingRoom({ ...duel, encounters: [{x:400,y:820,enemies:[{x:700,y:820}]}] });
  room.update(idle,0);
  room.update({...idle,rain:true,aim:{x:700,y:820}},0);
  advance(room,0.48);
  assert.equal(room.snapshot.enemies[0].health,45);
  room.setPaused(true);
  const paused = room.snapshot;
  advance(room,1,{...idle,moveX:1,pierce:true,dodge:true,fire:true});
  assert.deepEqual(room.snapshot,paused);
  room.setPaused(false);
  advance(room,0.36);
  assert.equal(room.snapshot.enemies[0].health,15);
  assert.ok(room.snapshot.cooldowns.rain>7);
  room.reset();room.update(idle,0);
  room.update({...idle,pierce:true},0);
  room.setPaused(true);room.setPaused(false);
  advance(room,0.3);
  assert.equal(room.snapshot.arrows.length,0);
  assert.ok(room.snapshot.cooldowns.pierce>3.6);
});

test('跨越箭雨前摇的长帧只推进生效后的余量，不提前结算后续段', () => {
  const room = new TrainingRoom({ ...duel, encounters: [{x:400,y:820,enemies:[{x:700,y:820}]}] });
  room.update(idle,0);room.update({...idle,rain:true,aim:{x:700,y:820}},0);
  advance(room,0.4);room.update(idle,0.1);
  assert.ok(Math.abs(room.snapshot.rains[0].age-0.05)<0.0001);
});

test('释放箭的长帧只推进离弦后的时间，不额外增加射程', () => {
  const room = new TrainingRoom({...duel,encounters:[]});
  room.update(idle,0);room.update({...idle,fire:true},0.1);
  assert.equal(room.snapshot.arrows.length,1);
  assert.ok(Math.abs(room.snapshot.arrows[0].age-0.02)<0.0001);
});

test('跨越闪避结束的长帧保留剩余普通移动时间', () => {
  const room = new TrainingRoom({...duel,encounters:[]});
  room.update(idle,0);room.update({...idle,moveX:1,dodge:true},0);
  room.update({...idle,moveX:1},0.15);room.update({...idle,moveX:1},0.1);
  assert.ok(Math.abs(room.snapshot.player.x-531)<0.001);
});

test('闪避无敌窗结束后仍处于有效挥击区域会受伤，不能多保护一个长帧', () => {
  const room = new TrainingRoom({...duel,obstacles:[{x:375,y:820,halfWidth:1,halfHeight:150,height:120,kind:'wall'}]});
  advance(room,0.35);room.update({...idle,moveX:-1,dodge:true},0);
  room.update({...idle,moveX:-1},0.13);
  assert.equal(room.snapshot.health,80);
});

test('敌人跨越预警和挥击边界保留余量，闪避不会因长帧多受一次伤', () => {
  const layout = {...duel,obstacles:[{x:375,y:820,halfWidth:1,halfHeight:150,height:120,kind:'wall'}]};
  for (const coarse of [true,false]) {
    const room = new TrainingRoom(layout);
    advance(room,0.44);room.update({...idle,moveX:-1,dodge:true},0);
    if(coarse){room.update({...idle,moveX:-1},0.1);room.update({...idle,moveX:-1},0.03);}
    else advance(room,0.13,{...idle,moveX:-1});
    assert.equal(room.snapshot.health,100);
    assert.equal(room.snapshot.enemies[0].phase,'recover');
  }
});

test('箭寿命结束后的长帧不再延长穿透箭射程', () => {
  const layout = {...duel,encounters:[],targets:[{x:1730,y:820.8}]};
  for (const coarse of [true,false]) {
    const room = new TrainingRoom(layout);
    const aim = {...idle,aim:{x:1000,y:776}};
    room.update(aim,0);room.update({...aim,pierce:true},0);room.update(aim,0.18);
    advance(room,1.39,aim);
    if(coarse)room.update(aim,0.1);else advance(room,0.1,aim);
    assert.equal(room.snapshot.hits,0);
    assert.equal(room.snapshot.arrows.length,0);
  }
});

test('暂停中断闪避位移且保留冷却，恢复后没有新输入不会滑行', () => {
  const room = new TrainingRoom({...duel,encounters:[]});
  room.update({...idle,moveX:1,dodge:true},0);room.update({...idle,moveX:1},0.05);
  room.setPaused(true);room.setPaused(false);
  const x = room.snapshot.player.x;
  room.update(idle,0.05);
  assert.equal(room.snapshot.player.x,x);
  assert.equal(room.snapshot.dodge,0);
  assert.ok(room.snapshot.cooldowns.dodge>0);
});

test('挥击结束后才进入范围不会被追溯扣血，长短帧结果一致', () => {
  for(const coarse of [true,false]) {
    const room = new TrainingRoom(duel);
    room.update(idle,0);advance(room,0.14,{...idle,moveX:-1});advance(room,0.39);
    if(coarse)room.update({...idle,moveX:1},0.1);else advance(room,0.1,{...idle,moveX:1});
    assert.equal(room.snapshot.health,100);
    assert.equal(room.snapshot.enemies[0].phase,'recover');
  }
});


test('三组共十二只影偶混合三种外观，外观不改变近战基础属性', () => {
  const room = new TrainingRoom(TANGGU);
  const enemies = room.snapshot.enemies;
  assert.equal(enemies.length,12);
  assert.deepEqual([...new Set(enemies.map(e=>e.appearance))].sort(),['bird','paper','wood']);
  assert.ok(enemies.every(e=>e.health===60&&e.phase==='inactive'));
});
