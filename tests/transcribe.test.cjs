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

test('scoped transcription and broadcast requests use access tokens', async()=>{
  const context=vm.createContext({
    document:{getElementById:()=>({addEventListener(){}})},
    window:{getAccessToken:async scoped=>scoped?'access-token':'id-token'},
    fetch:async(url,options)=>{
      if(url==='auth-config.json') return {ok:true,json:async()=>({api_url:'https://api.example'})};
      const expected = url.includes('/meetings') ? 'Bearer id-token' : 'Bearer access-token';
      assert.equal(options.headers.Authorization,expected);
      return {ok:true,status:200,json:async()=>({})};
    }
  });
  vm.runInContext(fs.readFileSync('main.js','utf8'),context);
  for(const path of ['/transcribe?filename=test.wav','/transcribe/job-1','/broadcast','/meetings']) {
    await context.requestAPI(path);
  }
});

test('sample transcription starts without a local upload and polls normally', async()=>{
  const {context,calls}=setup([{jobId:'sample-job'},{status:'completed',transcript:'Sample text'}]);
  assert.equal((await context.transcribeAudio(null,true)).transcript,'Sample text');
  assert.equal(calls[0].path,'/transcribe?sample=true');
  assert.equal(calls[0].options.body,undefined);
});
