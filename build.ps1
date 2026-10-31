# Builds team/<slug>/index.html and team/<slug>/<slug>.vcf for every person in people.json.
# Run from anywhere:  powershell -ExecutionPolicy Bypass -File build.ps1
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding $false

function Html([string]$s) { [System.Net.WebUtility]::HtmlEncode($s) }

# vCard 3.0: escape \ , ; and fold lines at 75 characters
function VEsc([string]$s) { $s.Replace('\', '\\').Replace(',', '\,').Replace(';', '\;') }
function Fold([string]$line) {
    if ($line.Length -le 75) { return $line }
    $parts = @($line.Substring(0, 75))
    for ($i = 75; $i -lt $line.Length; $i += 74) {
        $parts += ' ' + $line.Substring($i, [Math]::Min(74, $line.Length - $i))
    }
    $parts -join "`r`n"
}

$icons = @{
    phone    = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2.1 4.2 2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1 1 .4 1.9.7 2.8a2 2 0 0 1-.5 2.1L8 9.9a16 16 0 0 0 6 6l1.3-1.3a2 2 0 0 1 2.1-.4c.9.3 1.8.6 2.8.7a2 2 0 0 1 1.7 2z"/></svg>'
    text     = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>'
    email    = '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="2" y="4" width="20" height="16" rx="2"/><path d="m22 7-10 6L2 7"/></svg>'
    website  = '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="10"/><path d="M2 12h20M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg>'
    linkedin = '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="2" y="2" width="20" height="20" rx="4"/><path d="M7 10v7M7 7v.01M11 17v-4a2 2 0 0 1 4 0v4M11 10v7"/></svg>'
}

# Small logo for the contact photo and the phone home-screen icon (made once from the big PNG)
$logo256 = Join-Path $root 'assets\logo-256.png'
if (-not (Test-Path $logo256)) {
    Add-Type -AssemblyName System.Drawing
    $src = [System.Drawing.Image]::FromFile((Join-Path $root 'assets\logo.png'))
    $bmp = New-Object System.Drawing.Bitmap 256, 256
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.Clear([System.Drawing.Color]::White)
    $g.DrawImage($src, 0, 0, 256, 256)
    $bmp.Save($logo256, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose(); $src.Dispose()
}
$photo = [Convert]::ToBase64String([IO.File]::ReadAllBytes($logo256))

$template = [IO.File]::ReadAllText((Join-Path $root 'template.html'))
$people = Get-Content -Raw (Join-Path $root 'people.json') | ConvertFrom-Json

foreach ($p in $people) {
    $hide = @($p.hide)
    function Has($field) { $p.$field -and ($hide -notcontains $field) }

    $name = "$($p.first) $($p.last)"
    $digits = ($p.mobile -replace '\D', '')
    if ($digits.Length -eq 10) { $digits = '1' + $digits }
    $tel = '+' + $digits
    $phoneShown = if ($digits.Length -eq 11 -and $digits[0] -eq '1') {
        '({0}) {1}-{2}' -f $digits.Substring(1, 3), $digits.Substring(4, 3), $digits.Substring(7)
    } else { $p.mobile }

    $actions = @()
    $details = @()
    if (Has 'mobile') {
        $actions += "    <a href=""tel:$tel"">$($icons.phone)Call</a>"
        $actions += "    <a href=""sms:$tel"">$($icons.text)Text</a>"
        $details += "    <li><a href=""tel:$tel"">$($icons.phone)<span><small>Mobile</small>$(Html $phoneShown)</span></a></li>"
    }
    if (Has 'email') {
        $actions += "    <a href=""mailto:$($p.email)"">$($icons.email)Email</a>"
        $details += "    <li><a href=""mailto:$($p.email)"">$($icons.email)<span><small>Email</small>$(Html $p.email)</span></a></li>"
    }
    if (Has 'website') {
        $shown = $p.website -replace '^https?://(www\.)?', '' -replace '/$', ''
        $details += "    <li><a href=""$($p.website)"">$($icons.website)<span><small>Website</small>$(Html $shown)</span></a></li>"
    }
    if (Has 'linkedin') {
        $shown = $p.linkedin -replace '^https?://(www\.)?', '' -replace '/$', ''
        $details += "    <li><a href=""$($p.linkedin)"">$($icons.linkedin)<span><small>LinkedIn</small>$(Html $shown)</span></a></li>"
    }

    $vcfName = "$($p.slug).vcf"
    $page = $template.
        Replace('{{NAME}}', (Html $name)).
        Replace('{{TITLE}}', (Html $p.title)).
        Replace('{{COMPANY}}', (Html $p.company)).
        Replace('{{VCF}}', $vcfName).
        Replace('{{ACTIONS}}', ($actions -join "`n")).
        Replace('{{DETAILS}}', ($details -join "`n"))

    $v = @(
        'BEGIN:VCARD'
        'VERSION:3.0'
        "N:$(VEsc $p.last);$(VEsc $p.first);;;"
        "FN:$(VEsc $name)"
        "ORG:$(VEsc $p.company)"
        "TITLE:$(VEsc $p.title)"
    )
    if (Has 'mobile')   { $v += "TEL;TYPE=CELL,VOICE:$tel" }
    if (Has 'email')    { $v += "EMAIL;TYPE=INTERNET,WORK:$($p.email)" }
    if (Has 'website')  { $v += "URL:$($p.website)" }
    if (Has 'linkedin') { $v += "X-SOCIALPROFILE;TYPE=linkedin:$($p.linkedin)"; $v += "URL;TYPE=LinkedIn:$($p.linkedin)" }
    $v += "PHOTO;ENCODING=b;TYPE=PNG:$photo"
    $v += 'END:VCARD'
    $vcard = (($v | ForEach-Object { Fold $_ }) -join "`r`n") + "`r`n"

    $dir = Join-Path $root "team\$($p.slug)"
    New-Item -ItemType Directory -Force $dir | Out-Null
    [IO.File]::WriteAllText((Join-Path $dir 'index.html'), $page, $utf8)
    [IO.File]::WriteAllText((Join-Path $dir $vcfName), $vcard, $utf8)
    Write-Host "Built team/$($p.slug)/"
}
