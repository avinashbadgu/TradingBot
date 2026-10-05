param([string]$Run='baseline')
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$deployment=Get-Content -LiteralPath (Join-Path $project 'deployment.json') -Raw | ConvertFrom-Json
$destination=Join-Path $project ('Backtests\'+$Run+'_exports')
New-Item -ItemType Directory -Path $destination -Force | Out-Null
$roots=@((Join-Path $env:APPDATA 'MetaQuotes\Tester'),(Join-Path $deployment.data_path 'Tester'))
$files=@(foreach($root in $roots){Get-ChildItem -LiteralPath $root -Filter ('TradingBot_'+$Run+'_*.csv') -Recurse -ErrorAction SilentlyContinue})
if($files.Count -eq 0){throw 'No exported run files found; this is not a completed backtest.'}
$launchPath=Join-Path $project ('Backtests\'+$Run+'_launch.json')
if(Test-Path -LiteralPath $launchPath) {
    $launch=Get-Content -LiteralPath $launchPath -Raw | ConvertFrom-Json
    if($launch.launched_utc) {
        $launchUtc=[datetime]::Parse($launch.launched_utc).ToUniversalTime()
        if(@($files | Where-Object {$_.LastWriteTimeUtc -lt $launchUtc}).Count -gt 0) {
            throw 'Stale exports predate this launch; do not treat them as current results.'
        }
    }
}
foreach($group in ($files | Group-Object Name)) {
    if($group.Count -gt 1){throw ('Ambiguous exports from multiple agents: '+$group.Name+'. Select the verified run manually.')}
    Copy-Item -LiteralPath $group.Group[0].FullName -Destination $destination
}
Get-ChildItem -LiteralPath $destination | Select-Object Name,Length
