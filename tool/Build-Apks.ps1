# Builds both editions of Slip as release APKs into dist/:
#   Slip-Free-<version>.apk  "Slip Free"  everything typed by hand, nothing leaves the phone
#   Slip-AI-<version>.apk    "Slip"       reads receipts with the AI reader (needs app/secrets.json)
# Run from anywhere:  powershell -File tool\Build-Apks.ps1
$ErrorActionPreference = 'Stop'
Set-Location "$PSScriptRoot\..\app"
$version = (Select-String '^version:\s*(\S+)' pubspec.yaml).Matches[0].Groups[1].Value
$dist = "$PSScriptRoot\..\dist"
New-Item -ItemType Directory -Force $dist | Out-Null

flutter build apk --release --flavor free --dart-define=SLIP_EDITION=free
Copy-Item build\app\outputs\flutter-apk\app-free-release.apk "$dist\Slip-Free-$version.apk"

if (Test-Path secrets.json) {
  flutter build apk --release --flavor ai --dart-define=SLIP_EDITION=ai --dart-define-from-file=secrets.json
  Copy-Item build\app\outputs\flutter-apk\app-ai-release.apk "$dist\Slip-AI-$version.apk"
} else {
  Write-Warning 'app/secrets.json is missing, so the AI edition would have no reader; skipped it.'
}

Get-ChildItem $dist | Select-Object Name, @{n = 'MB'; e = { [math]::Round($_.Length / 1MB, 1) } }
