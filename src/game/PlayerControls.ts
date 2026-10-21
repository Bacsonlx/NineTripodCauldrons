import type { Point, TrainingRoom } from './TrainingRoom';

const CODES = new Set(['KeyW','KeyA','KeyS','KeyD','KeyQ','KeyE','KeyF','KeyR','Space','Escape']);

export class PlayerControls {
  private keys = new Set<string>();
  private fire = false;
  private firePulse = false;
  private interact = false;
  private interactPulse = false;
  private skills = {pierce:false,rain:false,dodge:false};

  constructor(private room: TrainingRoom) {}

  get movement() {
    return {moveX:Number(this.keys.has('KeyD'))-Number(this.keys.has('KeyA')),moveY:Number(this.keys.has('KeyS'))-Number(this.keys.has('KeyW'))};
  }

  keyDown(code: string,repeat = false): boolean {
    if(!CODES.has(code))return false;
    if(repeat)return true;
    const state=this.room.snapshot;
    if(code==='Escape'){
      if(state.reading)this.room.closeReading();else this.room.setPaused(!state.paused);
      this.interrupt();
    }else if(code==='KeyR'){
      if(!state.paused){this.room.reset();this.interrupt();}
    }else if(code==='KeyF'){
      if(!state.paused||state.reading){this.interact=true;this.interactPulse=true;}
    }else if(!state.paused&&state.status!=='failed'){
      if(code==='KeyQ')this.skills.pierce=true;
      else if(code==='KeyE')this.skills.rain=true;
      else if(code==='Space')this.skills.dodge=true;
      else this.keys.add(code);
    }
    return true;
  }

  keyUp(code: string): void { this.keys.delete(code);if(code==='KeyF')this.interact=false; }

  pointerDown(inside: boolean): void {
    if(inside&&!this.room.snapshot.paused&&this.room.snapshot.status!=='failed'){this.fire=true;this.firePulse=true;}
  }

  pointerUp(): void { this.fire=false; }

  pointerLeave(): void {
    this.fire=false;this.firePulse=false;this.skills.pierce=false;this.skills.rain=false;
    this.room.cancelPendingAttacks();
  }

  interrupt(blur = false): void {
    if(blur)this.room.setPaused(true);
    this.keys.clear();this.fire=false;this.firePulse=false;this.interact=false;this.interactPulse=false;
    this.skills={pierce:false,rain:false,dodge:false};
    this.room.cancelInput();
  }

  update(aim: Point,pointerInside: boolean,seconds: number) {
    const wasReading=this.room.snapshot.reading;
    this.room.update({...this.movement,aim,pointerInside,fire:this.fire||this.firePulse,interact:this.interact||this.interactPulse,...this.skills},seconds);
    this.firePulse=false;this.interactPulse=false;this.skills={pierce:false,rain:false,dodge:false};
    if(this.room.snapshot.reading!==wasReading)this.interrupt();
    return this.room.snapshot;
  }
}
