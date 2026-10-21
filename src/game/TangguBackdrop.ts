import Phaser from 'phaser';
import { TANGGU } from './Tanggu';
import frames from '../../assets/mvp03/frames.json';
import type { TrainingRoom } from './TrainingRoom';

export class TangguBackdrop {
  private props: { image: Phaser.GameObjects.Image; x: number; y: number; height: number }[] = [];
  private flames: Phaser.GameObjects.Image[] = [];
  private objects = new Map<string,Phaser.GameObjects.Image>();
  private altarLight: Phaser.GameObjects.Image;
  private feedback: Phaser.GameObjects.Graphics;

  constructor(scene: Phaser.Scene) {
    scene.add.rectangle(TANGGU.width/2,TANGGU.height/2,TANGGU.width,TANGGU.height,0x121c18).setDepth(-12);
    scene.add.tileSprite(TANGGU.width/2,TANGGU.height/2,TANGGU.width,TANGGU.height,'terrain','forest').setTileScale(0.55).setTint(0x647258).setDepth(-11);
    const mask = scene.make.graphics({x:0,y:0});
    TANGGU.walkableAreas.forEach(a=>{
      mask.fillStyle(0xffffff).fillRect(a.left,a.top,a.right-a.left,a.bottom-a.top);
      scene.add.tileSprite(a.left,a.top,a.right-a.left,a.bottom-a.top,'terrain',a.material)
        .setOrigin(0).setTileScale(0.5).setTilePosition(a.left*2,a.top*2).setDepth(-9);
    });
    scene.events.once('shutdown',()=>mask.destroy());
    for(const p of TANGGU.groundPatches)
      scene.add.image(p.x,p.y,'junctionGround').setDisplaySize(p.width,p.height).setDepth(-7).setMask(mask.createGeometryMask());

    // Paving follows the actual main route; optional paths retain leaf-covered earth.
    const route=TANGGU.mainRoute;
    for(let i=1;i<route.length;i++){
      const {x,y}=route[i-1],{x:nx,y:ny}=route[i],length=Math.hypot(nx-x,ny-y);
      scene.add.tileSprite((x+nx)/2,(y+ny)/2,length+12,44,'terrain','paving').setTileScale(0.2).setRotation(Math.atan2(ny-y,nx-x)).setDepth(-6).setAlpha(0.75);
    }
    const edges=scene.add.graphics().setDepth(-5);
    for(const a of TANGGU.walkableAreas)for(const vertical of [false,true])for(const side of [false,true]){
      const line=vertical?(side?a.right:a.left):(side?a.bottom:a.top);
      const min=vertical?a.top:a.left,max=vertical?a.bottom:a.right;
      const cuts=[min,max,...TANGGU.walkableAreas.flatMap(b=>vertical?[b.top,b.bottom]:[b.left,b.right])].filter(v=>v>=min&&v<=max).sort((x,y)=>x-y);
      for(let i=1;i<cuts.length;i++){
        const lo=cuts[i-1],hi=cuts[i],mid=(lo+hi)/2,x=vertical?line:mid,y=vertical?mid:line;
        if(hi===lo||TANGGU.walkableAreas.some(b=>b!==a&&x>b.left&&x<b.right&&y>b.top&&y<b.bottom))continue;
        edges.lineStyle(10,0x171f14,0.9).lineBetween(vertical?line:lo,vertical?lo:line,vertical?line:hi,vertical?hi:line);
        edges.lineStyle(2,0x82734a,0.6).lineBetween(vertical?line:lo,vertical?lo:line,vertical?line:hi,vertical?hi:line);
        // Low root banks explain the walkable edge; they aren't tall arrow blockers.
        for(let n=lo+28;n<hi;n+=74){
          const bx=vertical?line+(side?23:-23):n,by=vertical?n:line+(side?15:-15);
          this.prop(scene,2,bx,by,0.12);
        }
      }
    }
    for(const p of TANGGU.obstacles){
      if(p.kind==='brazier'){
        const flame=this.prop(scene,0,p.x,p.y,0.15);this.flames.push(flame);
        scene.add.image(p.x,p.y-26,'vfx','halo').setDisplaySize(100,46).setAlpha(0.1).setDepth(p.y-1);
      }else if(p.kind==='waystone')this.prop(scene,1,p.x,p.y,0.19);
      else if(p.kind==='stele'||p.kind==='altar'||p.kind==='gate'){
        const image=scene.add.image(p.x,p.y+p.halfHeight,'exploration',p.kind==='altar'?'altarLit':p.kind).setOrigin(0.5,1).setDisplaySize(p.halfWidth*2,p.height+p.halfHeight).setDepth(p.y);
        this.objects.set(p.kind,image);this.props.push({image,x:p.x,y:p.y,height:p.height});
        scene.add.ellipse(p.x,p.y,p.halfWidth*2,18,0x050b08,0.45).setDepth(1);
      }
    }
    const altar=TANGGU.obstacles.find(p=>p.kind==='altar')!;
    this.altarLight=scene.add.image(altar.x,altar.y-20,'vfx','halo').setDisplaySize(150,70).setAlpha(0.12).setDepth(altar.y-1);
    this.feedback=scene.add.graphics().setDepth(4);
    const signs=scene.add.graphics().setDepth(-4);
    for(const p of TANGGU.obstacles)if('markerOffsetY' in p){
      const x=p.x,y=p.y+p.markerOffsetY;
      signs.lineStyle(1,0xb09958,0.45).strokeEllipse(x,y,80,35).strokeEllipse(x,y,68,28);
    }
  }

  private prop(scene: Phaser.Scene,index: number,x: number,y: number,scale: number): Phaser.GameObjects.Image {
    const f=frames.props[index];
    scene.add.ellipse(x,y,f.width*scale*0.7,12,0x050b08,0.35).setDepth(1);
    const image=scene.add.image(x,y,'sampleProps',f.name).setOrigin(f.originX,f.originY).setScale(scale).setDepth(y);
    this.props.push({image,x,y,height:f.height*scale});
    return image;
  }

  update(s: TrainingRoom['snapshot'],clock: number): void {
    const p=s.player;
    for(const prop of this.props)prop.image.setAlpha(p.y<prop.y&&p.y>prop.y-prop.height&&Math.abs(p.x-prop.x)<prop.image.displayWidth/2?0.3:1);
    for(let i=0;i<this.flames.length;i++)if(this.flames[i].alpha>0.4)this.flames[i].setAlpha(0.94+Math.sin(clock*4+i)*0.04);
    const altar=this.objects.get('altar')!,gate=this.objects.get('gate')!;
    const altarLayout=TANGGU.obstacles.find(p=>p.kind==='altar')!,gateLayout=TANGGU.obstacles.find(p=>p.kind==='gate')!;
    altar.setFrame(s.exploration.altarUsed?'altarSpent':'altarLit').setDisplaySize(altarLayout.halfWidth*2,altarLayout.height+altarLayout.halfHeight);
    this.altarLight.setVisible(!s.exploration.altarUsed).setAlpha(0.1+Math.sin(clock*3)*0.02);
    // Handle-rattle stays closed and blocking; the final open pose and collision switch together.
    gate.setDisplaySize(s.exploration.gateOpen?14:gateLayout.halfWidth*2,gateLayout.height+gateLayout.halfHeight).setX(s.exploration.gateOpen?gateLayout.x-gateLayout.halfWidth+7:gateLayout.x).setRotation(s.gateOpening>0?Math.sin(clock*45)*0.008:0);
    this.feedback.clear();
    if(s.feedback?.healed&&s.feedback.remaining>1){
      const t=(1.6-s.feedback.remaining)/0.6;
      this.feedback.lineStyle(2,0xe7cb82,(1-t)*0.65).strokeEllipse(p.x,p.y,45+t*35,20+t*15);
      for(let i=0;i<6;i++){const a=i*Math.PI/3;this.feedback.fillStyle(0xe7cb82,(1-t)*0.6).fillCircle(p.x+Math.cos(a)*25,p.y-15-t*35+Math.sin(a)*9,1.5);}
    }
  }
}
