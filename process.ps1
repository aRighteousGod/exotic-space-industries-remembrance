#==============================================================================
# ESIR FILE MAP
# owns: legacy pack deploy wrapper for exotic-space-industries-remembrance
# loaded_by: manual invocation or scripts\invoke-esir-dev.ps1 -Task pack-deploy
# cadence: manual packaging and deployment
# forwarded_events: none
# storage_roots: none
# gui_ids: none
# remote_interfaces: none
# rebuild_on: pack version changes, packaging layout changes
#==============================================================================
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# --- CONFIGURATION ---
$modName = "exotic-space-industries-remembrance"
$modSource = (Resolve-Path (Join-Path "." $modName)).Path
$info = Get-Content (Join-Path $modSource "info.json") | ConvertFrom-Json
$version = $info.version
$folderName = "${modName}_${version}"
$modsPath = "$env:APPDATA\Factorio\mods"
$zipPath = Join-Path (Split-Path $modSource) "$folderName.zip"

# --- Forbidden Folders (relative path matching) ---
$forbiddenFolders = @(
    ".idea",
    ".git",
    ".vscode",
    ".gitignore"
)

# --- CLEAN OLD ZIP ---
Remove-Item -Force $zipPath -ErrorAction SilentlyContinue

# --- CREATE ZIP ---
$zip = [System.IO.Compression.ZipFile]::Open($zipPath, 'Create')

# Add files manually, preserving correct structure, SKIPPING forbidden paths
Get-ChildItem -Recurse -File $modSource | ForEach-Object {
    $relativePath = $_.FullName.Substring($modSource.Length).TrimStart('\','/')
    $relativePathParts = $relativePath -split '\\'

    # Check if any part of the path matches forbidden folders
    if ($relativePathParts | Where-Object { $forbiddenFolders -contains $_ }) {
        return # Skip forbidden paths
    }

    $zipEntryPath = "$modName\$relativePath" -replace '\\','/' # Force forward slashes
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $zipEntryPath, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
}

$zip.Dispose()

# --- MOVE ZIP TO MODS FOLDER ---
Move-Item -Force $zipPath (Join-Path $modsPath (Split-Path $zipPath -Leaf))

Write-Host "Minimal-motion, Factorio-correct, garbage-free ZIP created and deployed: $folderName.zip" -ForegroundColor Green

# --- VALIDATE ZIP CONTENTS ---
function List-ZipContentsRecursively($folder, $prefix = "") {
    foreach ($item in $folder.Items()) {
        $path = if ($prefix) { "$prefix/$($item.Name)" } else { $item.Name }
        Write-Host " - $path" -ForegroundColor Gray

        # If item is a folder, recurse into it
        if ($item.IsFolder) {
            List-ZipContentsRecursively -folder $item.GetFolder -prefix $path
        }
    }
}

$shell = New-Object -ComObject Shell.Application
$zip = $shell.NameSpace((Join-Path $modsPath "$folderName.zip"))

Write-Host "`nFull contents of $folderName.zip:" -ForegroundColor Cyan

List-ZipContentsRecursively $zip

$shell = $null
