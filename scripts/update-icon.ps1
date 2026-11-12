$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$project = Split-Path $PSScriptRoot -Parent
$source = [System.Drawing.Bitmap]::new((Join-Path $project 'image app.png'))
$resources = Join-Path $project 'android\app\src\main\res'
# The source is an icon on a blue field. Extract the cassette within the
# central artwork, keeping its black and cream details as supplied.
$x = [int]($source.Width * .06); $y = [int]($source.Height * .20)
$w = [int]($source.Width * .88); $h = [int]($source.Height * .60)
$art = [System.Drawing.Bitmap]::new($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$ag = [System.Drawing.Graphics]::FromImage($art)
try { $ag.DrawImage($source, [System.Drawing.Rectangle]::new(0,0,$w,$h), [System.Drawing.Rectangle]::new($x,$y,$w,$h), [System.Drawing.GraphicsUnit]::Pixel) } finally { $ag.Dispose() }
$rect = [System.Drawing.Rectangle]::new(0,0,$w,$h)
$bits = $art.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
try {
    $bytes = [byte[]]::new([Math]::Abs($bits.Stride) * $h)
    [System.Runtime.InteropServices.Marshal]::Copy($bits.Scan0,$bytes,0,$bytes.Length)
    for ($i=0; $i -lt $bytes.Length; $i+=4) {
        $b=[int]$bytes[$i]; $g=[int]$bytes[$i+1]; $r=[int]$bytes[$i+2]
        $dominance=$b-[Math]::Max($r,$g)
        if ($b -gt 100 -and $dominance -gt 10) {
            $bytes[$i+3]=[byte][Math]::Round(255 * [Math]::Max(0,[Math]::Min(1,(40-$dominance)/30)))
        }
    }
    [System.Runtime.InteropServices.Marshal]::Copy($bytes,0,$bits.Scan0,$bytes.Length)
} finally { $art.UnlockBits($bits) }
function Save-Icon([string]$path, [int]$size, [double]$fraction, [bool]$transparent) {
    $bitmap = [System.Drawing.Bitmap]::new($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $background = if ($transparent) { [System.Drawing.Color]::Transparent } else { [System.Drawing.ColorTranslator]::FromHtml('#1B76FD') }
        $graphics.Clear($background)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $scale = $size * $fraction / $art.Width
        $width = [int][Math]::Round($art.Width * $scale); $height = [int][Math]::Round($art.Height * $scale)
        $graphics.DrawImage($art, [int](($size - $width) / 2), [int](($size - $height) / 2), $width, $height)
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
try {
    foreach ($entry in @{mdpi=48; hdpi=72; xhdpi=96; xxhdpi=144; xxxhdpi=192}.GetEnumerator()) {
        Save-Icon (Join-Path $resources "mipmap-$($entry.Key)\ic_launcher.png") $entry.Value .84 $false
    }
    $foreground = Join-Path $resources 'drawable-nodpi'
    New-Item -ItemType Directory -Force -Path $foreground | Out-Null
    Save-Icon (Join-Path $foreground 'ic_launcher_foreground.png') 432 .50 $true
    Save-Icon (Join-Path $project 'assets\app_logo.png') 512 .84 $false
} finally { $art.Dispose(); $source.Dispose() }
