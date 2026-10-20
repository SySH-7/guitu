/* Run with the bundled Node + NODE_PATH. Does not touch a real account or cloud. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const {chromium,webkit} = require('playwright');
const {variedArchive} = require('./final-varied-fixtures.js');
const C = require('../src/core.js');

const ARCHIVE = variedArchive();
const URL = pathToFileURL(path.resolve(__dirname,'../dist/guitu-tieba-0.2.2.html')).href;
const ARTIFACTS = path.resolve(__dirname,'../test-artifacts/final-varied');
const ACCOUNT = 'final-varied-isolated';
const KEY = 'guitu-v022:' + ACCOUNT;
const report = {fixture:{records:ARCHIVE.entries.length,range:['1999-12-31','2026-10-16'],
  kinds:{book:73,film:67,place:60},notes:'Fictional data; isolated SDK and map mocks. No real cloud writes.'},runs:[]};
const sorted = (entries) => entries.slice().sort((a,b) => b.date.localeCompare(a.date));
const sum = (entries,kind) => entries.filter((entry) => entry.kind === kind)
  .reduce((total,entry) => total + (kind === 'place' ? 1 : entry.amount),0);
const yearsOf = (entries) => [...new Set([2026,...entries.filter((entry) => entry.kind !== 'place').map((entry) => Number(entry.date.slice(0,4)))])].sort((a,b) => b-a);

function mocks() {
  window.__uploads = 0;
  window.tieba = {getUserInfo:() => ({user_id:'final-varied-isolated'}),
    downloadData:async () => ({}),uploadData:async () => { window.__uploads++; }};
  class Point { constructor(lng,lat) { this.lng=lng; this.lat=lat; } }
  class Marker { constructor(point) { this.point=point; } setTitle() {} addEventListener() {} }
  class Map {
    constructor() { this.overlays=[]; }
    centerAndZoom() {} getViewport() { return {center:new Point(104,32),zoom:3}; }
    setViewport() {} disableDragging() {} enableDragging() {} disableScrollWheelZoom() {}
    enableScrollWheelZoom() {} checkResize() {} addEventListener() {}
    addOverlay(marker) { this.overlays.push(marker); } removeOverlay(marker) { this.overlays=this.overlays.filter((value) => value!==marker); }
  }
  class Geocoder { getPoint(address,callback) { setTimeout(() => callback(new Point(121.5,25.1)),0); } }
  window.BMap = {Map,Point,Marker,Geocoder};
}

async function click(page,selector) {
  const target = page.locator(selector).first();
  // CSS smooth scrolling continues after newly appended records change the
  // page height. Place the target first, as a person would scroll then tap;
  // still require a real actionability-checked click (no forced DOM event).
  await target.evaluate((element) => element.scrollIntoView({behavior:'instant',block:'center',inline:'center'}));
  await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  await target.click();
}
async function localPage(page) {
  await click(page,'[data-action="tab"][data-tab="settings"]');
  await click(page,'[data-page="cloud"]');
  await click(page,'[data-page="local-data"]');
}
async function importText(page,text) {
  await click(page,'[data-action="import"]');
  await page.locator('#f-import-json').fill(text);
  await click(page,'#import-form button[type="submit"]');
}
async function readStored(page) {
  return page.evaluate((key) => JSON.parse(localStorage.getItem(key)).snapshot,KEY);
}
async function assertPagination(page,key,entries) {
  const selector = '#records-' + key + ' .record';
  const more = '[data-action="load-more"][data-list="' + key + '"]';
  let shown = Math.min(10,entries.length);
  const noHorizontalOverflow = async () => {
    const geometry = await page.evaluate(() => ({scrollWidth:document.documentElement.scrollWidth,
      records:[...document.querySelectorAll('main .record')].map((node) => node.getBoundingClientRect().right)}));
    assert.ok(geometry.scrollWidth <= page.viewportSize().width+1,key+' no horizontal overflow with '+shown+' records');
    assert.ok(geometry.records.every((right) => right <= page.viewportSize().width+1),key+' all cards stay inside viewport');
  };
  assert.equal(await page.locator(selector).count(),shown,key + ' initial ten');
  assert.equal(await page.locator(more).count(),shown<entries.length ? 1 : 0,key + ' initial more');
  await noHorizontalOverflow();
  while (shown<entries.length) {
    await click(page,more);
    shown = Math.min(shown+10,entries.length);
    assert.equal(await page.locator(selector).count(),shown,key + ' loads next ten');
    assert.equal(await page.locator(more).count(),shown<entries.length ? 1 : 0,key + ' hides exhausted more');
    await noHorizontalOverflow();
  }
  assert.deepEqual(await page.locator(selector).evaluateAll((nodes) => nodes.map((node) => node.dataset.id)),
    sorted(entries).map((entry) => entry.id),key + ' descending date order');
}
async function search(page,word) {
  await click(page,'[data-action="search"]');
  await page.locator('#f-query').fill(word);
  await click(page,'#search-form button');
}
function expectedSearch(word) {
  return ARCHIVE.entries.filter((entry) => [entry.title,entry.creator || '',entry.category || '',entry.province || '',entry.city || '',''].join('').toLowerCase().includes(word.toLowerCase()));
}

async function run(browser,label,width,timeZone) {
  const context = await browser.newContext({viewport:{width,height:844},isMobile:true,hasTouch:true,
    timezoneId:timeZone,locale:'zh-CN'});
  const errors = [];
  const page = await context.newPage();
  page.on('pageerror',(error) => errors.push(error.message));
  page.on('dialog',(dialog) => dialog.accept());
  await page.addInitScript(mocks);
  await page.route(/^https?:/, (route) => route.abort());
  const started = Date.now();
  const result = {engine:label,width,timezone:timeZone,checks:[]};
  try {
    await page.goto(URL,{waitUntil:'domcontentloaded'});
    await page.locator('main .hero').waitFor();
    assert.equal(await page.locator('#records-home .record').count(),0,'formal build must not auto-seed');
    await localPage(page);
    await importText(page,JSON.stringify(ARCHIVE));
    const firstStored = await readStored(page);
    assert.equal(firstStored.entries.length,200);
    assert.deepEqual(firstStored.entries,C.normalizeSnapshot(ARCHIVE).entries,'UI import preserves all valid fields');
    assert.equal(await page.evaluate(() => window.__uploads),0);
    result.checks.push('UI paste imports 200 records without cloud write; leap/calendar dates, max title/creator/count and Unicode preserved');

    for (const invalid of ['{broken',JSON.stringify({entries:[{kind:'place',title:'缺少省市'}]}),
      JSON.stringify({entries:[{kind:'book',title:'长'.repeat(61)}]})]) {
      await importText(page,invalid);
      await page.locator('.toast').waitFor();
      assert.deepEqual((await readStored(page)).entries,firstStored.entries,'invalid import cannot alter existing data');
      await click(page,'[data-action="close"]');
    }
    result.checks.push('Malformed JSON, missing place fields and oversized title imports rejected with local records unchanged');

    await click(page,'[data-action="export-text"]');
    const backup = JSON.parse(await page.locator('#export-json').inputValue());
    assert.deepEqual(backup.entries,firstStored.entries,'backup contains every record and original characters');
    await click(page,'[data-action="close"]');
    await importText(page,JSON.stringify(backup));
    assert.equal((await readStored(page)).entries.length,200,'reimport same backup does not duplicate IDs');
    fs.writeFileSync(path.join(ARTIFACTS,label + '-' + width + '-backup.json'),JSON.stringify(backup,null,2)+'\n');
    result.checks.push('Backup round trip retains all fields; importing same archive twice creates no duplicate records');

    await click(page,'[data-action="tab"][data-tab="home"]');
    for (const kind of ['book','film','place']) assert.equal(await page.locator('.stat.'+kind+' .num').innerText(),String(sum(ARCHIVE.entries,kind)));
    await assertPagination(page,'home',ARCHIVE.entries);
    await page.evaluate(() => scrollTo({top:0,behavior:'instant'}));
    await page.screenshot({path:path.join(ARTIFACTS,label+'-'+width+'-home.png'),fullPage:false});
    const titleGeometry = await page.locator('[data-id="final-varied-book-002"] .record-title').evaluate((node) => ({
      clientWidth:node.clientWidth,scrollWidth:node.scrollWidth,textOverflow:getComputedStyle(node).textOverflow,
      docWidth:document.documentElement.scrollWidth,cardWidth:node.closest('.record').getBoundingClientRect().width
    }));
    assert.ok(titleGeometry.scrollWidth>titleGeometry.clientWidth,'long title text is clipped within card');
    assert.equal(titleGeometry.textOverflow,'ellipsis');
    const latinGeometry = await page.locator('[data-id="final-varied-film-004"] .record-title').evaluate((node) => ({
      clientWidth:node.clientWidth,scrollWidth:node.scrollWidth,textOverflow:getComputedStyle(node).textOverflow,
      docWidth:document.documentElement.scrollWidth,cardWidth:node.closest('.record').getBoundingClientRect().width
    }));
    assert.ok(latinGeometry.scrollWidth>latinGeometry.clientWidth,'60-character unbroken Latin title stays clipped');
    assert.equal(latinGeometry.textOverflow,'ellipsis');
    fs.writeFileSync(path.join(ARTIFACTS,label+'-'+width+'-latin-title-after.json'),JSON.stringify(latinGeometry,null,2)+'\n');
    fs.writeFileSync(path.join(ARTIFACTS,label+'-'+width+'-long-title-after.json'),JSON.stringify(titleGeometry,null,2)+'\n');
    await click(page,'[data-id="final-varied-book-002"]');
    assert.equal(await page.locator('.modal-head h2').innerText(),'春'.repeat(60),'detail keeps complete long title');
    await click(page,'[data-action="close"]');
    result.checks.push('Home weighted totals, date sorting and all 10-at-a-time pages verified');

    await click(page,'[data-action="tab"][data-tab="books"]');
    assert.deepEqual(await page.locator('[data-action="year"]').evaluateAll((nodes) => nodes.map((node) => Number(node.dataset.year))),yearsOf(ARCHIVE.entries));
    const annual = yearsOf(ARCHIVE.entries).slice().sort((a,b) => a-b).flatMap((year) => [
      year+' 阅读 '+sum(ARCHIVE.entries.filter((entry) => Number(entry.date.slice(0,4))===year),'book'),
      year+' 影视 '+sum(ARCHIVE.entries.filter((entry) => Number(entry.date.slice(0,4))===year),'film')
    ]);
    assert.deepEqual(await page.locator('.trend circle title').allTextContents(),annual,'annual plot exact counts independent of selected year');
    for (const year of yearsOf(ARCHIVE.entries)) {
      await click(page,'[data-action="year"][data-year="'+year+'"]');
      const entries = ARCHIVE.entries.filter((entry) => entry.kind!=='place' && Number(entry.date.slice(0,4))===year);
      const monthly = Array.from({length:12},(_,month) => {
        const subset=entries.filter((entry) => Number(entry.date.slice(5,7))===month+1);
        return (month+1)+'月 阅读'+sum(subset,'book')+' 影视'+sum(subset,'film');
      });
      assert.deepEqual(await page.locator('.bar-pair').evaluateAll((nodes) => nodes.map((node) => node.title)),monthly,'monthly values for '+year);
      const legend = await page.locator('.legend').innerText();
      assert.match(legend,new RegExp('阅读 '+sum(entries,'book')));
      assert.match(legend,new RegExp('影视 '+sum(entries,'film')));
      const blocks = page.locator('.card.chart').filter({has:page.locator('.category-row')});
      for (const [index,kind] of ['book','film'].entries()) {
        const expected={}; entries.filter((entry) => entry.kind===kind).forEach((entry) => { expected[entry.category]=(expected[entry.category]||0)+entry.amount; });
        const actual = await blocks.nth(index).locator('.category-row').evaluateAll((rows) => rows.map((row) => [row.querySelector('span').textContent,Number(row.querySelector('strong').textContent)]));
        assert.deepEqual(actual,Object.entries(expected).sort((a,b) => b[1]-a[1]),kind+' category quantities for '+year);
      }
      await assertPagination(page,'books',entries);
    }
    await click(page,'[data-action="year"][data-year="2026"]');
    for (const kind of ['book','film']) {
      await click(page,'[data-action="filter"][data-filter="'+kind+'"]');
      await assertPagination(page,'books',ARCHIVE.entries.filter((entry) => entry.kind===kind && entry.date.startsWith('2026')));
    }
    await page.evaluate(() => scrollTo({top:0,behavior:'instant'}));
    await page.screenshot({path:path.join(ARTIFACTS,label+'-'+width+'-books.png'),fullPage:false});
    result.checks.push('All data years 1999–2026, 12 monthly buckets, category weighted counts, annual trend totals and book/film filter pagination verified');

    for (const word of ['小说','RAIN & "纸舟"','澳门','日','完全不存在的虚构记录']) {
      await search(page,word);
      await assertPagination(page,'search',expectedSearch(word));
      assert.equal(await page.locator('main 纸舟,main 晨光').count(),0,'title angle brackets must remain text');
    }
    result.checks.push('Global category/title/city/Unicode/empty-result searches and search pagination verified');

    await click(page,'[data-action="tab"][data-tab="travel"]');
    await assertPagination(page,'travel',ARCHIVE.entries.filter((entry) => entry.kind==='place'));
    const visits = {};
    ARCHIVE.entries.filter((entry) => entry.kind==='place').forEach((entry) => {
      const key=entry.province+'|'+entry.city; visits[key]=(visits[key]||0)+1;
    });
    assert.equal(await page.locator('.visit').count(),Object.keys(visits).length);
    for (const [key,count] of Object.entries(visits)) {
      const button = page.locator('.visit').filter({has:page.locator('small',{hasText:key.split('|')[0]})}).filter({has:page.locator('strong',{hasText:key.split('|')[1]})});
      assert.match(await button.innerText(),new RegExp(count+' 次记录'));
    }
    assert.deepEqual(await page.locator('.travel-stats .num').allTextContents(),[String(Object.keys(visits).length),'60']);
    result.checks.push('Place records, distinct city counts, repeated visit counts and paginated travel lists verified including municipalities, Taiwan, Hong Kong and Macao');

    await page.reload({waitUntil:'domcontentloaded'});
    await page.locator('main .hero').waitFor();
    assert.deepEqual((await readStored(page)).entries,firstStored.entries,'reload restores cross-year data exactly');
    assert.equal(await page.evaluate(() => window.__uploads),0);
    assert.deepEqual(errors,[],'no browser runtime exceptions');
    result.checks.push('Refresh restores all records; zero real/mock cloud uploads and zero browser runtime errors');

    // Fresh context: a current year with no records is still selectable and all
    // chart/list states must be empty, while historical data remains available.
    const emptyContext = await browser.newContext({viewport:{width,height:844},isMobile:true,hasTouch:true,timezoneId:timeZone});
    const emptyPage = await emptyContext.newPage();
    emptyPage.on('dialog',(dialog) => dialog.accept());
    await emptyPage.addInitScript(mocks);
    await emptyPage.route(/^https?:/,(route) => route.abort());
    await emptyPage.goto(URL,{waitUntil:'domcontentloaded'});
    await emptyPage.locator('main .hero').waitFor();
    await localPage(emptyPage);
    await importText(emptyPage,JSON.stringify(backup));
    assert.deepEqual((await readStored(emptyPage)).entries,firstStored.entries,'export backup restores exactly in a fresh context');
    await click(emptyPage,'[data-action="clear"]');
    assert.equal((await readStored(emptyPage)).entries.length,0,'explicit local clear empties only this isolated context');
    await importText(emptyPage,JSON.stringify({...ARCHIVE,entries:ARCHIVE.entries.filter((entry) => !entry.date.startsWith('2026'))}));
    await click(emptyPage,'[data-action="tab"][data-tab="books"]');
    assert.equal(await emptyPage.locator('#records-books .record').count(),0);
    assert.equal(await emptyPage.locator('[data-action="load-more"][data-list="books"]').count(),0);
    assert.deepEqual(await emptyPage.locator('.bar-pair').evaluateAll((nodes) => nodes.map((node) => node.title)),Array.from({length:12},(_,month) => (month+1)+'月 阅读0 影视0'));
    assert.equal(await emptyPage.getByText('这一年还没有记录',{exact:true}).count(),2);
    await emptyPage.screenshot({path:path.join(ARTIFACTS,label+'-'+width+'-empty-year.png'),fullPage:false});
    await localPage(emptyPage);
    await click(emptyPage,'[data-action="clear"]');
    await importText(emptyPage,JSON.stringify({...ARCHIVE,entries:ARCHIVE.entries.slice(0,10)}));
    await click(emptyPage,'[data-action="tab"][data-tab="home"]');
    await assertPagination(emptyPage,'home',ARCHIVE.entries.slice(0,10));
    await localPage(emptyPage);
    await importText(emptyPage,JSON.stringify({...ARCHIVE,entries:[ARCHIVE.entries[10]]}));
    await click(emptyPage,'[data-action="tab"][data-tab="home"]');
    await assertPagination(emptyPage,'home',ARCHIVE.entries.slice(0,11));
    await emptyContext.close();
    result.checks.push('Fresh-context backup restore; empty current year; exact 10 records hide more, 11 records load 10 then 1');
    result.status='PASS';
  } catch (error) {
    result.status='FAIL'; result.error=error.stack;
    await page.screenshot({path:path.join(ARTIFACTS,label+'-'+width+'-failure.png'),fullPage:true}).catch(() => {});
    throw error;
  } finally {
    result.durationMs=Date.now()-started; report.runs.push(result); await context.close();
  }
}
async function main() {
  fs.mkdirSync(ARTIFACTS,{recursive:true});
  const variants = process.env.GUITU_FINAL_ENGINES==='chromium' ? [['chromium',chromium]] : [['chromium',chromium],['webkit',webkit]];
  try {
    for (const [label,engine] of variants) {
      const browser = await engine.launch(label==='chromium' ? {headless:true,executablePath:process.env.GUITU_CHROMIUM_EXECUTABLE || undefined,args:['--no-sandbox']} : {headless:true});
      try {
        await run(browser,label,390,'Asia/Shanghai');
        await run(browser,label,320,'America/Los_Angeles');
      } finally { await browser.close(); }
    }
    console.log('PASS: varied 200-record archive, cross-year statistics, sorting, filters, pagination, safe imports, backup and refresh; Chromium/WebKit, two mobile widths and time zones.');
  } finally { fs.writeFileSync(path.join(ARTIFACTS,'report.json'),JSON.stringify(report,null,2)+'\n'); }
}
main().catch((error) => { console.error(error); process.exitCode=1; });
