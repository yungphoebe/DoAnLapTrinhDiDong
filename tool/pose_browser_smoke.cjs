// Automated camera smoke test. Uses Chrome fake media; never opens a physical camera.
const {createServer} = require('node:http');
const {readFile} = require('node:fs/promises');
const path = require('node:path');
const assert = require('node:assert/strict');
const {chromium} = require(path.join(process.env.TEMP,'aigym-browser-test/node_modules/playwright-core'));
const root=path.resolve(__dirname,'../web');
const types={'.mjs':'text/javascript','.js':'text/javascript','.wasm':'application/wasm','.html':'text/html'};
const server=createServer(async(req,res)=>{
  const file=path.resolve(root,'.'+new URL(req.url,'http://localhost').pathname);
  if(!file.startsWith(root+path.sep)){res.writeHead(403).end();return;}
  try{res.setHeader('Content-Type',types[path.extname(file)]??'application/octet-stream');res.end(await readFile(file));}
  catch{res.writeHead(404).end();}
});
(async()=>{
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,
    args:['--use-fake-device-for-media-stream','--use-fake-ui-for-media-stream']});
  try{
    const page=await browser.newPage();
    const errors=[];
    page.on('pageerror',e=>errors.push(String(e)));
    page.on('console',m=>{if(m.type()==='error')console.log('browser:',m.text());});
    await page.goto(`http://127.0.0.1:${server.address().port}/pose_camera.html`);
    await page.locator('#start').click();
    try{await page.waitForFunction(()=>document.querySelector('#status').textContent==='Đang theo dõi chuyển động.' || document.querySelector('#status').textContent.startsWith('Không mở'),{},{timeout:60000});}
    catch(error){console.log('STATUS',await page.locator('#status').textContent());throw error;}
    assert.equal(await page.locator('#status').textContent(),'Đang theo dõi chuyển động.');
    await page.waitForFunction(()=>document.querySelector('#feedback').textContent.includes('khớp'),{},{timeout:20000});
    assert.equal(await page.locator('#reps').textContent(),'0');
    await page.locator('#pause').click();
    assert.match(await page.locator('#status').textContent(),/tạm dừng/);
    await page.locator('#start').click();
    await page.locator('#finish').click();
    assert.equal(await page.locator('#video').evaluate(v=>v.srcObject),null);
    assert.equal(errors.length,0,errors.join('\n'));
    console.log('PASS: local model worker initialized, fake frames inferred, no fake reps, pause/resume/finish releases camera.');
  }finally{await browser.close();server.close();}
})().catch(error=>{console.error(error);server.close();process.exitCode=1;});
