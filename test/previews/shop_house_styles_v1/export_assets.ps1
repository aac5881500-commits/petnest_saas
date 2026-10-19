param([string[]]$ReexportFiles = @())
$ErrorActionPreference = 'Stop'
# 本機格式／尺寸輸出與檢查；不含任何 Firebase、網路或 Git 寫入操作。
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies 'System.Drawing' -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class HouseStyleImageAudit {
  public static int[] Scan(Bitmap source) {
    using (var b = new Bitmap(source.Width, source.Height, PixelFormat.Format32bppArgb)) {
      using (var g = Graphics.FromImage(b)) g.DrawImageUnscaled(source, 0, 0);
      var data = b.LockBits(new Rectangle(0,0,b.Width,b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
      try {
        var bytes = new byte[data.Stride * b.Height]; Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);
        int empty=0, solid=0, minX=b.Width, minY=b.Height, maxX=0, maxY=0, logoSolid=0, logoCount=0;
        for (int y=0;y<b.Height;y++) for (int x=0;x<b.Width;x++) {
          int a=bytes[y*data.Stride+x*4+3];
          if(a==0) empty++; if(a>16) { solid++; minX=Math.Min(minX,x); minY=Math.Min(minY,y); maxX=Math.Max(maxX,x); maxY=Math.Max(maxY,y); }
          if(x>=b.Width*.205 && x<b.Width*.795 && y>=b.Height*.175 && y<b.Height*.765) {logoCount++; if(a>16) logoSolid++;}
        }
        return new int[]{empty,solid,minX,minY,maxX,maxY,logoSolid,logoCount};
      } finally { b.UnlockBits(data); }
    }
  }
}
'@
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
if ($projectRoot -ne 'C:\flutter_apps\petnest_saas') { throw 'Unexpected project root' }
$jobs = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'generation.json') -Encoding UTF8 -Raw | ConvertFrom-Json
$report = @()
foreach ($job in $jobs) {
  $directory = Join-Path $projectRoot ('assets/images/shop_house/' + $job.style)
  [IO.Directory]::CreateDirectory($directory) | Out-Null
  $extension = if ($job.transparent) { 'png' } else { 'jpg' }
  $fileName = $job.style + '_' + $job.part + '.' + $extension
  $destination = Join-Path $directory $fileName
  if ((-not (Test-Path -LiteralPath $destination)) -or ($ReexportFiles -contains $fileName)) {
    $source = [Drawing.Bitmap]::new([string]$job.source)
    try {
      $width = [int]$job.size[0]; $height = [int]$job.size[1]
      $crop = [Drawing.RectangleF]::new(0,0,$source.Width,$source.Height)
      if ($job.part -eq 'base') {
        # 只移除生成畫布外圍的全透明空間，不切除任何可見建築。
        [int[]]$houseAlphaBounds = @([HouseStyleImageAudit]::Scan($source))
        $crop = [Drawing.RectangleF]::new([Math]::Max(0,$houseAlphaBounds[2]-3),[Math]::Max(0,$houseAlphaBounds[3]-3),[Math]::Min($source.Width,$houseAlphaBounds[4]+4)-[Math]::Max(0,$houseAlphaBounds[2]-3),[Math]::Min($source.Height,$houseAlphaBounds[5]+4)-[Math]::Max(0,$houseAlphaBounds[3]-3))
      }
      $output = [Drawing.Bitmap]::new($width,$height,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
      try {
        $graphics = [Drawing.Graphics]::FromImage($output)
        try {
          $graphics.Clear([Drawing.Color]::Transparent)
          $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
          $graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
          $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
          $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
          $factor = if ($job.transparent) { [Math]::Min($width/$crop.Width,$height/$crop.Height) } else { [Math]::Max($width/$crop.Width,$height/$crop.Height) }
          $drawWidth=$crop.Width*$factor; $drawHeight=$crop.Height*$factor
          $target = [Drawing.RectangleF]::new(($width-$drawWidth)/2,($height-$drawHeight)/2,$drawWidth,$drawHeight)
          $graphics.DrawImage($source,$target,$crop,[Drawing.GraphicsUnit]::Pixel)
        } finally { $graphics.Dispose() }
        if ($job.transparent) { $output.Save($destination,[Drawing.Imaging.ImageFormat]::Png) }
        else {
          $encoder=[Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/jpeg'
          $parameters=[Drawing.Imaging.EncoderParameters]::new(1)
          try {
            $parameters.Param[0]=[Drawing.Imaging.EncoderParameter]::new([Drawing.Imaging.Encoder]::Quality,[long]85)
            $output.Save($destination,$encoder,$parameters)
          } finally { $parameters.Dispose() }
        }
      } finally { $output.Dispose() }
    } finally { $source.Dispose() }
  }
  $decoded=[Drawing.Bitmap]::new($destination)
  try {
    $audit=[HouseStyleImageAudit]::Scan($decoded)
    $file=Get-Item -LiteralPath $destination
    if ($file.Length -gt 5MB) { throw "Over upload limit: $fileName" }
    if ($job.transparent -and $audit[0] -lt 100) { throw "Missing transparency: $fileName" }
    $report += [PSCustomObject]@{
      style=$job.style; part=$job.part; fileName=$fileName
      relativePath=('assets/images/shop_house/'+$job.style+'/'+$fileName)
      width=$decoded.Width; height=$decoded.Height; bytes=$file.Length
      sha256=(Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
      transparentPixels=$audit[0]; visiblePixels=$audit[1]
      logoSafeOpaqueFraction=($audit[6]/[double]$audit[7])
      placement=$job.placement; device=$job.device
    }
  } finally { $decoded.Dispose() }
}
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'asset-audit.json') -Encoding UTF8
$report | Select-Object style,part,width,height,bytes,transparentPixels,logoSafeOpaqueFraction | Format-Table -AutoSize
