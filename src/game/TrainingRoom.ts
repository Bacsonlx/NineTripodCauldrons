export type Point = { x: number; y: number };
export type RoomInput = {
  moveX: number;
  moveY: number;
  aim: Point;
  fire: boolean;
  pointerInside: boolean;
};

export const ROOM = {
  width: 1280,
  height: 720,
  floor: [{ x: 640, y: 130 }, { x: 1180, y: 360 }, { x: 640, y: 620 }, { x: 100, y: 360 }],
  pillars: [{ x: 650, y: 360 }, { x: 940, y: 315 }, { x: 530, y: 530 }],
  targets: [{ x: 920, y: 420 }, { x: 820, y: 280 }],
  shoulderHeight: 52,
  pillarBody: [[30, -109, -75], [22, -83, -23], [35, -36, 0]],
  targetFace: { offsetY: -44.8, radiusX: 21.6, radiusY: 23.2 },
} as const;

type Arrow = Point & { id: number; angle: number; age: number };
type Hit = Point & { target: number | null };

function rectangleContact(from: Point, to: Point, left: number, top: number, right: number, bottom: number): number | null {
  let entry = 0;
  let exit = 1;
  for (const [start, end, min, max] of [[from.x, to.x, left, right], [from.y, to.y, top, bottom]]) {
    const delta = end - start;
    if (Math.abs(delta) < 0.00001) {
      if (start < min || start > max) return null;
    } else {
      const a = (min - start) / delta;
      const b = (max - start) / delta;
      entry = Math.max(entry, Math.min(a, b));
      exit = Math.min(exit, Math.max(a, b));
      if (entry > exit) return null;
    }
  }
  return entry;
}

function targetContact(from: Point, to: Point, target: Point): number | null {
  const face = ROOM.targetFace;
  const x = (from.x - target.x) / face.radiusX;
  const y = (from.y - (target.y + face.offsetY)) / face.radiusY;
  const dx = (to.x - from.x) / face.radiusX;
  const dy = (to.y - from.y) / face.radiusY;
  const c = x * x + y * y - 1;
  if (c <= 0) return 0;
  const a = dx * dx + dy * dy;
  const b = 2 * (x * dx + y * dy);
  const discriminant = b * b - 4 * a * c;
  if (a === 0 || discriminant < 0) return null;
  const t = (-b - Math.sqrt(discriminant)) / (2 * a);
  return t >= 0 && t <= 1 ? t : null;
}

export class TrainingRoom {
  private player = { x: 400, y: 440, moving: false, angle: 0 };
  private arrows: Arrow[] = [];
  private effects: (Hit & { remaining: number })[] = [];
  private flashes = [0, 0];
  private hits = 0;
  private cooldown = 0;
  private windup: number | null = null;
  private nextArrowId = 0;
  private needsRelease = false;
  private paused = false;

  get snapshot() {
    return {
      player: { ...this.player }, hits: this.hits, windup: this.windup, paused: this.paused,
      attack: this.windup !== null ? 'draw' : this.cooldown > 0.22 ? 'release' : this.cooldown > 0.12 ? 'recover' : 'idle',
      arrows: this.arrows.map(a => ({ ...a })),
      effects: this.effects.map(e => ({ ...e })),
      targets: ROOM.targets.map((t, i) => ({ ...t, flash: this.flashes[i] })),
    };
  }

  setPaused(paused: boolean): void {
    this.paused = paused;
    this.windup = null;
    this.needsRelease = true;
  }

  reset(): void {
    if (this.paused) return;
    this.player = { x: 400, y: 440, moving: false, angle: 0 };
    this.arrows = [];
    this.effects = [];
    this.flashes = [0, 0];
    this.hits = 0;
    this.cooldown = 0;
    this.windup = null;
    this.needsRelease = true;
  }

  update(input: RoomInput, seconds: number): void {
    if (this.paused) return;
    if (!input.fire) this.needsRelease = false;
    if (!input.pointerInside) {
      this.windup = null;
      this.needsRelease = input.fire;
    }
    const length = Math.max(1, Math.hypot(input.moveX, input.moveY));
    const start = { ...this.player };
    const steps = Math.max(1, Math.ceil(seconds * 220 / 2));
    for (let i = 0; i < steps; i++) {
      const x = this.player.x + input.moveX / length * 220 * seconds / steps;
      if (this.canWalk(x, this.player.y)) this.player.x = x;
      const y = this.player.y + input.moveY / length * 220 * seconds / steps;
      if (this.canWalk(this.player.x, y)) this.player.y = y;
    }
    this.player.moving = Math.hypot(this.player.x - start.x, this.player.y - start.y) > 0.01;
    const dx = input.aim.x - this.player.x;
    const dy = input.aim.y - (this.player.y - ROOM.shoulderHeight);
    if (input.pointerInside && Math.hypot(dx, dy) > 4) this.player.angle = Math.atan2(dy, dx);

    this.effects = this.effects.filter(e => (e.remaining -= seconds) > 0);
    this.flashes = this.flashes.map(f => Math.max(0, f - seconds));
    this.cooldown = Math.max(0, this.cooldown - seconds);
    if (input.fire && !this.needsRelease && this.cooldown <= 0.000001 && input.pointerInside) {
      this.windup = 0.08;
      this.cooldown = 0.35;
    }
    if (this.windup !== null) {
      this.windup -= seconds;
      if (this.windup <= 0) {
        const origin = { x: this.player.x, y: this.player.y - ROOM.shoulderHeight };
        const angle = this.player.angle;
        const muzzle = { x: origin.x + Math.cos(angle) * 26, y: origin.y + Math.sin(angle) * 26 };
        const blocked = this.contact(origin, muzzle);
        if (blocked) this.impact(blocked);
        else this.arrows.push({ ...muzzle, id: this.nextArrowId++, angle, age: 0 });
        this.windup = null;
      }
    }
    this.arrows = this.arrows.filter(arrow => {
      const next = { x: arrow.x + Math.cos(arrow.angle) * 700 * seconds, y: arrow.y + Math.sin(arrow.angle) * 700 * seconds };
      const hit = this.contact(arrow, next);
      if (hit) { this.impact(hit); return false; }
      Object.assign(arrow, next);
      arrow.age += seconds;
      return arrow.age < 2;
    });
  }

  private impact(hit: Hit): void {
    if (hit.target !== null) { this.hits++; this.flashes[hit.target] = 0.1; }
    this.effects.push({ ...hit, remaining: 0.15 });
  }

  private contact(from: Point, to: Point): Hit | null {
    let first = Infinity;
    let target: number | null = null;
    for (const p of ROOM.pillars) {
      for (const [halfWidth, top, bottom] of ROOM.pillarBody) {
        const t = rectangleContact(from, to, p.x - halfWidth, p.y + top, p.x + halfWidth, p.y + bottom);
        if (t !== null && t < first) { first = t; target = null; }
      }
    }
    ROOM.targets.forEach((p, i) => {
      const t = targetContact(from, to, p);
      if (t !== null && t < first) { first = t; target = i; }
    });
    for (let i = 0; i < ROOM.floor.length; i++) {
      const a = ROOM.floor[i];
      const b = ROOM.floor[(i + 1) % ROOM.floor.length];
      const cross = (p: Point) => (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x);
      const before = cross(from);
      const after = cross(to);
      if (after < 0) {
        const t = before <= 0 ? 0 : before / (before - after);
        if (t < first) { first = t; target = null; }
      }
    }
    return first <= 1 ? { x: from.x + (to.x - from.x) * first, y: from.y + (to.y - from.y) * first, target } : null;
  }

  private canWalk(x: number, y: number): boolean {
    for (let i = 0; i < ROOM.floor.length; i++) {
      const a = ROOM.floor[i];
      const b = ROOM.floor[(i + 1) % ROOM.floor.length];
      const dx = b.x - a.x;
      const dy = b.y - a.y;
      if (dx * (y - a.y) - dy * (x - a.x) < 12 * Math.hypot(dx, dy)) return false;
    }
    return !ROOM.pillars.some(p => Math.abs(x - p.x) < 40 && Math.abs(y - p.y) < 30);
  }
}
