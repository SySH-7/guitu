const assert = require('node:assert/strict');
const {chromium} = require('playwright');
const {pathToFileURL} = require('node:url');
const {resolve} = require('node:path');
const C = require('../src/core.js');
const {largeArchive} = require('./large-fixtures.js');
const url = pathToFileURL(resolve(__dirname,'../dist/guitu-tieba-0.2.2.html')).href;

async function open(page,archive,remote,onUpload) {
  await page.exposeFunction('__download',async()=>remote.value);
  await page.exposeFunction('__upload',async(value)=>{ onUpload(value); remote.value=value; });
  await page.addInitScript((snapshot)=>{
    localStorage.setItem('guitu-v022:compression-ui',JSON.stringify({snapshot,dirty:true}));
    window.tieba={getUserInfo:()=>({user_id:'compression-ui'}),
      downloadData:()=>window.__download(),uploadData:value=>window.__upload(value)};
  },archive);
  page.on('dialog',dialog=>dialog.accept());
  await page.goto(url,{waitUntil:'domcontentloaded'});
  await page.locator('[data-action="tab"][data-tab="settings"]').click();
  await page.locator('[data-page="cloud"]').click();
}
async function save(page) {
  await page.locator('[data-action="cloud-push"]').click();
  await page.waitForFunction(()=>!document.querySelector('#upload-acknowledge')?.disabled);
  await page.locator('#upload-acknowledge').click();
}
async function localEntries(page) {
  return page.evaluate(()=>JSON.parse(localStorage.getItem('guitu-v022:compression-ui')).snapshot.entries);
}
async function main() {
  const browser=await chromium.launch({headless:true,
    executablePath:process.env.GUITU_CHROMIUM_EXECUTABLE || undefined,args:['--no-sandbox']});
  try {
    let writes=0;
    const remote={value:{other:{kept:true}}};
    const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
    const page=await context.newPage();
    const errors=[];
    page.on('pageerror',error=>errors.push(error.message));
    const small=largeArchive(100);
    await open(page,small,remote,()=>writes++);
    await save(page);
    await page.getByText('本周剩余云端保存次数：4 / 5').waitFor();
    assert.equal(writes,1);
    assert.equal(C.readCloudSnapshot(remote.value[C.CLOUD_KEY]).entries.length,300);
    assert.deepEqual(await localEntries(page),small.entries);
    await page.locator('[data-action="cloud-view"]').click();
    const summary=await page.locator('.summary-list').innerText();
    for(const kind of ['书籍','影视','旅途 / 地点']) assert.ok(summary.includes(kind));
    assert.equal((summary.match(/100 条/g)||[]).length,3);
    await page.locator('[data-action="close"]').click();
    await page.evaluate(()=>localStorage.removeItem('guitu-v022:compression-ui'));
    // The startup path must decode cloud data too, without an existing local copy.
    await page.removeAllListeners('dialog');
    const recovered=await context.newPage();
    await recovered.exposeFunction('__recoveryDownload',async()=>remote.value);
    await recovered.addInitScript(()=>{
      window.tieba={getUserInfo:()=>({user_id:'compression-ui'}),
        downloadData:()=>window.__recoveryDownload(),uploadData:async()=>{}};
    });
    await recovered.goto(url,{waitUntil:'domcontentloaded'});
    await recovered.getByText('把喜欢的日子').waitFor();
    assert.deepEqual(await localEntries(recovered),small.entries);
    await context.close();

    for(const perKind of [300,500]) {
      const big=largeArchive(perKind);
      const before={other:{kept:true},[C.QUOTA_KEY]:{week:C.weekKey(),used:2}};
      const store={value:structuredClone(before)};
      let calls=0;
      const scope=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
      const largePage=await scope.newPage();
      largePage.on('pageerror',error=>errors.push(error.message));
      await open(largePage,big,store,()=>calls++);
      await largePage.locator('[data-action="cloud-push"]').click();
      await largePage.getByText('数据过大，无法上传',{exact:false}).first().waitFor();
      assert.equal(await largePage.locator('#upload-acknowledge').isDisabled(),true);
      await largePage.waitForTimeout(5100);
      assert.equal(await largePage.locator('#upload-acknowledge').isDisabled(),true);
      await largePage.locator('#upload-acknowledge').evaluate(button=>
        button.dispatchEvent(new MouseEvent('click',{bubbles:true})));
      assert.equal(calls,0,'oversized data must be stopped before invoking uploadData');
      assert.deepEqual(store.value,before,'failed upload must not alter cloud data or quota');
      assert.deepEqual(await localEntries(largePage),big.entries,'all local records must survive');
      await scope.close();
    }
    assert.deepEqual(errors,[]);
    console.log('PASS: default compression, readable summary, startup restore, 900/1500-record capacity rejection preserves local data and quota');
  } finally { await browser.close(); }
}
main().catch(error=>{console.error(error);process.exitCode=1;});
