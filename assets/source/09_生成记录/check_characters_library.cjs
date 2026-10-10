
const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url');
const {chromium}=require('C:/Users/24586/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root="D:\\AAA找到工作\\素材们\\项目3-中国传统制茶技艺数字展示策略研究\\茶园物语-制作素材";
(async()=>{
 const browser=await chromium.launch({headless:true,timeout:15000,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',args:['--allow-file-access-from-files']});
 const page=await browser.newPage({viewport:{width:1920,height:1080},deviceScaleFactor:1});
 page.setDefaultTimeout(15000);
 const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 await page.goto(pathToFileURL(path.join(root,'素材库预览.html')).href);
 const loaded=()=>page.waitForFunction(()=>[...document.querySelectorAll('#gallery img')].every(x=>x.complete&&x.naturalWidth>0),{},{timeout:25000});
 await loaded();
 const snapshots=[];
 const snapshot=async(label,expected)=>{
  await loaded();
  const v=await page.evaluate(()=>({count:document.querySelectorAll('#gallery [data-id]').length,text:document.getElementById('count').textContent,overflow:document.documentElement.scrollWidth>innerWidth,imageFailures:[...document.querySelectorAll('#gallery img')].filter(x=>!x.complete||!x.naturalWidth).map(x=>x.src)}));
  snapshots.push({label,expected,...v,pass:v.count===expected&&!v.overflow&&!v.imageFailures.length});
 };
 await snapshot('全部素材',92);
 await page.locator('[data-batch="05_人物与茶铺"]').click();
 await snapshot('人物批筛选',12);
 await page.screenshot({path:path.join(root,'08_预览/人物批_12项/02_素材库人物筛选_v008.png'),fullPage:true});
 await page.locator('[data-batch="05_茶铺素材"]').click();await snapshot('茶铺批筛选',10);
 await page.locator('[data-batch="04_工坊素材"]').click();await snapshot('工坊批筛选',14);
 await page.locator('[data-batch=""]').click();
 await page.locator('#search').fill('主角');await snapshot('搜索主角',5);
 await page.locator('#search').fill('旅人');await snapshot('搜索旅人',2);
 await page.locator('#search').fill('不存在的编号');await snapshot('空搜索状态',0);
 const links=await page.locator('.links a').evaluateAll(xs=>xs.map(x=>({label:x.textContent,href:x.getAttribute('href')})));
 const missingLinks=links.filter(l=>!fs.existsSync(path.join(root,l.href)));
 const result={date:'2026-10-08',galleryVersion:'v008',snapshots,linkCount:links.length,missingLinks,errors,pass:snapshots.every(v=>v.pass)&&!missingLinks.length&&!errors.length};
 fs.writeFileSync(path.join(root,'09_生成记录/characters_batch_library_check_v001.json'),JSON.stringify(result,null,2)+'\n','utf8');
 console.log(JSON.stringify(result));
 await browser.close();
 if(!result.pass)process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1});
