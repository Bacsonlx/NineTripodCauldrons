import Phaser from 'phaser';
import type { Point, TrainingRoom } from './TrainingRoom';
import { ATTACK_TIMING, RAIN_RADIUS } from './TrainingRoom';

type Snapshot = TrainingRoom['snapshot'];
type Burst = Point & { age: number; kind: 'normal' | 'pierce' | 'rain' | 'dust' };
type Ghost = { lower: Phaser.GameObjects.Sprite; upper: Phaser.GameObjects.Sprite; age: number };

export class CombatEffects {
  private stamps: Phaser.GameObjects.Image[] = [];
  private used = 0;
  private bursts: Burst[] = [];
  private trails = new Map<number,Point[]>();
  private lastImpact = -1;
  private ghostTimer = 0;
  private wasDodging = false;
  private ghosts: Ghost[];

  constructor(private scene: Phaser.Scene,private legs: Phaser.GameObjects.Sprite,private torso: Phaser.GameObjects.Sprite) {
    this.ghosts=Array.from({length:4},()=>({lower:scene.add.sprite(0,0,'lower').setVisible(false),upper:scene.add.sprite(0,0,'upper').setVisible(false),age:1}));
  }

  private stamp(frame: string,x: number,y: number,width: number,height: number,alpha: number,angle=0,depth=4000): void {
    const image=this.stamps[this.used]??(this.stamps[this.used]=this.scene.add.image(0,0,'vfx',frame));
    this.used++;
    image.setFrame(frame).setPosition(x,y).setOrigin(0.5).setDisplaySize(width,height).setRotation(angle).setAlpha(alpha).setDepth(depth).setVisible(true);
  }

  reset(): void {
    this.bursts=[];this.trails.clear();this.lastImpact=-1;this.wasDodging=false;this.ghostTimer=0;
    for(const image of this.stamps)image.setVisible(false);
    for(const ghost of this.ghosts){ghost.age=1;ghost.lower.setVisible(false);ghost.upper.setVisible(false);}
  }

  private fallingArrows(point: Point,progress: number): void {
    for(let i=0;i<10;i++){
      const a=i*2.39996,r=18+Math.sqrt(i/10)*(RAIN_RADIUS-34),x=point.x+Math.cos(a)*r,y=point.y+Math.sin(a)*r;
      const height=(1-progress)*140;
      this.stamp('streak',x-height*0.17,y-height-16,42,6,0.72,Math.PI/2-0.17);
    }
  }

  update(s: Snapshot,delta: number,clock: number): void {
    const dt=s.paused||s.status==='failed'?0:delta;
    this.used=0;
    for(const hit of s.effects)if(hit.id>this.lastImpact){
      this.bursts.push({x:hit.x,y:hit.y,kind:hit.kind,age:0});
      this.lastImpact=hit.id;
    }
    this.bursts=this.bursts.filter(b=>{b.age+=dt;return b.age<(b.kind==='dust'?0.3:0.24);});
    for(const b of this.bursts){
      const progress=b.age/(b.kind==='dust'?0.3:0.24),alpha=1-progress;
      if(b.kind==='dust')this.stamp('dust',b.x,b.y+3,30+progress*35,15+progress*12,alpha*0.26,0,3);
      else {
        const size=(b.kind==='pierce'?39:25)+progress*17;
        this.stamp('spark',b.x,b.y,size,size,alpha*0.8,b.age*2);
        for(let i=0;i<3;i++){
          const a=i*2.1+0.4,d=8+progress*(b.kind==='pierce'?30:20);
          this.stamp('shards',b.x+Math.cos(a)*d,b.y+Math.sin(a)*d+progress*6,12,12,alpha*0.72,a);
        }
      }
    }

    const active=new Set(s.arrows.map(a=>a.id));
    for(const id of this.trails.keys())if(!active.has(id))this.trails.delete(id);
    for(const a of s.arrows){
      let trail=this.trails.get(a.id);
      if(!trail){trail=[];this.trails.set(a.id,trail);}
      if(dt>0&&(!trail.length||Math.hypot(a.x-trail.at(-1)!.x,a.y-trail.at(-1)!.y)>7)){
        trail.push({x:a.x,y:a.y});
        if(trail.length>(a.kind==='pierce'?8:4))trail.shift();
      }
      for(let i=1;i<trail.length;i++){
        const p=trail[i-1],q=trail[i],width=Math.hypot(q.x-p.x,q.y-p.y)+10;
        this.stamp('feather',(p.x+q.x)/2,(p.y+q.y)/2,width,a.kind==='pierce'?15:7,(i/trail.length)*(a.kind==='pierce'?0.7:0.3),a.angle);
      }
      this.stamp('streak',a.x-Math.cos(a.angle)*18,a.y-Math.sin(a.angle)*18,a.kind==='pierce'?78:32,a.kind==='pierce'?15:6,a.kind==='pierce'?0.8:0.6,a.angle);
    }

    const charging=s.windup!==null||s.skill?.phase==='windup'&&s.skill.kind==='pierce';
    if(charging){
      const strong=s.skill?.kind==='pierce';
      const progress=1-(strong?s.skill!.remaining/ATTACK_TIMING.pierceWindup:(s.windup??0)/ATTACK_TIMING.normalWindup),size=(strong?28:12)+progress*(strong?30:13);
      this.stamp('halo',s.grip.x,s.grip.y,size,size,0.25+progress*0.4,clock*0.6);
      if(strong)for(let i=0;i<4;i++){
        const a=i*Math.PI/2+clock*1.7,d=23*(1-progress)+9;
        this.stamp('embers',s.grip.x+Math.cos(a)*d,s.grip.y+Math.sin(a)*d,9,9,0.5);
      }
    }
    if(s.attack==='release')this.stamp('spark',s.grip.x,s.grip.y,17,17,0.45,s.player.angle);

    if(s.rainPreview){
      const progress=1-(s.skill?.remaining??0)/ATTACK_TIMING.rainWindup;
      this.stamp('ring',s.rainPreview.x,s.rainPreview.y,RAIN_RADIUS*2,RAIN_RADIUS*2,0.14+progress*0.16,clock*0.15,2.2);
      if(s.skill&&s.skill.remaining<=0.16)this.fallingArrows(s.rainPreview,1-s.skill.remaining/0.16);
    }
    for(const rain of s.rains){
      for(let pulse=0;pulse<ATTACK_TIMING.rainPulses;pulse++){
        const until=pulse*ATTACK_TIMING.rainInterval-rain.age;
        if(pulse>0&&until>0&&until<=0.16)this.fallingArrows(rain,1-until/0.16);
        const age=rain.age-pulse*ATTACK_TIMING.rainInterval;
        if(age>=0&&age<ATTACK_TIMING.rainInterval){
          const progress=age/ATTACK_TIMING.rainInterval;
          this.stamp('ring',rain.x,rain.y,110+progress*110,110+progress*110,(1-progress)*0.42,0,2.2);
          for(let i=0;i<6;i++){
            const a=i*2.39996,r=20+Math.sqrt(i/6)*65;
            this.stamp('spark',rain.x+Math.cos(a)*r,rain.y+Math.sin(a)*r,18,18,(1-progress)*0.45,a);
          }
        }
      }
    }

    const dodging=s.dodge>0;
    if(dt>0){
      this.ghostTimer+=dt;
      if(dodging&&!this.wasDodging)this.bursts.push({x:s.player.x,y:s.player.y,kind:'dust',age:0});
      for(const ghost of this.ghosts)ghost.age+=dt;
      if(dodging&&this.ghostTimer>=0.035){
        const ghost=this.ghosts.reduce((old,g)=>g.age>old.age?g:old);
        ghost.age=0;this.ghostTimer=0;
        for(const [copy,body] of [[ghost.lower,this.legs],[ghost.upper,this.torso]])copy.setTexture(body.texture.key,body.frame.name).setOrigin(body.originX,body.originY).setPosition(body.x,body.y).setScale(body.scaleX,body.scaleY).setTint(0x8f8054).setDepth(s.player.y-0.1);
      }
      this.wasDodging=dodging;
    }
    for(const ghost of this.ghosts){
      const alpha=Math.max(0,1-ghost.age/0.16)*0.22;
      ghost.lower.setVisible(alpha>0).setAlpha(alpha);ghost.upper.setVisible(alpha>0).setAlpha(alpha);
    }
    for(let i=this.used;i<this.stamps.length;i++)this.stamps[i].setVisible(false);
  }
}
