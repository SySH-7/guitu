const assert = require('node:assert/strict');
const fs = require('node:fs');
const {pathToFileURL} = require('node:url');
const {resolve} = require('node:path');
const {chromium} = require('playwright');
const C = require('../src/core.js');

const url = pathToFileURL(resolve(__dirname,'../dist/guitu-tieba-0.2.2.html')).href;
const fixture = fs.readFileSync(resolve(__dirname,'fictional-archive.json'),'utf8');
const browserPath = process.env.GUITU_CHROMIUM_EXECUTABLE || undefined;
const click = (page,selector) => page.locator(selector).first().click();
async function addBook(page,title) {
  await click(page,'[data-action="add"]');
  await click(page,'[data-action="choose-kind"][data-kind="book"]');
  await page.locator('#f-title').fill(title);
  await click(page,'#entry-form button[type="submit"]');
  await page.getByText('记录已保存').waitFor();
}
async function save(page,remaining) {
  await click(page,'[data-action="cloud-push"]');
  await page.locator('#upload-acknowledge').waitFor({state:'visible'});
  assert.equal(await page.locator('#upload-acknowledge').isDisabled(),true);
  await page.locator('#upload-acknowledge').waitFor({state:'visible'});
  await page.waitForFunction(() => !document.querySelector('#upload-acknowledge')?.disabled);
  await click(page,'#upload-acknowledge');
  await page.getByText('本周剩余云端保存次数：' + remaining + ' / 5').waitFor();
}
async function main() {
  const browser = await chromium.launch({headless:true,executablePath:browserPath,args:['--no-sandbox']});
  const errors = [];
  try {
    let cloudStore = {otherFeature:{kept:true}};
    let rejectUpload = false;
    let auditCalls = 0;
    const context = await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
    const page = await context.newPage();
    page.on('dialog',(dialog) => dialog.accept());
    await page.route(/workers\.dev|aip\.baidubce\.com/,async (route) => {
      auditCalls++;
      await route.abort();
    });
    page.on('pageerror',(error) => errors.push(error.message));
    await page.exposeFunction('__cloudDownload',async () => JSON.parse(JSON.stringify(cloudStore)));
    await page.exposeFunction('__cloudUpload',async (state) => {
      if (rejectUpload) throw new Error('mock write rejected');
      cloudStore = JSON.parse(JSON.stringify(state));
    });
    await page.addInitScript(() => {
      window.tieba = {
        getUserInfo: () => ({user_id:'fictional-test-account'}),
        downloadData: () => window.__cloudDownload(),
        uploadData: (state) => window.__cloudUpload(state)
      };
    });
    await page.goto(url,{waitUntil:'domcontentloaded'});
    await page.getByText('把喜欢的日子').waitFor();
    await click(page,'[data-action="tab"][data-tab="settings"]');
    assert.equal(await page.locator('[data-action="cloud-push"]').count(),0);
    assert.equal(await page.locator('[data-action="probe"]').count(),0);
    assert.equal(await page.locator('[data-action="map-key"]').count(),0);
    await click(page,'[data-page="help"]');
    await page.getByText('如何备份、导入和导出数据').waitFor();
    assert.match(await page.locator('main').innerText(),/换设备/);
    await click(page,'[data-page="settings"]');
    await click(page,'[data-page="cloud"]');
    await page.getByText('本周剩余云端保存次数：5 / 5').waitFor();
    await click(page,'[data-action="cloud-view"]');
    await page.getByText('云端还没有保存归途记录。').waitFor();
    assert.equal(await page.locator('#cloud-json').count(),0);
    await click(page,'[data-action="close"]');
    await click(page,'[data-page="local-data"]');
    assert.equal(await page.locator('input[type="file"]').count(),0);
    assert.equal(await page.locator('[data-action="export"]').count(),0);
    await click(page,'[data-action="import"]');
    await page.locator('#f-import-json').fill('{broken');
    await click(page,'#import-form button[type="submit"]');
    await page.getByText('备份文本格式不正确',{exact:false}).waitFor();
    assert.equal(await page.evaluate(() => (JSON.parse(localStorage.getItem('guitu-v022:fictional-test-account'))?.snapshot.entries.length || 0)),0);
    await page.locator('#f-import-json').fill(fixture);
    await click(page,'#import-form button[type="submit"]');
    assert.equal(await page.evaluate(() => JSON.parse(localStorage.getItem('guitu-v022:fictional-test-account')).snapshot.entries.length),90);
    assert.equal(cloudStore.guitu_v022,undefined);
    await click(page,'[data-action="import"]');
    await page.locator('#f-import-json').fill('{"entries":[{"kind":"place","title":"缺少省市"}]}');
    await click(page,'#import-form button[type="submit"]');
    assert.equal(await page.evaluate(() => JSON.parse(localStorage.getItem('guitu-v022:fictional-test-account')).snapshot.entries.length),90);
    await click(page,'[data-action="close"]');
    await click(page,'[data-action="export-text"]');
    const backup = JSON.parse(await page.locator('#export-json').inputValue());
    assert.equal(backup.entries.length,90);
    await click(page,'[data-action="close"]');
    await click(page,'[data-page="cloud"]');
    rejectUpload = true;
    await click(page,'[data-action="cloud-push"]');
    await page.waitForFunction(() => !document.querySelector('#upload-acknowledge')?.disabled);
    await click(page,'#upload-acknowledge');
    await page.getByText('保存到云端失败',{exact:false}).first().waitFor();
    assert.equal(cloudStore.guitu_v022,undefined);
    assert.match(await page.locator('main').innerText(),/5 \/ 5/);
    rejectUpload = false;
    await save(page,4);
    assert.equal(cloudStore.guitu_v022.encoding,'guitu.deflate-base64url.v1');
    assert.equal(C.readCloudSnapshot(cloudStore.guitu_v022).entries.length,90);
    assert.equal(cloudStore.guitu_save_quota_v1.used,1);
    assert.deepEqual(cloudStore.otherFeature,{kept:true});
    assert.equal(await page.evaluate(() => JSON.parse(localStorage.getItem('guitu-v022:fictional-test-account')).snapshot.entries.length),90);
    assert.equal(auditCalls,0,'cloud saving must not call an external content review service');
    await click(page,'[data-action="cloud-view"]');
    const summary = await page.locator('.summary-list').innerText();
    assert.match(summary,/书籍\s+30 条/);
    assert.match(summary,/影视\s+30 条/);
    assert.match(summary,/旅途 \/ 地点\s+30 条/);
    assert.match(summary,/最近保存时间/);
    assert.equal(await page.locator('#cloud-json').count(),0);
    await click(page,'[data-action="close"]');
    for (let i=0;i<4;i++) {
      await addBook(page,'补充测试书 ' + (i+1));
      await save(page,3-i);
    }
    assert.equal(cloudStore.guitu_save_quota_v1.used,5);
    await addBook(page,'额度外本机记录');
    await click(page,'[data-action="cloud-push"]');
    await page.getByText('本周 5 次云端保存次数已用完',{exact:false}).first().waitFor();
    assert.equal(C.readCloudSnapshot(cloudStore.guitu_v022).entries.length,94);
    assert.equal(await page.evaluate(() => JSON.parse(localStorage.getItem('guitu-v022:fictional-test-account')).snapshot.entries.length),95);
    const anotherDevice = C.readCloudSnapshot(cloudStore.guitu_v022);
    anotherDevice.entries.push({...backup.entries[0],id:'remote-only',title:'云端独有的虚构书'});
    anotherDevice.entries[0].title = '云端修改的同一记录';
    cloudStore = C.mergeCloudEnvelope(cloudStore,anotherDevice);
    await click(page,'[data-action="cloud-pull"]');
    await page.getByText('已从云端合并 1 条记录').waitFor();
    assert.equal(await page.evaluate(() => JSON.parse(localStorage.getItem('guitu-v022:fictional-test-account')).snapshot.entries.length),96);
    assert.equal(await page.evaluate(() => JSON.parse(localStorage.getItem('guitu-v022:fictional-test-account')).snapshot.entries.find(e => e.id === 'fiction-book-1').title),'雨后书店');
    await click(page,'[data-action="cloud-delete"]');
    await page.getByText('云端记录已删除，本机记录仍在').waitFor();
    assert.equal(cloudStore.guitu_v022,undefined);
    assert.equal(cloudStore.guitu_save_quota_v1.used,5);
    assert.deepEqual(cloudStore.otherFeature,{kept:true});
    assert.equal(await page.evaluate(() => JSON.parse(localStorage.getItem('guitu-v022:fictional-test-account')).snapshot.entries.length),96);
    await page.reload({waitUntil:'domcontentloaded'});
    await page.getByText('把喜欢的日子').waitFor();
    assert.equal(await page.locator('.stat.book .num').innerText(),'36');
    assert.deepEqual(errors,[]);
    await context.close();
    const preview = await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
    const previewPage = await preview.newPage();
    await previewPage.addInitScript(() => {
      window.tieba = {getUserInfo:() => ({user_id:''}),downloadData:async () => ({}),
        uploadData:async () => {}};
    });
    await previewPage.goto(url,{waitUntil:'domcontentloaded'});
    await addBook(previewPage,'临时记录');
    assert.match(await previewPage.locator('#cloud-status').innerText(),/本次打开临时保存/);
    assert.equal(await previewPage.evaluate(() => localStorage.getItem('guitu-v022:tieba-unknown')),null);
    assert.equal(await previewPage.evaluate(() => JSON.parse(sessionStorage.getItem('guitu-v022:tieba-unknown')).snapshot.entries.length),1);
    await click(previewPage,'[data-action="tab"][data-tab="settings"]');
    await click(previewPage,'[data-page="cloud"]');
    assert.match(await previewPage.locator('main').innerText(),/无法确认这里的云端记录属于你的手机账号/);
    await preview.close();
    console.log('PASS: fictional import, safe backup, cloud summary, write failures, five-save reminder, merge, delete, reload');
  } finally { await browser.close(); }
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
