[CmdletBinding()]
param([Parameter(Mandatory)][string]$ContextPath,[ValidateSet(256,1024)][int]$Budget=256)
$ErrorActionPreference='Stop'
$runner=Join-Path $PSScriptRoot '../../invoke-factory-passage-qc.ps1'
$record=Get-Content -LiteralPath $ContextPath -Raw | ConvertFrom-Json
function Invoke-Step([hashtable]$Options) {
    & $runner -ContextPath $ContextPath @Options
    if (-not $?) { throw 'Factory passage performance step failed.' }
}
foreach ($count in @(10000,100000)) {
    foreach ($burst in @($false,$true)) {
        $kind=if($burst){'burst'}else{'idle'}
        foreach ($mode in @('vanilla','esir')) {
            $label="$count-$mode-$kind"
            Invoke-Step @{Phase='Configure';PipeMode=$mode;Performance=$count;Budget=$Budget;Burst=$burst}
            Invoke-Step @{Phase='Create';Label=$label}
            Invoke-Step @{Phase='Settle';Label=$label}
        }
        for ($trial=1;$trial -le 5;$trial++) {
            $order=if($trial%2){@('vanilla','esir')}else{@('esir','vanilla')}
            foreach ($mode in $order) {
                $label="$count-$mode-$kind"
                Invoke-Step @{Phase='Configure';PipeMode=$mode;Performance=$count;Budget=$Budget;Burst=$burst}
                $save=Join-Path $record.write_data "$label-settled.zip"
                $accepted=$false
                for($attempt=1;$attempt -le 5;$attempt++) {
                    try {
                        Invoke-Step @{Phase='Run';Label="$label-$trial";Save=$save;Ticks=$(if($burst){1000}else{6000});ExpectedReceipt="performance-$kind"}
                        $accepted=$true;break
                    } catch {
                        $monitorPath=Join-Path $record.evidence "$label-$trial-monitor.json"
                        $monitor=if(Test-Path -LiteralPath $monitorPath){Get-Content -LiteralPath $monitorPath -Raw | ConvertFrom-Json}else{$null}
                        if(-not $monitor -or $monitor.isolated){throw}
                        Copy-Item -LiteralPath $monitorPath -Destination (Join-Path $record.evidence "$label-$trial-rejected-overlap-$attempt.json")
                        Write-Output "Rejected overlapping measurement; waiting to retry $label / $trial."
                    }
                }
                if(-not $accepted){throw "Repeated external Factorio overlap prevented $label / $trial."}
                Write-Output "Accepted $count / $mode / $kind / trial $trial"
            }
        }
    }
}
python (Join-Path $PSScriptRoot 'performance.py') --context $ContextPath
if ($LASTEXITCODE -ne 0) { throw 'Performance acceptance failed.' }
