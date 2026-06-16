Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FactorioLuaDocsPaths {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [switch]$EnsureCacheRoot
    )

    $resolvedRepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
    $cacheRoot = Join-Path $resolvedRepoRoot '.factorio-lua-docs-cache'
    if ($EnsureCacheRoot) {
        New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null
    }

    return [pscustomobject]@{
        repo_root            = $resolvedRepoRoot
        cache_root           = $cacheRoot
        runtime_json_path    = Join-Path $cacheRoot 'runtime-api.json'
        prototype_json_path  = Join-Path $cacheRoot 'prototype-api.json'
        index_path           = Join-Path $cacheRoot 'doc-index.json'
        source_manifest_path = Join-Path $cacheRoot 'source-manifest.json'
    }
}

function Write-FactorioLuaDocsJson {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Data
    )

    $directory = Split-Path -Parent $Path
    if ($directory) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }

    $json = $Data | ConvertTo-Json -Depth 32
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
}

function Read-FactorioLuaDocsJson {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $text = [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false, $true))
    return ($text | ConvertFrom-Json)
}

function Get-FactorioLuaDocsSourceMap {
    $auxiliaryTopics = @(
        [ordered]@{ id = 'data-lifecycle'; title = 'Data Lifecycle'; stage = 'auxiliary'; url = 'https://lua-api.factorio.com/latest/auxiliary/data-lifecycle.html' }
        [ordered]@{ id = 'storage'; title = 'Storage'; stage = 'auxiliary'; url = 'https://lua-api.factorio.com/latest/auxiliary/storage.html' }
        [ordered]@{ id = 'mod-structure'; title = 'Mod Structure'; stage = 'auxiliary'; url = 'https://lua-api.factorio.com/latest/auxiliary/mod-structure.html' }
        [ordered]@{ id = 'changelog-format'; title = 'Changelog Format'; stage = 'auxiliary'; url = 'https://lua-api.factorio.com/latest/auxiliary/changelog-format.html' }
        [ordered]@{ id = 'libraries'; title = 'Libraries and functions'; stage = 'auxiliary'; url = 'https://lua-api.factorio.com/latest/auxiliary/libraries.html' }
        [ordered]@{ id = 'migrations'; title = 'Migrations'; stage = 'auxiliary'; url = 'https://lua-api.factorio.com/latest/auxiliary/migrations.html' }
        [ordered]@{ id = 'prototype-tree'; title = 'Prototype Inheritance Tree'; stage = 'auxiliary'; url = 'https://lua-api.factorio.com/latest/auxiliary/prototype-tree.html' }
        [ordered]@{ id = 'noise-expressions'; title = 'Noise Expressions'; stage = 'auxiliary'; url = 'https://lua-api.factorio.com/latest/auxiliary/noise-expressions.html' }
        [ordered]@{ id = 'instrument-mode'; title = 'Instrument Mode'; stage = 'auxiliary'; url = 'https://lua-api.factorio.com/latest/auxiliary/instrument.html' }
        [ordered]@{ id = 'item-weight'; title = 'Item Weight'; stage = 'auxiliary'; url = 'https://lua-api.factorio.com/latest/auxiliary/item-weight.html' }
        [ordered]@{ id = 'runtime-json-format'; title = 'Runtime JSON Format'; stage = 'auxiliary'; url = 'https://lua-api.factorio.com/latest/auxiliary/json-docs-runtime.html' }
        [ordered]@{ id = 'prototype-json-format'; title = 'Prototype JSON Format'; stage = 'auxiliary'; url = 'https://lua-api.factorio.com/latest/auxiliary/json-docs-prototype.html' }
        [ordered]@{ id = 'defines'; title = 'Defines'; stage = 'auxiliary'; url = 'https://lua-api.factorio.com/latest/defines.html' }
    )

    $wikiTopics = @(
        [ordered]@{ id = 'tutorial-scripting'; title = 'Tutorial:Scripting'; stage = 'wiki'; url = 'https://wiki.factorio.com/Tutorial:Scripting' }
        [ordered]@{ id = 'tutorial-script-interfaces'; title = 'Tutorial:Script interfaces'; stage = 'wiki'; url = 'https://wiki.factorio.com/Tutorial:Script_interfaces' }
        [ordered]@{ id = 'tutorial-localisation'; title = 'Tutorial:Localisation'; stage = 'wiki'; url = 'https://wiki.factorio.com/Tutorial:Localisation' }
        [ordered]@{ id = 'scenario-system'; title = 'Scenario System'; stage = 'wiki'; url = 'https://wiki.factorio.com/Scenario_system' }
        [ordered]@{ id = 'command-line-parameters'; title = 'Command line parameters'; stage = 'wiki'; url = 'https://wiki.factorio.com/Command_line_parameters' }
        [ordered]@{ id = 'console'; title = 'Console'; stage = 'wiki'; url = 'https://wiki.factorio.com/Console' }
        [ordered]@{ id = 'data-raw'; title = 'data.raw'; stage = 'wiki'; url = 'https://wiki.factorio.com/Data.raw' }
        [ordered]@{ id = 'modding-tutorial'; title = 'Tutorial:Modding tutorial'; stage = 'wiki'; url = 'https://wiki.factorio.com/Tutorial:Modding_tutorial/Gangsir' }
        [ordered]@{ id = 'copyrights'; title = 'Factorio:Copyrights'; stage = 'wiki'; url = 'https://wiki.factorio.com/Factorio:Copyrights' }
    )

    return [ordered]@{
        runtime_api_url   = 'https://lua-api.factorio.com/latest/runtime-api.json'
        prototype_api_url = 'https://lua-api.factorio.com/latest/prototype-api.json'
        license_url       = 'https://lua-api.factorio.com/latest/license.html'
        auxiliary_topics  = $auxiliaryTopics
        wiki_topics       = $wikiTopics
    }
}

function ConvertFrom-FactorioLuaDocsMarkdown {
    param([AllowEmptyString()][string]$Text)

    if ($null -eq $Text) {
        return ''
    }

    $plain = $Text
    $plain = [regex]::Replace($plain, '\[(?<label>[^\]]+)\]\([^)]+\)', '${label}')
    $plain = [regex]::Replace($plain, '`+', '')
    $plain = [regex]::Replace($plain, '\s+', ' ')
    return $plain.Trim()
}

function Get-FactorioLuaDocsShortText {
    param(
        [AllowEmptyString()][string]$Text,
        [int]$Length = 220
    )

    $plain = ConvertFrom-FactorioLuaDocsMarkdown -Text $Text
    if ($plain.Length -le $Length) {
        return $plain
    }

    return ($plain.Substring(0, [Math]::Max(0, $Length - 3)).TrimEnd() + '...')
}

function ConvertFrom-FactorioLuaDocsHtml {
    param([AllowEmptyString()][string]$Html)

    if ($null -eq $Html) {
        return ''
    }

    $text = $Html
    $text = [regex]::Replace($text, '(?is)<script.*?</script>', ' ')
    $text = [regex]::Replace($text, '(?is)<style.*?</style>', ' ')
    $text = [regex]::Replace($text, '(?i)<br\s*/?>', "`n")
    $text = [regex]::Replace($text, '(?is)<[^>]+>', ' ')
    $text = [System.Net.WebUtility]::HtmlDecode($text)
    $text = [regex]::Replace($text, '\s+', ' ')
    return $text.Trim()
}

function Get-FactorioLuaDocsHtmlTitle {
    param([AllowEmptyString()][string]$Html)

    if ($null -eq $Html) {
        return $null
    }

    $match = [regex]::Match($Html, '(?is)<title>\s*(?<title>.*?)\s*</title>')
    if ($match.Success) {
        return ([System.Net.WebUtility]::HtmlDecode($match.Groups['title'].Value)).Trim()
    }

    return $null
}

function Get-FactorioLuaDocsHtmlSummary {
    param([AllowEmptyString()][string]$Html)

    if ($null -eq $Html) {
        return ''
    }

    $paragraphs = [regex]::Matches($Html, '(?is)<p[^>]*>(?<text>.*?)</p>')
    $chunks = [System.Collections.Generic.List[string]]::new()
    foreach ($paragraph in $paragraphs) {
        $text = ConvertFrom-FactorioLuaDocsHtml -Html $paragraph.Groups['text'].Value
        if ([string]::IsNullOrWhiteSpace($text)) {
            continue
        }
        $chunks.Add($text) | Out-Null
        if ($chunks.Count -ge 2) {
            break
        }
    }

    return Get-FactorioLuaDocsShortText -Text ($chunks -join ' ')
}

function Get-FactorioLuaDocsRuntimeUrl {
    param(
        [Parameter(Mandatory = $true)][string]$Kind,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$Parent
    )

    switch ($Kind) {
        'class' { return "https://lua-api.factorio.com/latest/classes/$Name.html" }
        'method' { return "https://lua-api.factorio.com/latest/classes/$Parent.html#$Name" }
        'attribute' { return "https://lua-api.factorio.com/latest/classes/$Parent.html#$Name" }
        'operator' { return "https://lua-api.factorio.com/latest/classes/$Parent.html#$Name" }
        'event' { return "https://lua-api.factorio.com/latest/events.html#$Name" }
        'concept' { return "https://lua-api.factorio.com/latest/concepts/$Name.html" }
        'concept-property' { return "https://lua-api.factorio.com/latest/concepts/$Parent.html#$Name" }
        'define' { return "https://lua-api.factorio.com/latest/defines.html#$Name" }
        'define-value' { return "https://lua-api.factorio.com/latest/defines.html#$Parent" }
        default { return 'https://lua-api.factorio.com/latest/index-runtime.html' }
    }
}

function Get-FactorioLuaDocsPrototypeUrl {
    param(
        [Parameter(Mandatory = $true)][string]$Kind,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$Parent
    )

    switch ($Kind) {
        'prototype' { return "https://lua-api.factorio.com/latest/prototypes/$Name.html" }
        'prototype-property' { return "https://lua-api.factorio.com/latest/prototypes/$Parent.html#$Name" }
        'type' { return "https://lua-api.factorio.com/latest/types/$Name.html" }
        'type-property' { return "https://lua-api.factorio.com/latest/types/$Parent.html#$Name" }
        'define' { return "https://lua-api.factorio.com/latest/defines.html#$Name" }
        'define-value' { return "https://lua-api.factorio.com/latest/defines.html#$Parent" }
        default { return 'https://lua-api.factorio.com/latest/index-prototype.html' }
    }
}

function New-FactorioLuaDocsEntry {
    param(
        [Parameter(Mandatory = $true)][string]$Stage,
        [Parameter(Mandatory = $true)][string]$Kind,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$Parent,
        [AllowEmptyString()][string]$Summary,
        [string]$Url,
        $Extra = $null
    )

    $entry = [ordered]@{
        stage   = $Stage
        kind    = $Kind
        name    = $Name
        symbol  = if ([string]::IsNullOrWhiteSpace($Parent)) { $Name } else { "$Parent::$Name" }
        summary = Get-FactorioLuaDocsShortText -Text $Summary
        url     = $Url
    }

    if (-not [string]::IsNullOrWhiteSpace($Parent)) {
        $entry.parent = $Parent
    }

    if ($Extra) {
        foreach ($property in $Extra.GetEnumerator()) {
            $entry[$property.Key] = $property.Value
        }
    }

    return $entry
}

function Add-FactorioLuaDocsDefineEntries {
    param(
        [Parameter(Mandatory = $true)]$Defines,
        [Parameter(Mandatory = $true)][string]$Stage,
        [Parameter(Mandatory = $true)]$Entries
    )

    foreach ($define in $Defines) {
        $defineName = [string]$define.name
        $baseUrl = if ($Stage -eq 'runtime') {
            Get-FactorioLuaDocsRuntimeUrl -Kind 'define' -Name $defineName
        } else {
            Get-FactorioLuaDocsPrototypeUrl -Kind 'define' -Name $defineName
        }

        $Entries.Add((New-FactorioLuaDocsEntry -Stage $Stage -Kind 'define' -Name $defineName -Summary $define.description -Url $baseUrl)) | Out-Null

        if ($define.PSObject.Properties.Name -contains 'values') {
            foreach ($value in @($define.values)) {
                $valueName = [string]$value.name
                if ([string]::IsNullOrWhiteSpace($valueName)) {
                    continue
                }

                $Entries.Add((New-FactorioLuaDocsEntry -Stage $Stage -Kind 'define-value' -Name $valueName -Parent $defineName -Summary $value.description -Url $baseUrl)) | Out-Null
            }
        }
    }
}

function Get-FactorioLuaDocsRuntimeEntries {
    param([Parameter(Mandatory = $true)]$RuntimeDoc)

    $entries = [System.Collections.Generic.List[object]]::new()

    foreach ($class in @($RuntimeDoc.classes)) {
        $className = [string]$class.name
        $classUrl = Get-FactorioLuaDocsRuntimeUrl -Kind 'class' -Name $className
        $entries.Add((New-FactorioLuaDocsEntry -Stage 'runtime' -Kind 'class' -Name $className -Summary $class.description -Url $classUrl)) | Out-Null

        foreach ($method in @($class.methods)) {
            $entries.Add((New-FactorioLuaDocsEntry -Stage 'runtime' -Kind 'method' -Name ([string]$method.name) -Parent $className -Summary $method.description -Url (Get-FactorioLuaDocsRuntimeUrl -Kind 'method' -Name ([string]$method.name) -Parent $className))) | Out-Null
        }
        foreach ($attribute in @($class.attributes)) {
            $entries.Add((New-FactorioLuaDocsEntry -Stage 'runtime' -Kind 'attribute' -Name ([string]$attribute.name) -Parent $className -Summary $attribute.description -Url (Get-FactorioLuaDocsRuntimeUrl -Kind 'attribute' -Name ([string]$attribute.name) -Parent $className))) | Out-Null
        }
        foreach ($operator in @($class.operators)) {
            $entries.Add((New-FactorioLuaDocsEntry -Stage 'runtime' -Kind 'operator' -Name ([string]$operator.name) -Parent $className -Summary $operator.description -Url (Get-FactorioLuaDocsRuntimeUrl -Kind 'operator' -Name ([string]$operator.name) -Parent $className))) | Out-Null
        }
    }

    foreach ($event in @($RuntimeDoc.events)) {
        $entries.Add((New-FactorioLuaDocsEntry -Stage 'runtime' -Kind 'event' -Name ([string]$event.name) -Summary $event.description -Url (Get-FactorioLuaDocsRuntimeUrl -Kind 'event' -Name ([string]$event.name)))) | Out-Null
    }

    foreach ($concept in @($RuntimeDoc.concepts)) {
        $conceptName = [string]$concept.name
        $conceptUrl = Get-FactorioLuaDocsRuntimeUrl -Kind 'concept' -Name $conceptName
        $entries.Add((New-FactorioLuaDocsEntry -Stage 'runtime' -Kind 'concept' -Name $conceptName -Summary $concept.description -Url $conceptUrl)) | Out-Null

        foreach ($propertyName in @('properties', 'attributes')) {
            if ($concept.PSObject.Properties.Name -contains $propertyName) {
                foreach ($member in @($concept.$propertyName)) {
                    $entries.Add((New-FactorioLuaDocsEntry -Stage 'runtime' -Kind 'concept-property' -Name ([string]$member.name) -Parent $conceptName -Summary $member.description -Url (Get-FactorioLuaDocsRuntimeUrl -Kind 'concept-property' -Name ([string]$member.name) -Parent $conceptName))) | Out-Null
                }
            }
        }
    }

    Add-FactorioLuaDocsDefineEntries -Defines @($RuntimeDoc.defines) -Stage 'runtime' -Entries $entries

    foreach ($object in @($RuntimeDoc.global_objects)) {
        $entries.Add((New-FactorioLuaDocsEntry -Stage 'runtime' -Kind 'global-object' -Name ([string]$object.name) -Summary $object.description -Url 'https://lua-api.factorio.com/latest/index-runtime.html')) | Out-Null
    }

    foreach ($function in @($RuntimeDoc.global_functions)) {
        $entries.Add((New-FactorioLuaDocsEntry -Stage 'runtime' -Kind 'global-function' -Name ([string]$function.name) -Summary $function.description -Url 'https://lua-api.factorio.com/latest/index-runtime.html')) | Out-Null
    }

    return @($entries | Sort-Object stage, kind, symbol)
}

function Get-FactorioLuaDocsPrototypeEntries {
    param([Parameter(Mandatory = $true)]$PrototypeDoc)

    $entries = [System.Collections.Generic.List[object]]::new()

    foreach ($prototype in @($PrototypeDoc.prototypes)) {
        $prototypeName = [string]$prototype.name
        $prototypeUrl = Get-FactorioLuaDocsPrototypeUrl -Kind 'prototype' -Name $prototypeName
        $entries.Add((New-FactorioLuaDocsEntry -Stage 'prototype' -Kind 'prototype' -Name $prototypeName -Summary $prototype.description -Url $prototypeUrl)) | Out-Null

        foreach ($property in @($prototype.properties)) {
            $entries.Add((New-FactorioLuaDocsEntry -Stage 'prototype' -Kind 'prototype-property' -Name ([string]$property.name) -Parent $prototypeName -Summary $property.description -Url (Get-FactorioLuaDocsPrototypeUrl -Kind 'prototype-property' -Name ([string]$property.name) -Parent $prototypeName))) | Out-Null
        }
    }

    foreach ($type in @($PrototypeDoc.types)) {
        $typeName = [string]$type.name
        $typeUrl = Get-FactorioLuaDocsPrototypeUrl -Kind 'type' -Name $typeName
        $entries.Add((New-FactorioLuaDocsEntry -Stage 'prototype' -Kind 'type' -Name $typeName -Summary $type.description -Url $typeUrl)) | Out-Null

        foreach ($propertyName in @('properties', 'attributes')) {
            if ($type.PSObject.Properties.Name -contains $propertyName) {
                foreach ($member in @($type.$propertyName)) {
                    $entries.Add((New-FactorioLuaDocsEntry -Stage 'prototype' -Kind 'type-property' -Name ([string]$member.name) -Parent $typeName -Summary $member.description -Url (Get-FactorioLuaDocsPrototypeUrl -Kind 'type-property' -Name ([string]$member.name) -Parent $typeName))) | Out-Null
                }
            }
        }
    }

    Add-FactorioLuaDocsDefineEntries -Defines @($PrototypeDoc.defines) -Stage 'prototype' -Entries $entries

    return @($entries | Sort-Object stage, kind, symbol)
}

function Get-FactorioLuaDocsTopicEntries {
    param(
        [Parameter(Mandatory = $true)]$Sources,
        [Parameter(Mandatory = $true)]$Paths
    )

    $entries = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[object]]::new()
    foreach ($topic in @($Sources.auxiliary_topics) + @($Sources.wiki_topics)) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri $topic.url
            $html = [string]$response.Content
            $entries.Add([ordered]@{
                stage   = [string]$topic.stage
                kind    = 'topic'
                name    = if ($topic.title) { [string]$topic.title } else { (Get-FactorioLuaDocsHtmlTitle -Html $html) }
                symbol  = [string]$topic.id
                summary = Get-FactorioLuaDocsHtmlSummary -Html $html
                url     = [string]$topic.url
            }) | Out-Null
        } catch {
            $warnings.Add([ordered]@{
                topic = [string]$topic.id
                url   = [string]$topic.url
                error = $_.Exception.Message
            }) | Out-Null
        }
    }

    return [pscustomobject]@{
        entries  = @($entries | Sort-Object stage, name)
        warnings = @($warnings)
    }
}

function Invoke-FactorioLuaDocsRefresh {
    param([Parameter(Mandatory = $true)]$Paths)

    $sources = Get-FactorioLuaDocsSourceMap

    $runtimeResponse = Invoke-WebRequest -UseBasicParsing -Uri $sources.runtime_api_url
    $prototypeResponse = Invoke-WebRequest -UseBasicParsing -Uri $sources.prototype_api_url

    [System.IO.File]::WriteAllText($Paths.runtime_json_path, [string]$runtimeResponse.Content, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($Paths.prototype_json_path, [string]$prototypeResponse.Content, [System.Text.UTF8Encoding]::new($false))

    $runtimeDoc = ([string]$runtimeResponse.Content | ConvertFrom-Json)
    $prototypeDoc = ([string]$prototypeResponse.Content | ConvertFrom-Json)

    $runtimeEntries = Get-FactorioLuaDocsRuntimeEntries -RuntimeDoc $runtimeDoc
    $prototypeEntries = Get-FactorioLuaDocsPrototypeEntries -PrototypeDoc $prototypeDoc
    $topicResult = Get-FactorioLuaDocsTopicEntries -Sources $sources -Paths $Paths
    $topicEntries = @($topicResult.entries)
    $refreshWarnings = @($topicResult.warnings)

    $index = [ordered]@{
        schema_version = 1
        refreshed_at   = (Get-Date).ToString('o')
        runtime        = [ordered]@{
            application_version = $runtimeDoc.application_version
            api_version         = $runtimeDoc.api_version
        }
        prototype      = [ordered]@{
            application_version = $prototypeDoc.application_version
            api_version         = $prototypeDoc.api_version
        }
        sources        = $sources
        warnings       = $refreshWarnings
        counts         = [ordered]@{
            runtime_entries   = @($runtimeEntries).Count
            prototype_entries = @($prototypeEntries).Count
            topic_entries     = @($topicEntries).Count
            total_entries     = (@($runtimeEntries).Count + @($prototypeEntries).Count + @($topicEntries).Count)
        }
        entries        = @($runtimeEntries + $prototypeEntries + $topicEntries)
    }

    Write-FactorioLuaDocsJson -Path $Paths.source_manifest_path -Data $sources
    Write-FactorioLuaDocsJson -Path $Paths.index_path -Data $index

    return [ordered]@{
        task           = 'refresh'
        overall_status = if ($refreshWarnings.Count -gt 0) { 'warning' } else { 'ok' }
        cache_root     = $Paths.cache_root
        index_path     = $Paths.index_path
        counts         = $index.counts
        warnings       = $refreshWarnings
        versions       = [ordered]@{
            runtime   = $runtimeDoc.application_version
            prototype = $prototypeDoc.application_version
        }
    }
}

function Get-FactorioLuaDocsStatus {
    param([Parameter(Mandatory = $true)]$Paths)

    $index = Read-FactorioLuaDocsJson -Path $Paths.index_path
    if (-not $index) {
        return [ordered]@{
            task           = 'status'
            overall_status = 'warning'
            cache_root     = $Paths.cache_root
            index_path     = $Paths.index_path
            cache_exists   = $false
            error          = 'Factorio Lua docs cache missing. Run refresh first.'
        }
    }

    return [ordered]@{
        task           = 'status'
        overall_status = 'ok'
        cache_root     = $Paths.cache_root
        index_path     = $Paths.index_path
        cache_exists   = $true
        refreshed_at   = $index.refreshed_at
        runtime        = $index.runtime
        prototype      = $index.prototype
        counts         = $index.counts
        warnings       = $index.warnings
        sources        = [ordered]@{
            api_home      = 'https://lua-api.factorio.com/'
            runtime_json  = $index.sources.runtime_api_url
            prototype_json = $index.sources.prototype_api_url
        }
    }
}

function Get-FactorioLuaDocsIndex {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [switch]$RefreshIfMissing
    )

    $index = Read-FactorioLuaDocsJson -Path $Paths.index_path
    if ($index) {
        return $index
    }

    if ($RefreshIfMissing) {
        Invoke-FactorioLuaDocsRefresh -Paths $Paths | Out-Null
        return (Read-FactorioLuaDocsJson -Path $Paths.index_path)
    }

    throw "Factorio Lua docs cache missing. Run refresh first."
}

function Get-FactorioLuaDocsMatchScore {
    param(
        [Parameter(Mandatory = $true)]$Entry,
        [AllowEmptyString()][string]$Query
    )

    if ([string]::IsNullOrWhiteSpace($Query)) {
        return 1
    }

    $queryLower = $Query.ToLowerInvariant()
    $name = ([string]$Entry.name).ToLowerInvariant()
    $symbol = ([string]$Entry.symbol).ToLowerInvariant()
    $summary = ([string]$Entry.summary).ToLowerInvariant()
    $parent = if ($Entry.PSObject.Properties.Name -contains 'parent') { ([string]$Entry.parent).ToLowerInvariant() } else { '' }

    if ($name -eq $queryLower -or $symbol -eq $queryLower) { return 100 }
    if ($name.StartsWith($queryLower) -or $symbol.StartsWith($queryLower)) { return 80 }
    if ($name.Contains($queryLower) -or $symbol.Contains($queryLower)) { return 60 }
    if ($parent.Contains($queryLower)) { return 40 }
    if ($summary.Contains($queryLower)) { return 20 }
    return 0
}

function Invoke-FactorioLuaDocsQuery {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [string]$Query,
        [ValidateSet('runtime', 'prototype', 'auxiliary', 'wiki', 'all')][string]$Stage = 'all',
        [ValidateSet('class', 'method', 'attribute', 'operator', 'event', 'concept', 'concept-property', 'define', 'define-value', 'global-object', 'global-function', 'prototype', 'prototype-property', 'type', 'type-property', 'topic', 'all')][string]$Kind = 'all',
        [string]$ExactName,
        [ValidateRange(1, 100)]
        [int]$Limit = 12,
        [switch]$RefreshIfMissing
    )

    if ([string]::IsNullOrWhiteSpace($Query) -and [string]::IsNullOrWhiteSpace($ExactName)) {
        return [ordered]@{
            task           = 'query'
            overall_status = 'failed'
            query          = $Query
            exact_name     = $ExactName
            stage          = $Stage
            kind           = $Kind
            error          = 'Provide -Query or -ExactName for docs query.'
            counts         = [ordered]@{
                searched_entries = 0
                matches          = 0
            }
            matches        = @()
        }
    }

    $index = Get-FactorioLuaDocsIndex -Paths $Paths -RefreshIfMissing:$RefreshIfMissing
    $entries = @($index.entries)
    if ($Stage -ne 'all') {
        $entries = @($entries | Where-Object { $_.stage -eq $Stage })
    }
    if ($Kind -ne 'all') {
        $entries = @($entries | Where-Object { $_.kind -eq $Kind })
    }

    if (-not [string]::IsNullOrWhiteSpace($ExactName)) {
        $matches = @($entries | Where-Object {
            $_.name -ieq $ExactName -or $_.symbol -ieq $ExactName
        })
    } else {
        $scored = foreach ($entry in $entries) {
            $score = Get-FactorioLuaDocsMatchScore -Entry $entry -Query $Query
            if ($score -gt 0) {
                [pscustomobject]@{
                    score = $score
                    entry = $entry
                }
            }
        }

        $matches = @($scored | Sort-Object @{ Expression = 'score'; Descending = $true }, @{ Expression = { $_.entry.name } } | Select-Object -First $Limit | ForEach-Object { $_.entry })
    }

    return [ordered]@{
        task           = 'query'
        overall_status = if (@($matches).Count -gt 0) { 'ok' } else { 'warning' }
        query          = $Query
        exact_name     = $ExactName
        stage          = $Stage
        kind           = $Kind
        index_path     = $Paths.index_path
        runtime_version = $index.runtime.application_version
        prototype_version = $index.prototype.application_version
        counts         = [ordered]@{
            searched_entries = @($entries).Count
            matches          = @($matches).Count
        }
        matches        = @($matches | Select-Object -First $Limit)
    }
}
