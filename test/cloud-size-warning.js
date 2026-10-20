const assert = require('node:assert/strict');
const fs = require('node:fs');
const {resolve} = require('node:path');
const {pathToFileURL} = require('node:url');
const {chromium} = require('playwright');
const C = require('../src/core.js');
const {largeArchive} = require('./large-fixtures.js');
const url = pathToFileURL(resolve(__dirname,'../dist/guitu-tieba-0.2.2.html')).href;
const artifacts = resolve(__dirname,'../test-artifacts');
async function open(context,remote,behavior) {
  const page = await context.newPage();
  const archive = largeArchive(1);
  let writes = 0;
  await page.exposeFunction('__download',async()=>{
    if (behavior.fail) throw new Error('read failed');
    return remote.value;
  });
  await page.exposeFunction('__upload',async value=>{ writes++; remote.value=value; });
  await page.addInitScript(snapshot=>{
    localStorage.setItem('guitu-v022:size-warning',JSON.stringify({snapshot,dirty:true}));
    window.tieba={getUserInfo:()=>({user_id:'size-warning'}),
      downloadData:()=>window.__download(),uploadData:value=>window.__upload(value)};
  },archive);
  page.on('dialog',dialog=>dialog.accept());
  await page.goto(url,{waitUntil:'domcontentloaded'});
  await page.locator('[data-action="tab"][data-tab="settings"]').click();
  await page.locator('[data-page="cloud"]').click();
  return {page,archive,writes:()=>writes};
}
async function main() {
  const browser=await chromium.launch({headless:true,
    executablePath:process.env.GUITU_CHROMIUM_EXECUTABLE || undefined,args:['--no-sandbox']});
  fs.mkdirSync(artifacts,{recursive:true});
  const errors=[];
  try {
    const contexts=[];
    const fresh=async()=>{
      const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
      contexts.push(context);
      context.on('page',page=>page.on('pageerror',error=>errors.push(error.message)));
      return context;
    };
    const remote={value:{}};
    const normal=await open(await fresh(),remote,{});
    await normal.page.locator('[data-action="cloud-push"]').click();
    await normal.page.locator('#upload-size').getByText('本次上传：',{exact:false}).waitFor();
    assert.match(await normal.page.locator('#upload-size').innerText(),new RegExp('单次上限：'+C.CLOUD_UPLOAD_LIMIT/1000+' KB'));
    assert.equal(await normal.page.locator('#upload-acknowledge').isDisabled(),true);
    await normal.page.screenshot({path:resolve(artifacts,'cloud-size-warning.png')});
    // The cloud can grow after preview; the final size guard must still stop the write.
    remote.value={other:'A'.repeat(C.CLOUD_UPLOAD_LIMIT)};
    await normal.page.waitForFunction(()=>!document.querySelector('#upload-acknowledge')?.disabled);
    await normal.page.locator('#upload-acknowledge').click();
    await normal.page.getByText('超出云端保存容量',{exact:false}).first().waitFor();
    assert.equal(normal.writes(),0);
    assert.equal(remote.value.guitu_save_quota_v1,undefined);

    const bad={fail:false};
    const failure=await open(await fresh(),{value:{}},bad);
    bad.fail=true;
    await failure.page.locator('[data-action="cloud-push"]').click();
    await failure.page.getByText('云端暂不可用，请稍后重试',{exact:false}).waitFor();
    assert.equal(await failure.page.locator('#upload-acknowledge').isDisabled(),true);
    assert.equal(failure.writes(),0);

    const tooLarge=await open(await fresh(),{value:{other:'A'.repeat(C.CLOUD_UPLOAD_LIMIT)}},{});
    await tooLarge.page.locator('[data-action="cloud-push"]').click();
    await tooLarge.page.getByText('数据过大，无法上传',{exact:false}).first().waitFor();
    await tooLarge.page.screenshot({path:resolve(artifacts,'cloud-size-warning-over-limit.png')});
    assert.equal(await tooLarge.page.locator('#upload-acknowledge').isDisabled(),true);
    assert.equal(tooLarge.writes(),0);
    const local=await tooLarge.page.evaluate(()=>JSON.parse(localStorage.getItem('guitu-v022:size-warning')));
    assert.deepEqual(local.snapshot.entries,tooLarge.archive.entries);
    assert.deepEqual(errors,[]);
    for (const context of contexts) await context.close();
    console.log('PASS: readable size preview, five-second acknowledgement, metadata size, read failure, cloud growth after preview, no oversized writes');
  } finally { await browser.close(); }
}
main().catch(error=>{console.error(error);process.exitCode=1;});
