import Phaser from 'phaser';
import { BootScene } from '../game/BootScene';

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
    scene: [new BootScene(version)],
  });
}

void start().catch((error: unknown) => {
  console.error('九鼎初始化失败', error);
  document.getElementById('game')!.textContent = '初始化失败，请查看开发日志。';
});
