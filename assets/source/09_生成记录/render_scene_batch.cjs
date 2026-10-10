
const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url');
const sharp=require('C:/Users/24586/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const {chromium}=require('C:/Users/24586/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root="D:\\AAA找到工作\\素材们\\项目3-中国传统制茶技艺数字展示策略研究\\茶园物语-制作素材";
const read=p=>JSON.parse(fs.readFileSync(path.join(root,p),'utf8').replace(/^\uFEFF/,''));
const qa=read('09_生成记录/batch06_alpha_check_v001.json'),records=read('09_生成记录/batch06_prompts_v001.json').assets,m=read('00_规范与清单/library_manifest_v008.json');
const plan=m.plan.filter(p=>p.batch==='06_场景与装饰');
const map=new Map([...m.sampleAssets,...m.generatedAssets].map(a=>[a.id,a]));
const added=plan.map(p=>{
 const a=qa.assets.find(a=>a.id===p.id);
 const kind=p.id.startsWith('BG_')?'山水透明层':p.id==='BLD_105'||p.id==='BLD_106'?'空建筑结构壳':p.id.startsWith('BLD_')?'地图建筑单体':p.id.startsWith('PLT_')?'独立景观植物':'独立装饰单体';
 return {id:p.id,name:p.plannedFile.replace(/\.png$/,''),label:p.label,category:p.category,batch:p.batch,relativePath:a.file,status:'已生成v001',width:a.width,height:a.height,alphaCheck:a.alphaCheck,visibleBBoxAlpha16:a.visibleBBoxAlpha16,solidBBoxAlpha128:a.solidBBoxAlpha128,approxAnchor:a.approxAnchor,anchorMeaning:a.anchorMeaning,sha256:a.sha256,assetKind:kind,positionReference:'00_规范与清单/场景素材分层与锚点参考_v001.json',reviewNotes:'独立透明PNG，按既有素材统一笔触与低饱和配色；保留原始alpha。建筑壳为空结构，独立屋顶与前遮挡另补。仅静态摆放预览，尚未进入Godot。'};
});
for(const a of added)map.set(a.id,a);
const outdir=path.join(root,'08_预览/第06批_场景与装饰');fs.mkdirSync(outdir,{recursive:true});
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;');
const src=a=>'../../'+a.relativePath;
function visual(a,w,h){
 const b=a.visibleBBoxAlpha16,bw=b[2]-b[0]+1,bh=b[3]-b[1]+1,s=Math.min((w-24)/bw,(h-24)/bh);
 return '<span class="visual" style="width:'+bw*s+'px;height:'+bh*s+'px"><img src="'+esc(src(a))+'" alt="'+esc(a.label)+'" style="width:'+a.width*s+'px;height:'+a.height*s+'px;left:'+(-b[0]*s)+'px;top:'+(-b[1]*s)+'px"></span>';
}
const css='*{box-sizing:border-box}body{margin:0;background:#f5f2e9;color:#43564a;font-family:"Microsoft YaHei",sans-serif}main{width:1920px;padding:48px 64px}header{border-bottom:1px solid #b8c2a6;padding-bottom:22px;margin-bottom:25px}.eye{font-size:18px;letter-spacing:4px;color:#80907d}h1{font-family:SimSun,serif;font-weight:500;font-size:43px;letter-spacing:4px;margin:18px 0 13px}header p{font-size:18px;margin:0;color:#7b8676;line-height:1.8}h2{font-family:SimSun,serif;font-size:27px;font-weight:500;margin:26px 0 15px;letter-spacing:2px}.grid{display:grid;gap:18px}.c3{grid-template-columns:repeat(3,1fr)}.c5{grid-template-columns:repeat(5,1fr)}.c4{grid-template-columns:repeat(4,1fr)}.card{border:1px solid #d4dbc8;border-radius:5px;overflow:hidden;background:#faf9f1}.stage{display:flex;align-items:center;justify-content:center;background-color:#eff1e9;background-image:linear-gradient(45deg,#e3e8dd 25%,transparent 25%),linear-gradient(-45deg,#e3e8dd 25%,transparent 25%),linear-gradient(45deg,transparent 75%,#e3e8dd 75%),linear-gradient(-45deg,transparent 75%,#e3e8dd 75%);background-size:24px 24px;background-position:0 0,0 12px,12px -12px,-12px 0;overflow:hidden}.visual{position:relative;display:block;overflow:hidden;flex:none}.visual img{position:absolute;max-width:none}.meta{padding:13px 17px 15px}.tag{font-size:13px;color:#83957e}.meta h3{font-size:19px;font-weight:500;margin:6px 0}.meta p{font-size:14px;color:#7e8b79;margin:0;line-height:1.65}.hint{background:#e9ede0;padding:16px 20px;border-left:3px solid #91a183;font-size:16px;line-height:1.85;color:#718169;margin:22px 0 0}footer{font-size:15px;color:#7f8d79;line-height:1.8;border-top:1px solid #d5dbc8;margin-top:25px;padding-top:20px}.pair{display:flex}.pair .stage{background-image:none}.light{background:#f4f0e6}.dark{background:#34443e}.labelbar{display:flex;justify-content:space-around;padding:8px;font-size:13px;color:#7f8d77}.compose{position:relative;overflow:hidden;background:#eeeede;height:640px}.sprite{position:absolute;max-width:none;pointer-events:none}.compose.mapscene{height:660px;background:linear-gradient(#f1f0e6,#eff0e4)}.compose.small{height:580px}.two{display:grid;grid-template-columns:repeat(2,1fr);gap:24px}.compose-caption{padding:16px 22px;color:#71816c;font-size:17px;line-height:1.7}.panel{border:1px solid #d2dbc4;background:#faf9f1;overflow:hidden;border-radius:5px}';
const wrap=(title,desc,body)=>'<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>'+title+'</title><style>'+css+'</style><main><header><div class="eye">茶园物语 · 国风水墨淡彩素材库</div><h1>'+title+'</h1><p>'+desc+'</p></header>'+body+'<footer>棋盘格与浅深底仅用于预览；每项正式PNG保留真实透明背景及原始尺寸。仅素材生产，未搭建Godot。</footer></main></html>';
const card=(a,w,h)=>'<article class="card"><div class="stage" style="height:'+h+'px">'+visual(a,w,h)+'</div><div class="meta"><div class="tag">'+a.id+' · '+a.assetKind+'</div><h3>'+a.label+'</h3><p>'+a.width+' × '+a.height+' · 独立透明 PNG</p></div></article>';
const layers=added.filter(a=>a.id.startsWith('BG_')),buildings=added.filter(a=>a.id.startsWith('BLD_')),decor=added.filter(a=>!a.id.startsWith('BG_')&&!a.id.startsWith('BLD_'));
const overview='<h2>山水分层 · 3项</h2><div class="grid c3">'+layers.map(a=>card(a,580,200)).join('')+'</div><h2>建筑与空场景壳 · 6项</h2><div class="grid c3">'+buildings.map(a=>card(a,580,310)).join('')+'</div><h2>装饰与景观植物 · 5项</h2><div class="grid c5">'+decor.map(a=>card(a,338,300)).join('')+'</div><div class="hint">山、水、云各自独立；建筑外观用于主地图，空场景壳供家具与人物另层摆放。植物不带土地、岩石或花盆。</div>';
fs.writeFileSync(path.join(outdir,'00_第06批素材总览_v001.html'),wrap('场景与装饰 · 14项总览','3项山水层 + 6项建筑与空场景壳 + 5项装饰植物',overview),'utf8');
const edge='<div class="grid c4">'+added.map(a=>'<article class="card"><div class="pair"><div class="stage light" style="width:214px;height:240px">'+visual(a,210,230)+'</div><div class="stage dark" style="width:214px;height:240px">'+visual(a,210,230)+'</div></div><div class="labelbar"><span>米白底</span><span>黛绿底</span></div><div class="meta"><div class="tag">'+a.id+'</div><h3>'+a.label+'</h3></div></article>').join('')+'</div>';
fs.writeFileSync(path.join(outdir,'02_浅深底透明检查_v001.html'),wrap('透明边缘 · 浅深底对照','14项均已通过透明通道与边缘裁切检查；这张图片用于观察轮廓在不同底色上的表现。',edge),'utf8');
async function need(id){
 const a=map.get(id);if(!a)throw Error('Missing '+id);
 if(!a.visibleBBoxAlpha16){
  const {data,info}=await sharp(path.join(root,a.relativePath)).ensureAlpha().raw().toBuffer({resolveWithObject:true});const b=[info.width,info.height,-1,-1];
  for(let y=0;y<info.height;y++)for(let x=0;x<info.width;x++)if(data[(y*info.width+x)*info.channels+info.channels-1]>=16){b[0]=Math.min(b[0],x);b[1]=Math.min(b[1],y);b[2]=Math.max(b[2],x);b[3]=Math.max(b[3],y);}
  a.visibleBBoxAlpha16=b;
 }return a;
}
async function bottom(id,x,y,visualWidth,z=1){
 const a=await need(id),b=a.visibleBBoxAlpha16,s=visualWidth/(b[2]-b[0]+1),anchor=a.approxAnchor||a.footApproxAnchor||[(b[0]+b[2])/2,b[3]];
 return '<img class="sprite" alt="'+esc(a.label)+'" src="'+esc(src(a))+'" style="width:'+a.width*s+'px;height:'+a.height*s+'px;left:'+(x-anchor[0]*s)+'px;top:'+(y-anchor[1]*s)+'px;z-index:'+z+'">';
}
async function center(id,x,y,visualWidth,z=1){
 const a=await need(id),b=a.visibleBBoxAlpha16,s=visualWidth/(b[2]-b[0]+1);
 return '<img class="sprite" alt="'+esc(a.label)+'" src="'+esc(src(a))+'" style="width:'+a.width*s+'px;height:'+a.height*s+'px;left:'+(x-(b[0]+b[2])*0.5*s)+'px;top:'+(y-(b[1]+b[3])*0.5*s)+'px;z-index:'+z+'">';
}
(async()=>{
let mapbody='';
mapbody+=await center('BG_101',880,170,1460,1);
mapbody+=await center('BG_102',1190,456,1020,2);
mapbody+=await center('BG_103',910,237,1090,3);
mapbody+=await bottom('TER_102',661,497,470,4);
mapbody+=await bottom('BLD_103',942,432,205,6);
mapbody+=await bottom('PLT_107',689,445,117,7);
mapbody+=await bottom('BLD_101',430,547,320,8);
mapbody+=await bottom('PLT_106',157,580,146,9);
mapbody+=await bottom('BLD_104',1108,591,285,10);
mapbody+=await bottom('BLD_102',1436,570,340,11);
mapbody+=await bottom('DEC_103',1581,610,117,12);
mapbody+=await bottom('DEC_102',612,581,194,13);
let workshop='';
workshop+=await bottom('BLD_105',437,536,815,1);
workshop+=await bottom('PRP_207',401,281,108,2);
workshop+=await bottom('CHR_004',476,401,91,3);
workshop+=await bottom('PRP_205',269,412,202,4);
workshop+=await center('PRP_201',249,324,95,5);
workshop+=await bottom('PRP_204',573,394,107,6);
workshop+=await center('PRP_203',579,316,109,7);
workshop+=await bottom('PRP_210',365,463,62,8);
let tea='';
const teaScale=730/815;
const teaBottom=(id,x,y,w,z)=>bottom(id,437+(x-437)*teaScale,536+(y-536)*teaScale,w*teaScale,z);
const teaCenter=(id,x,y,w,z)=>center(id,437+(x-437)*teaScale,536+(y-536)*teaScale,w*teaScale,z);
tea+=await teaBottom('BLD_106',437,536,815,1);
tea+=await teaBottom('PRP_307',624,285,119,2);
tea+=await teaBottom('CHR_102',539,350,82,3);
tea+=await teaBottom('PRP_306',501,385,243,4);
tea+=await teaBottom('PRP_305',178,366,74,5);
tea+=await teaBottom('CHR_202',244,396,78,6);
tea+=await teaBottom('PRP_304',313,430,184,7);
tea+=await teaCenter('PRP_301',309,328,39,8);
tea+=await teaCenter('PRP_302',351,344,23,9);
const combined='<h2>山水与主地图建筑 · 分层摆放示意</h2><div class="panel"><div class="compose mapscene">'+mapbody+'</div><div class="compose-caption">远山 → 水面 → 云纹 → 道路 → 建筑与景观植物。此处使用既有道路作视角参照，素材均可单独移动。</div></div><h2>空场景壳 + 既有道具与人物</h2><div class="two"><div class="panel"><div class="compose small">'+workshop+'</div><div class="compose-caption">制茶工坊 · 茶台、竹匾、炉台、炒锅、晾架与人物分别叠放。</div></div><div class="panel"><div class="compose small">'+tea+'</div><div class="compose-caption">临水茶铺 · 柜台、茶柜、桌椅、茶具与人物分别叠放。</div></div></div><div class="hint">这是静态素材组合预览。屋顶与前遮挡后续另补；人物姿态与器具的接触位置、遮挡顺序仍需在Godot中调整。</div>';
fs.writeFileSync(path.join(outdir,'01_场景分层组合预览_v001.html'),wrap('场景素材 · 分层组合预览','本批建筑、山水和装饰与既有素材的笔触、配色及轴测方向对照。',combined),'utf8');
fs.writeFileSync(path.join(root,'09_生成记录/batch06_preview_data_v001.json'),JSON.stringify({added,previewOnlyReferences:['TER_102','PRP_207','CHR_004','PRP_205','PRP_201','PRP_204','PRP_203','PRP_210','PRP_307','CHR_102','PRP_306','PRP_305','CHR_202','PRP_304','PRP_301','PRP_302']},null,2)+'\n','utf8');
 const browser=await chromium.launch({headless:true,timeout:15000,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',args:['--allow-file-access-from-files']});
 const page=await browser.newPage({viewport:{width:1920,height:1080},deviceScaleFactor:1});page.setDefaultTimeout(15000);
 const errors=[];page.on('pageerror',e=>errors.push(String(e)));const checks=[];
 for(const name of ['00_第06批素材总览_v001','01_场景分层组合预览_v001','02_浅深底透明检查_v001']){
  await page.goto(pathToFileURL(path.join(outdir,name+'.html')).href);
  await page.waitForFunction(()=>[...document.images].every(x=>x.complete&&x.naturalWidth>0),{},{timeout:20000});
  const check=await page.evaluate(()=>({images:document.images.length,overflow:document.documentElement.scrollWidth>innerWidth,missingImages:[...document.images].filter(x=>!x.naturalWidth).map(x=>x.src)}));
  checks.push({name,...check});await page.screenshot({path:path.join(outdir,name+'.png'),fullPage:true});
 }
 await browser.close();
 const result={checks,errors,pass:checks.every(x=>!x.overflow&&!x.missingImages.length)&&!errors.length};
 fs.writeFileSync(path.join(root,'09_生成记录/batch06_contact_preview_check_v001.json'),JSON.stringify(result,null,2)+'\n','utf8');
 console.log(JSON.stringify(result));if(!result.pass)process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1});
