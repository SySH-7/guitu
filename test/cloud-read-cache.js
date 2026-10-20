const assert = require('node:assert/strict');
const fs = require('node:fs');
const {resolve} = require('node:path');
const {chromium} = require('playwright');
const C = require('../src/core.js');
const fixture=C.normalizeSnapshot(JSON.parse(fs.readFileSync(resolve(__dirname,'fictional-archive.json'),'utf8')));
const html=fs.readFileSync(resolve(__dirname,'../dist/guitu-tieba-0.2.2.html'),'utf8');
async function main() {
  const browser=await chromium.launch({headless:true,
    executablePath:process.env.GUITU_CHROMIUM_EXECUTABLE || undefined,args:['--no-sandbox']});
  try {
    const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
    const page=await context.newPage();
    const errors=[];
    let remote={};
    const cached=new Map();
    const readUrls=[];
    const uploadUrls=[];
    page.on('dialog',dialog=>dialog.accept());
    page.on('pageerror',error=>errors.push(error.message));
    await page.route('https://tieba.baidu.com/**',async route=>{
      const url=new URL(route.request().url());
      if(url.pathname==='/c/s/game/html')return route.fulfill({contentType:'text/html',body:html});
      if(url.pathname==='/c/s/game/payloadDownload') {
        readUrls.push(url.href);
        if(!cached.has(url.href))cached.set(url.href,JSON.stringify({error_code:0,data:{payload:JSON.stringify(remote)}}));
        return route.fulfill({contentType:'application/json',body:cached.get(url.href)});
      }
      if(url.pathname==='/c/s/game/payloadUpload') {
        uploadUrls.push(url.href);
        remote=JSON.parse(url.searchParams.get('payload'));
        return route.fulfill({contentType:'application/json',body:'{}'});
      }
      await route.abort();
    });
    await page.addInitScript(snapshot=>{
      localStorage.setItem('guitu-v022:cache-test',JSON.stringify({snapshot,dirty:true}));
      const request=url=>new Promise((resolve,reject)=>{
        const xhr=new XMLHttpRequest();
        xhr.open('GET',url);
        xhr.onload=()=>resolve(JSON.parse(xhr.responseText));
        xhr.onerror=reject;
        xhr.send();
      });
      window.tieba={getUserInfo:()=>({user_id:'cache-test'}),
        downloadData:()=>request('/c/s/game/payloadDownload?game_id=test-app').then(body=>JSON.parse(body.data.payload)),
        uploadData:state=>request('/c/s/game/payloadUpload?game_id=test-app&payload='+encodeURIComponent(JSON.stringify(state)))};
    },fixture);
    await page.goto('https://tieba.baidu.com/c/s/game/html?game_id=test-app',{waitUntil:'domcontentloaded'});
    await page.locator('[data-action="tab"][data-tab="settings"]').click();
    await page.locator('[data-page="cloud"]').click();
    await page.locator('[data-action="cloud-push"]').click();
    await page.waitForFunction(()=>!document.querySelector('#upload-acknowledge')?.disabled);
    await page.locator('#upload-acknowledge').click();
    await page.getByText('本周剩余云端保存次数：4 / 5').waitFor();
    assert.equal(C.readCloudSnapshot(remote[C.CLOUD_KEY]).entries.length,90);
    await page.locator('[data-action="cloud-view"]').click();
    assert.equal((await page.locator('.summary-list').innerText()).match(/30 条/g).length,3);
    await page.locator('[data-action="close"]').click();
    await page.locator('[data-action="cloud-delete"]').click();
    await page.getByText('云端记录已删除，本机记录仍在').waitFor();
    assert.equal(remote[C.CLOUD_KEY],undefined);
    assert.equal(remote[C.QUOTA_KEY].used,1);
    assert.ok(readUrls.length>=8);
    assert.equal(new Set(readUrls).size,readUrls.length,'each SDK download must bypass a cached response');
    assert.ok(readUrls.every(url=>new URL(url).searchParams.has('_guitu_read')));
    assert.ok(uploadUrls.every(url=>!new URL(url).searchParams.has('_guitu_read')),'upload transport and size must remain unchanged');
    assert.deepEqual(errors,[]);
    console.log('PASS: SDK read cache cannot hide a successful save or deletion; upload URLs unchanged');
  } finally { await browser.close(); }
}
main().catch(error=>{console.error(error);process.exitCode=1;});
