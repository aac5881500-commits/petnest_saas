$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$assets = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'asset-audit.json') -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($style in @('romantic_garden','modern_japanese')) {
  $sheet=[Drawing.Bitmap]::new(2000,820)
  $g=[Drawing.Graphics]::FromImage($sheet)
  $font=[Drawing.Font]::new('Segoe UI',15)
  $brush=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(255,55,57,54))
  try {
    $g.Clear([Drawing.Color]::FromArgb(255,243,242,236))
    $g.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $index=0
    foreach ($asset in @($assets | Where-Object style -eq $style)) {
      $x=($index%5)*400; $y=[Math]::Floor($index/5)*410
      $g.FillRectangle([Drawing.Brushes]::WhiteSmoke,$x+8,$y+8,384,350)
      $image=[Drawing.Image]::FromFile((Join-Path $projectRoot $asset.relativePath))
      try {
        $scale=[Math]::Min(370/$image.Width,330/$image.Height)
        $width=$image.Width*$scale; $height=$image.Height*$scale
        $g.DrawImage($image,[Drawing.RectangleF]::new($x+200-$width/2,$y+180-$height/2,$width,$height))
      } finally { $image.Dispose() }
      $g.DrawString([string]$asset.part,$font,$brush,$x+12,$y+365)
      $g.DrawString(('{0}x{1} / {2:N0} KB' -f $asset.width,$asset.height,($asset.bytes/1024)),$font,$brush,$x+12,$y+389)
      $index++
    }
    $sheet.Save((Join-Path $PSScriptRoot ($style+'_contact.png')),[Drawing.Imaging.ImageFormat]::Png)
  } finally { $g.Dispose(); $sheet.Dispose(); $font.Dispose(); $brush.Dispose() }
}
