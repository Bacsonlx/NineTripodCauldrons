import { ROOM } from './TrainingRoom';

// Coordinates share the same horizontal battle plane; height is only drawn.
export const TANGGU = {
  width: 2560,
  height: 1440,
  spawn: { x: 400, y: 820 },
  floor: [{ x: 120, y: 180 }, { x: 2440, y: 180 }, { x: 2440, y: 1310 }, { x: 120, y: 1310 }],
  pillars: [{ x: 780, y: 750 }, { x: 1190, y: 600 }, { x: 1720, y: 890 }],
  targets: [],
  obstacles: [
    { x: 1030, y: 775, halfWidth: 98, halfHeight: 24, height: 180, kind: 'wall' },
    { x: 1430, y: 920, halfWidth: 105, halfHeight: 30, height: 144, kind: 'root' },
    { x: 2150, y: 525, halfWidth: 90, halfHeight: 35, height: 170, kind: 'altar' },
    { x: 560, y: 560, halfWidth: 36, halfHeight: 26, height: 232, kind: 'tree' },
    { x: 1210, y: 1030, halfWidth: 38, halfHeight: 26, height: 232, kind: 'tree' },
    { x: 2040, y: 1030, halfWidth: 38, halfHeight: 26, height: 232, kind: 'tree' },
  ],
  encounters: [
    { x: 800, y: 790, enemies: [{ x: 980, y: 690, appearance: 'bird' }, { x: 1030, y: 880, appearance: 'paper' }, { x: 1110, y: 960, appearance: 'wood' }] },
    { x: 1330, y: 720, enemies: [{ x: 1500, y: 580, appearance: 'paper' }, { x: 1530, y: 730, appearance: 'wood' }, { x: 1480, y: 860, appearance: 'bird' }, { x: 1600, y: 800, appearance: 'paper' }] },
    { x: 1830, y: 750, enemies: [{ x: 2000, y: 660, appearance: 'bird' }, { x: 2080, y: 740, appearance: 'paper' }, { x: 2000, y: 860, appearance: 'wood' }, { x: 2180, y: 850, appearance: 'paper' }, { x: 2290, y: 760, appearance: 'wood' }] },
  ],
  shoulderHeight: ROOM.shoulderHeight,
  grips: ROOM.grips,
  pillarBody: [[40, -122, -95], [26, -98, -22], [40, -28, 0]],
  targetFace: ROOM.targetFace,
} as const;
