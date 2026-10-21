import { ROOM, type Point } from './TrainingRoom';

// Coordinates share the same horizontal battle plane; height is only drawn.
export const TANGGU = {
  width: 2560,
  height: 1440,
  spawn: { x: 400, y: 820 },
  floor: [{ x: 120, y: 180 }, { x: 2440, y: 180 }, { x: 2440, y: 1310 }, { x: 120, y: 1310 }],
  walkableAreas: [
    { name: '起点', region: '扶桑残径', material: 'path', priority: 0, left: 120, top: 650, right: 680, bottom: 1100 },
    { name: '第一庭院', region: '扶桑残径', material: 'stone', priority: 0, left: 620, top: 620, right: 1040, bottom: 1060 },
    { name: '断垣廊道', region: '断垣之道', material: 'path', priority: 0, left: 990, top: 700, right: 1270, bottom: 890 },
    { name: '第二庭院', region: '断垣之道', material: 'stone', priority: 0, left: 1200, top: 400, right: 1690, bottom: 850 },
    { name: '日鸟廊道', region: '断垣之道', material: 'path', priority: 0, left: 1610, top: 620, right: 1840, bottom: 800 },
    { name: '第三庭院', region: '日鸟石庭', material: 'stone', priority: 0, left: 1770, top: 520, right: 2390, bottom: 1000 },
    { name: '碑林支路', region: '碑林幽径', material: 'path', priority: 1, left: 1020, top: 300, right: 1150, bottom: 800 },
    { name: '碑林空地', region: '碑林幽径', material: 'path', priority: 1, left: 740, top: 210, right: 1150, bottom: 450 },
    { name: '祭火支路', region: '祭火林地', material: 'path', priority: 1, left: 1520, top: 790, right: 1660, bottom: 1170 },
    { name: '祭火空地', region: '祭火林地', material: 'path', priority: 1, left: 1440, top: 1090, right: 1950, bottom: 1310 },
    { name: '回程捷径', region: '祭火林地', material: 'path', priority: 1, left: 1800, top: 950, right: 1930, bottom: 1200 },
  ],
  mainRoute: [{x:400,y:820},{x:850,y:820},{x:1100,y:790},{x:1430,y:720},{x:1800,y:720},{x:2110,y:750},{x:2270,y:870}],
  groundPatches: [{x:930,y:820,width:740,height:500},{x:1440,y:630,width:490,height:420},{x:2100,y:760,width:610,height:450}],
  exploration: [{ id: 'stele', x: 840, y: 365 }, { id: 'altar', x: 1660, y: 1240 }, { id: 'gate', x: 1865, y: 1100 }],
  pillars: [{ x: 780, y: 680 }, { x: 1240, y: 440 }, { x: 2140, y: 560 }],
  targets: [],
  obstacles: [
    { x: 840, y: 300, halfWidth: 53, halfHeight: 18, height: 97, kind: 'stele' },
    { x: 940, y: 560, halfWidth: 90, halfHeight: 24, height: 125, kind: 'wall' },
    { x: 1360, y: 410, halfWidth: 105, halfHeight: 30, height: 144, kind: 'root' },
    { x: 1660, y: 1180, halfWidth: 70, halfHeight: 32, height: 97, kind: 'altar' },
    { x: 600, y: 600, halfWidth: 36, halfHeight: 26, height: 232, kind: 'tree' },
    { x: 1160, y: 460, halfWidth: 38, halfHeight: 26, height: 232, kind: 'tree' },
    { x: 1700, y: 930, halfWidth: 38, halfHeight: 26, height: 232, kind: 'tree' },
    { x: 1865, y: 1045, halfWidth: 66, halfHeight: 14, height: 87, kind: 'gate' },
    { x: 515, y: 710, halfWidth: 18, halfHeight: 14, height: 100, kind: 'waystone', markerOffsetY: 60 },
    { x: 1375, y: 815, halfWidth: 18, halfHeight: 14, height: 100, kind: 'waystone', markerOffsetY: -50 },
    { x: 2240, y: 985, halfWidth: 18, halfHeight: 14, height: 100, kind: 'waystone', markerOffsetY: -85 },
    { x: 700, y: 1010, halfWidth: 18, halfHeight: 14, height: 70, kind: 'brazier' },
    { x: 1180, y: 860, halfWidth: 18, halfHeight: 14, height: 70, kind: 'brazier' },
    { x: 1600, y: 820, halfWidth: 18, halfHeight: 14, height: 70, kind: 'brazier' },
    { x: 1800, y: 760, halfWidth: 18, halfHeight: 14, height: 70, kind: 'brazier' },
    { x: 2320, y: 900, halfWidth: 18, halfHeight: 14, height: 70, kind: 'brazier' },
    { x: 995, y: 690, halfWidth: 18, halfHeight: 14, height: 70, kind: 'brazier' },
    { x: 1170, y: 720, halfWidth: 18, halfHeight: 14, height: 70, kind: 'brazier' },
    { x: 985, y: 1030, halfWidth: 18, halfHeight: 14, height: 100, kind: 'waystone' },
  ],
  encounters: [
    { x: 740, y: 850, landmark: '扶桑石庭', enemies: [{ x: 830, y: 760, appearance: 'bird' }, { x: 930, y: 920, appearance: 'paper' }, { x: 950, y: 740, appearance: 'wood' }] },
    { x: 1290, y: 720, landmark: '断垣庭院', enemies: [{ x: 1410, y: 500, appearance: 'paper' }, { x: 1530, y: 700, appearance: 'wood' }, { x: 1410, y: 790, appearance: 'bird' }, { x: 1620, y: 520, appearance: 'paper' }] },
    { x: 1880, y: 750, landmark: '日鸟石庭', enemies: [{ x: 1990, y: 600, appearance: 'bird' }, { x: 2090, y: 730, appearance: 'paper' }, { x: 2000, y: 900, appearance: 'wood' }, { x: 2220, y: 850, appearance: 'paper' }, { x: 2290, y: 700, appearance: 'wood' }] },
  ],
  shoulderHeight: ROOM.shoulderHeight,
  grips: ROOM.grips,
  pillarBody: [[40, -122, -95], [26, -98, -22], [40, -28, 0]],
  targetFace: ROOM.targetFace,
} as const;

export function tangguGuidance(point: Point,encounter: number,complete: boolean) {
  const areas=TANGGU.walkableAreas.filter(a=>point.x>=a.left&&point.x<=a.right&&point.y>=a.top&&point.y<=a.bottom);
  const area=areas.sort((a,b)=>b.priority-a.priority)[0];
  const next=TANGGU.encounters[Math.max(0,Math.min(encounter,TANGGU.encounters.length-1))];
  return {region:area?.region??'汤谷',landmark:complete?'主路已肃清 · 可回头探索':`下一地标 · ${next.landmark}`};
}
