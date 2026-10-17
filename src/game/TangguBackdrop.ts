import Phaser from 'phaser';
import { TANGGU } from './Tanggu';
import frames from '../../assets/mvp03/frames.json';
import type { Point } from './TrainingRoom';

// Only the first courtyard and fork receive finished art before sample approval.
export class TangguBackdrop {
  private props: { image: Phaser.GameObjects.Image; x: number; y: number; height: number }[] = [];
  private flames: Phaser.GameObjects.Image[] = [];

  constructor(scene: Phaser.Scene) {
    scene.add.rectangle(1280,720,2560,1440,0x121c18).setDepth(-12);
    const floor = scene.add.graphics().setDepth(-9);
    for (const a of TANGGU.walkableAreas) {
      floor.fillStyle(0x292f29).fillRect(a.left,a.top,a.right-a.left,a.bottom-a.top);
    }
    // Suppress interior rectangle edges so connected lanes never look walled off.
    floor.lineStyle(6,0x52604a,0.6);
    for(const a of TANGGU.walkableAreas)for(const vertical of [false,true])for(const side of [false,true]){
      const line=vertical?(side?a.right:a.left):(side?a.bottom:a.top);
      const min=vertical?a.top:a.left,max=vertical?a.bottom:a.right;
      const cuts=[min,max,...TANGGU.walkableAreas.flatMap(b=>vertical?[b.top,b.bottom]:[b.left,b.right])].filter(v=>v>=min&&v<=max).sort((x,y)=>x-y);
      for(let i=1;i<cuts.length;i++){
        const mid=(cuts[i-1]+cuts[i])/2,x=vertical?line:mid,y=vertical?mid:line;
        if(cuts[i]===cuts[i-1]||TANGGU.walkableAreas.some(b=>b!==a&&x>b.left&&x<b.right&&y>b.top&&y<b.bottom))continue;
        floor.lineBetween(vertical?line:cuts[i-1],vertical?cuts[i-1]:line,vertical?line:cuts[i],vertical?cuts[i]:line);
      }
    }
    const mask = scene.make.graphics({ x:0,y:0 });
    for (const a of TANGGU.walkableAreas) mask.fillStyle(0xffffff).fillRect(a.left,a.top,a.right-a.left,a.bottom-a.top);
    scene.add.image(930,820,'junctionGround').setDisplaySize(740,500).setDepth(-7).setMask(mask.createGeometryMask());
    scene.events.once('shutdown',()=>mask.destroy());

    const road = scene.add.graphics().setDepth(-6);
    for (let i=0;i<14;i++) {
      const x=570+i*48,y=810-Math.min(1,(x-650)/380)*20;
      road.fillStyle(i%3?0x8c8061:0xb19b6e,0.28).fillRoundedRect(x,y,37,21,3);
      road.lineStyle(1,0xd4bd83,0.17).strokeRoundedRect(x,y,37,21,3);
    }
    // Local root/stone edges sit outside the walkable lane, never hidden colliders.
    for (const [x,y,frame,scale] of [[660,612,2,0.24],[860,1078,2,0.23],[1010,605,3,0.22],[1168,630,2,0.15]] as const) this.prop(scene,frame,x,y,scale);
    for (const p of TANGGU.obstacles) {
      if (p.kind==='brazier') {
        const image=this.prop(scene,0,p.x,p.y,0.15);this.flames.push(image);
        scene.add.image(p.x,p.y-26,'vfx','halo').setDisplaySize(100,46).setAlpha(0.1).setDepth(p.y-1);
      } else if (p.kind==='waystone') this.prop(scene,1,p.x,p.y,0.19);
    }

    const gray=scene.add.graphics().setDepth(2);
    gray.fillStyle(0x57615a).fillRect(825,270,30,57).lineStyle(2,0x92998a).strokeRect(825,270,30,57);
    const gate=TANGGU.obstacles.find(p=>p.kind==='gate')!;
    const gateArt=scene.add.graphics().setDepth(gate.y),left=gate.x-gate.halfWidth,top=gate.y-gate.height;
    for(let i=0;i<7;i++)gateArt.fillStyle(0x78684e).fillRect(left+i*(gate.halfWidth*2-8)/6,top,8,gate.height+gate.halfHeight);
    gateArt.lineStyle(5,0x9a845c).lineBetween(left,top+14,gate.x+gate.halfWidth,top+14);
    const label=(x:number,y:number,text:string)=>scene.add.text(x,y,text,{fontFamily:'Songti SC, SimSun, serif',fontSize:'16px',color:'#b4b9a4',backgroundColor:'#17201bd9',padding:{x:8,y:5}}).setOrigin(0.5).setDepth(3800);
    label(840,365,'残碑 · 探索节点占位');
    label(1650,1270,'祭坛 · 探索节点占位');
    label(1865,1120,'栅门关闭 · 开门后续接入');
    label(1420,435,'断垣之道 · 灰盒');
    label(2140,950,'日鸟石庭 · 灰盒');
  }

  private prop(scene: Phaser.Scene,index: number,x: number,y: number,scale: number): Phaser.GameObjects.Image {
    const f=frames.props[index];
    scene.add.ellipse(x,y,f.width*scale*0.7,14,0x050b08,0.35).setDepth(1);
    const image=scene.add.image(x,y,'sampleProps',f.name).setOrigin(f.originX,f.originY).setScale(scale).setDepth(y);
    this.props.push({image,x,y,height:f.height*scale});
    return image;
  }

  update(player: Point,clock: number): void {
    for(const p of this.props)p.image.setAlpha(player.y<p.y&&player.y>p.y-p.height&&Math.abs(player.x-p.x)<p.image.displayWidth/2?0.3:1);
    for(let i=0;i<this.flames.length;i++)if(this.flames[i].alpha>0.4)this.flames[i].setAlpha(0.94+Math.sin(clock*4+i)*0.04);
  }
}
