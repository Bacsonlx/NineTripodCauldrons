const { test } = require('node:test');
const assert = require('node:assert/strict');
const { cameraView, screenToWorld } = require('../.test-build/CameraView.js');
test('固定屏幕指针随跟随镜头重新映射世界坐标', () => {
  const before = cameraView({ x: 400, y: 820 }, 1280, 720, 2560, 1440);
  const after = cameraView({ x: 1000, y: 820 }, 1280, 720, 2560, 1440);
  assert.deepEqual(screenToWorld({ x: 1000, y: 410 }, before), { x: 1000, y: 870 });
  assert.deepEqual(screenToWorld({ x: 1000, y: 410 }, after), { x: 1360, y: 870 });
});
test('超宽窗口多显示横向世界，边缘镜头保持在地图内且比例一致', () => {
  const wide = cameraView({ x: 2000, y: 900 }, 2560, 1080, 2560, 1440);
  assert.equal(wide.zoom, 1.5);
  assert.ok(Math.abs(wide.x + 2560 / wide.zoom - 2560) < 0.001);
  assert.equal(wide.y, 540);
  const huge = cameraView({ x: 2000, y: 900 }, 4000, 450, 2560, 1440);
  assert.equal(huge.x, 0);
  assert.equal(4000 / huge.zoom, 2560);
});
