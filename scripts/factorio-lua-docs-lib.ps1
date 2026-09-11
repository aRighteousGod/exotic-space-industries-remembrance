Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FactorioLuaDocsPaths {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [ValidateSet('installed', 'hosted')][string]$Source = 'installed',
        [ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version = '2.0.77',
        [string]$DocsRoot = 'C:\Program Files (x86)\Steam\steamapps\common\Factorio\doc-html',
        [switch]$EnsureCacheRoot
    )

    $resolvedRepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
    $cacheBaseRoot = Join-Path $resolvedRepoRoot '.factorio-lua-docs-cache'
    $cacheRoot = Join-Path $cacheBaseRoot $Version
    if ($EnsureCacheRoot) {
        New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null
    }

    $canonicalBaseUrl = "https://lua-api.factorio.com/$Version"

    return [pscustomobject]@{
        repo_root            = $resolvedRepoRoot
        cache_base_root      = $cacheBaseRoot
        cache_root           = $cacheRoot
        source               = $Source
        requested_version    = $Version
        docs_root            = [System.IO.Path]::GetFullPath($DocsRoot)
        canonical_base_url   = $canonicalBaseUrl
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
    param([Parameter(Mandatory = $true)]$Paths)

    $baseUrl = $Paths.canonical_base_url
    $docsRoot = $Paths.docs_root
    $auxiliaryTopics = @(
        [ordered]@{ id = 'data-lifecycle'; title = 'Data Lifecycle'; stage = 'auxiliary'; relative_path = 'auxiliary/data-lifecycle.html'; url = "$baseUrl/auxiliary/data-lifecycle.html" }
        [ordered]@{ id = 'storage'; title = 'Storage'; stage = 'auxiliary'; relative_path = 'auxiliary/storage.html'; url = "$baseUrl/auxiliary/storage.html" }
        [ordered]@{ id = 'mod-structure'; title = 'Mod Structure'; stage = 'auxiliary'; relative_path = 'auxiliary/mod-structure.html'; url = "$baseUrl/auxiliary/mod-structure.html" }
        [ordered]@{ id = 'changelog-format'; title = 'Changelog Format'; stage = 'auxiliary'; relative_path = 'auxiliary/changelog-format.html'; url = "$baseUrl/auxiliary/changelog-format.html" }
        [ordered]@{ id = 'libraries'; title = 'Libraries and functions'; stage = 'auxiliary'; relative_path = 'auxiliary/libraries.html'; url = "$baseUrl/auxiliary/libraries.html" }
        [ordered]@{ id = 'migrations'; title = 'Migrations'; stage = 'auxiliary'; relative_path = 'auxiliary/migrations.html'; url = "$baseUrl/auxiliary/migrations.html" }
        [ordered]@{ id = 'prototype-tree'; title = 'Prototype Inheritance Tree'; stage = 'auxiliary'; relative_path = 'auxiliary/prototype-tree.html'; url = "$baseUrl/auxiliary/prototype-tree.html" }
        [ordered]@{ id = 'noise-expressions'; title = 'Noise Expressions'; stage = 'auxiliary'; relative_path = 'auxiliary/noise-expressions.html'; url = "$baseUrl/auxiliary/noise-expressions.html" }
        [ordered]@{ id = 'instrument-mode'; title = 'Instrument Mode'; stage = 'auxiliary'; relative_path = 'auxiliary/instrument.html'; url = "$baseUrl/auxiliary/instrument.html" }
        [ordered]@{ id = 'item-weight'; title = 'Item Weight'; stage = 'auxiliary'; relative_path = 'auxiliary/item-weight.html'; url = "$baseUrl/auxiliary/item-weight.html" }
        [ordered]@{ id = 'runtime-json-format'; title = 'Runtime JSON Format'; stage = 'auxiliary'; relative_path = 'auxiliary/json-docs-runtime.html'; url = "$baseUrl/auxiliary/json-docs-runtime.html" }
        [ordered]@{ id = 'prototype-json-format'; title = 'Prototype JSON Format'; stage = 'auxiliary'; relative_path = 'auxiliary/json-docs-prototype.html'; url = "$baseUrl/auxiliary/json-docs-prototype.html" }
        [ordered]@{ id = 'defines'; title = 'Defines'; stage = 'auxiliary'; relative_path = 'defines.html'; url = "$baseUrl/defines.html" }
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
        source                  = $Paths.source
        requested_version       = $Paths.requested_version
        canonical_base_url      = $baseUrl
        installed_docs_root     = if ($Paths.source -eq 'installed') { $docsRoot } else { $null }
        installed_runtime_json  = if ($Paths.source -eq 'installed') { Join-Path $docsRoot 'runtime-api.json' } else { $null }
        installed_prototype_json = if ($Paths.source -eq 'installed') { Join-Path $docsRoot 'prototype-api.json' } else { $null }
        runtime_api_url         = "$baseUrl/runtime-api.json"
        prototype_api_url       = "$baseUrl/prototype-api.json"
        license_url             = "$baseUrl/license.html"
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
        [string]$Parent,
        [Parameter(Mandatory = $true)][string]$CanonicalBaseUrl,
        [switch]$ParentOnly
    )

    switch ($Kind) {
        'class' { return "$CanonicalBaseUrl/classes/$Name.html" }
        'method' { return "$CanonicalBaseUrl/classes/$Parent.html#$Name" }
        'attribute' { return "$CanonicalBaseUrl/classes/$Parent.html#$Name" }
        'operator' { return "$CanonicalBaseUrl/classes/$Parent.html#$Name" }
        'event' { return "$CanonicalBaseUrl/events.html#$Name" }
        'concept' { return "$CanonicalBaseUrl/concepts/$Name.html" }
        'concept-property' { if ($ParentOnly) { return "$CanonicalBaseUrl/concepts/$Parent.html" }; return "$CanonicalBaseUrl/concepts/$Parent.html#$Name" }
        'define' { return "$CanonicalBaseUrl/defines.html#$Name" }
        'define-value' { return "$CanonicalBaseUrl/defines.html#$Parent" }
        default { return "$CanonicalBaseUrl/index-runtime.html" }
    }
}

function Get-FactorioLuaDocsPrototypeUrl {
    param(
        [Parameter(Mandatory = $true)][string]$Kind,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$Parent,
        [Parameter(Mandatory = $true)][string]$CanonicalBaseUrl
    )

    switch ($Kind) {
        'prototype' { return "$CanonicalBaseUrl/prototypes/$Name.html" }
        'prototype-property' { return "$CanonicalBaseUrl/prototypes/$Parent.html#$Name" }
        'type' { return "$CanonicalBaseUrl/types/$Name.html" }
        'type-property' { return "$CanonicalBaseUrl/types/$Parent.html#$Name" }
        'define' { return "$CanonicalBaseUrl/defines.html#$Name" }
        'define-value' { return "$CanonicalBaseUrl/defines.html#$Parent" }
        default { return "$CanonicalBaseUrl/index-prototype.html" }
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
        [Parameter(Mandatory = $true)]$Entries,
        [Parameter(Mandatory = $true)][string]$CanonicalBaseUrl
    )

    foreach ($define in $Defines) {
        $defineName = [string]$define.name
        $baseUrl = if ($Stage -eq 'runtime') {
            Get-FactorioLuaDocsRuntimeUrl -Kind 'define' -Name $defineName -CanonicalBaseUrl $CanonicalBaseUrl
        } else {
            Get-FactorioLuaDocsPrototypeUrl -Kind 'define' -Name $defineName -CanonicalBaseUrl $CanonicalBaseUrl
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

function Add-FactorioLuaDocsInlineTypeMembers {
    param(
        $TypeNode,
        [Parameter(Mandatory = $true)]$Members
    )

    if ($null -eq $TypeNode -or $TypeNode -is [string] -or $TypeNode -is [ValueType]) {
        return
    }

    if ($TypeNode -is [System.Array]) {
        foreach ($item in $TypeNode) {
            Add-FactorioLuaDocsInlineTypeMembers -TypeNode $item -Members $Members
        }
        return
    }

    $propertyNames = @($TypeNode.PSObject.Properties | ForEach-Object { $_.Name })
    $containerHasAnchors = ($propertyNames -contains 'complex_type') -and ([string]$TypeNode.complex_type -eq 'LuaStruct')

    foreach ($collectionName in @('parameters', 'attributes')) {
        if ($propertyNames -notcontains $collectionName) {
            continue
        }

        foreach ($member in @($TypeNode.$collectionName)) {
            if ($null -eq $member -or [string]::IsNullOrWhiteSpace([string]$member.name)) {
                continue
            }

            $Members.Add([pscustomobject]@{
                name        = [string]$member.name
                description = [string]$member.description
                has_anchor  = $containerHasAnchors
            }) | Out-Null

            foreach ($memberTypeName in @('type', 'read_type', 'write_type')) {
                if ($member.PSObject.Properties.Name -contains $memberTypeName) {
                    Add-FactorioLuaDocsInlineTypeMembers -TypeNode $member.$memberTypeName -Members $Members
                }
            }
        }
    }

    if ($propertyNames -contains 'variant_parameter_groups') {
        foreach ($group in @($TypeNode.variant_parameter_groups)) {
            foreach ($member in @($group.parameters)) {
                if ($null -eq $member -or [string]::IsNullOrWhiteSpace([string]$member.name)) {
                    continue
                }

                $Members.Add([pscustomobject]@{
                    name        = [string]$member.name
                    description = [string]$member.description
                    has_anchor  = $false
                }) | Out-Null
                if ($member.PSObject.Properties.Name -contains 'type') {
                    Add-FactorioLuaDocsInlineTypeMembers -TypeNode $member.type -Members $Members
                }
            }
        }
    }

    foreach ($childName in @('type', 'value', 'options', 'values', 'element_type', 'key_type')) {
        if ($propertyNames -contains $childName) {
            Add-FactorioLuaDocsInlineTypeMembers -TypeNode $TypeNode.$childName -Members $Members
        }
    }
}

function Get-FactorioLuaDocsConceptMembers {
    param([Parameter(Mandatory = $true)]$Concept)

    $candidates = [System.Collections.Generic.List[object]]::new()
    if ($Concept.PSObject.Properties.Name -contains 'type') {
        Add-FactorioLuaDocsInlineTypeMembers -TypeNode $Concept.type -Members $candidates
    }

    $members = @{}
    foreach ($candidate in $candidates) {
        $name = [string]$candidate.name
        if (-not $members.ContainsKey($name)) {
            $members[$name] = $candidate
            continue
        }

        $existing = $members[$name]
        if ([string]::IsNullOrWhiteSpace([string]$existing.description) -and
            -not [string]::IsNullOrWhiteSpace([string]$candidate.description)) {
            $members[$name] = $candidate
        } elseif (-not $existing.has_anchor -and $candidate.has_anchor) {
            $members[$name] = $candidate
        }
    }

    return @($members.Values | Sort-Object name)
}

function Get-FactorioLuaDocsRuntimeEntries {
    param(
        [Parameter(Mandatory = $true)]$RuntimeDoc,
        [Parameter(Mandatory = $true)][string]$CanonicalBaseUrl
    )

    $entries = [System.Collections.Generic.List[object]]::new()

    foreach ($class in @($RuntimeDoc.classes)) {
        $className = [string]$class.name
        $classUrl = Get-FactorioLuaDocsRuntimeUrl -Kind 'class' -Name $className -CanonicalBaseUrl $CanonicalBaseUrl
        $entries.Add((New-FactorioLuaDocsEntry -Stage 'runtime' -Kind 'class' -Name $className -Summary $class.description -Url $classUrl)) | Out-Null

        foreach ($method in @($class.methods)) {
            $entries.Add((New-FactorioLuaDocsEntry -Stage 'runtime' -Kind 'method' -Name ([string]$method.name) -Parent $className -Summary $method.description -Url (Get-FactorioLuaDocsRuntimeUrl -Kind 'method' -Name ([string]$method.name) -Parent $className -CanonicalBaseUrl $CanonicalBaseUrl))) | Out-Null
        }
        foreach ($attribute in @($class.attributes)) {
            $entries.Add((New-FactorioLuaDocsEntry -Stage 'runtime' -Kind 'attribute' -Name ([string]$attribute.name) -Parent $className -Summary $attribute.description -Url (Get-FactorioLuaDocsRuntimeUrl -Kind 'attribute' -Name ([string]$attribute.name) -Parent $className -CanonicalBaseUrl $CanonicalBaseUrl))) | Out-Null
        }
        foreach ($operator in @($class.operators)) {
            $entries.Add((New-FactorioLuaDocsEntry -Stage 'runtime' -Kind 'operator' -Name ([string]$operator.name) -Parent $className -Summary $operator.description -Url (Get-FactorioLuaDocsRuntimeUrl -Kind 'operator' -Name ([string]$operator.name) -Parent $className -CanonicalBaseUrl $CanonicalBaseUrl))) | Out-Null
        }
    }

    foreach ($event in @($RuntimeDoc.events)) {
        $entries.Add((New-FactorioLuaDocsEntry -Stage 'runtime' -Kind 'event' -Name ([string]$event.name) -Summary $event.description -Url (Get-FactorioLuaDocsRuntimeUrl -Kind 'event' -Name ([string]$event.name) -CanonicalBaseUrl $CanonicalBaseUrl))) | Out-Null
    }

    foreach ($concept in @($RuntimeDoc.concepts)) {
        $conceptName = [string]$concept.name
        $conceptUrl = Get-FactorioLuaDocsRuntimeUrl -Kind 'concept' -Name $conceptName -CanonicalBaseUrl $CanonicalBaseUrl
        $entries.Add((New-FactorioLuaDocsEntry -Stage 'runtime' -Kind 'concept' -Name $conceptName -Summary $concept.description -Url $conceptUrl)) | Out-Null

        foreach ($member in @(Get-FactorioLuaDocsConceptMembers -Concept $concept)) {
            $memberUrl = Get-FactorioLuaDocsRuntimeUrl -Kind 'concept-property' -Name ([string]$member.name) -Parent $conceptName -CanonicalBaseUrl $CanonicalBaseUrl -ParentOnly:(-not $member.has_anchor)
            $entries.Add((New-FactorioLuaDocsEntry -Stage 'runtime' -Kind 'concept-property' -Name ([string]$member.name) -Parent $conceptName -Summary $member.description -Url $memberUrl)) | Out-Null
        }
    }

    Add-FactorioLuaDocsDefineEntries -Defines @($RuntimeDoc.defines) -Stage 'runtime' -Entries $entries -CanonicalBaseUrl $CanonicalBaseUrl

    foreach ($object in @($RuntimeDoc.global_objects)) {
        $entries.Add((New-FactorioLuaDocsEntry -Stage 'runtime' -Kind 'global-object' -Name ([string]$object.name) -Summary $object.description -Url "$CanonicalBaseUrl/index-runtime.html")) | Out-Null
    }

    foreach ($function in @($RuntimeDoc.global_functions)) {
        $entries.Add((New-FactorioLuaDocsEntry -Stage 'runtime' -Kind 'global-function' -Name ([string]$function.name) -Summary $function.description -Url "$CanonicalBaseUrl/index-runtime.html")) | Out-Null
    }

    return @($entries | Sort-Object stage, kind, symbol)
}

function Get-FactorioLuaDocsPrototypeEntries {
    param(
        [Parameter(Mandatory = $true)]$PrototypeDoc,
        [Parameter(Mandatory = $true)][string]$CanonicalBaseUrl
    )

    $entries = [System.Collections.Generic.List[object]]::new()

    foreach ($prototype in @($PrototypeDoc.prototypes)) {
        $prototypeName = [string]$prototype.name
        $prototypeUrl = Get-FactorioLuaDocsPrototypeUrl -Kind 'prototype' -Name $prototypeName -CanonicalBaseUrl $CanonicalBaseUrl
        $entries.Add((New-FactorioLuaDocsEntry -Stage 'prototype' -Kind 'prototype' -Name $prototypeName -Summary $prototype.description -Url $prototypeUrl)) | Out-Null

        foreach ($property in @($prototype.properties)) {
            $entries.Add((New-FactorioLuaDocsEntry -Stage 'prototype' -Kind 'prototype-property' -Name ([string]$property.name) -Parent $prototypeName -Summary $property.description -Url (Get-FactorioLuaDocsPrototypeUrl -Kind 'prototype-property' -Name ([string]$property.name) -Parent $prototypeName -CanonicalBaseUrl $CanonicalBaseUrl))) | Out-Null
        }
    }

    foreach ($type in @($PrototypeDoc.types)) {
        $typeName = [string]$type.name
        $typeUrl = Get-FactorioLuaDocsPrototypeUrl -Kind 'type' -Name $typeName -CanonicalBaseUrl $CanonicalBaseUrl
        $entries.Add((New-FactorioLuaDocsEntry -Stage 'prototype' -Kind 'type' -Name $typeName -Summary $type.description -Url $typeUrl)) | Out-Null

        foreach ($propertyName in @('properties', 'attributes')) {
            if ($type.PSObject.Properties.Name -contains $propertyName) {
                foreach ($member in @($type.$propertyName)) {
                    $entries.Add((New-FactorioLuaDocsEntry -Stage 'prototype' -Kind 'type-property' -Name ([string]$member.name) -Parent $typeName -Summary $member.description -Url (Get-FactorioLuaDocsPrototypeUrl -Kind 'type-property' -Name ([string]$member.name) -Parent $typeName -CanonicalBaseUrl $CanonicalBaseUrl))) | Out-Null
                }
            }
        }
    }

    Add-FactorioLuaDocsDefineEntries -Defines @($PrototypeDoc.defines) -Stage 'prototype' -Entries $entries -CanonicalBaseUrl $CanonicalBaseUrl

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
            $html = ''
            if ($Paths.source -eq 'installed' -and $topic.stage -eq 'auxiliary') {
                $relativePath = ([string]$topic.relative_path).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
                $localPath = Join-Path $Paths.docs_root $relativePath
                if (-not (Test-Path -LiteralPath $localPath)) {
                    throw "Installed auxiliary document missing: $localPath"
                }
                $html = [System.IO.File]::ReadAllText($localPath, [System.Text.UTF8Encoding]::new($false, $true))
            } elseif ($Paths.source -eq 'installed' -and $topic.stage -eq 'wiki') {
                # Wiki pages are intentionally unversioned. Keep their lookup records,
                # but do not contact the network during an installed-doc refresh.
                $html = ''
            } else {
                $response = Invoke-WebRequest -UseBasicParsing -Uri $topic.url
                $html = [string]$response.Content
            }
            $entries.Add([ordered]@{
                stage   = [string]$topic.stage
                kind    = 'topic'
                name    = if ($topic.title) { [string]$topic.title } else { (Get-FactorioLuaDocsHtmlTitle -Html $html) }
                symbol  = [string]$topic.id
                summary = if ($html) { Get-FactorioLuaDocsHtmlSummary -Html $html } else { 'Unversioned official Factorio wiki topic.' }
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

function Assert-FactorioLuaDocsDocument {
    param(
        [Parameter(Mandatory = $true)]$Document,
        [Parameter(Mandatory = $true)][ValidateSet('runtime', 'prototype')][string]$ExpectedStage,
        [Parameter(Mandatory = $true)][string]$ExpectedVersion,
        [Parameter(Mandatory = $true)][string]$SourceDescription
    )

    if ($Document.PSObject.Properties.Name -notcontains 'stage' -or [string]$Document.stage -ne $ExpectedStage) {
        throw "Factorio documentation '$SourceDescription' does not describe the $ExpectedStage stage."
    }
    if ($Document.PSObject.Properties.Name -notcontains 'application_version') {
        throw "Factorio documentation '$SourceDescription' does not declare application_version."
    }
    if ([string]$Document.application_version -ne $ExpectedVersion) {
        throw "Factorio documentation '$SourceDescription' reports application_version = $($Document.application_version); expected $ExpectedVersion."
    }
}

function Test-FactorioLuaDocsIndexProfile {
    param(
        [Parameter(Mandatory = $true)]$Index,
        [Parameter(Mandatory = $true)]$Paths
    )

    if ($Index.PSObject.Properties.Name -notcontains 'schema_version' -or [int]$Index.schema_version -ne 2) {
        return $false
    }
    if ($Index.PSObject.Properties.Name -notcontains 'source' -or [string]$Index.source -ne [string]$Paths.source) {
        return $false
    }
    if ($Index.PSObject.Properties.Name -notcontains 'requested_version' -or [string]$Index.requested_version -ne [string]$Paths.requested_version) {
        return $false
    }
    if ($Index.PSObject.Properties.Name -notcontains 'resolved_version' -or [string]$Index.resolved_version -ne [string]$Paths.requested_version) {
        return $false
    }

    return $true
}

function Invoke-FactorioLuaDocsRefresh {
    param([Parameter(Mandatory = $true)]$Paths)

    $sources = Get-FactorioLuaDocsSourceMap -Paths $Paths
    if ($Paths.source -eq 'installed') {
        foreach ($sourcePath in @($sources.installed_runtime_json, $sources.installed_prototype_json)) {
            if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
                throw "Installed Factorio documentation is incomplete: '$sourcePath' was not found. No hosted fallback was attempted."
            }
        }

        $runtimeJson = [System.IO.File]::ReadAllText($sources.installed_runtime_json, [System.Text.UTF8Encoding]::new($false, $true))
        $prototypeJson = [System.IO.File]::ReadAllText($sources.installed_prototype_json, [System.Text.UTF8Encoding]::new($false, $true))
    } else {
        $runtimeResponse = Invoke-WebRequest -UseBasicParsing -Uri $sources.runtime_api_url
        $prototypeResponse = Invoke-WebRequest -UseBasicParsing -Uri $sources.prototype_api_url
        $runtimeJson = [string]$runtimeResponse.Content
        $prototypeJson = [string]$prototypeResponse.Content
    }

    try {
        $runtimeDoc = $runtimeJson | ConvertFrom-Json
    } catch {
        throw "Runtime documentation JSON is invalid: $($_.Exception.Message)"
    }
    try {
        $prototypeDoc = $prototypeJson | ConvertFrom-Json
    } catch {
        throw "Prototype documentation JSON is invalid: $($_.Exception.Message)"
    }

    Assert-FactorioLuaDocsDocument -Document $runtimeDoc -ExpectedStage 'runtime' -ExpectedVersion $Paths.requested_version -SourceDescription $(if ($Paths.source -eq 'installed') { $sources.installed_runtime_json } else { $sources.runtime_api_url })
    Assert-FactorioLuaDocsDocument -Document $prototypeDoc -ExpectedStage 'prototype' -ExpectedVersion $Paths.requested_version -SourceDescription $(if ($Paths.source -eq 'installed') { $sources.installed_prototype_json } else { $sources.prototype_api_url })

    # Validation completes before the versioned cache is created or replaced.
    New-Item -ItemType Directory -Force -Path $Paths.cache_root | Out-Null
    [System.IO.File]::WriteAllText($Paths.runtime_json_path, $runtimeJson, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($Paths.prototype_json_path, $prototypeJson, [System.Text.UTF8Encoding]::new($false))

    $runtimeEntries = Get-FactorioLuaDocsRuntimeEntries -RuntimeDoc $runtimeDoc -CanonicalBaseUrl $Paths.canonical_base_url
    $prototypeEntries = Get-FactorioLuaDocsPrototypeEntries -PrototypeDoc $prototypeDoc -CanonicalBaseUrl $Paths.canonical_base_url
    $topicResult = Get-FactorioLuaDocsTopicEntries -Sources $sources -Paths $Paths
    $topicEntries = @($topicResult.entries)
    $refreshWarnings = @($topicResult.warnings)

    $index = [ordered]@{
        schema_version    = 2
        refreshed_at      = (Get-Date).ToString('o')
        source            = $Paths.source
        requested_version = $Paths.requested_version
        resolved_version  = [string]$runtimeDoc.application_version
        docs_root         = if ($Paths.source -eq 'installed') { $Paths.docs_root } else { $null }
        canonical_base_url = $Paths.canonical_base_url
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
        source         = $Paths.source
        requested_version = $Paths.requested_version
        resolved_version = [string]$runtimeDoc.application_version
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
            source         = $Paths.source
            requested_version = $Paths.requested_version
            cache_root     = $Paths.cache_root
            index_path     = $Paths.index_path
            cache_exists   = $false
            error          = 'Factorio Lua docs cache missing. Run refresh first.'
        }
    }

    $profileMatches = Test-FactorioLuaDocsIndexProfile -Index $index -Paths $Paths

    return [ordered]@{
        task           = 'status'
        overall_status = if ($profileMatches) { 'ok' } else { 'warning' }
        source         = $Paths.source
        requested_version = $Paths.requested_version
        resolved_version = if ($index.PSObject.Properties.Name -contains 'resolved_version') { $index.resolved_version } else { $null }
        cache_root     = $Paths.cache_root
        index_path     = $Paths.index_path
        cache_exists   = $true
        profile_matches = $profileMatches
        error          = if ($profileMatches) { $null } else { 'The cache metadata does not match the requested source/version profile. Run refresh for this profile.' }
        refreshed_at   = $index.refreshed_at
        runtime        = $index.runtime
        prototype      = $index.prototype
        counts         = $index.counts
        warnings       = $index.warnings
        sources        = [ordered]@{
            canonical_base_url = $index.canonical_base_url
            runtime_json  = $index.sources.runtime_api_url
            prototype_json = $index.sources.prototype_api_url
            installed_docs_root = $index.sources.installed_docs_root
        }
    }
}

function Get-FactorioLuaDocsIndex {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [switch]$RefreshIfMissing
    )

    $index = Read-FactorioLuaDocsJson -Path $Paths.index_path
    if ($index -and (Test-FactorioLuaDocsIndexProfile -Index $index -Paths $Paths)) {
        return $index
    }

    if ($RefreshIfMissing) {
        Invoke-FactorioLuaDocsRefresh -Paths $Paths | Out-Null
        return (Read-FactorioLuaDocsJson -Path $Paths.index_path)
    }

    if ($index) {
        throw "Factorio Lua docs cache profile mismatch for source '$($Paths.source)' and version '$($Paths.requested_version)'. Run refresh for this profile."
    }

    throw "Factorio Lua docs cache missing for source '$($Paths.source)' and version '$($Paths.requested_version)'. Run refresh first."
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
        source         = $index.source
        requested_version = $index.requested_version
        resolved_version = $index.resolved_version
        runtime_version = $index.runtime.application_version
        prototype_version = $index.prototype.application_version
        counts         = [ordered]@{
            searched_entries = @($entries).Count
            matches          = @($matches).Count
        }
        matches        = @($matches | Select-Object -First $Limit)
    }
}
