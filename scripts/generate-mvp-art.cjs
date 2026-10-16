// Original vector artwork for the MVP; deterministic poses are authored offline.
const fs = require('node:fs');
const path = require('node:path');
const out = path.join(__dirname, '../assets/mvp');
fs.mkdirSync(out, { recursive: true });
const svg = (w, h, body) => `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${body}</svg>`;
const write = (name, w, h, body) => fs.writeFileSync(path.join(out, name + '.svg'), svg(w, h, body));
let legs = '', torso = '';
for (let dir = 0; dir < 4; dir++) {
  for (let frame = 0; frame < 9; frame++) {
    const stride = frame === 0 ? 0 : Math.sin((frame - 1) * Math.PI / 4) * 9;
    const side = dir === 0 || dir === 2;
    const x1 = side ? 61 + stride : 55;
    const x2 = side ? 66 - stride : 73;
    const y1 = 108 - (side ? Math.max(0, stride) * 0.4 : stride * 0.5);
    const y2 = 108 - (side ? Math.max(0, -stride) * 0.4 : -stride * 0.5);
    legs += `<g transform="translate(${frame * 128},${dir * 128})" stroke="#151e23" stroke-width="3" stroke-linejoin="round"><path fill="#293c49" d="M49 78L65 77L${x1 + 8} ${y1 - 6}L${x1 - 6} ${y1 - 6}Z"/><path fill="#354c58" d="M63 77L78 78L${x2 + 7} ${y2 - 5}L${x2 - 6} ${y2 - 5}Z"/><path fill="#171d20" d="M${x1 - 7} ${y1 - 8}L${x1 + 6} ${y1 - 7}L${x1 + 9} ${y1}L${x1 - 9} ${y1}Z"/><path fill="#171d20" d="M${x2 - 7} ${y2 - 8}L${x2 + 6} ${y2 - 7}L${x2 + 11} ${y2}L${x2 - 8} ${y2}Z"/><path d="M54 83L57 96M70 83L71 95" stroke="#78908c" stroke-width="1.2"/></g>`;
  }
  for (let pose = 0; pose < 4; pose++) {
    const back = dir === 3;
    const flip = dir === 2;
    const pull = [0, 6, 0, 2][pose];
    torso += `<g transform="translate(${pose * 128},${dir * 128})"><g transform="${flip ? 'translate(128 0) scale(-1 1)' : ''}" stroke="#201d19" stroke-width="2.5" stroke-linejoin="round"><path fill="#9b332b" d="M57 47C42 43 35 47 19 39L31 53L15 61L38 57L25 73L48 61L60 59Z"/><path fill="#d5c29b" d="M53 47L72 45L83 74L73 83L48 79L46 66Z"/><path fill="#f0dbb4" d="M60 50L69 50L73 74L54 74Z"/><path fill="#b89d70" d="M49 72L78 73L77 80L49 79Z"/><path stroke="#343536" d="M57 52L62 67L69 52M52 69L73 70" fill="none" stroke-width="1.2"/><path fill="#a8312a" d="M54 44L73 44L73 51L55 54Z"/><path fill="#ddbb82" d="M54 30Q63 22 72 29L76 39L69 47L57 43Z"/><path fill="#172027" d="M51 36L53 25L59 19L72 23L76 33L69 30L65 35L59 30L57 40Z"/><path fill="#16202a" d="M57 25Q44 17 50 12Q60 9 64 21L44 31L46 24Z"/>${back ? '<path fill="#1a242a" d="M53 28L72 27L75 42L66 46L54 42Z"/>' : '<path d="M69 35L73 36M65 41L70 42" fill="none" stroke-width="1.4"/>'}<path fill="#e0cba5" d="M70 51L${81 - pull} 58L${75 - pull} 64L63 57Z"/><path fill="#ccad79" d="M${79 - pull} 57L${88 - pull} 59L${87 - pull} 64L${76 - pull} 64Z"/><path d="M50 58L55 63M54 75L58 76M70 60L72 64" stroke="#7a7160" stroke-width="1"/></g></g>`;
  }
}
write('child-legs', 1152, 512, legs);
write('child-torso', 512, 512, torso);
write('bow', 64, 80, `<g stroke-linecap="round" fill="none"><path d="M25 5Q47 16 44 40Q47 64 25 75" stroke="#171c1b" stroke-width="7"/><path d="M25 5Q45 18 41 40Q45 62 25 75" stroke="#b79a55" stroke-width="4"/><path d="M25 5L30 40L25 75" stroke="#e1d8ae" stroke-width="1.4"/><path d="M34 32L41 35M34 48L41 45" stroke="#77a69b" stroke-width="2"/><path d="M22 39L46 39" stroke="#d8b879" stroke-width="2"/></g>`);
write('arrow', 48, 12, `<path d="M2 6L37 6" stroke="#e2c887" stroke-width="2"/><path fill="#f3d27f" d="M47 6L35 1L38 6L35 11Z"/><path fill="#ab4631" d="M2 1L11 5L11 7L2 11L4 6Z"/>`);
write('pillar', 120, 160, `<g stroke="#26332f" stroke-linejoin="round"><path fill="#26332c" opacity=".25" stroke="none" d="M7 136L61 155L117 132L60 114Z"/><path fill="#6c715e" stroke-width="3" d="M17 118L59 103L103 119L61 139Z"/><path fill="#98977b" stroke-width="3" d="M17 118L61 133L103 119L103 130L61 148L17 133Z"/><path fill="#747b65" stroke-width="3" d="M35 35L62 25L87 37L85 119L61 130L35 119Z"/><path fill="#aaa185" stroke-width="2" d="M35 35L61 46L87 37L85 119L61 130L61 46"/><path fill="#b4a582" stroke-width="3" d="M25 25L59 12L98 25L96 41L60 54L25 41Z"/><path fill="#8a947b" stroke-width="2" d="M25 25L60 39L98 25L60 12Z"/><path fill="none" stroke="#4f7664" stroke-width="3" d="M43 55L53 60L53 81L45 78L45 67L49 69M68 57L78 54L77 77L69 81L69 68L73 67"/><path fill="none" stroke="#535e4e" stroke-width="1.5" d="M40 90L54 96M68 95L80 90M43 102L51 105M70 109L77 106M31 30L48 37M66 42L88 33"/><path d="M79 37L71 47L76 53L70 65" fill="none" stroke="#424f46" stroke-width="2"/></g>`);
write('target', 80, 100, `<g stroke="#332b23" stroke-width="3"><path d="M25 57L15 94M53 57L65 94M24 83L57 83" stroke="#7d694b" stroke-width="6"/><ellipse cx="40" cy="38" rx="27" ry="29" fill="#8a6041"/><ellipse cx="40" cy="38" rx="21" ry="23" fill="#c1a36c"/><ellipse cx="40" cy="38" rx="13" ry="15" fill="#924633"/><ellipse cx="40" cy="38" rx="5" ry="6" fill="#ddc487"/><path d="M17 23L22 18M57 57L62 52M19 48L25 53" stroke="#f0d6a0" stroke-width="1.4"/></g>`);
// A single fixed room bottom; all blocking objects remain separate sprites.
let floor = `<rect width="1280" height="720" fill="#171d20"/><defs><clipPath id="floor"><path d="M640 130L1180 360L640 620L100 360Z"/></clipPath><pattern id="stone" width="124" height="62" patternUnits="userSpaceOnUse" patternTransform="matrix(1 .44 -1 .44 640 100)"><rect width="124" height="62" fill="#716b56"/><path d="M0 0H124V62H0Z" fill="none" stroke="#343e36" stroke-width="4"/><path d="M4 5H119M5 7V57M10 54L27 49M90 10L112 17" fill="none" stroke="#aaa17e" stroke-width="1.5"/></pattern></defs><path d="M100 360L640 620L1180 360L1180 376L640 641L100 377Z" fill="#323e35" stroke="#101a1b" stroke-width="5"/><g clip-path="url(#floor)"><rect x="70" y="120" width="1140" height="530" fill="url(#stone)"/>`;
for (let i = 0; i < 950; i++) {
 const x = 100 + ((i * 397) % 1080), y = 130 + ((i * 211) % 490);
 floor += `<path d="M${x} ${y}l${2 + i % 7} ${i % 3 - 1}" stroke="${i % 3 ? '#383d31' : '#c5b38c'}" opacity=".32" stroke-width="1"/>`;
}
floor += `<g transform="translate(650 385) scale(1 .46)" fill="none" stroke="#a18a59" opacity=".55"><circle r="144" stroke-width="5"/><circle r="132"/><circle r="108"/><path d="M-78-30Q-10-92 62-38L15-13L82 20L17 27L-17 89L-32 25L-93 9L-32-14Z" stroke-width="5"/>`;
for(let i=0;i<12;i++)floor+=`<path transform="rotate(${i*30})" d="M0-117L6-125L0-130L-6-125Z" fill="#ac9363"/>`;
floor += `</g></g><path d="M640 130L1180 360L640 620L100 360Z" fill="none" stroke="#b59d6b" stroke-width="5"/><path d="M640 141L1156 360L640 608L123 360Z" fill="none" stroke="#3b493c" stroke-width="5"/><path d="M50 635H1230" stroke="#6b6349" stroke-width="1"/>`;
write('tanggu-floor', 1280, 720, floor);
console.log('Authored 7 original SVG assets; poses are precomputed frame sheets.');
