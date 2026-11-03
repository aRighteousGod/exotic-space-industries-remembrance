[CmdletBinding()]
param([Parameter(Mandatory)][string]$ContextPath,
    [ValidateSet('modes','transitions','switches','actors')][string]$Group='modes',
    [string[]]$Modes=@('esir','squeak-through','vanilla'),[switch]$Render)
$ErrorActionPreference='Stop'
$runner=Join-Path $PSScriptRoot '../../invoke-factory-passage-qc.ps1'
$record=Get-Content -LiteralPath $ContextPath -Raw | ConvertFrom-Json
function Invoke-Step([hashtable]$Options) {
    & $runner -ContextPath $ContextPath @Options
    if (-not $?) { throw 'Factory passage matrix step failed.' }
}
if ($Group -eq 'modes') {
    foreach ($mode in $Modes) {
        $label="full-$mode"
        Invoke-Step @{Phase='Configure';PipeMode=$mode;Render=$Render}
        Invoke-Step @{Phase='Create';Label=$label}
        Invoke-Step @{Phase='Run';Label=$label;Ticks=110}
        Invoke-Step @{Phase='Settle';Label=$label}
        if ($Render) { Invoke-Step @{Phase='Visual';Label="$mode-visual";Save=(Join-Path $record.write_data "$label.zip");ExpectedReceipt='visual'} }
        Write-Output "Accepted mode: $mode"
    }
} elseif ($Group -eq 'transitions') {
    foreach ($from in @('esir','squeak-through','vanilla')) {
        foreach ($to in @('esir','squeak-through','vanilla')) {
            if ($from -eq $to) { continue }
            Invoke-Step @{Phase='Configure';PipeMode=$to}
            Invoke-Step @{Phase='Run';Label="$from-to-$to";Save=(Join-Path $record.write_data "full-$from-settled.zip");ExpectedReceipt='transition'}
            Write-Output "Accepted transition: $from -> $to"
        }
    }
    Invoke-Step @{Phase='Configure';PipeMode='esir';Render=$Render}
    Invoke-Step @{Phase='Run';Label='full-reload';Save=(Join-Path $record.write_data 'full-esir-settled.zip');ExpectedReceipt='reload'}
} elseif ($Group -eq 'switches') {
    Invoke-Step @{Phase='Configure';PipeMode='esir';Disabled=$true;Render=$Render}
    Invoke-Step @{Phase='Run';Label='full-master-off';Save=(Join-Path $record.write_data 'full-esir-settled.zip');ExpectedReceipt='transition'}
    Invoke-Step @{Phase='Settle';Label='full-master-off';Save=(Join-Path $record.write_data 'full-esir-settled.zip');ExpectedReceipt='transition'}
    if ($Render) {
        Invoke-Step @{Phase='Create';Label='master-off-visual'}
        Invoke-Step @{Phase='Visual';Label='master-off-visual';ExpectedReceipt='visual'}
    }
    Invoke-Step @{Phase='Configure';PipeMode='esir'}
    Invoke-Step @{Phase='Run';Label='full-master-on';Save=(Join-Path $record.write_data 'full-master-off-settled.zip');ExpectedReceipt='transition'}
    foreach ($category in @('production','power','logistics','turrets')) {
        Invoke-Step @{Phase='Configure';PipeMode='esir';DisabledCategory=$category}
        Invoke-Step @{Phase='Create';Label="$category-off"}
        Invoke-Step @{Phase='Run';Label="$category-off"}
        Write-Output "Accepted category switch: $category"
    }
} else {
    Invoke-Step @{Phase='Configure';PipeMode='esir';Actors=$true}
    Invoke-Step @{Phase='Create';Label='actors'}
    Invoke-Step @{Phase='Visual';Label='actors';ExpectedReceipt='actors'}
}
