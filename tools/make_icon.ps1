# 生成 1024x1024 的 App 图标（无需设计软件）
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root 'LeafReader\Assets.xcassets\AppIcon.appiconset'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$outFile = Join-Path $outDir 'AppIcon-1024.png'

$size = 1024
$bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

$rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
$c1 = [System.Drawing.Color]::FromArgb(255, 24, 33, 44)
$c2 = [System.Drawing.Color]::FromArgb(255, 46, 88, 108)
$brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $c1, $c2, 55.0)
$g.FillRectangle($brush, $rect)

function New-RoundedRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

# 书页
$pageRect = New-RoundedRect 292 200 440 624 34
$pageBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 248, 243, 232))
$g.FillPath($pageBrush, $pageRect)

# 文本行
$lineBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70, 40, 48, 60))
$lineY = 300
$index = 0
while ($lineY -lt 720) {
    $width = if ($index % 4 -eq 3) { 180 } else { 296 }
    $g.FillRectangle($lineBrush, 344, $lineY, $width, 18)
    $lineY += 62
    $index++
}

# 书签
$ribbonBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 226, 122, 78))
$g.FillRectangle($ribbonBrush, 676, 200, 56, 200)
$ribbon = New-Object System.Drawing.Drawing2D.GraphicsPath
$points = [System.Drawing.PointF[]]@(
    [System.Drawing.PointF]::new(676, 400),
    [System.Drawing.PointF]::new(732, 400),
    [System.Drawing.PointF]::new(704, 452)
)
$ribbon.AddPolygon($points)
$g.FillPath($ribbonBrush, $ribbon)

$bmp.Save($outFile, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()
Write-Host "icon written: $outFile"