
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const sharp=require('C:/Users/24586/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root="D:\\AAA找到工作\\素材们\\项目3-中国传统制茶技艺数字展示策略研究\\茶园物语-制作素材",dest=path.join(root,'10_最终交付/茶园物语_素材交付_v001'),m=JSON.parse(fs.readFileSync(path.join(root,'00_规范与清单/library_manifest_v010.json'),'utf8')),all=[...m.sampleAssets,...m.generatedAssets];
if(fs.existsSync(dest))throw Error('Delivery folder already exists');
fs.mkdirSync(dest,{recursive:true});
const copied=new Set();
function copy(rel){const src=path.join(root,rel),to=path.join(dest,rel);if(!fs.existsSync(src))throw Error('Missing '+rel);fs.mkdirSync(path.dirname(to),{recursive:true});fs.copyFileSync(src,to);copied.add(rel.replaceAll('\\','/'));}
function walk(dir,prefix=''){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>{const r=prefix?prefix+'/'+e.name:e.name;return e.isDirectory()?walk(path.join(dir,e.name),r):[r];});}
(async()=>{
const hashes=[],errors=[];
for(const a of all){copy(a.relativePath);const src=path.join(root,a.relativePath),to=path.join(dest,a.relativePath),hash=b=>crypto.createHash('sha256').update(b).digest('hex'),meta=await sharp(to).metadata();const sourceHash=hash(fs.readFileSync(src)),packageHash=hash(fs.readFileSync(to));if(sourceHash!==packageHash)errors.push(a.id+':copy hash');if(!meta.hasAlpha||meta.width!==a.width||meta.height!==a.height)errors.push(a.id+':metadata');hashes.push({id:a.id,file:a.relativePath,width:meta.width,height:meta.height,hasAlpha:meta.hasAlpha,sha256:packageHash,bytes:fs.statSync(to).size});}
let html=fs.readFileSync(path.join(root,'素材库预览_v010.html'),'utf8');
const links=[...html.matchAll(/href="([^"]+)"/g)].map(x=>x[1]).filter(x=>!x.includes('://')&&!x.startsWith('#'));
for(const rel of links){if(rel.endsWith('.html')&&!rel.startsWith('08_预览/终版背景场景UI'))continue;copy(rel);}
for(const rel of walk(path.join(root,'08_预览/终版背景场景UI')))copy('08_预览/终版背景场景UI/'+rel);
for(const rel of walk(path.join(root,'09_生成记录/终版背景场景UI补充')).filter(x=>x.endsWith('.json')))copy('09_生成记录/终版背景场景UI补充/'+rel);
for(const rel of ['00_规范与清单/library_manifest_v010.json','00_规范与清单/素材制作清单_v010.csv','00_规范与清单/制作规范_v001.txt','00_规范与清单/UI组件位置与对位参考_v001.json','00_规范与清单/人物脚底锚点与身份参考_v001.json','00_规范与清单/茶树状态位置参考_v002.json','00_规范与清单/终版补充素材分层与锚点参考_v001.json','00_规范与清单/页面组合摆放参考_v001.json','09_生成记录/batch08_prompts_v001.json','09_生成记录/batch08_alpha_check_v001.json'])copy(rel);
fs.writeFileSync(path.join(dest,'素材库预览.html'),html);
const totals=Object.fromEntries([...new Set(all.map(a=>a.category||a.relativePath.split('/')[0]))].map(c=>[c,all.filter(a=>(a.category||a.relativePath.split('/')[0])===c).length]));
const guide=[
'茶园物语 · 当前素材交付 v001','日期：2026-10-08','',
'一、从这里查看','打开“素材库预览.html”可筛选118项独立素材并点击原图。','打开“08_预览/终版背景场景UI/终版页面预览.html”可切换7个页面。','“00_补充12项素材总览_v001.png”展示本批新增素材；“01_七个页面组合总览_v001.png”展示搭配效果。','',
'二、交付范围','共118项当前独立透明PNG，包括本批12项：3张背景画层、5个场景分件、4个UI控件和图标。','种植状态、人物、器具、茶铺道具和既有UI已一并收录。','6项制茶手记插画按用户要求保留待制作，不在本次范围。','旧6个PNG修订版本保留在原素材库，此交付包只收录当前版本。','',
'三、后续导入使用','正式PNG保持image_gen的原始RGBA尺寸，没有裁切、重采样、抠图或软件重绘。','以制作清单_v010.csv中的实际尺寸与路径为准；目标尺寸是生成意图。','建筑、植物、人物、器具、UI底板、图标均独立；文字、数字、品质名称另行渲染。','标题山水BG_201作为满幅背景画层，山体左右延伸至画布边缘；其余新分件保留透明边距。','对位参考JSON内的锚点为近似值，后续在引擎中调整屋檐、家具、遮挡和点击区域。','UI素材带透明边距，使用前参考UI位置说明；缩放大面板可采用安全区与9-slice。','人物与火焰均为静态素材，不是完整动作动画。','',
'四、预览说明','7个页面是浏览器静态素材摆放，不包含Godot工程或交互逻辑。','预览中的标签、数值和提示仅用于设计审阅，不烘焙到正式素材。','素材的画风为国风水墨淡彩，米白、灰绿、竹褐与黛灰；所有本批位图由built-in image_gen生成。','',
'分类数量：',...Object.entries(totals).map(([k,v])=>k+'：'+v+'项'),'',
'文件完整性：交付校验_v001.json记录118项PNG的尺寸、透明通道和SHA-256。'
].join('\r\n');
fs.writeFileSync(path.join(dest,'使用说明.txt'),'\uFEFF'+guide);
const report={date:'2026-10-08',packageRoot:dest,scope:'只补背景、场景和UI；6项手记插画保留待制作',mode:'built-in image_gen',assets:all.length,uniqueIds:new Set(all.map(x=>x.id)).size,newAssets:12,categories:totals,pendingHandbookItems:6,allCopiesByteIdentical:!errors.length,allPNGsHaveAlpha:hashes.every(x=>x.hasAlpha),godotBuilt:false,errors,files:hashes};
report.pass=report.assets===118&&report.uniqueIds===118&&!errors.length;
fs.writeFileSync(path.join(dest,'交付校验_v001.json'),JSON.stringify(report,null,2));
fs.writeFileSync(path.join(root,'09_生成记录/batch08_delivery_check_v001.json'),JSON.stringify(report,null,2));
console.log(JSON.stringify({dest,pass:report.pass,assets:all.length,copyErrors:errors,categories:totals,totalCopiedFiles:copied.size,assetMB:(hashes.reduce((a,b)=>a+b.bytes,0)/1048576).toFixed(1)}));
if(!report.pass)process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1});
