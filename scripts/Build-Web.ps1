$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$env:FLUTTER_SUPPRESS_ANALYTICS='true'
$env:DART_SUPPRESS_ANALYTICS='true'
$env:PUB_CACHE="$projectRoot\work\pub-cache"
$env:TEMP="$projectRoot\work"
$env:TMP=$env:TEMP
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'Analysis failed.' }
flutter test --no-pub
if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
flutter build web --release --no-pub --no-wasm-dry-run
if ($LASTEXITCODE -ne 0) { throw 'Web build failed.' }

