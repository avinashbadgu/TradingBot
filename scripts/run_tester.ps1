param([string]$Symbol='EURUSD',[string]$From='2025.01.01',[string]$To='2025.04.01',[string]$Run='baseline',[string]$PresetPath,[switch]$Visual,[switch]$LogicTests,[switch]$IntegrationChecks,[switch]$Optimize)
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$deployment=Get-Content -LiteralPath (Join-Path $project 'deployment.json') -Raw | ConvertFrom-Json
if (-not $deployment.installed) { throw 'Install the compiled EA first.' }
if (Get-Process terminal64 -ErrorAction SilentlyContinue) { throw 'Terminal is running. Close it yourself or use its Strategy Tester manually; this script will not restart it.' }
if ($Symbol -notmatch '^[A-Za-z0-9_.#-]+$' -or $Run -notmatch '^[A-Za-z0-9_-]+$') { throw 'Invalid symbol/run identifier.' }
$preset=Join-Path $deployment.data_path 'MQL5\Profiles\Tester\TradingBot_Run.set'
$presetSource=if($PresetPath){$PresetPath}else{Join-Path $project 'MT5\Config\TradingBot_Default.set'}
$settings=Get-Content -LiteralPath $presetSource
$settings=$settings | Where-Object {$_ -notmatch '^ExecutionMode='}
$settings+= 'ExecutionMode=0'
$settings=$settings -replace '^RunId=.*$',("RunId="+$Run)
$settings | Set-Content -LiteralPath $preset -Encoding Unicode
$report=Join-Path $project ('Backtests\'+$Run)
$visualFlag=if($Visual){1}else{0}
$expert=if($LogicTests){'LogicTests.ex5'}elseif($IntegrationChecks){'IntegrationChecks.ex5'}else{'TradingBot.ex5'}
$model=if($LogicTests){3}else{4}
$modelName=if($LogicTests){'math_calculations'}else{'real_ticks'}
$optimizationMode=if($Optimize){1}else{0}
if($Optimize -and -not $PresetPath){throw 'Optimization requires an explicit reviewed preset.'}
if($LogicTests){$From='2025.01.01';$To='2025.01.02'}
$config=@"
[Experts]
Enabled=0
AllowLiveTrading=0
AllowDllImport=0
[Tester]
Expert=TradingBot\$expert
ExpertParameters=TradingBot_Run.set
Symbol=$Symbol
Period=M5
Model=$model
ExecutionMode=100
Optimization=$optimizationMode
OptimizationCriterion=6
FromDate=$From
ToDate=$To
ForwardMode=0
Deposit=10000
Currency=USD
Leverage=1:100
Visual=$visualFlag
Report=$report
ReplaceReport=1
ShutdownTerminal=1
UseLocal=1
UseRemote=0
UseCloud=0
"@
$path=Join-Path $project ('MT5\Config\'+$Run+'.ini')
$config | Set-Content -LiteralPath $path -Encoding Unicode
$launch=@{FilePath=(Join-Path $deployment.installation 'terminal64.exe');ArgumentList=('/config:"'+$path+'"');PassThru=$true}
if(-not $Visual){$launch.WindowStyle='Hidden'}
$launchUtc=(Get-Date).ToUniversalTime().ToString('o')
$process=Start-Process @launch
$binaryHash=(Get-FileHash -LiteralPath (Join-Path $deployment.data_path ('MQL5\Experts\TradingBot\'+$expert))).Hash
[ordered]@{pid=$process.Id;run=$Run;config=$path;launched_utc=$launchUtc;binary_sha256=$binaryHash;status='launched_not_verified';symbol=$Symbol;from=$From;to=$To;model=$modelName;delay_ms=100} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $project ('Backtests\'+$Run+'_launch.json')) -Encoding UTF8
Write-Output ('Tester launched, PID '+$process.Id+'. Verify logs and report before treating this as a completed backtest.')
