const { test } = require('node:test');
const assert = require('node:assert/strict');
const { TrainingRoom } = require('../.test-build/TrainingRoom.js');
const { TANGGU } = require('../.test-build/Tanggu.js');
const idle = { moveX: 0, moveY: 0, aim: { x: 950, y: 768 }, fire: false, pointerInside: true };
function advance(room, seconds, input = idle) {
  for (let t = 0; t < seconds - 0.00001; t += 0.01) room.update(input, Math.min(0.01, seconds - t));
}

test('起点草坡有可见边界：不能穿过道路外侧，但可沿主路向右行走', () => {
  const room = new TrainingRoom(TANGGU);
  advance(room, 1.2, { ...idle, moveY: -1 });
  assert.ok(room.snapshot.player.y >= 662, '草坡边界应阻止走入道路外侧');
  advance(room, 0.6, { ...idle, moveX: 1 });
  assert.ok(room.snapshot.player.x > 520, '沿主路仍能前进');
});

function walkTo(room, x, y) {
  for (let i = 0; i < 1400; i++) {
    const p = room.snapshot.player, dx = x - p.x, dy = y - p.y;
    if (Math.hypot(dx, dy) < 4) return;
    room.update({ ...idle, moveX: Math.abs(dx) < 2 ? 0 : Math.sign(dx), moveY: Math.abs(dy) < 2 ? 0 : Math.sign(dy) }, 0.01);
  }
  assert.fail(`正常移动不能到达 ${x},${y}，停在 ${room.snapshot.player.x},${room.snapshot.player.y}`);
}

test('主路岔口可往返两条支路，关闭捷径不能穿过，主路仍能到第三庭院', () => {
  const room = new TrainingRoom({ ...TANGGU, encounters: [] });
  for (const [x,y] of [[650,820],[1080,820],[1080,340],[850,340],[1080,340],[1080,790],[1240,790],[1430,720],[1550,720],[1550,1250],[1800,1250],[1865,1180],[1865,1130]]) walkTo(room,x,y);
  advance(room, 1, { ...idle, moveY: -1 });
  assert.ok(room.snapshot.player.y >= 1071, '关闭的栅门阻挡内侧通行');
  for (const [x,y] of [[1865,1180],[1800,1250],[1550,1250],[1550,720],[1800,720],[1880,750],[2300,950]]) walkTo(room,x,y);
  room.reset();
  assert.deepEqual({x:room.snapshot.player.x,y:room.snapshot.player.y},{x:400,y:820});
});

test('命中反馈区分普通箭与穿透箭，特效事件不改变原伤害', () => {
  const duel = { ...TANGGU, pillars: [], obstacles: [], encounters: [{x:400,y:820,enemies:[{x:620,y:820}]}] };
  const normal = new TrainingRoom(duel);
  for(let i=0;i<100&&!normal.snapshot.effects.length;i++) normal.update({ ...idle, aim:{x:620,y:776}, fire:true },0.01);
  assert.equal(normal.snapshot.enemies[0].health,45);
  assert.equal(normal.snapshot.effects[0]?.kind,'normal');
  const piercing = new TrainingRoom(duel);
  for(let i=0;i<100&&!piercing.snapshot.effects.length;i++) piercing.update({ ...idle, aim:{x:620,y:776}, pierce:true },0.01);
  assert.equal(piercing.snapshot.enemies[0].health,20);
  assert.equal(piercing.snapshot.effects[0]?.kind,'pierce');
});

test('栅门只在可见轮廓阻箭，门北侧空白处普通箭与Q均可飞过', () => {
  for (const kind of ['normal','pierce']) {
    const clear = new TrainingRoom({ ...TANGGU, spawn:{x:1785,y:985}, encounters:[], pillars:[] });
    advance(clear,0.34,{...idle,aim:{x:2300,y:933},fire:kind==='normal',pierce:kind==='pierce'});
    assert.equal(clear.snapshot.effects.length,0,`${kind}不应命中门上方的空白处`);
    assert.ok(clear.snapshot.arrows.some(a=>a.x>1931),`${kind}应正常飞过门上方`);
    const blocked = new TrainingRoom({ ...TANGGU, spawn:{x:1865,y:1130}, encounters:[], pillars:[] });
    for(let i=0;i<100&&!blocked.snapshot.effects.length;i++) blocked.update({...idle,aim:{x:1865,y:900},fire:kind==='normal',pierce:kind==='pierce'},0.01);
    assert.equal(blocked.snapshot.arrows.length,0,`${kind}仍应被可见的关闭栅门挡住`);
    assert.ok(blocked.snapshot.effects.length>0,`${kind}应显示门上的命中反馈`);
  }
});
