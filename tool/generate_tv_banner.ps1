# Reproducible, language-neutral Android TV launcher banner (320 x 180 xhdpi).
# The only lettering is the OtherRadio brand, shared by Polish and English.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = (Resolve-Path "$PSScriptRoot\..").Path
$fonts = New-Object System.Drawing.Text.PrivateFontCollection
$fonts.AddFontFile("$root\assets\fonts\Sora-600.ttf")
$bitmap = New-Object System.Drawing.Bitmap 320, 180
$g = [System.Drawing.Graphics]::FromImage($bitmap)
$g.SmoothingMode = 'AntiAlias'
$g.TextRenderingHint = 'AntiAliasGridFit'
$g.Clear([System.Drawing.ColorTranslator]::FromHtml('#11151C'))
$mint = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#4FD1C5'))
$font = New-Object System.Drawing.Font ($fonts.Families[0], 30, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
try {
    $heights = @(16, 32, 48, 32, 16)
    for ($i = 0; $i -lt 5; $i++) {
        $g.FillRectangle($mint, 29 + 9 * $i, 90 - $heights[$i] / 2, 5, $heights[$i])
    }
    $g.DrawString('other', $font, $mint, 83, 48)
    $g.DrawString('radio', $font, $mint, 83, 86)
    $directory = "$root\android\app\src\main\res\drawable-xhdpi"
    New-Item -ItemType Directory -Force $directory | Out-Null
    $bitmap.Save("$directory\tv_banner.png", [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
    $font.Dispose(); $mint.Dispose(); $g.Dispose(); $bitmap.Dispose(); $fonts.Dispose()
}
