const { test } = require('node:test');
const assert = require('node:assert/strict');
const { TrainingRoom, ROOM } = require('../.test-build/TrainingRoom.js');

const idle = { moveX: 0, moveY: 0, aim: { x: 1000, y: 440 }, fire: false, pointerInside: true };

function advance(room, seconds, input = idle) {
  for (let i = 0; i < Math.round(seconds * 120); i++) room.update(input, 1 / 120);
}

test('玩家在房间中按住右移一秒后跑出220像素，松键立即停止', () => {
  const room = new TrainingRoom();
  advance(room, 1, { ...idle, moveX: 1 });
  assert.ok(Math.abs(room.snapshot.player.x - 620) < 0.01);
  assert.equal(room.snapshot.player.y, 440);
  advance(room, 0.5);
  assert.ok(Math.abs(room.snapshot.player.x - 620) < 0.01);
  assert.equal(room.snapshot.player.moving, false);
});

test('斜向跑动不加速，向右移动时仍可朝左瞄准', () => {
  const room = new TrainingRoom();
  advance(room, 0.25, { ...idle, moveX: 1, moveY: -1, aim: { x: 100, y: 410 } });
  assert.ok(Math.abs(Math.hypot(room.snapshot.player.x - 400, room.snapshot.player.y - 440) - 55) < 0.01);
  assert.ok(Math.cos(room.snapshot.player.angle) < -0.9);
});

test('玩家被柱基挡住，沿柱移动可绕行，持续向下不会跑出房间', () => {
  const room = new TrainingRoom();
  advance(room, 1, { ...idle, moveX: 1 });
  advance(room, 0.5, { ...idle, moveY: -1 });
  assert.ok(room.snapshot.player.y >= 389.9);
  advance(room, 0.4, { ...idle, moveX: 1, moveY: -1 });
  assert.ok(room.snapshot.player.x > 670);
  advance(room, 5, { ...idle, moveY: 1 });
  assert.ok(room.snapshot.player.y < 620);
  assert.equal(room.snapshot.player.moving, false);
});

test('短按拉弦后松手仍射完一箭，靶只计一次且箭会清理', () => {
  const room = new TrainingRoom();
  const aimed = { ...idle, aim: { x: 920, y: 387 } };
  room.update({ ...aimed, fire: true }, 1 / 120);
  advance(room, 1.5, aimed);
  assert.equal(room.snapshot.hits, 1);
  assert.equal(room.snapshot.arrows.length, 0);
});

test('按住按间隔连射，释放后不再增加待发射的箭', () => {
  const room = new TrainingRoom();
  const aimed = { ...idle, aim: { x: 920, y: 387 } };
  advance(room, 3, { ...aimed, fire: true });
  assert.equal(room.snapshot.hits, 7);
  advance(room, 2, aimed);
  const hits = room.snapshot.hits;
  advance(room, 2, aimed);
  assert.equal(room.snapshot.hits, hits);
  assert.equal(room.snapshot.arrows.length, 0);
});

test('前摇中离开画面会取消这一箭，重新进入仍按住时不会自行续射', () => {
  const room = new TrainingRoom();
  const aimed = { ...idle, aim: { x: 920, y: 387 }, fire: true };
  room.update(aimed, 0.01);
  advance(room, 0.2, { ...aimed, pointerInside: false });
  advance(room, 2, aimed);
  assert.equal(room.snapshot.hits, 0);
  assert.equal(room.snapshot.arrows.length, 0);
  room.update({ ...aimed, fire: false }, 0.01);
  advance(room, 1, aimed);
  assert.ok(room.snapshot.hits >= 1);
});

test('暂停冻结箭和人物，取消未发攻击；恢复后须重新释放再按下', () => {
  const room = new TrainingRoom();
  const aimed = { ...idle, aim: { x: 920, y: 387 }, fire: true };
  advance(room, 0.1, aimed);
  room.setPaused(true);
  const before = room.snapshot;
  advance(room, 1, { ...aimed, moveX: 1 });
  assert.deepEqual(room.snapshot, before);
  room.setPaused(false);
  advance(room, 2, aimed);
  assert.equal(room.snapshot.hits, 1);
  assert.equal(room.snapshot.arrows.length, 0);
  room.update({ ...aimed, fire: false }, 0.01);
  advance(room, 1, aimed);
  assert.ok(room.snapshot.hits > 1);
});

test('柱先于后方靶命中，绕到另一侧后能命中同一靶', () => {
  const room = new TrainingRoom();
  const aim = { x: 820, y: 247 };
  advance(room, 2, { ...idle, aim, fire: true });
  assert.equal(room.snapshot.hits, 0);
  advance(room, 2, { ...idle, moveX: 1, aim });
  advance(room, 1, { ...idle, aim, fire: true });
  assert.ok(room.snapshot.hits > 0);
});

test('反复重置清除箭、反馈、计数和待发攻击，暂停时重置无效', () => {
  const room = new TrainingRoom();
  advance(room, 1, { ...idle, aim: { x: 920, y: 387 }, fire: true });
  for (let i = 0; i < 20; i++) room.reset();
  assert.deepEqual(room.snapshot.player, { x: 400, y: 440, angle: 0, moving: false });
  assert.equal(room.snapshot.hits, 0);
  assert.equal(room.snapshot.arrows.length, 0);
  assert.equal(room.snapshot.effects.length, 0);
  assert.equal(room.snapshot.windup, null);
  advance(room, 0.1, { ...idle, moveX: 1 });
  room.setPaused(true);
  const before = room.snapshot;
  room.reset();
  assert.deepEqual(room.snapshot, before);
});

test('箭能命中可见靶面的上沿，而不是只检测靶下方', () => {
  const room = new TrainingRoom();
  const aimed = { ...idle, aim: { x: 920, y: 358 } };
  room.update({ ...aimed, fire: true }, 1 / 120);
  advance(room, 1.5, aimed);
  assert.equal(room.snapshot.hits, 1);
});

test('精修人物的箭从肩部参考沿准星方向释放，近零瞄准保留原方向', () => {
  const room = new TrainingRoom();
  const aim = { x: 920, y: 375 };
  advance(room, 0.09, { ...idle, aim, fire: true });
  const { player, arrows } = room.snapshot;
  assert.equal(arrows.length, 1);
  const originY = player.y - ROOM.shoulderHeight;
  assert.ok(Math.abs(Math.atan2(aim.y - originY, aim.x - player.x) - arrows[0].angle) < 0.0001);
  assert.ok(Math.abs((arrows[0].x - player.x) * Math.sin(player.angle) - (arrows[0].y - originY) * Math.cos(player.angle)) < 0.001);
  room.update({ ...idle, aim: { x: player.x, y: originY } }, 0);
  assert.equal(room.snapshot.player.angle, player.angle);
});

test('冷却内点击不排队，松手后不会在下次可攻击时补发', () => {
  const room = new TrainingRoom();
  const aimed = { ...idle, aim: { x: 920, y: 375 } };
  advance(room, 0.1, { ...aimed, fire: true });
  advance(room, 0.05, aimed);
  room.update({ ...aimed, fire: true }, 0.01);
  advance(room, 2, aimed);
  assert.equal(room.snapshot.hits, 1);
});

test('大步长箭路仍只命中最早接触，不越过靶或柱', () => {
  for (const [aim, expected] of [[{ x: 920, y: 375 }, 1], [{ x: 820, y: 235 }, 0]]) {
    const room = new TrainingRoom();
    advance(room, 0.09, { ...idle, aim, fire: true });
    room.update({ ...idle, aim }, 1);
    assert.equal(room.snapshot.hits, expected);
    assert.equal(room.snapshot.arrows.length, 0);
  }
});
