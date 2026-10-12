param([string]$Master='output/minigun-implementation/icon-framing-001/icon-master.png',[string]$Output='output/minigun-implementation/icon-framing-001')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$root=[IO.Path]::GetFullPath($Output)
$source=[Drawing.Image]::FromFile([IO.Path]::GetFullPath($Master))
try {
 foreach($size in @(128,256)){
  $image=[Drawing.Bitmap]::new($size,$size,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics=[Drawing.Graphics]::FromImage($image)
  $attributes=[Drawing.Imaging.ImageAttributes]::new()
  try {
   $graphics.Clear([Drawing.Color]::Transparent)
   $graphics.CompositingMode=[Drawing.Drawing2D.CompositingMode]::SourceCopy
   $graphics.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
   $graphics.PixelOffsetMode=[Drawing.Drawing2D.PixelOffsetMode]::HighQuality
   $attributes.SetWrapMode([Drawing.Drawing2D.WrapMode]::TileFlipXY)
   $rect=[Drawing.Rectangle]::new(0,0,$size,$size)
   $graphics.DrawImage($source,$rect,0,0,$source.Width,$source.Height,[Drawing.GraphicsUnit]::Pixel,$attributes)
   $image.Save((Join-Path $root ("gatling-turret-"+$size+'.png')),[Drawing.Imaging.ImageFormat]::Png)
  }finally{$attributes.Dispose();$graphics.Dispose();$image.Dispose()}
 }
}finally{$source.Dispose()}
