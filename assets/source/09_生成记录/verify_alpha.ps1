param([string]$AssetRoot)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$code = @'
using System;
public class TeaAlphaReport {
 public int width, height;
 public long transparentPixels, opaquePixels, partialPixels, borderNonzeroPixels;
 public int[] nonzeroBounds, visibleBounds;
 public static TeaAlphaReport Scan(byte[] bytes,int width,int height,int stride) {
  var r=new TeaAlphaReport();r.width=width;r.height=height;
  int x0=width,y0=height,x1=-1,y1=-1,vx0=width,vy0=height,vx1=-1,vy1=-1;
  for(int y=0;y<height;y++)for(int x=0;x<width;x++) {
   int a=bytes[y*stride+x*4+3];
   if(a==0)r.transparentPixels++;else if(a==255)r.opaquePixels++;else r.partialPixels++;
   if(a>0){x0=Math.Min(x0,x);y0=Math.Min(y0,y);x1=Math.Max(x1,x);y1=Math.Max(y1,y);if(x==0||x==width-1||y==0||y==height-1)r.borderNonzeroPixels++;}
   if(a>=16){vx0=Math.Min(vx0,x);vy0=Math.Min(vy0,y);vx1=Math.Max(vx1,x);vy1=Math.Max(vy1,y);}
  }
  r.nonzeroBounds=new int[]{x0,y0,x1,y1};r.visibleBounds=new int[]{vx0,vy0,vx1,vy1};return r;
 }
}
'@
Add-Type -TypeDefinition $code
$files = @(
'02_地形与植物\ter_soil_plot_empty_v001.png',
'02_地形与植物\plt_tea_bush_mature_v001.png',
'04_UI组件\ui_popup_base_v001.png',
'05_人物\chr_protagonist_portrait_neutral_v001.png',
'06_道具与图标\prp_bamboo_basket_empty_v001.png'
)
$reports = foreach ($file in $files) {
 $bitmap=[Drawing.Bitmap]::new((Join-Path $AssetRoot $file))
 try {
  $rect=[Drawing.Rectangle]::new(0,0,$bitmap.Width,$bitmap.Height)
  $data=$bitmap.LockBits($rect,[Drawing.Imaging.ImageLockMode]::ReadOnly,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
  try {
   $stride=[Math]::Abs($data.Stride)
   $bytes=[byte[]]::new($stride*$bitmap.Height)
   [Runtime.InteropServices.Marshal]::Copy($data.Scan0,$bytes,0,$bytes.Length)
   $scan=[TeaAlphaReport]::Scan($bytes,$bitmap.Width,$bitmap.Height,$stride)
  }finally{$bitmap.UnlockBits($data)}
  [PSCustomObject]@{file=$file;width=$scan.width;height=$scan.height;transparentPixels=$scan.transparentPixels;opaquePixels=$scan.opaquePixels;partialPixels=$scan.partialPixels;borderNonzeroPixels=$scan.borderNonzeroPixels;nonzeroBounds=$scan.nonzeroBounds;visibleBounds=$scan.visibleBounds;cornersTransparent=($bitmap.GetPixel(0,0).A -eq 0 -and $bitmap.GetPixel($bitmap.Width-1,0).A -eq 0 -and $bitmap.GetPixel(0,$bitmap.Height-1).A -eq 0 -and $bitmap.GetPixel($bitmap.Width-1,$bitmap.Height-1).A -eq 0);sha256=(Get-FileHash -LiteralPath (Join-Path $AssetRoot $file) -Algorithm SHA256).Hash}
 }finally{$bitmap.Dispose()}
}
$reports | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $AssetRoot '09_生成记录\batch01_alpha_check_v001.json') -Encoding utf8
$reports | ConvertTo-Json -Depth 6