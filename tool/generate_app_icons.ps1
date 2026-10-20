param(
    # Use the same font as Flutter's Icons.graphic_eq_rounded (U+F7BD).
    [string]$MaterialFont
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot -Parent
if (-not $MaterialFont) {
    $config = Get-Content (Join-Path $root '.dart_tool/package_config.json') -Raw | ConvertFrom-Json
    $sdk = ([uri]$config.flutterRoot).LocalPath
    $MaterialFont = Join-Path $sdk 'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
    if (-not (Test-Path $MaterialFont)) {
        $MaterialFont = Join-Path $root 'build/flutter_assets/fonts/MaterialIcons-Regular.otf'
    }
}
if (-not (Test-Path $MaterialFont)) {
    throw 'Pass -MaterialFont pointing to the full Flutter MaterialIcons-Regular.otf font.'
}

$culture = [Globalization.CultureInfo]::InvariantCulture
function Number([single]$value) { $value.ToString('0.######', $culture) }
function Write-Text([string]$relative, [string]$text) {
    $file = Join-Path $root $relative
    [IO.Directory]::CreateDirectory((Split-Path $file -Parent)) | Out-Null
    [IO.File]::WriteAllText($file, $text + "`n", [Text.UTF8Encoding]::new($false))
}

$fonts = [Drawing.Text.PrivateFontCollection]::new()
$fonts.AddFontFile((Resolve-Path $MaterialFont).Path)
if ($fonts.Families[0].Name -ne 'Material Icons') { throw 'Expected the Flutter Material Icons font.' }
$glyph = [Drawing.Drawing2D.GraphicsPath]::new()
# Extract at 64x resolution to avoid rounding the original glyph to screen pixels.
$glyph.AddString([string][char]0xf7bd, $fonts.Families[0], 0, 1536,
    [Drawing.PointF]::new(0, 0), [Drawing.StringFormat]::GenericTypographic)
$normalise = [Drawing.Drawing2D.Matrix]::new()
$normalise.Scale(1 / 64, 1 / 64)
$glyph.Transform($normalise)
$normalise.Dispose()
$bounds = $glyph.GetBounds()
if ($bounds.Width -lt 17 -or $bounds.Width -gt 19 -or $bounds.Height -lt 19 -or $bounds.Height -gt 21) {
    throw 'Glyph bounds do not match graphic_eq_rounded; do not use a subset font.'
}

$commands = [Collections.Generic.List[string]]::new()
$points = $glyph.PathPoints
$types = $glyph.PathTypes
for ($i = 0; $i -lt $points.Length; $i++) {
    $kind = $types[$i] -band 7
    switch ($kind) {
        0 { $commands.Add("M$(Number $points[$i].X),$(Number $points[$i].Y)") }
        1 { $commands.Add("L$(Number $points[$i].X),$(Number $points[$i].Y)") }
        3 {
            $commands.Add("C$(Number $points[$i].X),$(Number $points[$i].Y) $(Number $points[$i+1].X),$(Number $points[$i+1].Y) $(Number $points[$i+2].X),$(Number $points[$i+2].Y)")
            $i += 2
        }
        default { throw "Unsupported outline point: $kind" }
    }
    if ($types[$i] -band 128) { $commands.Add('Z') }
}
$data = $commands -join ' '
Write-Text 'assets/branding/other_radio.svg' @"
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 108 108">
  <!-- Existing _Brand logo: Flutter Material Icons graphic_eq_rounded U+F7BD. -->
  <rect width="108" height="108" rx="22" fill="#0A0D14"/>
  <path fill="#65E5CD" transform="translate(21.6 21.6) scale(2.7)" d="$data"/>
</svg>
"@

function New-IconBitmap([int]$size, [string]$shape) {
    $scale = 4
    $large = [Drawing.Bitmap]::new($size * $scale, $size * $scale)
    $graphics = [Drawing.Graphics]::FromImage($large)
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([Drawing.Color]::Transparent)
    $graphics.ScaleTransform($large.Width / 108, $large.Height / 108)
    $dark = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#0A0D14'))
    $mint = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#65E5CD'))
    if ($shape -eq 'round') {
        $graphics.FillEllipse($dark, 0, 0, 108, 108)
    } elseif ($shape -eq 'square') {
        $graphics.FillRectangle($dark, 0, 0, 108, 108)
    } elseif ($shape -ne 'foreground') {
        $tile = [Drawing.Drawing2D.GraphicsPath]::new()
        $tile.AddArc(0, 0, 44, 44, 180, 90)
        $tile.AddArc(64, 0, 44, 44, 270, 90)
        $tile.AddArc(64, 64, 44, 44, 0, 90)
        $tile.AddArc(0, 64, 44, 44, 90, 90)
        $tile.CloseFigure()
        $graphics.FillPath($dark, $tile)
        $tile.Dispose()
    }
    $graphics.TranslateTransform(21.6, 21.6)
    $graphics.ScaleTransform(2.7, 2.7)
    $graphics.FillPath($mint, $glyph)
    $graphics.Dispose()
    $dark.Dispose()
    $mint.Dispose()
    $bitmap = [Drawing.Bitmap]::new($size, $size)
    $resize = [Drawing.Graphics]::FromImage($bitmap)
    $resize.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
    $resize.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $resize.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $resize.DrawImage($large, 0, 0, $size, $size)
    $resize.Dispose()
    $large.Dispose()
    return ,$bitmap
}

function Save-Png([string]$relative, [int]$size, [string]$shape) {
    $file = Join-Path $root $relative
    [IO.Directory]::CreateDirectory((Split-Path $file -Parent)) | Out-Null
    $image = New-IconBitmap $size $shape
    $image.Save($file, [Drawing.Imaging.ImageFormat]::Png)
    $image.Dispose()
}

Save-Png 'assets/branding/other_radio.png' 1024 'rounded'
$res = 'android/app/src/main/res'
foreach ($density in @(@('mdpi', 48), @('hdpi', 72), @('xhdpi', 96), @('xxhdpi', 144), @('xxxhdpi', 192))) {
    Save-Png "$res/mipmap-$($density[0])/ic_launcher.png" $density[1] 'rounded'
    Save-Png "$res/mipmap-$($density[0])/ic_launcher_round.png" $density[1] 'round'
}
Write-Text "$res/drawable/ic_launcher_foreground.xml" @"
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <group android:translateX="21.6" android:translateY="21.6" android:scaleX="2.7" android:scaleY="2.7">
        <path android:fillColor="#65E5CD" android:pathData="$data" />
    </group>
</vector>
"@
Write-Text "$res/values/icon_colors.xml" @'
<resources>
    <color name="ic_launcher_background">#0A0D14</color>
</resources>
'@
foreach ($name in @('ic_launcher', 'ic_launcher_round')) {
    Write-Text "$res/mipmap-anydpi-v26/$name.xml" @'
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
'@
    Write-Text "$res/mipmap-anydpi-v33/$name.xml" @'
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
'@
}

# ICO directory with PNG-compressed RGBA entries, supported since Windows Vista.
$sizes = @(16, 20, 24, 32, 40, 48, 64, 96, 128, 256)
$frames = foreach ($size in $sizes) {
    $image = New-IconBitmap $size 'rounded'
    $stream = [IO.MemoryStream]::new()
    $image.Save($stream, [Drawing.Imaging.ImageFormat]::Png)
    ,$stream.ToArray()
    $stream.Dispose()
    $image.Dispose()
}
$ico = [IO.File]::Create((Join-Path $root 'windows/runner/resources/app_icon.ico'))
$writer = [IO.BinaryWriter]::new($ico)
$writer.Write([uint16]0)
$writer.Write([uint16]1)
$writer.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $dimension = $sizes[$i] % 256
    $writer.Write([byte]$dimension)
    $writer.Write([byte]$dimension)
    $writer.Write([byte]0)
    $writer.Write([byte]0)
    $writer.Write([uint16]1)
    $writer.Write([uint16]32)
    $writer.Write([uint32]$frames[$i].Length)
    $writer.Write([uint32]$offset)
    $offset += $frames[$i].Length
}
foreach ($frame in $frames) { $writer.Write([byte[]]$frame) }
$writer.Dispose()
$glyph.Dispose()
$fonts.Dispose()
Write-Output 'Generated source SVG/1024px PNG, Android legacy/adaptive/themed icons, and 10-frame Windows ICO.'
