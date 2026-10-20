// Original official SDK + intercepted HTTP; never calls the live cloud.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {chromium,webkit} = require('playwright');
const C = require('../src/core.js');
const root = path.resolve(__dirname,'..');
const artifact = path.join(root,'test-artifacts/cloud-guard');
fs.mkdirSync(artifact,{recursive:true});
const sdk = fs.readFileSync(path.join(root,'.cache/tieba-game.umd.js'),'utf8');
const source = fs.readFileSync(path.join(root,'dist/guitu-tieba-0.2.2.html'),'utf8');
const local = C.normalizeSnapshot({schema:C.SCHEMA,entries:[{id:'local-only',kind:'book',title:'本机书籍',date:'2026-10-16',amount:1,rating:4}],updatedAt:'2026-10-16T00:00:00Z',exportedAt:'2026-10-16T00:00:00Z'});
const html = source.replace('<head>','<head><script src="https://tb5.bdstatic.com/ai-game/tieba-game.umd.js"></script><script>window.tieba.getUserInfo=()=>({uid:"verified-read-test"});</script>');
const results=[];
function reply(state,mode) {
  if(mode==='503')return {status:503,body:'{"error_code":503,"data":null}'};
  if(mode==='abort')return null;
  if(mode==='business')return {status:200,body:'{"error_code":1,"errno":0,"data":{"payload":"{}"}}'};
  if(mode==='bad-body')return {status:200,body:'{not-json'};
  if(mode==='bad-payload')return {status:200,body:'{"error_code":0,"data":{"payload":"{bad"}}'};
  if(mode==='array')return {status:200,body:'{"error_code":0,"data":{"payload":"[]"}}'};
  if(mode==='primitive')return {status:200,body:'{"error_code":0,"data":{"payload":"null"}}'};
  if(mode==='missing-status')return {status:200,body:'{"data":{"payload":"{}"}}'};
  if(mode==='missing-data')return {status:200,body:'{"error_code":0}'};
  if(mode==='empty-json')return {status:200,body:'{"error_code":0,"data":{"payload":"{}"}}'};
  if(mode==='empty-null')return {status:200,body:'{"error_code":0,"data":null}'};
  if(mode==='empty-object')return {status:200,body:'{"error_code":0,"data":{}}'};
  if(mode==='empty-string')return {status:200,body:'{"error_code":0,"data":{"payload":""}}'};
  return {status:200,body:JSON.stringify({error_code:0,data:{game_id:'guard-app',payload:JSON.stringify(state.remote),field:''}})};
}
async function setup(browser,options={}) {
  const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
  const page=await context.newPage();
  await page.clock.install();
  const state={remote:options.remote || {otherFeature:{keep:true}},mode:options.mode || 'ok',reads:0,writes:0,readUrls:[],writeUrls:[],failAt:options.failAt || 0};
  page.on('dialog',d=>d.accept());
  await page.route('**/*',async route=>{
    const req=route.request(),url=new URL(req.url());
    if(url.pathname==='/c/s/game/html')return route.fulfill({contentType:'text/html; charset=utf-8',body:html});
    if(url.href==='https://tb5.bdstatic.com/ai-game/tieba-game.umd.js')return route.fulfill({contentType:'application/javascript',body:sdk});
    if(url.pathname==='/c/s/game/payloadDownload'){
      state.reads++;state.readUrls.push(url.href);
      const r=reply(state,state.failAt===state.reads?'503':state.mode);
      return r?route.fulfill({status:r.status,contentType:'application/json',body:r.body}):route.abort('failed');
    }
    if(url.pathname==='/c/s/game/payloadUpload'){
      state.writes++;state.writeUrls.push(url.href);state.remote=JSON.parse(url.searchParams.get('payload'));
      return route.fulfill({contentType:'application/json',body:'{"error_code":0,"data":{}}'});
    }
    return route.abort('blockedbyclient');
  });
  await page.addInitScript(value=>localStorage.setItem('guitu-v022:verified-read-test',JSON.stringify({snapshot:value,dirty:true})),local);
  await page.goto('https://tieba.baidu.com/c/s/game/html?game_id=guard-app',{waitUntil:'domcontentloaded'});
  await page.locator('.brand').waitFor();
  return {page,context,state};
}
async function cloudPage(page) {
  await page.locator('[data-tab="settings"]').click();
  await page.locator('[data-page="cloud"]').click();
}
async function warning(page) {
  await page.locator('[data-action="cloud-push"]').click();
  await page.locator('#upload-size').getByText('本次上传：',{exact:false}).waitFor();
  await page.clock.runFor(5100);
  assert.equal(await page.locator('#upload-acknowledge').isDisabled(),false);
}
async function unchanged(page) {
  const value=await page.evaluate(()=>JSON.parse(localStorage.getItem('guitu-v022:verified-read-test')).snapshot);
  assert.deepEqual(value.entries,local.entries);
}
async function run(browser,engine) {
  for(const mode of ['503','abort','business','bad-body','bad-payload','array','primitive','missing-status','missing-data']){
    const protectedRemote={guitu_v022:C.normalizeSnapshot({entries:[{id:'cloud-only-protected',kind:'film',title:'仅在云端的记录',date:'2000-02-29'}]}),otherFeature:{keep:true}};
    const originalRemote=JSON.stringify(protectedRemote);
    const {page,context,state}=await setup(browser,{mode,remote:protectedRemote});
    assert.match(await page.locator('#cloud-status').innerText(),/云端操作未完成/);
    await cloudPage(page);
    await page.locator('[data-action="cloud-view"]').click();
    await page.getByText('查看云端失败',{exact:false}).first().waitFor();
    assert.equal(await page.locator('.summary-list').count(),0);
    assert.equal(await page.getByText('云端还没有保存归途记录。',{exact:true}).count(),0);
    await page.locator('[data-action="cloud-pull"]').click();
    await page.getByText('下载云端记录失败',{exact:false}).first().waitFor();
    await page.locator('[data-action="cloud-delete"]').click();
    await page.getByText('删除云端数据失败',{exact:false}).first().waitFor();
    await page.locator('[data-action="cloud-push"]').click();
    await page.getByText('云端暂不可用，请稍后重试',{exact:false}).first().waitFor();
    await page.waitForFunction(()=>document.querySelector('#upload-acknowledge')?.textContent==='暂时无法上传');
    assert.equal(await page.locator('#upload-acknowledge').isDisabled(),true);
    assert.equal(state.writes,0);assert.equal(JSON.stringify(state.remote),originalRemote);await unchanged(page);
    if(mode==='503')await page.screenshot({path:path.join(artifact,`${engine}-failed-read.png`)});
    results.push({engine,scenario:mode,reads:state.reads,writes:0,localUnchanged:true,remoteUnchanged:true,passed:true});
    await context.close();
  }
  for(const mode of ['empty-json','empty-null','empty-object','empty-string']){
    const {page,context,state}=await setup(browser,{mode,remote:{}});
    assert.doesNotMatch(await page.locator('#cloud-status').innerText(),/云端操作未完成/);
    await cloudPage(page);await warning(page);assert.equal(state.writes,0);
    results.push({engine,scenario:mode,validEmpty:true,passed:true});await context.close();
  }
  // A swallowed error at the final pre-write read must prevent overwriting existing remote-only data.
  {
    const remote={guitu_v022:C.normalizeSnapshot({entries:[{id:'remote-only',kind:'film',title:'云端独有影视',date:'2000-02-29'}]}),otherFeature:{keep:true}};
    const {page,context,state}=await setup(browser,{remote,failAt:5});
    const original=JSON.stringify(state.remote);await cloudPage(page);await warning(page);
    await page.locator('#upload-acknowledge').click();
    await page.getByText('保存到云端失败',{exact:false}).first().waitFor();
    assert.equal(state.reads,5);assert.equal(state.writes,0);assert.equal(JSON.stringify(state.remote),original);await unchanged(page);
    results.push({engine,scenario:'last-prewrite-read-failed',writes:0,remoteUnchanged:true,passed:true});await context.close();
  }
  {
    const {page,context,state}=await setup(browser);
    await cloudPage(page);await warning(page);await page.locator('#upload-acknowledge').click();
    await page.getByText('本周剩余云端保存次数：4 / 5').waitFor();
    assert.equal(state.writes,1);assert.equal(C.readCloudSnapshot(state.remote.guitu_v022).entries.length,1);assert.deepEqual(state.remote.otherFeature,{keep:true});await unchanged(page);
    await page.locator('[data-action="cloud-view"]').click();await page.locator('.summary-list').waitFor();
    await page.locator('.modal-head [data-action="close"]').click();
    await page.locator('[data-action="cloud-delete"]').click();await page.getByText('云端记录已删除，本机记录仍在').waitFor();
    assert.equal(state.writes,2);assert.equal(state.remote.guitu_v022,undefined);assert.deepEqual(state.remote.otherFeature,{keep:true});assert.equal(state.remote.guitu_save_quota_v1.used,1);await unchanged(page);
    assert.equal(new Set(state.readUrls).size,state.readUrls.length);assert.ok(state.writeUrls.every(u=>!u.includes('_guitu_read')));
    results.push({engine,scenario:'normal-save-view-delete',writes:2,otherFieldsPreserved:true,localUnchanged:true,passed:true});await context.close();
  }
  // A write that succeeded before a failed verification read is uncertain, not confirmed deleted/saved.
  for(const operation of ['save','delete']){
    const initial=operation==='delete'?{guitu_v022:local,otherFeature:{keep:true}}:undefined;
    const {page,context,state}=await setup(browser,{remote:initial,failAt:operation==='save'?6:4});await cloudPage(page);
    if(operation==='save'){await warning(page);await page.locator('#upload-acknowledge').click();}
    else await page.locator('[data-action="cloud-delete"]').click();
    await page.getByText(operation==='save'?'保存结果暂无法确认':'删除结果暂无法确认',{exact:false}).first().waitFor();
    assert.equal(state.writes,1);await unchanged(page);
    results.push({engine,scenario:operation+'-verification-read-failed',writes:1,resultUnconfirmed:true,passed:true});await context.close();
  }
  for(const variant of ['no-request','response-mismatch','wrong-game']) {
    const {page,context,state}=await setup(browser);
    await page.evaluate(variant=>{
      const original=window.tieba.downloadData;
      if(variant==='no-request')window.tieba.downloadData=async()=>({});
      if(variant==='response-mismatch')window.tieba.downloadData=async()=>{await original();return {};};
      if(variant==='wrong-game')window.tieba.downloadData=()=>new Promise(resolve=>{
        const xhr=new XMLHttpRequest();xhr.open('GET','/c/s/game/payloadDownload?game_id=other-game');
        xhr.onload=()=>resolve(JSON.parse(JSON.parse(xhr.responseText).data.payload));xhr.send();
      });
    },variant);
    await cloudPage(page);
    await page.locator('[data-action="cloud-push"]').click();
    await page.waitForFunction(()=>document.querySelector('#upload-acknowledge')?.textContent==='暂时无法上传');
    assert.equal(await page.locator('#upload-acknowledge').isDisabled(),true);assert.equal(state.writes,0);await unchanged(page);
    results.push({engine,scenario:variant,writes:0,passed:true});await context.close();
  }
}
(async()=>{
  for(const [engine,type] of [['chromium',chromium],['webkit',webkit]]){
    const browser=await type.launch({headless:true,...(engine==='chromium'?{executablePath:process.env.GUITU_CHROMIUM_EXECUTABLE || undefined}:{})});
    try{await run(browser,engine);}finally{await browser.close();}
  }
  fs.writeFileSync(path.join(artifact,'verified-read-results.json'),JSON.stringify({sdk:'Original official SDK; fully intercepted network; no live cloud mutation',results},null,2)+'\n');
  console.log(`PASS: ${results.length} cloud-read guard scenarios (official SDK with isolated failure adapters) across Chromium and WebKit`);
})().catch(e=>{console.error(e);process.exitCode=1;});
