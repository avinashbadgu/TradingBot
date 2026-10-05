param([string]$DataPath, [switch]$Install)
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$origins = @(Get-ChildItem -LiteralPath (Join-Path $env:APPDATA 'MetaQuotes\Terminal') -Filter origin.txt -Recurse -ErrorAction SilentlyContinue)
$candidates = @($origins | ForEach-Object {
    $installPath = (Get-Content -LiteralPath $_.FullName -Raw).Trim()
    if (Test-Path -LiteralPath (Join-Path $installPath 'MetaEditor64.exe')) {
        [pscustomobject]@{ Data = $_.DirectoryName; Install = $installPath }
    }
})
if ($DataPath) { $candidates = @($candidates | Where-Object { $_.Data -eq $DataPath }) }
if ($candidates.Count -ne 1) { $candidates | Format-Table; throw 'Select the intended data folder explicitly with -DataPath.' }
$target = $candidates[0]
$source = Join-Path $project 'MT5\Experts\TradingBot'
$main = Join-Path $source 'TradingBot.mq5'
$log = Join-Path $project 'compile.log'
$compiler = Start-Process -FilePath (Join-Path $target.Install 'MetaEditor64.exe') -ArgumentList @('/compile:"' + $main + '"', '/log:"' + $log + '"') -WindowStyle Hidden -PassThru
if (-not $compiler.WaitForExit(60000)) { throw 'Compilation timed out; inspect MetaEditor.' }
$result = Get-Content -LiteralPath $log -Raw
if ($result -notmatch '0 errors, 0 warnings') { throw $result }
$binary = Join-Path $source 'TradingBot.ex5'
if (-not (Test-Path -LiteralPath $binary)) { throw 'No compiled artifact.' }
$qa = Join-Path $source 'LogicTests.mq5'
$qaLog = Join-Path $project 'compile_logic_tests.log'
$qaCompiler = Start-Process -FilePath (Join-Path $target.Install 'MetaEditor64.exe') -ArgumentList @('/compile:"' + $qa + '"', '/log:"' + $qaLog + '"') -WindowStyle Hidden -PassThru
if (-not $qaCompiler.WaitForExit(60000)) { throw 'QA compilation timed out.' }
if ((Get-Content -LiteralPath $qaLog -Raw) -notmatch '0 errors, 0 warnings') { throw (Get-Content -LiteralPath $qaLog -Raw) }
$integration = Join-Path $source 'IntegrationChecks.mq5'
$integrationLog = Join-Path $project 'compile_integration.log'
$integrationCompiler = Start-Process -FilePath (Join-Path $target.Install 'MetaEditor64.exe') -ArgumentList @('/compile:"' + $integration + '"', '/log:"' + $integrationLog + '"') -WindowStyle Hidden -PassThru
if (-not $integrationCompiler.WaitForExit(60000)) { throw 'Integration-check compilation timed out.' }
if ((Get-Content -LiteralPath $integrationLog -Raw) -notmatch '0 errors, 0 warnings') { throw (Get-Content -LiteralPath $integrationLog -Raw) }
$manifest = [ordered]@{ compiled = $true; installed = $false; data_path = $target.Data; installation = $target.Install; binary_sha256 = (Get-FileHash -LiteralPath $binary).Hash; verified_at = (Get-Date).ToUniversalTime().ToString('o'); navigator_verified = $false; tester_selected = $false }
if ($Install) {
    $destination = Join-Path $target.Data 'MQL5\Experts\TradingBot'
    if (Test-Path -LiteralPath $destination) {
        $backup = Join-Path $project ('Backtests\deployment_backup_' + (Get-Date -Format yyyyMMdd_HHmmss))
        Copy-Item -LiteralPath $destination -Destination $backup -Recurse
    }
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Get-ChildItem -LiteralPath $source -File | Copy-Item -Destination $destination
    $presetDir = Join-Path $target.Data 'MQL5\Profiles\Tester'
    New-Item -ItemType Directory -Path $presetDir -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $project 'MT5\Config\TradingBot_Default.set') -Destination $presetDir
    $manifest.installed = $true
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $project 'deployment.json') -Encoding UTF8
$manifest | ConvertTo-Json
