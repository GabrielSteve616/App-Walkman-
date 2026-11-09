$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$project = Split-Path $PSScriptRoot -Parent
$source = [System.Drawing.Image]::FromFile((Join-Path $project 'image app.png'))
$resources = Join-Path $project 'android\app\src\main\res'
function Save-Icon([string]$path, [int]$size, [double]$fraction, [bool]$transparent) {
    $bitmap = [System.Drawing.Bitmap]::new($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $background = if ($transparent) { [System.Drawing.Color]::Transparent } else {
            [System.Drawing.ColorTranslator]::FromHtml('#101820')
        }
        $graphics.Clear($background)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $scale = $size * $fraction / [Math]::Max($source.Width, $source.Height)
        $width = [int][Math]::Round($source.Width * $scale)
        $height = [int][Math]::Round($source.Height * $scale)
        $graphics.DrawImage($source, [int](($size - $width) / 2), [int](($size - $height) / 2), $width, $height)
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}
try {
    foreach ($entry in @{mdpi=48; hdpi=72; xhdpi=96; xxhdpi=144; xxxhdpi=192}.GetEnumerator()) {
        Save-Icon (Join-Path $resources "mipmap-$($entry.Key)\ic_launcher.png") $entry.Value 0.96 $false
    }
    $foreground = Join-Path $resources 'drawable-nodpi'
    New-Item -ItemType Directory -Force -Path $foreground | Out-Null
    Save-Icon (Join-Path $foreground 'ic_launcher_foreground.png') 432 0.66 $true
} finally {
    $source.Dispose()
}
