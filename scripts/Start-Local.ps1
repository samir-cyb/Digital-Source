$Port=8000
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$env:PYTHONPATH="$projectRoot;$projectRoot\backend\.deps"
$env:TEMP="$projectRoot\work"
$env:TMP=$env:TEMP
New-Item -ItemType Directory -Force -Path $env:TEMP | Out-Null
if (!(Test-Path -LiteralPath "$projectRoot\backend\.deps\fastapi")) {
    python -m pip install --target backend/.deps -r backend/requirements.lock.txt
    if ($LASTEXITCODE -ne 0) { throw 'Backend dependency installation failed.' }
}
python -m backend.app.seed
if ($LASTEXITCODE -ne 0) { throw 'Database initialization failed.' }
$access="$projectRoot\work\local-access.txt"
if (Test-Path -LiteralPath $access) { Get-Content -LiteralPath $access }
Write-Host "Open http://localhost:$Port in your browser."
Write-Host 'Development mode only. Press Ctrl+C to stop.'
python -m uvicorn backend.app.main:app --host 127.0.0.1 --port $Port

