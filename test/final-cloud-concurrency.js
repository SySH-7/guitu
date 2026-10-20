/* Cloud concurrency probes use only isolated mock SDK data. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {chromium} = require('playwright');
const {pathToFileURL} = require('node:url');
const {resolve,dirname} = require('node:path');
const C = require('../src/core.js');
const archive = C.normalizeSnapshot({entries:[{id:'audit-original',kind:'book',
  title:'原有小路',date:'2020-02-03',createdAt:'2020-02-03T12:00:00Z'}]});

async function main() {
  const browser = await chromium.launch({headless:true,
    executablePath:process.env.GUITU_CHROMIUM_EXECUTABLE || undefined});
  const results = [];
  try {
    for (const scenario of ['local-edits-during-upload','cloud-changed-before-upload']) {
      const context = await browser.newContext({viewport:{width:390,height:844}});
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror',error => errors.push(error.message));
      await page.clock.install();
      let remote = {}, reads = 0, writes = 0, release;
      await page.exposeFunction('__edgeRead',async () => {
        reads++;
        if (scenario === 'cloud-changed-before-upload' && reads >= 4)
          remote = {other:{changed:true}};
        return remote;
      });
      await page.exposeFunction('__edgeWrite',async value => {
        writes++;
        await new Promise(resolve => { release = resolve; });
        remote = value;
      });
      await page.addInitScript(snapshot => {
        localStorage.setItem('guitu-v022:concurrency-audit',JSON.stringify({snapshot,dirty:true}));
        window.tieba = {getUserInfo:() => ({user_id:'concurrency-audit'}),
          downloadData:() => window.__edgeRead(),
          uploadData:value => {
            window.__edgeUploadStarted = true;
            return window.__edgeWrite(value);
          }};
      },archive);
      page.on('dialog',dialog => dialog.accept());
      await page.goto(pathToFileURL(resolve(__dirname,'../dist/guitu-tieba-0.2.2.html')).href);
      await page.locator('[data-tab="settings"]').click();
      await page.locator('[data-page="cloud"]').click();
      await page.locator('[data-action="cloud-push"]').click();
      await page.locator('#upload-size').getByText('本次上传：',{exact:false}).waitFor();
      await page.clock.fastForward(6000);
      await page.locator('#upload-acknowledge').click();
      if (scenario === 'local-edits-during-upload') {
        await page.waitForFunction(() => window.__edgeUploadStarted);
        await page.locator('[data-tab="home"]').click();
        await page.locator('[data-action="add"]').first().click();
        await page.locator('[data-action="choose-kind"][data-kind="book"]').click();
        await page.locator('#f-title').fill('上传期间新增的书');
        await page.locator('#f-date').fill('2021-09-03');
        await page.locator('#entry-form button[type="submit"]').click();
        await page.locator('[data-action="detail"][data-id="audit-original"]').click();
        await page.locator('[data-action="delete"]').click();
        release();
        await page.waitForFunction(() => document.querySelector('#cloud-status').textContent.includes('本机已保存'));
        const local = await page.evaluate(() => JSON.parse(localStorage.getItem('guitu-v022:concurrency-audit')));
        assert.equal(local.snapshot.entries.length,1);
        assert.equal(local.snapshot.entries[0].title,'上传期间新增的书');
        assert.equal(local.dirty,true);
        assert.equal(C.readCloudSnapshot(remote.guitu_v022).entries[0].title,'原有小路');
        assert.equal(writes,1);
        results.push({scenario,status:'passed',mockOnly:true,reads,writes,
          localTitles:local.snapshot.entries.map(x => x.title),localDirty:local.dirty,
          cloudTitles:C.readCloudSnapshot(remote.guitu_v022).entries.map(x => x.title)});
      } else {
        await page.getByText('保存到云端失败：云端内容刚刚变化，请重新操作',{exact:false}).first().waitFor();
        assert.equal(writes,0);
        const local = await page.evaluate(() => JSON.parse(localStorage.getItem('guitu-v022:concurrency-audit')));
        assert.equal(local.snapshot.entries[0].title,'原有小路');
        results.push({scenario,status:'passed',mockOnly:true,reads,writes,
          localTitles:local.snapshot.entries.map(x => x.title),
          reason:'Cloud changed after confirmation; write rejected before invoking uploadData'});
      }
      assert.deepEqual(errors,[]);
      console.log('PASS: ' + scenario + ' (mock SDK only)');
      await context.close();
    }
    const output = resolve(__dirname,'../test-artifacts/final-acceptance/cloud-concurrency.json');
    fs.mkdirSync(dirname(output),{recursive:true});
    fs.writeFileSync(output,JSON.stringify({checkedAt:new Date().toISOString(),results},null,2) + '\n');
  } finally { await browser.close(); }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
