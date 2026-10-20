// Capture only the existing public rule boundary; no private fields are read.
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const root = path.resolve(__dirname, '../..');
const source = require(path.join(root, '.test-build/TrainingRoom.js'));
const Original = source.TrainingRoom;
let trace, id = 0, depth = 0;
const snapshot = Object.getOwnPropertyDescriptor(Original.prototype, 'snapshot').get;
class TracedRoom extends Original {
  constructor(layout = source.ROOM) {
    super(layout); this.traceId = id++;
    trace.events.push({room:this.traceId, op:'create', args:[layout]});
  }
  get snapshot() {
    const state = snapshot.call(this);
    if (!depth) trace.events.push({room:this.traceId, op:'snapshot', expected:state});
    return state;
  }
}
for (const method of ['update','reset','setPaused','cancelPendingAttacks','cancelInput','closeReading']) {
  TracedRoom.prototype[method] = function(...args) {
    if (!depth) trace.events.push({room:this.traceId, op:method, args});
    depth++;
    try { return Original.prototype[method].apply(this,args); } finally { depth--; }
  };
}
source.TrainingRoom = TracedRoom;
const traces = [];
const load = Module._load;
Module._load = function(request, ...args) {
  if (request === 'node:test') return {test(name, callback) {
    trace={name,events:[]}; callback();
    if(trace.events.length) traces.push(trace);
  }};
  return load.call(this,request,...args);
};
for (const name of ['TrainingRoom','Tanggu','CombatFeedback','Exploration','PlayerControls','TangguRoutes'])
  require(path.join(root,`tests/${name}.test.cjs`));
const target=path.join(root,'godot/tests/fixtures');fs.mkdirSync(target,{recursive:true});
fs.writeFileSync(path.join(target,'rule-traces.json'),JSON.stringify(traces)+'\n');
fs.writeFileSync(path.join(target,'tanggu.json'),JSON.stringify(require(path.join(root,'.test-build/Tanggu.js')).TANGGU,null,2)+'\n');
console.log(JSON.stringify({cases:traces.length,events:traces.reduce((n,t)=>n+t.events.length,0)}));
