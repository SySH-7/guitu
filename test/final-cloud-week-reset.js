/* Regression: an app kept open from Sunday into Monday must refresh its quota. */
const assert = require('node:assert/strict');
const {pathToFileURL} = require('node:url');
const {resolve} = require('node:path');
const {chromium} = require('playwright');

async function main() {
  const browser = await chromium.launch({headless:true,
    executablePath:process.env.GUITU_CHROMIUM_EXECUTABLE || undefined});
  try {
    const page = await browser.newPage({viewport:{width:390,height:844}});
    let reads = 0;
    let writes = 0;
    await page.clock.install({time:new Date('2026-10-18T15:59:00Z')});
    await page.exposeFunction('__rolloverRead',async () => {
      reads++;
      return {guitu_save_quota_v1:{week:'2026-10-12',used:5}};
    });
    await page.exposeFunction('__rolloverWrite',async () => { writes++; });
    await page.addInitScript(() => {
      window.tieba = {getUserInfo:() => ({user_id:'weekly-rollover'}),
        downloadData:() => window.__rolloverRead(),
        uploadData:() => window.__rolloverWrite()};
    });
    await page.goto(pathToFileURL(resolve(__dirname,'../dist/guitu-tieba-0.2.2.html')).href);
    await page.locator('[data-tab="settings"]').click();
    await page.locator('[data-page="cloud"]').click();
    assert.match(await page.locator('#app').innerText(),/本周剩余云端保存次数：0 \/ 5/);
    // Preserve the existing same-week exhausted-quota behavior.
    await page.locator('[data-action="cloud-push"]').click();
    await page.getByText('本周 5 次云端保存次数已用完，请下周再试',{exact:false}).waitFor();
    if (await page.locator('#upload-acknowledge').count()) {
      assert.equal(await page.locator('#upload-acknowledge').isDisabled(),true);
      await page.locator('[data-action="close"]').click();
    }
    assert.equal(writes,0,'an exhausted quota must not write to cloud');
    await page.clock.setFixedTime(new Date('2026-10-18T16:01:00Z'));
    await page.locator('[data-action="cloud-push"]').click();
    assert.equal(await page.locator('#upload-acknowledge').count(),1,
      'a cached zero quota from last week must not block this week before refreshing');
    await page.locator('#upload-size').getByText('本次上传：',{exact:false}).waitFor();
    assert.ok(reads >= 2,'a new week must refresh from mock cloud rather than trust the cached zero');
    assert.match(await page.locator('#app').innerText(),/本周剩余云端保存次数：5 \/ 5/);
    assert.equal(writes,0,'opening the warning must not write to cloud');
    console.log('PASS: same-week exhausted quota stays blocked; an app kept open across Monday refreshes to 5 / 5 without writing cloud data');
  } finally { await browser.close(); }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
