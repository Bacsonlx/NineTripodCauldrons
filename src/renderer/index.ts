import Phaser from 'phaser';
import { TrainingScene } from '../game/TrainingScene';

async function start(): Promise<void> {
  const version = await window.desktop.getAppVersion();

  new Phaser.Game({
    type: Phaser.WEBGL,
    parent: 'game',
    backgroundColor: '#171b1b',
    scale: {
      mode: Phaser.Scale.FIT,
      autoCenter: Phaser.Scale.CENTER_BOTH,
      width: 1280,
      height: 720,
    },
    scene: [TrainingScene],
  });
  document.getElementById('version')!.textContent = `MVP-01 · ${version}`;
}

void start().catch((error: unknown) => {
  console.error('九鼎初始化失败', error);
  document.getElementById('game')!.textContent = '初始化失败，请查看开发日志。';
});
