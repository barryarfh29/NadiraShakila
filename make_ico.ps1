# Membuat file .ico multi-ukuran yang valid dari assets/logo.png
# Frame disimpan sebagai PNG di dalam ICO (didukung Windows Vista+).
Add-Type -AssemblyName System.Drawing

$src = "$PSScriptRoot\assets\logo.png"
$out = "$PSScriptRoot\windows\runner\resources\app_icon.ico"
$sizes = @(256, 128, 64, 48, 32, 16)

$orig = [System.Drawing.Image]::FromFile($src)

# Siapkan PNG bytes untuk tiap ukuran
$pngList = @()
foreach ($s in $sizes) {
    $bmp = New-Object System.Drawing.Bitmap($s, $s)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.DrawImage($orig, 0, 0, $s, $s)
    $g.Dispose()
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $pngList += ,($ms.ToArray())
    $bmp.Dispose()
}
$orig.Dispose()

# Tulis file ICO
$fs = New-Object System.IO.FileStream($out, [System.IO.FileMode]::Create)
$bw = New-Object System.IO.BinaryWriter($fs)

# ICONDIR header
$bw.Write([UInt16]0)            # reserved
$bw.Write([UInt16]1)            # type = icon
$bw.Write([UInt16]$sizes.Count) # count

# Hitung offset awal data gambar
$offset = 6 + (16 * $sizes.Count)

for ($i = 0; $i -lt $sizes.Count; $i++) {
    $s = $sizes[$i]
    $data = $pngList[$i]
    $w = if ($s -ge 256) { 0 } else { $s }   # 0 berarti 256
    $h = if ($s -ge 256) { 0 } else { $s }
    $bw.Write([Byte]$w)        # width
    $bw.Write([Byte]$h)        # height
    $bw.Write([Byte]0)         # color count
    $bw.Write([Byte]0)         # reserved
    $bw.Write([UInt16]1)       # color planes
    $bw.Write([UInt16]32)      # bits per pixel
    $bw.Write([UInt32]$data.Length) # size of data
    $bw.Write([UInt32]$offset)      # offset
    $offset += $data.Length
}

# Tulis data PNG tiap frame
foreach ($data in $pngList) {
    $bw.Write($data)
}

$bw.Flush(); $bw.Close(); $fs.Close()
Write-Host "ICO dibuat: $out ($([math]::Round((Get-Item $out).Length/1KB,1)) KB, $($sizes.Count) ukuran)"
