
const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url');
const sharp=require('C:/Users/24586/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const {chromium}=require('C:/Users/24586/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root="D:\\AAA找到工作\\素材们\\项目3-中国传统制茶技艺数字展示策略研究\\茶园物语-制作素材",out=path.join(root,'08_预览/第09批_完整背景主页与存档UI');
fs.mkdirSync(out,{recursive:true});
const m=JSON.parse(fs.readFileSync(path.join(root,'00_规范与清单/library_manifest_v011.json'),'utf8')),all=[...m.sampleAssets,...m.generatedAssets],map=new Map(all.map(a=>[a.id,a]));
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;');
const placements={};
(async()=>{
for(const a of all)if(!a.visibleBBoxAlpha16){const {data,info}=await sharp(path.join(root,a.relativePath)).ensureAlpha().raw().toBuffer({resolveWithObject:true});let b=[info.width,info.height,-1,-1];for(let y=0;y<info.height;y++)for(let x=0;x<info.width;x++)if(data[(y*info.width+x)*info.channels+info.channels-1]>=16){b[0]=Math.min(b[0],x);b[1]=Math.min(b[1],y);b[2]=Math.max(b[2],x);b[3]=Math.max(b[3],y);}a.visibleBBoxAlpha16=b;}
let pageKey='';function art(id,x,y,w,h,z=1){const a=map.get(id);if(!a)throw Error(id);const b=a.visibleBBoxAlpha16,bw=b[2]-b[0]+1,bh=b[3]-b[1]+1;if(h===undefined)h=w*bh/bw;const sx=w/bw,sy=h/bh;if(pageKey)(placements[pageKey]??=[]).push({id,visibleTopLeft:[x,y],visibleDisplaySize:[w,h],z});return '<div class="art" data-id="'+id+'" style="left:'+x+'px;top:'+y+'px;width:'+w+'px;height:'+h+'px;z-index:'+z+'"><img src="../../'+esc(a.relativePath)+'" alt="'+esc(a.label||a.name)+'" style="width:'+a.width*sx+'px;height:'+a.height*sy+'px;left:'+(-b[0]*sx)+'px;top:'+(-b[1]*sy)+'px"></div>';}
function txt(s,x,y,size=26,cls='',z=40){return '<div class="text '+cls+'" style="left:'+x+'px;top:'+y+'px;font-size:'+size+'px;z-index:'+z+'">'+s+'</div>';}
function toolbar(items){let result=art('UI_005',527,927,870,96,30);items.forEach((t,i)=>{const x=527+(870-((items.length-1)*158+72))/2+i*158;result+=art('UI_014',x,917,72,72,31)+art(t[0],x+16,932,40,39,32)+'<div class="text center" style="left:'+(x-24)+'px;top:995px;width:120px;font-size:20px;z-index:40">'+t[1]+'</div>';});return result;}

function textBox(s,x,y,w,size=26,color='#536056',z=40){return '<div class="text" style="left:'+x+'px;top:'+y+'px;width:'+w+'px;font-size:'+size+'px;color:'+color+';z-index:'+z+';white-space:normal">'+s+'</div>';}
function button(s,x,y,w=330,h=64,id='UI_040',z=35){return art(id,x,y,w,h,z)+'<div class="text center" style="left:'+x+'px;top:'+(y+(h-32)/2)+'px;width:'+w+'px;font-size:25px;color:'+(id==='UI_043'?'#89907e':'#f7f3e9')+';z-index:'+(z+1)+'">'+s+'</div>';}
function bubble(s,x,y,w=270){return art('UI_007',x,y,w,59,25)+textBox(s,x,y+16,w,22,'#64705f',30).replace('class="text"','class="text center"');}
function iconLink(id,label,x,y){return art('UI_014',x,y,68,68,30)+art(id,x+16,y+15,37,37,31)+textBox(label,x-23,y+75,114,18,'#65705f',35).replace('class="text"','class="text center"');}
function frame(name,subtitle){return art('UI_002',45,35,330,71,30)+txt(name,73,51,30,'serif light',40)+art('UI_006',600,34,615,65,30)+art('PRP_308',629,50,31,31,31)+txt('128',675,48,23)+art('ICO_108',826,48,31,32,31)+txt('第三日',876,48,23)+art('PRP_103',1032,51,36,28,31)+txt('12',1080,48,23)+iconLink('ICO_402','保存',1465,30)+iconLink('ICO_106','手记',1562,30)+iconLink('ICO_107','设置',1659,30)+iconLink('ICO_404','主页',1756,30)+button(name==='茶村'?'返回主页':'返回茶村',53,955,265,59,'UI_010')+textBox(subtitle,56,124,670,20,'#72816e')+'<div class="preview-note">页面设计预览 · 文字、数值与图片分层</div>';}
const pages=[];function add(key,name,body){pages.push({key,name,body});}
pageKey='主页';
let home=art('BG_301',0,0,1920,1080,0)+art('LOG_301',740,560,440,320,10)+button('开始游戏',780,917,360,85)+art('UI_014',795,932,55,55,37)+art('ICO_401',809,944,30,28,38)+button('继续游戏',1180,930,226,60)+iconLink('ICO_403','读取存档',1630,33)+iconLink('ICO_107','设置',1760,33);
add('01_主页','主页',home);
pageKey='载入页';
let loading=art('BG_302',0,0,1920,1080,0)+art('PRP_402',655,460,640,266,4)+art('PRP_403',662,329,214,177,5)+art('PRP_401',844,345,252,227,7)+art('PRP_201',1070,509,186,90,8)+art('PRP_208',1091,520,145,56,9)+