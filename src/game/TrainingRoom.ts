export type Point = { x: number; y: number };
export type RoomInput = {
  moveX: number;
  moveY: number;
  aim: Point;
  fire: boolean;
  pointerInside: boolean;
  dodge?: boolean;
  pierce?: boolean;
  rain?: boolean;
};

export const SKILL_COOLDOWNS = { pierce: 4, rain: 8, dodge: 1 } as const;
export const RAIN_RADIUS = 110;

export const ROOM = {
  width: 1280,
  height: 720,
  floor: [{ x: 640, y: 130 }, { x: 1180, y: 360 }, { x: 640, y: 620 }, { x: 100, y: 360 }],
  pillars: [{ x: 650, y: 360 }, { x: 940, y: 315 }, { x: 530, y: 530 }],
  targets: [{ x: 920, y: 420 }, { x: 820, y: 280 }],
  shoulderHeight: 52,
  grips: [{ x: 27, y: -51 }, { x: 24, y: -48 }, { x: -21, y: -48 }, { x: -22, y: -53 }],
  pillarBody: [[30, -109, -75], [22, -83, -23], [35, -36, 0]],
  targetFace: { offsetY: -44.8, radiusX: 21.6, radiusY: 23.2 },
} as const;

// Grip offsets are measured at each generated pose's forward hand, in world pixels.
const SKILL_GRIPS = {
  pierce: [{x:31,y:-44},{x:17,y:-43},{x:-28,y:-45},{x:-24,y:-48}],
  rain: [{x:14,y:-68},{x:21,y:-70},{x:-21,y:-67},{x:-20,y:-68}],
  dodge: [{x:16,y:-39},{x:-3,y:-39},{x:-13,y:-37},{x:-8,y:-45}],
};

export type Obstacle = Point & { halfWidth: number; halfHeight: number; height: number; kind: string };
export type Encounter = Point & { readonly enemies: readonly Point[] };
export type RoomLayout = {
  readonly width: number; readonly height: number;
  readonly floor: readonly Point[]; readonly pillars: readonly Point[]; readonly targets: readonly Point[];
  readonly shoulderHeight: number; readonly grips: typeof ROOM.grips;
  readonly pillarBody: readonly (readonly [number, number, number])[]; readonly targetFace: typeof ROOM.targetFace;
  readonly spawn?: Point; readonly obstacles?: readonly Obstacle[]; readonly encounters?: readonly Encounter[];
};

type Arrow = Point & { id: number; angle: number; age: number; kind: 'normal' | 'pierce'; initialStep?: number; hitEnemies: number[] };
type Hit = Point & { target: number | null; enemy?: number };
type Enemy = Point & {
  id: number; group: number; health: number; phase: 'inactive' | 'chase' | 'warn' | 'swing' | 'recover' | 'dead';
  timer: number; angle: number; struck: boolean; flash: number; route: Point[]; repath: number;
};

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

function targetContact(from: Point, to: Point, target: Point, face = ROOM.targetFace): number | null {
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
  private player = { x: 400, y: 440, moving: false, angle: 0, facing: 0 };
  private arrows: Arrow[] = [];
  private effects: (Hit & { remaining: number })[] = [];
  private flashes = [0, 0];
  private hits = 0;
  private cooldown = 0;
  private windup: number | null = null;
  private attackReleased = false;
  private nextArrowId = 0;
  private needsRelease = false;
  private paused = false;
  private health = 100;
  private hurt = 0;
  private protection = 0;
  private status: 'running' | 'failed' | 'complete' = 'running';
  private enemies: Enemy[] = [];
  private encounter = 0;
  private dodgeTime = 0;
  private dodgeInvulnerability = 0;
  private dodgeCooldown = 0;
  private dodgeHeld = false;
  private piercing: number | null = null;
  private pierceCooldown = 0;
  private pierceHeld = false;
  private skillRecovery = 0;
  private lastSkill: 'pierce' | 'rain' | null = null;
  private raining: { remaining: number; point: Point } | null = null;
  private rainCooldown = 0;
  private rainHeld = false;
  private rains: (Point & { age: number; pulse: number })[] = [];
  private invalid: (Point & { remaining: number }) | null = null;
  private dodgeDirection = { x: 1, y: 0 };

  constructor(readonly layout: RoomLayout = ROOM) {
    const spawn = layout.spawn ?? { x: 400, y: 440 };
    this.player = { ...spawn, moving: false, angle: 0, facing: 0 };
    this.createEnemies();
  }

  private createEnemies(): void {
    this.enemies = (this.layout.encounters ?? []).flatMap((g, group) => g.enemies.map((p, i) => ({
      ...p, id: group * 100 + i, group, health: 60, phase: 'inactive' as const,
      timer: 0, angle: 0, struck: false, flash: 0, route: [], repath: 0,
    })));
  }

  private get attackPhase(): 'idle' | 'draw' | 'release' | 'recover' {
    if (this.windup !== null) return 'draw';
    if (this.attackReleased && this.cooldown > 0.22) return 'release';
    if (this.attackReleased && this.cooldown > 0.12) return 'recover';
    return 'idle';
  }

  private get grip(): Point {
    const offsets = this.dodgeTime > 0 ? SKILL_GRIPS.dodge : this.raining ? SKILL_GRIPS.rain : this.piercing !== null ? SKILL_GRIPS.pierce : this.layout.grips;
    const offset = offsets[this.player.facing];
    return { x: this.player.x + offset.x, y: this.player.y + offset.y };
  }

  get snapshot() {
    return {
      player: { ...this.player }, grip: this.grip, hits: this.hits, windup: this.windup, paused: this.paused,
      attack: this.attackPhase, health: this.health, hurt: this.hurt, protection: this.protection, status: this.status,
      dodge: this.dodgeTime, dodgeDirection: { ...this.dodgeDirection }, dodgeInvulnerability: this.dodgeInvulnerability, cooldowns: { dodge: this.dodgeCooldown, pierce: this.pierceCooldown, rain: this.rainCooldown },
      skill: this.raining ? { kind: 'rain' as const, phase: 'windup' as const, remaining: this.raining.remaining }
        : this.piercing !== null ? { kind: 'pierce' as const, phase: 'windup' as const, remaining: this.piercing }
        : this.skillRecovery > 0 && this.lastSkill ? { kind: this.lastSkill, phase: 'recover' as const, remaining: this.skillRecovery } : null,
      rainPreview: this.raining ? { ...this.raining.point } : null, rains: this.rains.map(r => ({ ...r })), invalid: this.invalid ? { ...this.invalid } : null,
      encounter: this.encounter, totalEncounters: this.layout.encounters?.length ?? 0,
      enemies: this.enemies.map(({ route, repath, ...e }) => ({ ...e })),
      arrows: this.arrows.map(a => ({ ...a, hitEnemies: [...a.hitEnemies] })),
      effects: this.effects.map(e => ({ ...e })),
      targets: this.layout.targets.map((t, i) => ({ ...t, flash: this.flashes[i] })),
    };
  }

  setPaused(paused: boolean): void {
    this.paused = paused;
    this.windup = null;
    this.attackReleased = false;
    this.needsRelease = true;
    this.dodgeTime = 0; this.dodgeInvulnerability = 0; this.player.moving = false;
    this.dodgeHeld = true; this.pierceHeld = true; this.piercing = null; this.rainHeld = true; this.raining = null;
  }

  reset(): void {
    if (this.paused) return;
    this.player = { ...(this.layout.spawn ?? { x: 400, y: 440 }), moving: false, angle: 0, facing: 0 };
    this.arrows = [];
    this.effects = [];
    this.flashes = this.layout.targets.map(() => 0);
    this.health = 100; this.hurt = 0; this.protection = 0; this.status = 'running';
    this.encounter = 0; this.createEnemies();
    this.dodgeTime = 0; this.dodgeInvulnerability = 0; this.dodgeCooldown = 0; this.dodgeHeld = true;
    this.piercing = null; this.pierceCooldown = 0; this.pierceHeld = true; this.skillRecovery = 0; this.lastSkill = null;
    this.raining = null; this.rainCooldown = 0; this.rainHeld = true; this.rains = []; this.invalid = null;
    this.hits = 0;
    this.cooldown = 0;
    this.windup = null;
    this.attackReleased = false;
    this.needsRelease = true;
  }

  update(input: RoomInput, seconds: number): void {
    // Movement and combat share short steps so a long rendered frame cannot
    // test a past swing against a future player position.
    const steps = Math.max(1, Math.ceil(seconds / 0.01));
    for (let i = 0; i < steps; i++) this.step(input, seconds / steps);
  }

  private step(input: RoomInput, seconds: number): void {
    if (this.paused || this.status === 'failed') return;
    const protectionAtStart = this.protection;
    this.hurt = Math.max(0, this.hurt - seconds);
    this.protection = Math.max(0, this.protection - seconds);
    if (!input.fire) this.needsRelease = false;
    if (!input.pointerInside) {
      this.windup = null; this.piercing = null; this.raining = null;
      this.attackReleased = false;
      this.needsRelease = input.fire;
    }
    const rainPressed = !!input.rain && !this.rainHeld;
    this.rainHeld = !!input.rain;
    this.rainCooldown = Math.max(0, this.rainCooldown - seconds);
    if (this.invalid && (this.invalid.remaining -= seconds) <= 0) this.invalid = null;
    const piercePressed = !!input.pierce && !this.pierceHeld;
    this.pierceHeld = !!input.pierce;
    this.pierceCooldown = Math.max(0, this.pierceCooldown - seconds);
    this.skillRecovery = Math.max(0, this.skillRecovery - seconds);
    this.dodgeCooldown = Math.max(0, this.dodgeCooldown - seconds);
    if (input.dodge && !this.dodgeHeld && this.dodgeCooldown === 0 && this.hurt === 0 && this.dodgeTime === 0) {
      const length = Math.hypot(input.moveX, input.moveY);
      this.dodgeDirection = length > 0 ? { x: input.moveX / length, y: input.moveY / length } : { x: Math.cos(this.player.angle), y: Math.sin(this.player.angle) };
      this.dodgeTime = 0.20; this.dodgeInvulnerability = 0.12; this.dodgeCooldown = SKILL_COOLDOWNS.dodge;
      this.windup = null; this.piercing = null; this.raining = null; this.attackReleased = false;
    }
    this.dodgeHeld = !!input.dodge;
    const dashing = this.dodgeTime > 0;
    const length = Math.max(1, Math.hypot(input.moveX, input.moveY));
    const start = { ...this.player };
    const steps = Math.max(1, Math.ceil(seconds * (dashing ? 600 : 220) / 2));
    const interval = seconds / steps;
    for (let i = 0; i < steps; i++) {
      const dash = dashing ? Math.max(0, Math.min(interval, this.dodgeTime - i * interval)) : 0;
      const walk = interval - dash;
      const dx = this.hurt > 0 ? 0 : this.dodgeDirection.x * 600 * dash + input.moveX / length * 220 * walk;
      const dy = this.hurt > 0 ? 0 : this.dodgeDirection.y * 600 * dash + input.moveY / length * 220 * walk;
      if (this.canWalk(this.player.x + dx, this.player.y)) this.player.x += dx;
      if (this.canWalk(this.player.x, this.player.y + dy)) this.player.y += dy;
    }
    this.player.moving = Math.hypot(this.player.x - start.x, this.player.y - start.y) > 0.01;
    const dx = input.aim.x - this.player.x;
    const dy = input.aim.y - (this.player.y - this.layout.shoulderHeight);
    if (input.pointerInside && Math.hypot(dx, dy) > 4) {
      const referenceAngle = Math.atan2(dy, dx);
      const difference = Math.atan2(Math.sin(referenceAngle - this.player.facing * Math.PI / 2), Math.cos(referenceAngle - this.player.facing * Math.PI / 2));
      if (Math.abs(difference) > Math.PI / 4 + 0.08) this.player.facing = (Math.round(referenceAngle / (Math.PI / 2)) + 4) % 4;
      const grip = this.grip;
      if (Math.hypot(input.aim.x - grip.x, input.aim.y - grip.y) > 4) this.player.angle = Math.atan2(input.aim.y - grip.y, input.aim.x - grip.x);
    }

    this.updateEnemies(seconds, protectionAtStart, this.dodgeInvulnerability);
    this.dodgeInvulnerability = Math.max(0, this.dodgeInvulnerability - seconds);
    if (this.health <= 0) return;
    this.effects = this.effects.filter(e => (e.remaining -= seconds) > 0);
    this.flashes = this.flashes.map(f => Math.max(0, f - seconds));
    this.cooldown = Math.max(0, this.cooldown - seconds);
    const canStart = !dashing && this.hurt === 0 && this.windup === null && this.piercing === null && this.raining === null
      && this.skillRecovery === 0 && !(this.attackReleased && this.cooldown > 0.12);
    if (canStart && piercePressed && this.pierceCooldown === 0 && input.pointerInside) {
      this.piercing = 0.18; this.pierceCooldown = SKILL_COOLDOWNS.pierce; this.lastSkill = 'pierce'; this.attackReleased = false;
    }
    if (canStart && this.piercing === null && rainPressed && this.rainCooldown === 0 && input.pointerInside) {
      if (Math.hypot(input.aim.x - this.player.x, input.aim.y - this.player.y) <= 480 && this.canWalk(input.aim.x, input.aim.y)) {
        this.raining = { remaining: 0.45, point: { ...input.aim } }; this.rainCooldown = SKILL_COOLDOWNS.rain; this.lastSkill = 'rain'; this.attackReleased = false; this.invalid = null;
      } else this.invalid = { ...input.aim, remaining: 0.35 };
    }
    if (this.raining !== null) {
      this.raining.remaining -= seconds;
      if (this.raining.remaining <= 0) {
        this.rains.push({ ...this.raining.point, age: -this.raining.remaining - seconds, pulse: 0 }); this.raining = null; this.skillRecovery = 0.12;
      }
    }
    if (this.piercing !== null) {
      this.piercing -= seconds;
      if (this.piercing <= 0) { this.launch('pierce', -this.piercing); this.piercing = null; this.skillRecovery = 0.12; }
    }
    if (!dashing && this.piercing === null && this.raining === null && this.skillRecovery === 0 && this.hurt <= 0 && input.fire && !this.needsRelease && this.cooldown <= 0.000001 && input.pointerInside) {
      this.windup = 0.08; this.lastSkill = null;
      this.attackReleased = false;
      this.cooldown = 0.35;
    }
    if (this.windup !== null) {
      this.windup -= seconds;
      if (this.windup <= 0) {
        this.launch('normal', -this.windup);
        this.windup = null;
        this.attackReleased = true;
      }
    }
    this.arrows = this.arrows.filter(arrow => {
      const lifetime = arrow.kind === 'pierce' ? 1.4 : 2;
      const elapsed = Math.max(0, Math.min(arrow.initialStep ?? seconds, lifetime - arrow.age));
      delete arrow.initialStep;
      const speed = arrow.kind === 'pierce' ? 900 : 700;
      const next = { x: arrow.x + Math.cos(arrow.angle) * speed * elapsed, y: arrow.y + Math.sin(arrow.angle) * speed * elapsed };
      let hit = this.contact(arrow, next, arrow.hitEnemies);
      while (hit) {
        this.impact(hit, arrow.kind === 'pierce' ? 40 : 15);
        if (arrow.kind !== 'pierce' || hit.enemy === undefined) return false;
        arrow.hitEnemies.push(hit.enemy);
        hit = this.contact(arrow, next, arrow.hitEnemies);
      }
      Object.assign(arrow, next);
      arrow.age += elapsed;
      return arrow.age < lifetime - 0.000001;
    });
    this.rains = this.rains.filter(rain => {
      rain.age += seconds;
      while (rain.pulse < 3 && rain.age >= rain.pulse * 0.18) {
        for (const e of this.enemies) {
          if (e.phase !== 'inactive' && e.phase !== 'dead' && Math.hypot(e.x - rain.x, e.y - rain.y) <= RAIN_RADIUS) this.impact({ x: e.x, y: e.y - 35, target: null, enemy: e.id });
        }
        rain.pulse++;
      }
      return rain.age < 0.65;
    });
    this.dodgeTime = Math.max(0, this.dodgeTime - seconds);
  }

  private launch(kind: 'normal' | 'pierce', initialStep: number): void {
    const muzzle = this.grip;
    const blocked = this.contact({ x: this.player.x, y: this.player.y - this.layout.shoulderHeight }, muzzle);
    const hitEnemies: number[] = [];
    if (blocked) {
      this.impact(blocked, kind === 'pierce' ? 40 : 15);
      if (kind !== 'pierce' || blocked.enemy === undefined) return;
      hitEnemies.push(blocked.enemy);
    }
    this.arrows.push({ ...muzzle, id: this.nextArrowId++, angle: this.player.angle, age: 0, kind, initialStep, hitEnemies });
  }

  private clearPath(from: Point, to: Point): boolean {
    const steps = Math.ceil(Math.hypot(to.x - from.x, to.y - from.y) / 10);
    for (let i = 1; i <= steps; i++) if (!this.canWalk(from.x + (to.x - from.x) * i / steps, from.y + (to.y - from.y) * i / steps)) return false;
    return true;
  }

  private route(from: Point, to: Point): Point[] {
    const cell = 32;
    const columns = Math.ceil(this.layout.width / cell);
    const rows = Math.ceil(this.layout.height / cell);
    const index = (p: Point) => Math.max(0, Math.min(rows - 1, Math.floor(p.y / cell))) * columns + Math.max(0, Math.min(columns - 1, Math.floor(p.x / cell)));
    const point = (i: number) => ({ x: (i % columns + 0.5) * cell, y: (Math.floor(i / columns) + 0.5) * cell });
    const start = index(from), goal = index(to);
    const previous = new Int32Array(columns * rows).fill(-1);
    previous[start] = start;
    const queue = [start];
    let found = -1;
    for (let head = 0; head < queue.length; head++) {
      const current = queue[head];
      if ((current === goal || Math.hypot(point(current).x - to.x, point(current).y - to.y) <= 48) && this.clearPath(point(current), to)) { found = current; break; }
      const x = current % columns, y = Math.floor(current / columns);
      for (const [nx, ny] of [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]]) {
        if (nx < 0 || ny < 0 || nx >= columns || ny >= rows) continue;
        const next = ny * columns + nx;
        if (previous[next] !== -1 || !this.canWalk(point(next).x, point(next).y)) continue;
        previous[next] = current; queue.push(next);
      }
    }
    if (found < 0) return [];
    const path = [to];
    while (found !== start) { path.push(point(found)); found = previous[found]; }
    return path.reverse();
  }

  private updateEnemies(seconds: number, protectionAtStart: number, dodgeInvulnerabilityAtStart: number): void {
    const group = this.layout.encounters?.[this.encounter];
    if (group && this.enemies.filter(e => e.group === this.encounter).every(e => e.phase === 'inactive')
      && Math.hypot(this.player.x - group.x, this.player.y - group.y) <= 170) {
      for (const e of this.enemies) if (e.group === this.encounter) e.phase = 'chase';
    }
    for (const e of this.enemies) {
      e.flash = Math.max(0, e.flash - seconds);
      if (e.phase === 'inactive') continue;
      if (e.phase === 'dead') { e.timer = Math.max(0, e.timer - seconds); continue; }
      // Keep the actual overlap with the swing, including a frame crossing its end.
      const swingUntil = e.phase === 'swing' ? Math.min(seconds, e.timer)
        : e.phase === 'warn' && seconds > e.timer ? Math.min(seconds, e.timer + 0.10) : null;
      e.timer -= seconds;
      const distance = Math.hypot(this.player.x - e.x, this.player.y - e.y);
      if (e.phase === 'chase') {
        e.angle = Math.atan2(this.player.y - e.y, this.player.x - e.x);
        if (distance <= 70) { e.phase = 'warn'; e.timer = 0.45; e.struck = false; }
        else {
          let destination: Point = this.player;
          e.repath -= seconds;
          if (!this.clearPath(e, this.player)) {
            if (e.repath <= 0) { e.route = this.route(e, this.player); e.repath = 0.35; }
            while (e.route.length > 1 && this.clearPath(e, e.route[1])) e.route.shift();
            if (e.route[0] && Math.hypot(e.route[0].x - e.x, e.route[0].y - e.y) < 3) e.route.shift();
            if (!e.route[0]) continue;
            destination = e.route[0];
          }
          e.angle = Math.atan2(destination.y - e.y, destination.x - e.x);
          const travel = Math.min(Math.hypot(destination.x - e.x, destination.y - e.y), 120 * seconds);
          const x = e.x + Math.cos(e.angle) * travel;
          const y = e.y + Math.sin(e.angle) * travel;
          if (this.canWalk(x, e.y)) e.x = x;
          if (this.canWalk(e.x, y)) e.y = y;
          for (const other of this.enemies) {
            if (other === e || other.phase === 'inactive' || other.phase === 'dead') continue;
            const dx = e.x - other.x, dy = e.y - other.y;
            const gap = Math.hypot(dx, dy);
            if (gap < 26) {
              const angle = gap > 0.01 ? Math.atan2(dy, dx) : e.id * 2.4;
              const push = Math.min((26 - gap) / 2, 60 * seconds);
              const px = e.x + Math.cos(angle) * push, py = e.y + Math.sin(angle) * push;
              if (this.canWalk(px, py)) { e.x = px; e.y = py; }
            }
          }
        }
      } else {
        if (e.phase === 'warn' && e.timer <= 0) { e.phase = 'swing'; e.timer += 0.10; }
        if (e.phase === 'swing' && e.timer <= 0) { e.phase = 'recover'; e.timer += 0.65; }
        if (e.phase === 'recover' && e.timer <= 0) { e.phase = 'chase'; e.timer = 0; }
      }
      if (swingUntil !== null && !e.struck) {
        const a = Math.atan2(this.player.y - e.y, this.player.x - e.x) - e.angle;
        if (distance <= 70 && Math.abs(Math.atan2(Math.sin(a), Math.cos(a))) <= Math.PI / 4 && protectionAtStart < swingUntil && dodgeInvulnerabilityAtStart < swingUntil && this.protection <= 0) {
          e.struck = true; this.health = Math.max(0, this.health - 20); this.hurt = 0.12; this.protection = 0.6;
          this.windup = null; this.piercing = null; this.raining = null; this.attackReleased = false; this.needsRelease = true;
          if (this.health === 0) { this.status = 'failed'; this.player.moving = false; return; }
        }
      }
    }
    if (group && this.enemies.filter(e => e.group === this.encounter).every(e => e.phase === 'dead')) {
      this.encounter++;
      if (this.encounter === this.layout.encounters!.length) this.status = 'complete';
    }
  }

  private impact(hit: Hit, damage = 15): void {
    if (hit.target !== null) { this.hits++; this.flashes[hit.target] = 0.1; }
    if (hit.enemy !== undefined) {
      const enemy = this.enemies.find(e => e.id === hit.enemy)!;
      enemy.health = Math.max(0, enemy.health - damage); enemy.flash = 0.12; this.hits++;
      if (enemy.health === 0) { enemy.phase = 'dead'; enemy.timer = 0.6; }
    }
    this.effects.push({ ...hit, remaining: 0.15 });
  }

  private contact(from: Point, to: Point, ignored: number[] = []): Hit | null {
    let first = Infinity;
    let target: number | null = null;
    let enemy: number | undefined;
    for (const p of this.layout.pillars) {
      for (const [halfWidth, top, bottom] of this.layout.pillarBody) {
        const t = rectangleContact(from, to, p.x - halfWidth, p.y + top, p.x + halfWidth, p.y + bottom);
        if (t !== null && t < first) { first = t; target = null; }
      }
    }
    for (const p of this.layout.obstacles ?? []) {
      const t = rectangleContact(from, to, p.x - p.halfWidth, p.y - p.height, p.x + p.halfWidth, p.y + p.halfHeight);
      if (t !== null && t < first) { first = t; target = null; }
    }
    this.layout.targets.forEach((p, i) => {
      const t = targetContact(from, to, p, this.layout.targetFace);
      if (t !== null && t < first) { first = t; target = i; }
    });
    for (const e of this.enemies) {
      if (e.phase === 'inactive' || e.phase === 'dead' || ignored.includes(e.id)) continue;
      const t = rectangleContact(from, to, e.x - 18, e.y - 82, e.x + 18, e.y - 8);
      if (t !== null && t < first) { first = t; target = null; enemy = e.id; }
    }
    for (let i = 0; i < this.layout.floor.length; i++) {
      const a = this.layout.floor[i];
      const b = this.layout.floor[(i + 1) % this.layout.floor.length];
      const cross = (p: Point) => (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x);
      const before = cross(from);
      const after = cross(to);
      if (after < 0) {
        const t = before <= 0 ? 0 : before / (before - after);
        if (t < first) { first = t; target = null; enemy = undefined; }
      }
    }
    return first <= 1 ? { x: from.x + (to.x - from.x) * first, y: from.y + (to.y - from.y) * first, target, ...(enemy === undefined ? {} : { enemy }) } : null;
  }

  private canWalk(x: number, y: number): boolean {
    for (let i = 0; i < this.layout.floor.length; i++) {
      const a = this.layout.floor[i];
      const b = this.layout.floor[(i + 1) % this.layout.floor.length];
      const dx = b.x - a.x;
      const dy = b.y - a.y;
      if (dx * (y - a.y) - dy * (x - a.x) < 12 * Math.hypot(dx, dy)) return false;
    }
    return !this.layout.pillars.some(p => Math.abs(x - p.x) < 40 && Math.abs(y - p.y) < 30)
      && !(this.layout.obstacles ?? []).some(p => Math.abs(x - p.x) < p.halfWidth + 12 && Math.abs(y - p.y) < p.halfHeight + 12);
  }
}
