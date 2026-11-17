param(
  [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$releaseDir = Join-Path $root "build\windows\x64\runner\$Configuration"
if (-not (Test-Path (Join-Path $releaseDir "second_brain.exe"))) {
  throw "Сначала выполните: flutter build windows --$($Configuration.ToLower())"
}

$isccPath = (Get-Command iscc.exe -ErrorAction SilentlyContinue).Source
if (-not $isccPath) {
  $candidates = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe"
  )
  foreach ($candidate in $candidates) {
    if (Test-Path $candidate) {
      $isccPath = $candidate
      break
    }
  }
}
if (-not $isccPath) {
  throw "Inno Setup 6 не найден. Установите: choco install innosetup -y"
}

$iss = Join-Path $root "installer\second_brain.iss"
$redist = Join-Path $root "installer\vc_redist.x64.exe"
if (-not (Test-Path $redist)) {
  Write-Host "Downloading Microsoft Visual C++ Redistributable..."
  Invoke-WebRequest `
    -Uri "https://aka.ms/vs/17/release/vc_redist.x64.exe" `
    -OutFile $redist `
    -UseBasicParsing
}
$dist = Join-Path $root "dist"
New-Item -ItemType Directory -Force -Path $dist | Out-Null
Push-Location $root
try {
  & $isccPath $iss
  if ($LASTEXITCODE -ne 0) {
    throw "ISCC завершился с кодом $LASTEXITCODE"
  }
  Get-ChildItem $dist -Filter "SecondBrain-*-setup.exe" |
    Select-Object FullName, Length, LastWriteTime
} finally {
  Pop-Location
}
