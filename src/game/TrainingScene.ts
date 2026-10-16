import Phaser from 'phaser';
import { ROOM, TrainingRoom, type Point } from './TrainingRoom';
import floorUrl from '../../assets/mvp/tanggu-floor.svg';
import pillarUrl from '../../assets/mvp/pillar.svg';
import targetUrl from '../../assets/mvp/target.svg';
import childUrl from '../../assets/mvp/child-refined-v2.png';
import childFrames from '../../assets/mvp/child-refined-v2.frames.json';
import bowUrl from '../../assets/mvp/bow-refined-v2.png';
import arrowUrl from '../../assets/mvp/arrow-refined-v2.png';

export class TrainingScene extends Phaser.Scene {
  private room = new TrainingRoom();
  private keys = new Set<string>();
  private aim: Point = { x: 1000, y: 410 };
  private inside = false;
  private fire = false;
  private firePulse = false;
  private walkTime = 0;
  private bodyDirection = 0;
  private loaded = true;
  private child!: Phaser.GameObjects.Sprite;
  private bow!: Phaser.GameObjects.Image;
  private nockedArrow!: Phaser.GameObjects.Image;
  private shadow!: Phaser.GameObjects.Ellipse;
  private targets: Phaser.GameObjects.Image[] = [];
  private pillars: Phaser.GameObjects.Image[] = [];
  private arrows = new Map<number, Phaser.GameObjects.Image>();
  private effects!: Phaser.GameObjects.Graphics;
  private crosshair!: Phaser.GameObjects.Graphics;
  private collisionGuide!: Phaser.GameObjects.Graphics;

  constructor() { super('training'); }

  preload(): void {
    this.load.on('loaderror', () => {
      this.loaded = false;
      const status = document.getElementById('status')!;
      status.hidden = false;
      status.textContent = '素材加载失败，请关闭后重新启动。';
    });
    this.load.image('floor', floorUrl);
    this.load.image('pillar', pillarUrl);
    this.load.image('target', targetUrl);
    this.load.image('bow', bowUrl);
    this.load.image('arrow', arrowUrl);
    this.load.image('child', childUrl);
  }

  create(): void {
    if (!this.loaded) return;
    this.add.image(640, 360, 'floor');
    this.pillars = ROOM.pillars.map(p => this.add.image(p.x, p.y, 'pillar').setOrigin(0.5, 0.925).setScale(0.8).setDepth(p.y));
    this.targets = ROOM.targets.map(p => this.add.image(p.x, p.y, 'target').setOrigin(0.5, 0.94).setScale(0.8).setDepth(p.y));
    this.shadow = this.add.ellipse(400, 440, 36, 14, 0x111b1a, 0.45).setDepth(1);
    for (const frame of childFrames) this.textures.get('child').add(frame.name, 0, frame.x, frame.y, frame.width, frame.height);
    this.child = this.add.sprite(400, 440, 'child', '0-0').setScale(0.26);
    this.bow = this.add.image(400, 388, 'bow').setScale(0.035).setOrigin(805 / 1254, 620 / 1254);
    this.nockedArrow = this.add.image(400, 388, 'arrow').setOrigin(1509 / 1536, 0.5).setScale(0.029).setVisible(false);
    this.effects = this.add.graphics().setDepth(2000);
    this.crosshair = this.add.graphics().setDepth(3000);
    this.collisionGuide = this.add.graphics().setDepth(4000).setVisible(false);
    document.getElementById('status')!.hidden = true;

    const canvas = this.game.canvas;
    canvas.style.cursor = 'none';
    const onMove = (event: PointerEvent) => this.updatePointer(event);
    const onDown = (event: PointerEvent) => {
      this.updatePointer(event);
      if (event.button === 0 && this.inside && !this.room.snapshot.paused) {
        this.fire = true;
        this.firePulse = true;
      }
    };
    const onUp = (event: PointerEvent) => { if (event.button === 0) this.fire = false; };
    const onLeave = () => {
      this.inside = false;
      this.fire = false;
      this.firePulse = false;
      this.room.update({ moveX: 0, moveY: 0, aim: this.aim, fire: false, pointerInside: false }, 0);
    };
    const onKeyDown = (event: KeyboardEvent) => {
      if (!['KeyW', 'KeyA', 'KeyS', 'KeyD', 'KeyR', 'Escape', 'F1'].includes(event.code)) return;
      event.preventDefault();
      if (event.repeat) return;
      if (event.code === 'F1') this.collisionGuide.setVisible(!this.collisionGuide.visible);
      else if (event.code === 'Escape') {
        this.room.setPaused(!this.room.snapshot.paused);
        this.clearInput();
      } else if (!this.room.snapshot.paused) {
        if (event.code === 'KeyR') {
          this.room.reset();
          this.aim = { x: 1000, y: 410 };
          this.clearInput();
        } else this.keys.add(event.code);
      }
    };
    const onKeyUp = (event: KeyboardEvent) => this.keys.delete(event.code);
    const onBlur = () => { this.room.setPaused(true); this.clearInput(); };
    window.addEventListener('pointermove', onMove);
    window.addEventListener('pointerdown', onDown);
    window.addEventListener('pointerup', onUp);
    window.addEventListener('keydown', onKeyDown);
    window.addEventListener('keyup', onKeyUp);
    window.addEventListener('blur', onBlur);
    canvas.addEventListener('pointerleave', onLeave);
    this.events.once('shutdown', () => {
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerdown', onDown);
      window.removeEventListener('pointerup', onUp);
      window.removeEventListener('keydown', onKeyDown);
      window.removeEventListener('keyup', onKeyUp);
      window.removeEventListener('blur', onBlur);
      canvas.removeEventListener('pointerleave', onLeave);
      this.arrows.clear();
    });
  }

  private updatePointer(event: PointerEvent): void {
    const rect = this.game.canvas.getBoundingClientRect();
    this.inside = event.clientX >= rect.left && event.clientX < rect.right && event.clientY >= rect.top && event.clientY < rect.bottom;
    if (this.inside) this.aim = { x: (event.clientX - rect.left) * ROOM.width / rect.width, y: (event.clientY - rect.top) * ROOM.height / rect.height };
    else {
      this.fire = false;
      this.firePulse = false;
      this.room.update({ moveX: 0, moveY: 0, aim: this.aim, fire: false, pointerInside: false }, 0);
    }
  }

  private clearInput(): void {
    this.keys.clear();
    this.fire = false;
    this.firePulse = false;
    if (!this.room.snapshot.paused) this.room.update({ moveX: 0, moveY: 0, aim: this.aim, fire: false, pointerInside: this.inside }, 0);
  }

  update(_time: number, delta: number): void {
    if (!this.loaded || !this.child) return;
    const moveX = Number(this.keys.has('KeyD')) - Number(this.keys.has('KeyA'));
    const moveY = Number(this.keys.has('KeyS')) - Number(this.keys.has('KeyW'));
    this.room.update({ moveX, moveY, aim: this.aim, fire: this.fire || this.firePulse, pointerInside: this.inside }, Math.min(delta / 1000, 0.1));
    this.firePulse = false;
    const state = this.room.snapshot;
    const p = state.player;
    if (p.moving && !state.paused) {
      this.walkTime += delta / 1000;
    }
    const direction = this.direction(p.angle);
    const difference = Math.atan2(Math.sin(p.angle - this.bodyDirection * Math.PI / 2), Math.cos(p.angle - this.bodyDirection * Math.PI / 2));
    if (Math.abs(difference) > Math.PI / 4 + 0.08) this.bodyDirection = direction;
    const pose = p.moving ? 1 + Math.floor(this.walkTime * 9) % 2 : state.attack === 'draw' || state.attack === 'release' ? 3 : 0;
    const frame = childFrames[pose * 4 + this.bodyDirection];
    this.child.setPosition(p.x, p.y).setFrame(frame.name).setOrigin(frame.originX, frame.originY).setDepth(p.y + 0.1);
    this.shadow.setPosition(p.x, p.y);
    if (this.collisionGuide.visible) {
      const guide = this.collisionGuide.clear();
      guide.lineStyle(1, 0x88e4bf, 0.9).strokePoints([...ROOM.floor], true).strokeCircle(p.x, p.y, 12);
      for (const base of ROOM.pillars) {
        guide.lineStyle(1, 0x88e4bf, 0.9).strokeRect(base.x - 40, base.y - 30, 80, 60);
        guide.lineStyle(1, 0xffae69, 0.9);
        for (const [halfWidth, top, bottom] of ROOM.pillarBody) guide.strokeRect(base.x - halfWidth, base.y + top, halfWidth * 2, bottom - top);
      }
      for (const target of ROOM.targets) guide.lineStyle(1, 0xffae69, 0.9).strokeEllipse(target.x, target.y + ROOM.targetFace.offsetY, ROOM.targetFace.radiusX * 2, ROOM.targetFace.radiusY * 2);
    }
    const ready = p.moving || state.attack !== 'idle';
    const reach = ready ? 26 : 16;
    const bowX = p.x + Math.cos(p.angle) * reach;
    const bowY = p.y - (ready ? ROOM.shoulderHeight : 31) + Math.sin(p.angle) * reach;
    this.bow.setPosition(bowX, bowY).setRotation(p.angle).setDepth(p.y + 0.3).setScale(state.attack === 'draw' ? 0.037 : 0.035);
    this.nockedArrow.setPosition(bowX, bowY).setRotation(p.angle).setDepth(p.y + 0.4).setVisible(state.attack === 'draw');
    this.pillars.forEach((sprite, i) => {
      const base = ROOM.pillars[i];
      sprite.setAlpha(p.y < base.y && p.y > base.y - 105 && Math.abs(p.x - base.x) < 42 ? 0.45 : 1);
    });
    state.targets.forEach((t, i) => this.targets[i].setTint(t.flash > 0 ? 0xffd68a : 0xffffff));
    const active = new Set(state.arrows.map(a => a.id));
    for (const [id, image] of this.arrows) if (!active.has(id)) { image.destroy(); this.arrows.delete(id); }
    for (const a of state.arrows) {
      let image = this.arrows.get(a.id);
      if (!image) {
        image = this.add.image(a.x, a.y, 'arrow').setOrigin(1509 / 1536, 0.5).setScale(0.029).setDepth(1800);
        this.arrows.set(a.id, image);
      }
      image.setPosition(a.x, a.y).setRotation(a.angle);
    }
    this.effects.clear();
    for (const e of state.effects) {
      const life = e.remaining / 0.15;
      this.effects.lineStyle(e.target === null ? 1.5 : 2.5, 0xf3cc77, life);
      for (let i = 0; i < 7; i++) {
        const angle = i * Math.PI * 2 / 7;
        const radius = (1 - life) * 15 + 5;
        this.effects.lineBetween(e.x + Math.cos(angle) * 3, e.y + Math.sin(angle) * 3, e.x + Math.cos(angle) * radius, e.y + Math.sin(angle) * radius);
      }
    }
    this.crosshair.clear();
    if (this.inside && !state.paused) {
      this.crosshair.lineStyle(1.5, 0xf2dab0, 0.9).strokeCircle(this.aim.x, this.aim.y, 7);
      this.crosshair.lineBetween(this.aim.x - 12, this.aim.y, this.aim.x - 4, this.aim.y);
      this.crosshair.lineBetween(this.aim.x + 4, this.aim.y, this.aim.x + 12, this.aim.y);
      this.crosshair.lineBetween(this.aim.x, this.aim.y - 12, this.aim.x, this.aim.y - 4);
      this.crosshair.lineBetween(this.aim.x, this.aim.y + 4, this.aim.x, this.aim.y + 12);
    }
    const hits = document.getElementById('hit-count')!;
    if (hits.textContent !== String(state.hits)) hits.textContent = String(state.hits);
    const status = document.getElementById('status')!;
    status.hidden = !state.paused;
    status.textContent = '已暂停 · 按 Esc 继续';
  }

  private direction(angle: number): number {
    return (Math.round(angle / (Math.PI / 2)) + 4) % 4;
  }
}
