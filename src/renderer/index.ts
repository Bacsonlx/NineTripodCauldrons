import Phaser from 'phaser';
import { TrainingScene } from '../game/TrainingScene';

async function start(): Promise<void> {
  const version = await window.desktop.getAppVersion();

  new Phaser.Game({
    type: Phaser.WEBGL,
    parent: 'game',
    backgroundColor: '#171b1b',
    scale: {
      mode: Phaser.Scale.RESIZE,
      width: '100%',
      height: '100%',
    },
    scene: [TrainingScene],
  });
  document.getElementById('version')!.textContent = `MVP-03 · 动态小样 · ${version}`;
}

void start().catch((error: unknown) => {
  console.error('九鼎初始化失败', error);
  document.getElementById('game')!.textContent = '初始化失败，请查看开发日志。';
});
