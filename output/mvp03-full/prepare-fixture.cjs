// System-boundary fixture: only a desktop window API script is added before the original bundle.
const fs=require('fs'),path=require('path'),asar=require('@electron/asar');
const root='/private/tmp/jiuding-mvp03-full-fixture';
asar.extractAll('out/九鼎-darwin-arm64/九鼎.app/Contents/Resources/app.asar',root);
const renderer=path.join(root,'.webpack/renderer');
fs.writeFileSync(path.join(renderer,'desktop-fixture.js'),"window.desktop=Object.freeze({getAppVersion:async()=>'0.3.0',toggleFullscreen:async()=>{},getWindowState:async()=>({fullscreen:false}),onWindowStateChange:()=>()=>{}});");
const html=path.join(renderer,'main_window/index.html');fs.writeFileSync(html,fs.readFileSync(html,'utf8').replace('<head>','<head><script src="/desktop-fixture.js"></script>'));
