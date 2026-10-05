param([Parameter(Mandatory=$true)][string]$JobsPath)
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$jobs=ConvertFrom-Json -InputObject (Get-Content -LiteralPath $JobsPath -Raw)
foreach($job in $jobs) {
    Write-Output ('START '+$job.run+' '+$job.symbol+' '+$job.from+' to '+$job.to)
    $arguments=@{Symbol=$job.symbol;From=$job.from;To=$job.to;Run=$job.run}
    if($job.preset){$arguments.PresetPath=$job.preset}
    if($job.optimize){$arguments.Optimize=$true}
    if($job.integration){$arguments.IntegrationChecks=$true}
    & (Join-Path $PSScriptRoot 'run_tester.ps1') @arguments
    $launch=Get-Content -LiteralPath (Join-Path $project ('Backtests\'+$job.run+'_launch.json')) -Raw | ConvertFrom-Json
    $started=Get-Date
    while(Get-Process -Id $launch.pid -ErrorAction SilentlyContinue) {
        Start-Sleep -Seconds 5
        if(((Get-Date)-$started).TotalMinutes -gt 20){throw ('Test exceeded 20 minutes: '+$job.run+'. It has been left running for inspection.')}
    }
    $deployment=Get-Content -LiteralPath (Join-Path $project 'deployment.json') -Raw | ConvertFrom-Json
    $log=Join-Path $deployment.data_path ('Tester\logs\'+(Get-Date -Format yyyyMMdd)+'.log')
    Get-Content -LiteralPath $log | Select-Object -Last 120 | Set-Content -LiteralPath (Join-Path $project ('Backtests\'+$job.run+'_terminal_tail.log')) -Encoding UTF8
    if($job.optimize) {
        $files=@(Get-ChildItem -LiteralPath (Join-Path $deployment.data_path 'MQL5\Files') -Filter ('TradingBot_'+$job.run+'*_optimization.csv'))
        if($files.Count -ne 1){throw ('Optimization export absent/ambiguous: '+$job.run)}
        Copy-Item -LiteralPath $files[0].FullName -Destination (Join-Path $project 'Backtests')
    } else {
        & (Join-Path $PSScriptRoot 'collect_exports.ps1') -Run $job.run
        $agentRoot=Join-Path (Join-Path $env:APPDATA 'MetaQuotes\Tester') (Split-Path $deployment.data_path -Leaf)
        & (Join-Path $project '.venv\Scripts\python.exe') (Join-Path $project 'Research\log_evidence.py') --logs $agentRoot --output (Join-Path $project 'Backtests')
        if($LASTEXITCODE -ne 0){throw ('Log evidence collection failed: '+$job.run)}
    }
    Write-Output ('FINISHED '+$job.run+'; exports collected, research verification still required')
}
