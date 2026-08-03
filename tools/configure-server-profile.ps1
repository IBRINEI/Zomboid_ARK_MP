[CmdletBinding()]
param(
    [string]$ZomboidHome = 'C:\Users\Grishin\Zomboid',
    [string]$Profile = 'arkmp_qa',
    [switch]$ResetWorld
)

$ErrorActionPreference = 'Stop'
$serverDirectory = Join-Path $ZomboidHome 'Server'
$saveDirectory = Join-Path $ZomboidHome "Saves\Multiplayer\$Profile"
$sourceProfile = 'servertest'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

if (Test-Path -LiteralPath $saveDirectory) {
    if (-not $ResetWorld) {
        throw "QA world already exists: $saveDirectory. Use -ResetWorld to move it to a dated backup."
    }
    $saveBackup = "$saveDirectory.backup-$stamp"
    Move-Item -LiteralPath $saveDirectory -Destination $saveBackup
    Write-Host "Existing QA world moved to: $saveBackup"
}

New-Item -ItemType Directory -Path $serverDirectory -Force | Out-Null
foreach ($suffix in @('.ini', '_SandboxVars.lua', '_spawnpoints.lua', '_spawnregions.lua')) {
    $source = Join-Path $serverDirectory ($sourceProfile + $suffix)
    $target = Join-Path $serverDirectory ($Profile + $suffix)
    if (-not (Test-Path -LiteralPath $source)) { throw "Template file is missing: $source" }
    if (-not (Test-Path -LiteralPath $target)) {
        Copy-Item -LiteralPath $source -Destination $target
    } else {
        Copy-Item -LiteralPath $target -Destination "$target.bak-$stamp"
    }
}

$iniPath = Join-Path $serverDirectory "$Profile.ini"
$ini = Get-Content -LiteralPath $iniPath -Raw
$settings = [ordered]@{
    Mods = 'ZombieBuddy;Bandits2;Waterpipes;BunkerCampaign;BunkerCampaignArkMP;BunkerCampaignToxicMP;BunkerCampaignIntegration'
    WorkshopItems = '3619862853;3268487204;3546314080'
    Map = 'Muldraugh, KY'
}
foreach ($entry in $settings.GetEnumerator()) {
    $pattern = '(?m)^' + [regex]::Escape($entry.Key) + '=.*$'
    if ($ini -match $pattern) {
        $ini = [regex]::Replace($ini, $pattern, "$($entry.Key)=$($entry.Value)", 1)
    } else {
        $ini += "`r`n$($entry.Key)=$($entry.Value)`r`n"
    }
}
$ini | Set-Content -LiteralPath $iniPath -Encoding utf8

$sandboxPath = Join-Path $serverDirectory "${Profile}_SandboxVars.lua"
$sandbox = Get-Content -LiteralPath $sandboxPath -Raw
$begin = '    -- BEGIN BUNKER_CAMPAIGN_QA'
$end = '    -- END BUNKER_CAMPAIGN_QA'
$block = @"
$begin
    BWOA = {
        FalloutStarted = 4,
        FalloutEnds = 3,
        FalloutCurve = 4,
        TemperatureDrop = 3,
        ArkGeneratorFuelConsumption = 3,
        ShelterOccurance = 4,
        HostileGroupSize = 3,
        ResidueScrap = 4,
        SkeletonReanimation = false,
        AngelProximity = true,
        MemoryRegain = true,
        RetroRadiation = false,
    },
$end
"@
$pattern = '(?ms)^\s*-- BEGIN BUNKER_CAMPAIGN_QA.*?^\s*-- END BUNKER_CAMPAIGN_QA\s*'
if ($sandbox -match $pattern) {
    $sandbox = [regex]::Replace($sandbox, $pattern, $block)
} else {
    $lastBrace = $sandbox.LastIndexOf('}')
    if ($lastBrace -lt 0) { throw "Invalid SandboxVars file: $sandboxPath" }
    $sandbox = $sandbox.Insert($lastBrace, "$block`r`n")
}
$sandbox | Set-Content -LiteralPath $sandboxPath -Encoding utf8

[pscustomobject]@{
    Profile = $Profile
    Ini = $iniPath
    Sandbox = $sandboxPath
    Save = $saveDirectory
    Mods = $settings.Mods
    WorkshopItems = $settings.WorkshopItems
    ExistingServertestPreserved = $true
}
