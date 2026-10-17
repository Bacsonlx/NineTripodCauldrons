// Run from repository root after both final makers complete. Read-only package checks.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const asar=require('@electron/asar');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const file=p=>({path:p,bytes:fs.statSync(p).size,sha256:sha(fs.readFileSync(p))});
const packages={mac:'out/九鼎-darwin-arm64/九鼎.app/Contents/Resources/app.asar',windows:'out/九鼎-win32-x64/resources/app.asar'};
const outputs={};
for(const [platform,p] of Object.entries(packages)){
 const pkg=JSON.parse(asar.extractFile(p,'package.json'));
 assert.equal(pkg.version,'0.3.0-sample.1');
 const renderer=asar.extractFile(p,'.webpack/renderer/main_window/index.js');
 assert.ok(!renderer.includes('__jiudingRead')&&!renderer.includes('__demoLock'),'Diagnostic observer must not ship');
 const assets=['junction-ground-v1.png','junction-props-v1.png','combat-vfx-v1.png'].map(name=>{
  const bytes=asar.extractFile(p,'.webpack/renderer/assets/'+name),source=fs.readFileSync('assets/mvp03/'+name);
  assert.ok(bytes.equals(source),platform+' '+name+' must match source');
  return {name,bytes:bytes.length,sha256:sha(bytes)};
 });
 outputs[platform]={...file(p),version:pkg.version,rendererSHA256:sha(renderer),assets};
}
assert.equal(outputs.mac.rendererSHA256,outputs.windows.rendererSHA256,'Renderer must match between final packages');
const exe=fs.readFileSync('out/九鼎-win32-x64/nine-tripod-cauldrons.exe');
assert.equal(exe.readUInt16LE(exe.readUInt32LE(0x3c)+4),0x8664,'Windows game executable must be x64');
const sourceFiles=['package.json','package-lock.json','src/game/TrainingRoom.ts','src/game/Tanggu.ts','src/game/TrainingScene.ts','src/game/TangguBackdrop.ts','src/game/CombatEffects.ts','src/renderer/index.ts','src/renderer/index.html','assets/mvp03/frames.json','tests/TangguRoutes.test.cjs'];
const manifest={
 version:'0.3.0-sample.1',scope:'T01-T06 implemented; T07 candidate, user approval pending',
 baseline:'a3efff66f6f009a6e6655edfe078ea60b1c2f129',reviewSnapshot:'5bc96f071182f46a108d0eb0a9af1e431497495b',
 createdAt:new Date().toISOString(),packages:outputs,windowsGameMachine:'0x8664 (x64)',
 artifacts:[
  'out/installer/NineTripodCauldrons-Setup-0.3.0-sample.1-x64.exe',
  'out/make/zip/win32/x64/九鼎-win32-x64-0.3.0-sample.1.zip',
  'out/make/zip/darwin/arm64/九鼎-darwin-arm64-0.3.0-sample.1.zip'
 ].map(file),sourceFiles:sourceFiles.map(file),
 recordings:{
  rendererSHA256:sha(fs.readFileSync('/private/tmp/jiuding-mvp03-render-fixture/.webpack/renderer/main_window/index.js')),
  timing:'VFR from captured timestamps; no speed-up or slow-frame removal',
  videos:['output/mvp03-sample/九鼎_MVP03_动态小样.mp4','output/mvp03-sample/九鼎_MVP03_通路与战斗走访.mp4'].map(file),
  note:'Captured before review fixes. Final build changes gate collider/placeholder height and extracts equal attack timing constants; do not represent recordings as a final-build re-recording.'
 },
 verification:{tests:'39/39',typescript:'passed',standardsReview:'0 remaining',specReview:'0 remaining',macNative:'short attempt interrupted by OS lock; not passed',windowsNative:'pending user return',performance:'not sampled; user stopped repeated long runs',rendererOnly:'three encounters, two branches, ten resets; desktop window API fixture only; not native acceptance'}
};
fs.writeFileSync('output/mvp03-sample/release-manifest.json',JSON.stringify(manifest,null,2)+'\n');
console.log(JSON.stringify({version:manifest.version,rendererMatch:true,sourceAssetsMatch:true,artifacts:manifest.artifacts.map(a=>({path:a.path,bytes:a.bytes,sha256:a.sha256}))},null,2));
