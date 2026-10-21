import type { Point, TrainingRoom } from './TrainingRoom';

export type HitBurst = Point & { age: number; kind: 'normal' | 'pierce' | 'rain'; enemy?: number; angle: number };
type DamageNumber = Point & { slot: number; age: number; enemy: number; damage: number; kind: HitBurst['kind'] };

// Playback state is independent of Phaser; damage and knockback stay in the room.
export class HitFeedback {
  private runId = -1;
  private lastImpact = -1;
  private bursts: HitBurst[] = [];
  private numbers: DamageNumber[] = [];

  update(s: Pick<TrainingRoom['snapshot'],'runId'|'paused'|'status'|'effects'>,delta: number) {
    const changedRun = this.runId !== s.runId;
    if(changedRun){this.runId=s.runId;this.lastImpact=-1;this.bursts=[];this.numbers=[];}
    const dt=s.paused||s.status==='failed'?0:delta;
    this.bursts=this.bursts.filter(b=>{b.age+=dt;return b.age<0.24;});
    for(const number of this.numbers)number.age+=dt;
    for(const hit of s.effects)if(hit.id>this.lastImpact){
      this.bursts.push({x:hit.x,y:hit.y,kind:hit.kind,age:0,enemy:hit.enemy,angle:hit.angle});
      if(hit.enemy!==undefined&&hit.damage>0&&hit.damagePosition){
        const stack=this.numbers.filter(n=>n.enemy===hit.enemy&&n.age<0.65).length;
        let number=this.numbers.find(n=>n.age>=0.65);
        if(!number&&this.numbers.length<32){
          number={slot:this.numbers.length,age:1,enemy:hit.enemy,damage:0,kind:hit.kind,x:0,y:0};
          this.numbers.push(number);
        }
        number??=this.numbers.reduce((old,n)=>n.age>old.age?n:old);
        Object.assign(number,{age:0,enemy:hit.enemy,damage:hit.damage,kind:hit.kind,x:hit.damagePosition.x+(stack%2?14:-8),y:hit.damagePosition.y-100-(stack%3)*16});
      }
      this.lastImpact=hit.id;
    }
    return {changedRun,bursts:this.bursts.map(b=>({...b})),numbers:this.numbers.filter(n=>n.age<0.65).map(n=>({...n}))};
  }
}
