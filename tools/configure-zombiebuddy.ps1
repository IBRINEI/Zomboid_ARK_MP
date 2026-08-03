[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$WorkshopRoot = 'C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\3619862853',
    [string]$ClientRoot = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid',
    [string]$ServerRoot = 'C:\Program Files (x86)\Steam\steamapps\common\Project Zomboid Dedicated Server',
    [string]$RuntimeJar,
    [switch]$SkipClient,
    [switch]$SkipServer
)

$ErrorActionPreference = 'Stop'
$clientJson = Join-Path $ClientRoot 'ProjectZomboid64.json'
$workshopJar = Get-ChildItem -LiteralPath $WorkshopRoot -Recurse -Filter ZombieBuddy.jar | Select-Object -First 1
$workshopDll = Get-ChildItem -LiteralPath $WorkshopRoot -Recurse -Filter zbNative.dll | Select-Object -First 1
if (-not $workshopJar -or -not $workshopDll) { throw 'Workshop ZombieBuddy jar/dll were not found.' }

if (-not $RuntimeJar) {
    $RuntimeJar = Join-Path (Split-Path -Parent $PSScriptRoot) 'artifacts\ZombieBuddy-2.3.3-windows-http-hotfix.jar'
}
if (-not (Test-Path -LiteralPath $RuntimeJar -PathType Leaf)) {
    throw "Windows HTTP hotfix JAR was not found. Run tools/build-zombiebuddy-windows-hotfix.ps1 first: $RuntimeJar"
}

$runtimeHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $RuntimeJar).Hash
$workshopHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $workshopJar.FullName).Hash
$expectedWorkshopHash = '6DD95CEDCE60F03BF8B8CEFD0D19EB156230E0D54BFFA07DE9DA5212A06C7BE6'
if ($workshopHash -ne $expectedWorkshopHash) {
    throw "Unexpected Workshop ZombieBuddy version/hash: $workshopHash"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
if (-not $SkipClient -and $PSCmdlet.ShouldProcess($clientJson, 'Back up and configure client ZombieBuddy agent')) {
    Copy-Item -LiteralPath $clientJson -Destination "$clientJson.bak-$stamp"
    $clientJar = Join-Path $ClientRoot 'ZombieBuddy.jar'
    if (Test-Path -LiteralPath $clientJar) {
        Copy-Item -LiteralPath $clientJar -Destination "$clientJar.bak-$stamp"
    }
    Copy-Item -LiteralPath $RuntimeJar -Destination $clientJar -Force
    Copy-Item -LiteralPath $workshopDll.FullName -Destination (Join-Path $ClientRoot 'zbNative.dll') -Force
    $json = Get-Content -LiteralPath $clientJson -Raw | ConvertFrom-Json
    $agent = '-agentlib:zbNative=experimental,lua_server_host=127.0.0.1,lua_server_port=4445,lua_task_timeout=5000,verbosity=1,policy=prompt'
    $replaced = $false
    for ($index = 0; $index -lt $json.vmArgs.Count; $index++) {
        if ([string]$json.vmArgs[$index] -like '-agentlib:zbNative*') {
            $json.vmArgs[$index] = $agent
            $replaced = $true
        }
    }
    if (-not $replaced) { $json.vmArgs += $agent }
    $json | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $clientJson -Encoding utf8
}

$serverJar = Join-Path $ServerRoot 'ZombieBuddy.jar'
$serverDll = Join-Path $ServerRoot 'zbNative.dll'
if (-not $SkipServer -and $PSCmdlet.ShouldProcess($ServerRoot, 'Install matching ZombieBuddy runtime and create isolated launcher')) {
    if (Test-Path -LiteralPath $serverJar) {
        Copy-Item -LiteralPath $serverJar -Destination "$serverJar.bak-$stamp"
    }
    Copy-Item -LiteralPath $RuntimeJar -Destination $serverJar -Force
    Copy-Item -LiteralPath $workshopDll.FullName -Destination $serverDll -Force
    $jarHashMatches = $runtimeHash -eq (Get-FileHash $serverJar).Hash
    $dllHashMatches = (Get-FileHash $workshopDll.FullName).Hash -eq (Get-FileHash $serverDll).Hash
    if (-not $jarHashMatches -or -not $dllHashMatches) {
        throw 'ZombieBuddy server copy hash verification failed.'
    }

    $launcher = Join-Path $ServerRoot 'StartServer64_zb_arkmp_qa.bat'
    $lines = @(
        '@echo off',
        'setlocal',
        'cd /d "%~dp0"',
        'set "PZ_CLASSPATH=java/;java/projectzomboid.jar"',
        'set "PZ_ZB_AGENT=-agentlib:zbNative=experimental,lua_server_host=127.0.0.1,lua_server_port=4444,lua_task_timeout=5000,verbosity=1,policy=deny-new,frontend=console"',
        '".\jre64\bin\java.exe" -Djava.awt.headless=true -Dzomboid.steam=1 -Dzomboid.znetlog=1 -XX:+UseZGC -XX:-CreateCoredumpOnCrash -XX:-OmitStackTraceInFastThrow -Xms3g -Xmx6g -Djava.library.path=natives/ %PZ_ZB_AGENT% -cp %PZ_CLASSPATH% zombie.network.GameServer -- -statistic 0 -servername arkmp_qa %*',
        'endlocal'
    )
    $lines | Set-Content -LiteralPath $launcher -Encoding ascii
}

[pscustomobject]@{
    ClientJson = $clientJson
    ClientBackup = if ($SkipClient) { $null } else { "$clientJson.bak-$stamp" }
    WorkshopJarSha256 = $workshopHash
    RuntimeJarSha256 = $runtimeHash
    RuntimeJar = $RuntimeJar
    WorkshopDllSha256 = (Get-FileHash $workshopDll.FullName).Hash
    ServerLauncher = (Join-Path $ServerRoot 'StartServer64_zb_arkmp_qa.bat')
}
