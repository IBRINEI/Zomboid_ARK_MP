[CmdletBinding()]
param(
    [ValidateSet('Qa', 'Dev')]
    [string]$Mode = 'Qa',
    [string]$Destination = 'C:\Users\Grishin\Zomboid\mods',
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$destinationRoot = [IO.Path]::GetFullPath($Destination).TrimEnd('\')
$mods = @(
    @{ Name = 'BunkerCampaign'; LinkInDev = $true },
    @{ Name = 'BunkerCampaignArkMP'; LinkInDev = $false },
    @{ Name = 'BunkerCampaignToxicMP'; LinkInDev = $false },
    @{ Name = 'BunkerCampaignIntegration'; LinkInDev = $true }
)

New-Item -ItemType Directory -Path $destinationRoot -Force | Out-Null
$resolvedRoot = (Resolve-Path -LiteralPath $destinationRoot).Path.TrimEnd('\')
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path $resolvedRoot ".bunker-campaign-backup\$timestamp"
$manifestRoot = Join-Path $resolvedRoot '.deploy-manifests'
New-Item -ItemType Directory -Path $manifestRoot -Force | Out-Null

function Assert-ExactTarget([string]$Path, [string]$ExpectedName) {
    $full = [IO.Path]::GetFullPath($Path)
    $parent = [IO.Path]::GetDirectoryName($full).TrimEnd('\')
    if ($parent -ne $resolvedRoot -or [IO.Path]::GetFileName($full) -ne $ExpectedName) {
        throw "Refusing unsafe deployment target: $full"
    }
    return $full
}

function Backup-Target([string]$Target, [string]$Name) {
    if (-not (Test-Path -LiteralPath $Target)) { return }
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    Move-Item -LiteralPath $Target -Destination (Join-Path $backupRoot $Name)
}

function Mirror-Directory([string]$Source, [string]$Target) {
    New-Item -ItemType Directory -Path $Target -Force | Out-Null
    & robocopy.exe $Source $Target /MIR /COPY:DAT /DCOPY:DAT /R:2 /W:1 /NFL /NDL /NJH /NJS /NP
    if ($LASTEXITCODE -gt 7) { throw "robocopy failed with exit code $LASTEXITCODE for $Source" }
}

$deployed = @()
foreach ($mod in $mods) {
    $source = Join-Path $repository $mod.Name
    if (-not (Test-Path -LiteralPath (Join-Path $source '42.0\mod.info'))) {
        throw "Deployable mod is incomplete: $source"
    }
    $target = Assert-ExactTarget (Join-Path $resolvedRoot $mod.Name) $mod.Name

    if ($Clean -or (Test-Path -LiteralPath $target)) {
        Backup-Target $target $mod.Name
    }

    $deploymentKind = 'copy'
    if ($Mode -eq 'Dev' -and $mod.LinkInDev) {
        New-Item -ItemType Junction -Path $target -Target $source | Out-Null
        $deploymentKind = 'junction'
    } else {
        Mirror-Directory $source $target
    }

    $files = Get-ChildItem -LiteralPath $source -Recurse -File | ForEach-Object {
        [ordered]@{
            path = $_.FullName.Substring($source.Length + 1).Replace('\', '/')
            size = $_.Length
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    }
    $deployed += [ordered]@{
        name = $mod.Name
        source = $source
        destination = $target
        kind = $deploymentKind
        fileCount = @($files).Count
        files = @($files)
    }
}

$commit = (& git -C $repository rev-parse HEAD).Trim()
$workingTreeChanges = @(& git -C $repository status --porcelain=v1 --untracked-files=all)
$manifest = [ordered]@{
    schemaVersion = 1
    createdAt = (Get-Date).ToUniversalTime().ToString('o')
    repository = $repository
    commit = $commit
    workingTreeDirty = $workingTreeChanges.Count -gt 0
    workingTreeChanges = $workingTreeChanges
    mode = $Mode
    destination = $resolvedRoot
    backup = if (Test-Path -LiteralPath $backupRoot) { $backupRoot } else { $null }
    deployed = $deployed
    excluded = @(
        'BanditsWeekOneTheArk', 'TheArk', 'BanditsDayOne', 'BanditsWeekOne',
        'ToxicZonesSTALKERB42', 'BunkerCampaignThermalJava', 'repository ZombieBuddy marker'
    )
}
$manifestPath = Join-Path $manifestRoot "deployment-$timestamp.json"
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding utf8
Write-Host "Deployment complete: $Mode"
Write-Host "Manifest: $manifestPath"
if ($manifest.backup) { Write-Host "Previous targets moved to: $backupRoot" }
