
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const sharp=require('C:/Users/24586/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root="D:\\AAA找到工作\\素材们\\项目3-中国传统制茶技艺数字展示策略研究\\茶园物语-制作素材";
const input={assets:fs.readdirSync(path.join(root,'09_生成记录/终版背景场景UI补充')).filter(x=>x.endsWith('_prompt.json')).map(x=>JSON.parse(fs.readFileSync(path.join(root,'09_生成记录/终版背景场景UI补充',x),'utf8')))}; writePrompts(); function writePrompts(){fs.writeFileSync(path.join(root,'09_生成记录/batch08_prompts_v001.json'),JSON.stringify({date:'2026-10-08',mode:'built-in image_gen',scope:'只补背景、场景和UI，不制作6项手记插画',assets:input.assets},null,2)+'\n');}
const write=(p,v)=>fs.writeFileSync(path.join(root,p),JSON.stringify(v,null,2)+'\n','utf8');
(async()=>{
const results=[];
for(const a of input.assets){
 const file=path.join(root,a.relativePath),meta=await sharp(file).metadata();
 const {data,info}=await sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject:true});
 const w=info.width,h=info.height,c=info.channels;
 let transparent=0,borderNonzero=0,border16=0;
 let b16=[w,h,-1,-1],b128=[w,h,-1,-1];
 for(let y=0;y<h;y++)for(let x=0;x<w;x++){
  const alpha=data[(y*w+x)*c+c-1];
  if(alpha===0)transparent++;
  const edge=x===0||y===0||x===w-1||y===h-1;
  if(edge&&alpha>0)borderNonzero++;if(edge&&alpha>=16)border16++;
  if(alpha>=16){b16[0]=Math.min(b16[0],x);b16[1]=Math.min(b16[1],y);b16[2]=Math.max(b16[2],x);b16[3]=Math.max(b16[3],y);}
  if(alpha>=128){b128[0]=Math.min(b128[0],x);b128[1]=Math.min(b128[1],y);b128[2]=Math.max(b128[2],x);b128[3]=Math.max(b128[3],y);}
 }
 const alphaAt=(x,y)=>data[(y*w+x)*c+c-1];
 const corners=[alphaAt(0,0),alphaAt(w-1,0),alphaAt(0,h-1),alphaAt(w-1,h-1)];
 const pass=!!meta.hasAlpha&&corners.every(x=>x===0)&&transparent>0&&(border16===0||a.id==='BG_201')&&b128[2]>b128[0];
 let anchor,label;
 if(a.id.startsWith('BG_')||a.id.startsWith('UI_')||a.id.startsWith('ICO_')||a.id==='BLD_201'||a.id==='BLD_202'){
  anchor=[(b16[0]+b16[2])/2,(b16[1]+b16[3])/2];label='图层可见范围中心';
 }else if(a.id==='DEC_101'){
  anchor=[(b128[0]+b128[2])/2,b128[1]];label='悬挂点近似位置';
 }else{
  let minX=w,maxX=-1;
  const start=Math.max(b128[1],b128[3]-Math.round((b128[3]-b128[1])*0.025));
  for(let y=start;y<=b128[3];y++)for(let x=b128[0];x<=b128[2];x++)if(alphaAt(x,y)>=128){minX=Math.min(minX,x);maxX=Math.max(maxX,x);}
  anchor=[(minX+maxX)/2,b128[3]];label=a.id.startsWith('PLT_')||a.id==='DEC_103'?'根部近似位置':'底部接地点近似位置';
 }
 results.push({id:a.id,file:a.relativePath,width:w,height:h,hasAlpha:!!meta.hasAlpha,alphaCheck:{pass,cornersAlpha:corners,transparentPixels:transparent,borderNonzeroPixels:borderNonzero,borderPixelsAlpha16:border16,warning:borderNonzero?'保留原始alpha；边缘存在少量alpha小于16的像素。':''},visibleBBoxAlpha16:b16,solidBBoxAlpha128:b128,approxAnchor:anchor,anchorMeaning:label,sha256:crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')});
}
const qa={date:'2026-10-08',batch:'08_背景场景与UI补充',total:results.length,passed:results.filter(x=>x.alphaCheck.pass).length,failures:results.filter(x=>!x.alphaCheck.pass).map(x=>x.id),assets:results};
qa.pass=qa.total===12&&qa.passed===12;
write('09_生成记录/batch08_alpha_check_v001.json',qa);
const positions={project:'茶园物语',date:'2026-10-08',batch:'08_背景场景与UI补充',notes:['原始PNG未裁切、重采样或清除alpha，真实尺寸如下。BG_201为标题页满幅山水画层，左右山体延伸至画布边缘属于背景构图；其他分件应保留透明边距。','参考点依据可见范围和底部实像素估算，不能替代Godot中的地面、遮挡与对位验收。','本批补齐后侧屋檐、石阶、茶园入口及另一轴向栏杆；分件实际对位需要在后续场景摆放时调整。','远山、水面和云纹各自独立；植物无土块岩石或花盆，灯笼无墙面与支架。','所有组合预览均为浏览器中的静态素材摆放示意；未搭建Godot。'],assets:results.map(a=>({id:a.id,file:a.file,canvas:[a.width,a.height],visibleBBoxAlpha16:a.visibleBBoxAlpha16,solidBBoxAlpha128:a.solidBBoxAlpha128,approxAnchor:a.approxAnchor,anchorMeaning:a.anchorMeaning}))};
write('00_规范与清单/终版补充素材分层与锚点参考_v001.json',positions);
console.log(JSON.stringify({total:qa.total,passed:qa.passed,failures:qa.failures,items:results.map(a=>({id:a.id,size:[a.width,a.height],border16:a.alphaCheck.borderPixelsAlpha16,bbox:a.visibleBBoxAlpha16,anchor:a.approxAnchor}))}));
if(!qa.pass)process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1});
