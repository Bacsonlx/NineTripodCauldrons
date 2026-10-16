import Phaser from 'phaser';

export class BootScene extends Phaser.Scene {
  constructor(private readonly appVersion: string) {
    super('boot');
  }

  create(): void {
    this.add.text(640, 282, '九鼎', {
      fontFamily: 'Songti SC, SimSun, serif',
      fontSize: '76px',
      color: '#c9ab76',
    }).setOrigin(0.5);

    this.add.text(640, 366, '十日', {
      fontFamily: 'Songti SC, SimSun, serif',
      fontSize: '26px',
      color: '#c4c2b4',
    }).setOrigin(0.5);

    this.add.text(640, 444, `技术验证工程 · ${this.appVersion}`, {
      fontFamily: 'PingFang SC, Microsoft YaHei, sans-serif',
      fontSize: '16px',
      color: '#8c9993',
    }).setOrigin(0.5);
  }
}
