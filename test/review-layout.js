// Targeted regressions for the three issues in the official 2026-10-16 feedback.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const {chromium,webkit} = require('playwright');
const fixture = require('./fictional-archive.json');
const html = fs.readFileSync(process.env.GUITU_TEST_HTML || path.resolve(__dirname,'../dist/guitu-tieba-0.2.2.html'));
const out = process.env.GUITU_REVIEW_ARTIFACTS || path.resolve(__dirname,'../test-artifacts/review-2026-10-16');
fs.mkdirSync(out,{recursive:true});
const results = [];
const rect = (locator) => locator.evaluate(e => {const r=e.getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height,right:r.right,bottom:r.bottom};});
async function swipe(page,x,y,endY,engine) {
  if(engine === 'chromium') {
    await page.mouse.move(x,y);
    await page.mouse.wheel(0,y-endY);
  }
  await page.evaluate(({x,y,endY})=>{
    const target=document.elementFromPoint(x,y);
    const event=new Event('touchmove',{bubbles:true,cancelable:true});
    Object.defineProperty(event,'touches',{value:[{clientX:x,clientY:endY}]});
    target.dispatchEvent(event);
  },{x,y,endY});
}
async function check(browser,engine,size,origin) {
  const context=await browser.newContext({viewport:size,isMobile:true,hasTouch:true,locale:'zh-CN'});
  const p=await context.newPage();
  const errors=[];p.on('pageerror',e=>errors.push(e.message));
  await p.addInitScript(({fixture})=>{
    localStorage.setItem('guitu-v022:review-layout',JSON.stringify({snapshot:fixture,dirty:true}));
    window.tieba={getUserInfo:()=>({user_id:'review-layout'}),downloadData:async()=>({}),uploadData:async()=>{throw Error('Unexpected upload');}};
  },{fixture});
  await p.goto(origin,{waitUntil:'load'});
  await p.locator('.brand').waitFor();
  const header = await rect(p.locator('.brand'));
  const theme = await rect(p.locator('[data-action="theme"]'));
  assert.ok(header.y>=92 && theme.y>=92,engine+' header overlaps system/capsule area');
  // A larger system inset must reserve extra room, including in a modal.
  await p.evaluate(()=>document.documentElement.style.setProperty('--system-safe-top','64px'));
  assert.ok((await rect(p.locator('.brand'))).y>=112);
  await p.evaluate(()=>document.documentElement.style.removeProperty('--system-safe-top'));
  await p.evaluate(()=>window.scrollTo({top:480,behavior:'instant'}));
  const y=await p.evaluate(()=>window.scrollY);
  assert.ok(y>100);
  const beforeMain=await rect(p.locator('main'));
  const beforeHeader=await rect(p.locator('.topbar'));
  await p.locator('.nav [data-action="add"]').click();
  assert.equal(await p.evaluate(()=>getComputedStyle(document.body).position),'fixed');
  assert.equal(await p.evaluate(()=>document.body.style.top),-y+'px');
  await swipe(p,8,140,60,engine);
  assert.equal(await p.evaluate(()=>document.body.style.top),-y+'px');
  const lockedMain=await rect(p.locator('main'));
  assert.ok(Math.abs(beforeHeader.y-(await rect(p.locator('.topbar'))).y)<2,'sticky header moved when locking');
  assert.ok(Math.abs(beforeMain.y-lockedMain.y)<2,'background shifted when opening');
  await p.locator('[data-kind="book"]').click();
  assert.equal(await p.evaluate(()=>document.body.style.top),-y+'px','modal transition lost scroll');
  await p.locator('#f-date').fill('2026-10-14');
  const date=await rect(p.locator('#f-date')),amount=await rect(p.locator('#f-amount'));
  const form=await rect(p.locator('#entry-form'));
  assert.ok(Math.abs(date.width-amount.width)<2,'date and amount columns differ');
  assert.ok(Math.abs(date.y-amount.y)<2 && Math.abs(date.height-amount.height)<2,engine+' '+size.width+' fields do not align: '+JSON.stringify({date,amount}));
  assert.ok(date.x>=form.x && amount.right<=form.right+1,'form overflows');
  assert.equal(await p.locator('.modal').evaluate(e=>e.scrollWidth<=e.clientWidth),true);
  const modal=await rect(p.locator('.modal'));
  assert.ok(modal.y>=104-1 && modal.bottom<=size.height+1,'modal crosses top safe area');
  // Scroll a long modal to its end, then try to continue the gesture.
  await p.locator('.modal').evaluate(e=>{e.scrollTop=e.scrollHeight;});
  await swipe(p,Math.round(size.width/2),Math.round(size.height-70),Math.round(size.height-150),engine);
  assert.equal(await p.evaluate(()=>document.body.style.top),-y+'px');
  // Keyboard-sized viewport keeps the dialog scrollable and controls reachable.
  await p.setViewportSize({width:size.width,height:360});
  await p.locator('.modal').evaluate(e=>{e.scrollTop=e.scrollHeight;});
  const submit=await rect(p.locator('#entry-form [type="submit"]'));
  assert.ok(submit.bottom<=360+1 && submit.y>=104,'submit unreachable with small viewport');
  await p.setViewportSize(size);
  await p.locator('.modal').evaluate(e=>{e.scrollTop=0;});
  await p.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
  if(size.width===390 || size.width===320) {
    await p.screenshot({path:path.join(out,`${engine}-${size.width}-form.png`)});
  }
  await p.locator('[data-action="close"]').click();
  assert.equal(await p.evaluate(()=>document.documentElement.classList.contains('modal-open')),false);
  assert.ok(Math.abs(await p.evaluate(()=>window.scrollY)-y)<2,'close did not restore page position');
  await p.evaluate(()=>window.scrollTo({top:0,behavior:'instant'}));
  await p.locator('.nav [data-action="add"]').click();
  await p.locator('[data-kind="film"]').click();
  assert.ok(Math.abs((await rect(p.locator('#f-date'))).width-(await rect(p.locator('#f-amount'))).width)<2);
  await p.locator('#f-title').fill('审核布局测试影视');
  await p.locator('#entry-form [type="submit"]').click();
  assert.equal(await p.locator('.modal-wrap').count(),0);
  assert.equal(await p.evaluate(()=>document.body.style.top),'');
  assert.equal(await p.evaluate(()=>getComputedStyle(document.body).position),'static');
  await p.locator('.nav [data-action="add"]').click();
  await p.locator('[data-kind="place"]').click();
  assert.ok(Math.abs((await rect(p.locator('#f-date'))).width-(await rect(p.locator('#f-rating'))).width)<2);
  // Backdrop close also releases the lock.
  await p.locator('.modal-wrap').click({position:{x:2,y:2}});
  assert.equal(await p.locator('.modal-wrap').count(),0);
  await p.locator('[data-action="theme"]').click();
  if(size.width===390) {
    await p.screenshot({path:path.join(out,`${engine}-${size.width}-home-dark.png`)});
    await p.locator('[data-action="theme"]').click();
    await p.screenshot({path:path.join(out,`${engine}-${size.width}-home.png`)});
  }
  assert.deepEqual(errors,[]);
  results.push({engine,...size,top:header.y,dateWidth:date.width,amountWidth:amount.width,scrollRestored:y,status:'passed'});
  await context.close();
}
(async()=>{
  const server=http.createServer((req,res)=>{res.setHeader('Content-Type','text/html; charset=utf-8');res.end(html);});
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  try {
    for(const [engine,type] of [['chromium',chromium],['webkit',webkit]]) {
      const b=await type.launch({headless:true,...(engine==='chromium'?{executablePath:process.env.GUITU_CHROMIUM_EXECUTABLE || undefined}:{})});
      try {for(const size of [{width:320,height:568},{width:375,height:667},{width:390,height:844},{width:414,height:896},{width:430,height:932},{width:768,height:1024},{width:844,height:390}]) await check(b,engine,size,`http://127.0.0.1:${server.address().port}`);}
      finally {await b.close();}
    }
    fs.writeFileSync(path.join(out,'results.json'),JSON.stringify(results,null,2)+'\n');
    console.log('PASS: official feedback regressions, Chromium + WebKit, 14 viewport cases');
  } finally {server.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
