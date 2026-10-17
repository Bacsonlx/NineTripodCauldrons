import Phaser from 'phaser';
import { TrainingRoom, SKILL_COOLDOWNS, RAIN_RADIUS, type Point } from './TrainingRoom';
import { TANGGU } from './Tanggu';
import { cameraView, screenToWorld } from './CameraView';
import { TangguBackdrop } from './TangguBackdrop';
import { CombatEffects } from './CombatEffects';
import upperUrl from '../../assets/mvp/child-upper-refined-v3.png';
import oldFrames from '../../assets/mvp/child-refined-v3.frames.json';
import bowUrl from '../../assets/mvp/bow-states-v3.png';
import arrowUrl from '../../assets/mvp/arrow-refined-v2.png';
import lowerUrl from '../../assets/mvp02/child-lower-unified-v2.png';
import failedUrl from '../../assets/mvp02/child-failed-v1.png';
import skillsUrl from '../../assets/mvp02/child-skills-upper-v1.png';
import enemyUrl from '../../assets/mvp02/shadow-puppet-v2.png';
import enemyPaperUrl from '../../assets/mvp02/shadow-paper-v2.png';
import enemyWoodUrl from '../../assets/mvp02/shadow-wood-v2.png';
import propsUrl from '../../assets/mvp02/tanggu-props-v1.png';
import atlases from '../../assets/mvp02/atlases.json';
import junctionUrl from '../../assets/mvp03/junction-ground-v1.png';
import samplePropsUrl from '../../assets/mvp03/junction-props-v1.png';
import vfxUrl from '../../assets/mvp03/combat-vfx-v1.png';
import sampleFrames from '../../assets/mvp03/frames.json';

type Frame = { name: string; x: number; y: number; width: number; height: number; originX: number; originY: number };
const ENEMY_TEXTURES = { bird: 'enemy', paper: 'enemyPaper', wood: 'enemyWood' } as const;
type EnemyView = { body: Phaser.GameObjects.Sprite; shadow: Phaser.GameObjects.Ellipse };

export class TrainingScene extends Phaser.Scene {
  private room = new TrainingRoom(TANGGU);
  private keys = new Set<string>();
  private pointer = { x: 0, y: 0, present: false, controls: false };
  private fire = false;
  private firePulse = false;
  private skills = { pierce: false, rain: false, dodge: false };
  private loaded = true;
  private walkTime = 0;
  private moveDirection = 0;
  private motion = 0;
  private clock = 0;
  private legs!: Phaser.GameObjects.Sprite;
  private legsTransition!: Phaser.GameObjects.Sprite;
  private gaitTime = 0;
  private gaitMoving = false;
  private gaitDirection = 0;
  private torso!: Phaser.GameObjects.Sprite;
  private failedBody!: Phaser.GameObjects.Sprite;
  private bow!: Phaser.GameObjects.Image;
  private nockedArrow!: Phaser.GameObjects.Image;
  private shadow!: Phaser.GameObjects.Ellipse;
  private props: { image: Phaser.GameObjects.Image; x: number; y: number; width: number; height: number }[] = [];
  private enemies = new Map<number, EnemyView>();
  private arrows = new Map<number, Phaser.GameObjects.Image>();
  private groundEffects!: Phaser.GameObjects.Graphics;
  private airEffects!: Phaser.GameObjects.Graphics;
  private crosshair!: Phaser.GameObjects.Graphics;
  private dust!: Phaser.GameObjects.Graphics;
  private lastPaused = false;
  private backdrop!: TangguBackdrop;
  private combatEffects!: CombatEffects;

  constructor() { super('training'); }

  preload(): void {
    this.load.on('loaderror', () => this.fail('素材加载失败，请关闭后重新启动。'));
    for (const [key, url] of Object.entries({ upper: upperUrl, bow: bowUrl, arrow: arrowUrl, lower: lowerUrl, failed: failedUrl, skills: skillsUrl, enemy: enemyUrl, enemyPaper: enemyPaperUrl, enemyWood: enemyWoodUrl, props: propsUrl, junctionGround: junctionUrl, sampleProps: samplePropsUrl, vfx: vfxUrl })) this.load.image(key, url);
  }

  private fail(message: string): void {
    this.loaded = false;
    const status = document.getElementById('status')!;
    status.hidden = false;
    status.textContent = message;
  }

  create(): void {
    if (!this.loaded) return;
    const sources: [string, readonly Frame[]][] = [['upper', oldFrames.upper], ['bow', oldFrames.bow], ...Object.entries(atlases).map(([key, atlas]) => [key, atlas.frames] as [string, Frame[]]), ['sampleProps',sampleFrames.props], ['vfx',sampleFrames.vfx]];
    for (const [key, frames] of sources) {
      const texture = this.textures.get(key);
      const source = texture.getSourceImage() as HTMLImageElement;
      for (const f of frames) {
        if (f.x < 0 || f.y < 0 || f.x + f.width > source.width || f.y + f.height > source.height) { this.fail('图集裁切数据无效，请重新安装完整资源。'); return; }
        texture.add(f.name, 0, f.x, f.y, f.width, f.height);
      }
    }
    this.backdrop = new TangguBackdrop(this);
    this.groundEffects = this.add.graphics().setDepth(2);
    this.dust = this.add.graphics().setDepth(4);
    for (const pillar of TANGGU.pillars) this.addProp(3, pillar.x, pillar.y, 0.28, 80, 120);
    const frameFor = { tree: 0, root: 1, wall: 2, altar: 4 } as const;
    for (const p of TANGGU.obstacles) {
      if(p.kind==='gate'||p.kind==='brazier'||p.kind==='waystone')continue;
      this.addProp(frameFor[p.kind], p.x, p.y, p.kind === 'tree' ? 0.44 : p.kind === 'altar' ? 0.4 : 0.46, p.halfWidth * 2 + 24, p.height);
    }
    this.shadow = this.add.ellipse(400, 820, 36, 13, 0x100e0d, 0.45).setDepth(3);
    this.legsTransition = this.add.sprite(400,820,'lower').setVisible(false);
    this.legs = this.add.sprite(400,820,'lower').setScale(0.20);
    this.torso = this.add.sprite(400,790,'upper').setScale(0.20);
    this.failedBody = this.add.sprite(400,820,'failed').setScale(atlases.failed.scale).setVisible(false);
    this.bow = this.add.image(427,769,'bow').setScale(0.04);
    this.nockedArrow = this.add.image(427,769,'arrow').setOrigin(1509 / 1536,0.5).setScale(0.029).setVisible(false);
    for (const e of this.room.snapshot.enemies) this.enemies.set(e.id, {
      body: this.add.sprite(e.x,e.y,ENEMY_TEXTURES[e.appearance]).setScale(atlases[ENEMY_TEXTURES[e.appearance]].scale).setVisible(false),
      shadow: this.add.ellipse(e.x,e.y,36,12,0x0c0b0a,0.45).setDepth(3).setVisible(false),
    });
    this.airEffects = this.add.graphics().setDepth(4000);
    this.combatEffects = new CombatEffects(this,this.legs,this.torso);
    this.crosshair = this.add.graphics().setDepth(5000);
    this.installInput();
    this.updateCamera();
    document.getElementById('status')!.hidden = true;
  }

  private addProp(index: number, x: number, y: number, scale: number, width: number, height: number): void {
    const f = atlases.props.frames[index];
    this.add.ellipse(x,y,width,Math.max(12,width * 0.25),0x100e0d,0.3).setDepth(1);
    const image = this.add.image(x,y,'props',f.name).setOrigin(f.originX,f.originY).setScale(scale).setDepth(y);
    this.props.push({ image, x, y, width: Math.max(width,image.displayWidth), height: Math.max(height,image.displayHeight) });
  }

  private installInput(): void {
    const canvas = this.game.canvas;
    canvas.style.cursor = 'none';
    const point = (e: PointerEvent) => {
      this.pointer.x = e.clientX; this.pointer.y = e.clientY; this.pointer.present = true;
      this.pointer.controls = e.target instanceof Element && !!e.target.closest('button');
    };
    const down = (e: PointerEvent) => {
      point(e);
      if (e.button === 0 && this.inside() && !this.room.snapshot.paused && this.room.snapshot.status !== 'failed') { this.fire = true; this.firePulse = true; }
    };
    const up = (e: PointerEvent) => { if (e.button === 0) this.fire = false; };
    const leave = () => { this.pointer.present = false; this.fire = false; this.firePulse = false; this.skills.pierce = false; this.skills.rain = false; this.cancelPointer(); };
    const keydown = (e: KeyboardEvent) => {
      if (!['KeyW','KeyA','KeyS','KeyD','KeyQ','KeyE','KeyR','Space','Escape'].includes(e.code)) return;
      e.preventDefault();
      if (e.repeat) return;
      if (e.code === 'Escape') { this.room.setPaused(!this.room.snapshot.paused); this.clearInput(); }
      else if (e.code === 'KeyR' && !this.room.snapshot.paused) this.retry();
      else if (!this.room.snapshot.paused && this.room.snapshot.status !== 'failed') {
        if (e.code === 'KeyQ') this.skills.pierce = true;
        else if (e.code === 'KeyE') this.skills.rain = true;
        else if (e.code === 'Space') this.skills.dodge = true;
        else this.keys.add(e.code);
      }
    };
    const keyup = (e: KeyboardEvent) => this.keys.delete(e.code);
    const blur = () => { this.room.setPaused(true); this.clearInput(); };
    const resize = () => { this.clearInput(); this.updateCamera(); };
    const full = document.getElementById('fullscreen')!;
    const toggleFullscreen = () => { this.clearInput(); void window.desktop.toggleFullscreen().catch(() => this.fail('窗口模式切换失败，请重启后重试。')); };
    const state = (s: { fullscreen: boolean }) => { full.textContent = s.fullscreen ? '退出全屏' : '全屏'; full.setAttribute('aria-label',s.fullscreen ? '退出全屏' : '进入全屏'); this.clearInput(); };
    void window.desktop.getWindowState().then(state);
    const offWindowState = window.desktop.onWindowStateChange(state);
    window.addEventListener('pointermove',point);
    window.addEventListener('pointerdown',down);
    window.addEventListener('pointerup',up);
    window.addEventListener('keydown',keydown);
    window.addEventListener('keyup',keyup);
    window.addEventListener('blur',blur);
    canvas.addEventListener('pointerleave',leave);
    this.scale.on('resize',resize);
    full.addEventListener('click',toggleFullscreen);
    this.events.once('shutdown', () => {
      window.removeEventListener('pointermove',point);window.removeEventListener('pointerdown',down);window.removeEventListener('pointerup',up);
      window.removeEventListener('keydown',keydown);window.removeEventListener('keyup',keyup);window.removeEventListener('blur',blur);
      canvas.removeEventListener('pointerleave',leave);this.scale.off('resize',resize);full.removeEventListener('click',toggleFullscreen);offWindowState();
      this.arrows.clear();this.enemies.clear();this.props = [];
    });
  }

  private inside(): boolean {
    const r = this.game.canvas.getBoundingClientRect();
    return this.pointer.present && !this.pointer.controls && this.pointer.x >= r.left && this.pointer.x < r.right && this.pointer.y >= r.top && this.pointer.y < r.bottom;
  }

  private cancelPointer(): void {
    this.room.update({moveX:0,moveY:0,aim:{x:0,y:0},fire:false,pointerInside:false},0);
  }

  private clearInput(): void {
    this.keys.clear();this.fire = false;this.firePulse = false;this.skills = {pierce:false,rain:false,dodge:false};
    if (!this.room.snapshot.paused) this.cancelPointer();
  }

  private retry(): void {
    this.combatEffects.reset();
    this.room.reset();this.walkTime = 0;this.moveDirection = 0;this.motion = 0;this.gaitTime = 0;this.gaitMoving = false;this.gaitDirection = 0;this.legsTransition.setVisible(false);this.clearInput();this.updateCamera();
  }

  private updateCamera() {
    const c = this.cameras.main;
    const v = cameraView(this.room.snapshot.player,this.scale.width,this.scale.height,TANGGU.width,TANGGU.height);
    // A top-left camera origin makes the same transform serve input and rendering.
    c.setOrigin(0,0).setZoom(v.zoom).setScroll(v.x,v.y);
    return v;
  }

  private pose(sprite: Phaser.GameObjects.Sprite, texture: string, frame: Frame, x: number, y: number): void {
    sprite.setTexture(texture,frame.name).setOrigin(frame.originX,frame.originY).setPosition(x,y);
  }

  update(_time: number, delta: number): void {
    if (!this.loaded || !this.legs) return;
    const dt = Math.min(delta / 1000,0.1);
    const view = this.updateCamera();
    const rect = this.game.canvas.getBoundingClientRect();
    const aim = screenToWorld({x:(this.pointer.x-rect.left)*this.scale.width/rect.width,y:(this.pointer.y-rect.top)*this.scale.height/rect.height},view);
    const moveX = Number(this.keys.has('KeyD'))-Number(this.keys.has('KeyA'));
    const moveY = Number(this.keys.has('KeyS'))-Number(this.keys.has('KeyW'));
    this.room.update({moveX,moveY,aim,fire:this.fire||this.firePulse,pointerInside:this.inside(),...this.skills},dt);
    this.firePulse = false;this.skills = {pierce:false,rain:false,dodge:false};
    const s = this.room.snapshot,p = s.player;
    if (!s.paused && s.status !== 'failed') this.clock += dt;
    if (p.moving && !s.paused) { this.walkTime += dt;this.moveDirection = this.direction(s.dodge > 0 ? Math.atan2(s.dodgeDirection.y,s.dodgeDirection.x) : Math.atan2(moveY,moveX)); }
    if (!s.paused) this.motion = Phaser.Math.Linear(this.motion,p.moving ? 1 : 0,Math.min(1,dt*18));
    const moving = p.moving && s.dodge <= 0;
    const legDirection = moving ? this.moveDirection : p.facing;
    if (!s.paused && (moving !== this.gaitMoving || legDirection !== this.gaitDirection)) {
      this.legsTransition.setTexture(this.legs.texture.key,this.legs.frame.name).setOrigin(this.legs.originX,this.legs.originY).setScale(this.legs.scaleX,this.legs.scaleY);
      this.gaitTime = 0.08;
      if (moving && !this.gaitMoving) this.walkTime = 0;
      this.gaitMoving = moving;this.gaitDirection = legDirection;
    }
    if (!s.paused) this.gaitTime = Math.max(0,this.gaitTime-dt);
    const step = Math.floor(this.walkTime * 12) % atlases.lower.runFramesPerDirection;
    const leg = atlases.lower.frames[(moving ? (step+1)*4 : 0)+legDirection];
    const bob = Math.sin(this.walkTime*Math.PI*24/7)*this.motion*0.8;
    this.pose(this.legs,'lower',leg,p.x,p.y+bob);
    this.legs.setScale(leg.scale);
    const attackPose = {idle:0,draw:1,release:2,recover:3}[s.attack];
    let texture = 'upper',upper: Frame = oldFrames.upper[attackPose*4+p.facing];
    if (s.status === 'failed' || s.hurt > 0) { texture='skills';upper=atlases.skills.frames[12+p.facing]; }
    else if (s.dodge > 0) { texture='skills';upper=atlases.skills.frames[8+p.facing]; }
    else if (s.skill?.phase === 'windup') { texture='skills';upper=atlases.skills.frames[(s.skill.kind==='rain'?4:0)+p.facing]; }
    else if (s.skill) upper=oldFrames.upper[(s.skill.remaining>0.06?2:3)*4+p.facing];
    this.pose(this.torso,texture,upper,p.x,p.y-30+bob);
    const alpha = s.protection > 0 && Math.floor(this.clock*16)%2 ? 0.55 : 1;
    const blend = this.gaitTime / 0.08;
    this.legsTransition.setVisible(blend>0).setPosition(p.x,p.y+bob).setDepth(p.y+0.09).setAlpha(alpha*blend);
    this.legs.setAlpha(alpha*(1-blend)).setDepth(p.y+0.1);this.torso.setAlpha(alpha).setDepth(p.y+0.2);
    const failed = s.status === 'failed';
    this.legs.setVisible(!failed);this.torso.setVisible(!failed);
    this.legsTransition.setVisible(!failed&&blend>0);
    this.failedBody.setVisible(failed);
    if(failed)this.pose(this.failedBody,'failed',atlases.failed.frames[p.facing],p.x,p.y);
    this.failedBody.setDepth(p.y+0.2);
    this.shadow.setPosition(p.x,p.y);
    const bow = oldFrames.bow[s.attack==='draw'||s.skill?.phase==='windup' ? 1 : s.attack==='release' ? 2 : 0];
    this.bow.setFrame(bow.name).setOrigin(bow.originX,bow.originY).setPosition(s.grip.x,s.grip.y+bob).setRotation(s.skill?.kind==='rain'&&s.skill.phase==='windup'?-Math.PI/2:p.angle).setDepth(p.y+0.3).setVisible(s.status!=='failed');
    this.nockedArrow.setPosition(s.grip.x,s.grip.y+bob).setRotation(p.angle).setDepth(p.y+0.4).setVisible(s.attack==='draw'||(s.skill?.kind==='pierce'&&s.skill.phase==='windup'));
    for (const prop of this.props) prop.image.setAlpha(p.y < prop.y && p.y > prop.y-prop.height && Math.abs(p.x-prop.x)<prop.width/2 ? 0.30 : 1);
    this.backdrop.update(p,this.clock);
    const ground = this.groundEffects.clear(),air = this.airEffects.clear();
    for (const e of s.enemies) {
      const v = this.enemies.get(e.id)!;
      const visible = e.phase !== 'inactive' && (e.phase !== 'dead'||e.timer>0);
      v.body.setVisible(visible);v.shadow.setVisible(visible);
      if (!visible) continue;
      const row = e.phase==='dead'?6:e.flash>0?5:e.phase==='warn'?3:e.phase==='swing'?4:e.phase==='recover'?(e.timer<0.18?0:5):e.phase==='chase'?1+Math.floor(this.clock*8)%2:0;
      const texture = ENEMY_TEXTURES[e.appearance];
      this.pose(v.body,texture,atlases[texture].frames[row*4+this.direction(e.angle)],e.x,e.y);
      v.body.setDepth(e.y+0.1).setAlpha(e.phase==='dead'?e.timer/0.6:1).setTint(e.flash>0?0xffd89b:0xffffff);v.shadow.setPosition(e.x,e.y).setAlpha(e.phase==='dead'?e.timer*0.5:0.35);
      if (e.phase !== 'dead') {
        air.fillStyle(0x151714,0.85).fillRect(e.x-20,e.y-88,40,4);
        air.fillStyle(0xbc6745,0.95).fillRect(e.x-20,e.y-88,40*e.health/60,4);
      }
      if (e.phase==='warn'||e.phase==='swing') {
        ground.fillStyle(0xb34830,e.phase==='swing'?0.48:0.16).slice(e.x,e.y,70,e.angle-Math.PI/4,e.angle+Math.PI/4,false).fillPath();
        ground.lineStyle(e.phase==='swing'?3:1.5,0xef8860,0.95).beginPath().arc(e.x,e.y,70,e.angle-Math.PI/4,e.angle+Math.PI/4,false).strokePath();
        for(const offset of [-Math.PI/4,Math.PI/4])ground.lineBetween(e.x,e.y,e.x+Math.cos(e.angle+offset)*70,e.y+Math.sin(e.angle+offset)*70);
      }
    }
    if (s.rainPreview) this.rainCircle(ground,s.rainPreview,0.7,true);
    if (s.invalid) { const q=s.invalid;ground.lineStyle(2,0xe27d5a,0.9).strokeCircle(q.x,q.y,14).lineBetween(q.x-9,q.y-9,q.x+9,q.y+9).lineBetween(q.x+9,q.y-9,q.x-9,q.y+9); }
    for (const r of s.rains) {
      this.rainCircle(ground,r,Math.max(0,1-r.age/0.65),false);
    }
    const active = new Set(s.arrows.map(a=>a.id));
    for(const [id,image] of this.arrows) if(!active.has(id)){image.destroy();this.arrows.delete(id);}
    for(const a of s.arrows) {
      let image=this.arrows.get(a.id);
      if(!image){image=this.add.image(a.x,a.y,'arrow').setOrigin(1509/1536,0.5).setScale(a.kind==='pierce'?0.037:0.029);this.arrows.set(a.id,image);}
      image.setPosition(a.x,a.y).setRotation(a.angle).setDepth(a.y+52).setTint(a.kind==='pierce'?0xffd06c:0xffffff);
    }
    if(s.hurt>0){air.lineStyle(1.5,0xc97c59,s.hurt/0.12);for(let i=0;i<5;i++){const a=i*Math.PI*2/5;air.lineBetween(p.x+Math.cos(a)*18,p.y-40+Math.sin(a)*18,p.x+Math.cos(a)*26,p.y-40+Math.sin(a)*26);}}
    this.combatEffects.update(s,dt,this.clock);
    this.crosshair.clear();
    if(this.inside()&&!s.paused&&s.status!=='failed')this.crosshair.lineStyle(1.2,0xf5dbad,0.9).strokeCircle(aim.x,aim.y,6).lineBetween(aim.x-11,aim.y,aim.x-4,aim.y).lineBetween(aim.x+4,aim.y,aim.x+11,aim.y).lineBetween(aim.x,aim.y-11,aim.x,aim.y-4).lineBetween(aim.x,aim.y+4,aim.x,aim.y+11);
    this.dust.clear();
    for(let i=0;i<18;i++){const x=(170+i*137+this.clock*(i%2?5:-4)+TANGGU.width)%TANGGU.width,y=340+(i*73)%800+Math.sin(this.clock*0.6+i)*12;this.dust.fillStyle(0xbda16a,0.13).fillRect(x,y,2,1);}
    this.updateHUD(s);
  }

  private rainCircle(g: Phaser.GameObjects.Graphics,p: Point,alpha: number,preview: boolean): void {
    g.fillStyle(0xc5a05a,0.06*alpha).fillCircle(p.x,p.y,RAIN_RADIUS).lineStyle(preview?2:1.5,0xe6c47b,alpha).strokeCircle(p.x,p.y,RAIN_RADIUS).strokeCircle(p.x,p.y,RAIN_RADIUS-8);
    for(let i=0;i<8;i++){const a=i*Math.PI/4;g.lineBetween(p.x+Math.cos(a)*(RAIN_RADIUS-15),p.y+Math.sin(a)*(RAIN_RADIUS-15),p.x+Math.cos(a)*RAIN_RADIUS,p.y+Math.sin(a)*RAIN_RADIUS);}
  }

  private updateHUD(s: TrainingRoom['snapshot']): void {
    document.getElementById('health')!.textContent=String(s.health);
    (document.getElementById('health-fill') as HTMLElement).style.width=`${s.health}%`;
    const remaining=s.enemies.filter(e=>e.group===s.encounter&&e.phase!=='dead').length;
    document.getElementById('encounter')!.textContent=s.status==='complete'?'三庭肃清':`遭遇 ${Math.min(s.encounter+1,3)} / 3 · 影偶 ${remaining}`;
    document.getElementById('region')!.textContent=s.player.y<470&&s.player.x<1180?'碑林幽径':s.player.y>1040&&s.player.x>1400?'祭火林地':s.player.x<1160?'扶桑残径':s.player.x<1770?'断垣之道':'日鸟石庭';
    document.getElementById('landmark')!.textContent=s.status==='complete'?'主路已肃清 · 可回头探索':`下一地标 · ${['扶桑石庭','断垣庭院','日鸟石庭'][Math.min(s.encounter,2)]}`;
    for(const key of ['pierce','rain','dodge'] as const){const max=SKILL_COOLDOWNS[key];const el=document.getElementById(key)!;const cd=s.cooldowns[key];el.dataset.cooling=String(cd>0);el.style.setProperty('--cooldown',`${cd/max*100}%`);el.querySelector('.seconds')!.textContent=cd>0?cd.toFixed(1):'';}
    const status=document.getElementById('status')!;
    status.hidden=!s.paused&&s.status!=='failed';
    if(s.paused)status.textContent='已暂停 · 按 Esc 继续';
    else if(s.status==='failed')status.textContent='影散于汤谷 · 按 R 从起点重试';
    document.getElementById('complete')!.hidden=s.status!=='complete';
    if(s.paused!==this.lastPaused){this.lastPaused=s.paused;this.game.canvas.style.cursor=s.paused?'default':'none';}
  }

  private direction(angle: number): number { return (Math.round(angle/(Math.PI/2))+4)%4; }
}
