const fs=require('node:fs'),crypto=require('node:crypto'),assert=require('node:assert/strict'),asar=require('@electron/asar');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const file=p=>({path:p,bytes:fs.statSync(p).size,sha256:sha(fs.readFileSync(p))});
const packages={mac:'out/九鼎-darwin-arm64/九鼎.app/Contents/Resources/app.asar',windows:'out/九鼎-win32-x64/resources/app.asar'},verified={};
const assets=['assets/mvp03/junction-ground-v1.png','assets/mvp03/junction-props-v1.png','assets/mvp03/combat-vfx-v1.png','assets/mvp03/full/exploration-props-v1.png','assets/mvp03/full/terrain-materials-v1.png'];
for(const [platform,p] of Object.entries(packages)){
 const version=JSON.parse(asar.extractFile(p,'package.json')).version;assert.equal(version,'0.3.0');
 const renderer=asar.extractFile(p,'.webpack/renderer/main_window/index.js');
 assert.ok(!renderer.includes('__jiudingRead'),'Read-only diagnostic observer must not ship');
 const material=assets.map(source=>{
  const packed=asar.extractFile(p,'.webpack/renderer/assets/'+source.split('/').at(-1));assert.ok(packed.equals(fs.readFileSync(source)),platform+' '+source);
  return {...file(source),packagedPath:'.webpack/renderer/assets/'+source.split('/').at(-1)};
 });
 verified[platform]={...file(p),version,rendererSHA256:sha(renderer),assets:material};
}
assert.equal(verified.mac.rendererSHA256,verified.windows.rendererSHA256);
const recorded=sha(fs.readFileSync('/private/tmp/jiuding-mvp03-full-fixture/.webpack/renderer/main_window/index.js'));
assert.equal(recorded,verified.mac.rendererSHA256,'Recorded renderer must match final package');
const game=fs.readFileSync('out/九鼎-win32-x64/nine-tripod-cauldrons.exe');assert.equal(game.readUInt16LE(game.readUInt32LE(0x3c)+4),0x8664);
assert.match(fs.readFileSync('output/mvp03-full/test-results.txt','utf8'),/pass 46/);
const sources=['package.json','package-lock.json','src/game/TrainingRoom.ts','src/game/Tanggu.ts','src/game/TangguBackdrop.ts','src/game/TrainingScene.ts','src/game/CombatEffects.ts','src/renderer/index.html','src/renderer/index.ts','tests/Exploration.test.cjs','assets/mvp03/full/frames.json'];
const manifest={version:'0.3.0',baseline:'a3efff66f6f009a6e6655edfe078ea60b1c2f129',reviewSnapshot:'f96b5948d70ab449097ce7596df71442a4633277',createdAt:new Date().toISOString(),sourceFiles:sources.map(file),packages:verified,windowsMachine:'0x8664 x64',recordedRendererSHA256:recorded,
 artifacts:['out/installer/NineTripodCauldrons-Setup-0.3.0-x64.exe','out/make/zip/win32/x64/九鼎-win32-x64-0.3.0.zip','out/make/zip/darwin/arm64/九鼎-darwin-arm64-0.3.0.zip'].map(file),
 verification:{tests:'46/46 passed',typescript:'passed',standards:'0 remaining',spec:'0 remaining',nativeMac:'startup/image and fullscreen enter/exit only; complete native gameplay pending',nativeWindows:'pending user return',performance:'not sampled; no repeated stability loops'},
 approvals:{sample:'0.3.0-sample.1 approved',stele:'v0.1 separately approved',record:'docs/mvp/MVP03_小样与碑文确认记录.md'},
 fixture:'Original game JS and assets from actual Mac package. Fixture HTML adds one external script for low-frequency desktop window API only. No health/AI/time/focus/visibility/game-state overrides. Not native platform acceptance.'};
fs.writeFileSync('output/mvp03-full/release-manifest.json',JSON.stringify(manifest,null,2)+'\n');
console.log(JSON.stringify({version:manifest.version,rendererMatchesBothPlatformsAndRecording:true,assetsMatch:true,artifacts:manifest.artifacts},null,2));
