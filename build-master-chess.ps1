# Builds the Playgama release zip (master-chess.zip) containing ONLY the assets the
# single-file HTML5 game actually references. Keeps the upload artifact tiny.
# Usage: powershell -ExecutionPolicy Bypass -File build-master-chess.ps1

$ErrorActionPreference = 'Stop'
$Root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$Zip    = Join-Path $Root 'master-chess.zip'
$Stage  = Join-Path $env:TEMP 'master-chess-build'

Write-Host "Sourcing game files from: $Root"

# --- Staging: clean copy of just what the game needs ---
if (Test-Path $Stage) { Remove-Item $Stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $Stage | Out-Null
foreach ($d in 'public\images','public\piece\cburnett','public\assets\supreme-spike-font') {
  $destDir = Join-Path $Stage (Split-Path $d -Parent)
  New-Item -ItemType Directory -Force -Path $destDir | Out-Null
  Copy-Item (Join-Path $Root $d) $destDir -Recurse -Force
}

Copy-Item (Join-Path $Root 'index.html') (Join-Path $Stage 'index.html')
Copy-Item (Join-Path $Root 'playgama-bridge-config.json') (Join-Path $Stage 'playgama-bridge-config.json')

New-Item -ItemType Directory -Force -Path (Join-Path $Stage 'public\vendor') | Out-Null
Copy-Item (Join-Path $Root 'public\vendor\chess.min.js') (Join-Path $Stage 'public\vendor\chess.min.js')
Copy-Item (Join-Path $Root 'public\vendor\confetti.browser.min.js') (Join-Path $Stage 'public\vendor\confetti.browser.min.js')

New-Item -ItemType Directory -Force -Path (Join-Path $Stage 'public\font') | Out-Null
foreach ($f in 'noto-sans-latin.woff2','noto-sans-latin-ext.woff2','roboto-latin.woff2') {
  Copy-Item (Join-Path $Root "public\font\$f") (Join-Path $Stage 'public\font')
}

New-Item -ItemType Directory -Force -Path (Join-Path $Stage 'public\sound2\sfx') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Stage 'public\sound2\standard') | Out-Null
foreach ($f in 'Check.mp3','Defeat.mp3','Draw.mp3','GenericNotify.mp3','Heartbeat.mp3','Victory.mp3') {
  Copy-Item (Join-Path $Root "public\sound2\sfx\$f") (Join-Path $Stage 'public\sound2\sfx')
}
foreach ($f in 'Capture.mp3','Confirmation.mp3','Explosion.mp3','Move.mp3','Select.mp3') {
  Copy-Item (Join-Path $Root "public\sound2\standard\$f") (Join-Path $Stage 'public\sound2\standard')
}

# --- zip it (deflate), relative paths so archive has index.html + public at root ---
if (Test-Path $Zip) { Remove-Item $Zip -Force }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$dest = [System.IO.Compression.ZipFile]::Open($Zip,'Create')
try {
  $base = (Resolve-Path $Stage).Path
  Get-ChildItem $Stage -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($base.Length + 1).Replace('\','/')
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($dest,$_.FullName,$rel,'Optimal') | Out-Null
  }
} finally { $dest.Dispose() }

$stageSize = (Get-ChildItem $Stage -Recurse -File | Measure-Object Length -Sum).Sum
$fileCount = (Get-ChildItem $Stage -Recurse -File).Count
$zipSize   = (Get-Item $Zip).Length
Write-Host "Packaged $fileCount files."
Write-Host ('Staged (uncompressed) size: {0:N2} MB' -f ($stageSize / 1MB))
Write-Host ('Zip size:                   {0:N2} MB' -f ($zipSize / 1MB))
if ($zipSize -gt (30MB)) { throw 'Result zip exceeds 30MB - aborting.' }
Write-Host "OK: master-chess.zip ready at $Zip"
