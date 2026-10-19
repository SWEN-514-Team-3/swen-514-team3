const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
function setup({approved=true, text='Alex will test logout.', token='access-token', status=200}={}) {
  const elements=Object.fromEntries(['aiInput','aiApproved','aiResult','runAI','aiStatus'].map(id=>[id,{value:'',checked:false,addEventListener(type,fn){this.listener=fn;}}]));
  elements.aiInput.value=text; elements.aiApproved.checked=approved;
  const calls=[];
  const context=vm.createContext({document:{getElementById:id=>elements[id]},window:{getAccessToken:async()=>{if(!token)throw Error('Please sign in again.');return token;}},fetch:async(url,options)=>{calls.push({url,options});return {ok:url==='auth-config.json'||status===200,status,json:async()=>url==='auth-config.json'?{api_url:'https://api.example'}:status===200?{result:'<script>draft</script>',modelId:'amazon.nova-micro-v1:0'}:{error:'AI is busy. Wait a moment and try again.'}};}});
  vm.runInContext(fs.readFileSync('main.js','utf8'),context);
  return {context,elements,calls};
}
test('AI sends approved text and bearer token and renders editable plain text',async()=>{
  const {context,elements,calls}=setup();await context.runAI();
  assert.equal(calls[1].url,'https://api.example/ai-sample');
  assert.equal(calls[1].options.headers.Authorization,'Bearer access-token');
  assert.equal(JSON.parse(calls[1].options.body).approved,true);
  assert.equal(elements.aiResult.value,'<script>draft</script>');
  assert.match(elements.aiStatus.textContent,/Nothing has been saved/);
  assert.equal(elements.runAI.disabled,false);
});
test('unapproved or blank text cannot invoke the API',async()=>{
  for(const options of [{approved:false},{text:' '}]){const s=setup(options);await s.context.runAI();assert.equal(s.calls.length,0);}
});
test('expired session prevents model request',async()=>{
  const s=setup({token:null});await s.context.runAI();assert.equal(s.calls.length,1);assert.match(s.elements.aiStatus.textContent,/sign in/);
});
test('backend errors are shown and button reenabled',async()=>{
  const s=setup({status:429});await s.context.runAI();assert.match(s.elements.aiStatus.textContent,/AI is busy/);assert.equal(s.elements.runAI.disabled,false);
});
test('editing source clears approval and stale draft',async()=>{
  const s=setup();await s.context.runAI();s.elements.aiInput.listener();assert.equal(s.elements.aiApproved.checked,false);assert.equal(s.elements.aiResult.value,'');
});
