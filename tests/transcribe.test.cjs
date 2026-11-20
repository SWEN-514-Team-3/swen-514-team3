const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
function setup(results) {
  const calls = [];
  const context = vm.createContext({window:{},document:{getElementById:()=>({addEventListener(){}})}, setTimeout: fn=>fn()});
  vm.runInContext(fs.readFileSync('main.js','utf8'),context);
  context.requestAPI = async (path, options) => { calls.push({path,options}); return results.shift(); };
  return {context, calls};
}
const file = {name:'meeting.wav',arrayBuffer:async()=>new ArrayBuffer(2)};
test('upload once then poll until transcript is completed', async()=>{
  const {context,calls}=setup([{jobId:'job-1'}, {status:'queued'}, {status:'in_progress'}, {status:'completed',transcript:'Hello'}]);
  assert.equal((await context.transcribeAudio(file)).transcript,'Hello');
  assert.equal(calls.length,4);
  assert.equal(calls[0].options.method,'POST');
  assert.equal(calls[3].path,'/transcribe/job-1');
});
test('failed jobs stop polling with readable error',async()=>{
  const {context,calls}=setup([{jobId:'job-1'},{status:'failed',error:'Invalid recording'}]);
  await assert.rejects(context.transcribeAudio(file), /Invalid recording/);
  assert.equal(calls.length,2);
});
test('missing job ID is rejected', async()=>{
  const {context}=setup([{}]);
  await assert.rejects(context.transcribeAudio(file), /job ID/);
});
