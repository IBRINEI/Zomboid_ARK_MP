[CmdletBinding()]
param(
    [string]$GameRoot = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid',
    [string]$ReportPath,
    [switch]$IncludeExperimentalThermalJava
)

$ErrorActionPreference = 'Stop'
Remove-Item Alias:R -ErrorAction SilentlyContinue
Remove-Item Alias:G -ErrorAction SilentlyContinue
$repository = Split-Path -Parent $PSScriptRoot
$jar = Join-Path $GameRoot 'projectzomboid.jar'
$runnerDirectory = Join-Path $repository 'BunkerCampaign\42.0\tests'
if (-not $ReportPath) { $ReportPath = Join-Path $repository 'artifacts\test-results.json' }
if (-not (Test-Path -LiteralPath $jar)) { throw "Project Zomboid jar not found: $jar" }

function R([string]$Path) { Join-Path $repository $Path }
function G([string]$Path) { Join-Path $GameRoot $Path }
function New-Suite([string]$Name, [string[]]$Files) {
    [pscustomobject]@{ Name=$Name; Files=$Files }
}

$cc = R 'BunkerCampaign\42.0\media\lua\shared\BunkerCampaign\Constants.lua'
$cu = R 'BunkerCampaign\42.0\media\lua\shared\BunkerCampaign\Util.lua'
$cp = R 'BunkerCampaign\42.0\media\lua\shared\BunkerCampaign\PowerSimulation.lua'
$cw = R 'BunkerCampaign\42.0\media\lua\shared\BunkerCampaign\WaterSimulation.lua'
$cr = R 'BunkerCampaign\42.0\media\lua\shared\BunkerCampaign\RoomRegistry.lua'
$chc = R 'BunkerCampaign\42.0\media\lua\shared\BunkerCampaign\HeatingComponents.lua'
$ch = R 'BunkerCampaign\42.0\media\lua\shared\BunkerCampaign\HeatingSimulation.lua'
$cv = R 'BunkerCampaign\42.0\media\lua\shared\BunkerCampaign\VentilationSimulation.lua'
$cs = R 'BunkerCampaign\42.0\media\lua\shared\BunkerCampaign\StateSchema.lua'
$campaignState = R 'BunkerCampaign\42.0\media\lua\server\BunkerCampaign\CampaignState.lua'
$serverCommands = R 'BunkerCampaign\42.0\media\lua\server\BunkerCampaign\ServerCommands.lua'
$coreState = @($cc,$cu,$cp,$cw,$cr,$chc,$ch,$cv,$cs)

$ac = R 'BunkerCampaignArkMP\42.0\media\lua\shared\BunkerCampaignArkMP\Constants.lua'
$agmd = R 'BunkerCampaignArkMP\42.0\media\lua\shared\BWOAGMD.lua'
$apg = R 'BunkerCampaignArkMP\42.0\media\lua\server\BunkerCampaignArkMP\PowerGrid.lua'
$aserver = R 'BunkerCampaignArkMP\42.0\media\lua\server\BunkerCampaignArkMP\Server.lua'

$ic = R 'BunkerCampaignIntegration\42.0\media\lua\shared\BunkerCampaignIntegration\Constants.lua'
$iz = R 'BunkerCampaignIntegration\42.0\media\lua\shared\BunkerCampaignIntegration\ZoneSampler.lua'
$iwa = R 'BunkerCampaignIntegration\42.0\media\lua\shared\BunkerCampaignIntegration\WaterpipesAdapter.lua'
$idm = R 'BunkerCampaignIntegration\42.0\media\lua\shared\BunkerCampaignIntegration\DecontaminationModel.lua'
$icl = R 'BunkerCampaignIntegration\42.0\media\lua\shared\BunkerCampaignIntegration\ClimateAdapter.lua'
$iha = R 'BunkerCampaignIntegration\42.0\media\lua\shared\BunkerCampaignIntegration\HeatingAdapter.lua'
$imw = R 'BunkerCampaignIntegration\42.0\media\lua\shared\BunkerCampaignIntegration\ManualWashActions.lua'
$iws = R 'BunkerCampaignIntegration\42.0\media\lua\server\BunkerCampaignIntegration\WaterService.lua'
$ids = R 'BunkerCampaignIntegration\42.0\media\lua\server\BunkerCampaignIntegration\DecontaminationServer.lua'

$tc = R 'BunkerCampaignToxicMP\42.0\media\lua\shared\BunkerCampaignToxicMP\Constants.lua'
$tm = R 'BunkerCampaignToxicMP\42.0\media\lua\shared\BunkerCampaignToxicMP\ContaminationModel.lua'
$tserver = R 'BunkerCampaignToxicMP\42.0\media\lua\server\BunkerCampaignToxicMP\Server.lua'

$suites = @(
    New-Suite 'core.power' @($cc,$cu,$cp,(R 'BunkerCampaign\42.0\tests\test_power.lua'))
    New-Suite 'core.ventilation' @($coreState + (R 'BunkerCampaign\42.0\tests\test_ventilation.lua'))
    New-Suite 'core.life_support' @($cc,$cu,$cw,$cr,$cv,(R 'BunkerCampaign\42.0\tests\test_life_support.lua'))
    New-Suite 'core.heating' @($cc,$cu,$cr,$chc,$ch,(R 'BunkerCampaign\42.0\tests\test_heating.lua'))
    New-Suite 'core.client_state' @((R 'BunkerCampaign\42.0\tests\client_state_setup.lua'),$cc,(R 'BunkerCampaign\42.0\media\lua\client\BunkerCampaign\ClientState.lua'),(R 'BunkerCampaign\42.0\tests\test_client_state.lua'))
    New-Suite 'core.server_state' (@((R 'BunkerCampaign\42.0\tests\test_server_state.lua')) + $coreState + @($campaignState,$serverCommands,(R 'BunkerCampaign\42.0\tests\run_server_tests.lua')))

    New-Suite 'ark.gmd' @((R 'BunkerCampaignArkMP\42.0\tests\gmd_setup.lua'),$ac,$agmd,(R 'BunkerCampaignArkMP\42.0\tests\test_gmd.lua'))
    New-Suite 'ark.map_registration' @((R 'BunkerCampaignArkMP\42.0\tests\map_registration_setup.lua'),$ac,(R 'BunkerCampaignArkMP\42.0\media\lua\shared\BunkerCampaignArkMP\MapRegistration.lua'),(R 'BunkerCampaignArkMP\42.0\tests\test_map_registration.lua'))
    New-Suite 'ark.power_grid' @((R 'BunkerCampaignArkMP\42.0\tests\power_grid_setup.lua'),$apg,(R 'BunkerCampaignArkMP\42.0\tests\test_power_grid.lua'))
    New-Suite 'ark.client_teleport' @((R 'BunkerCampaignArkMP\42.0\tests\client_teleport_setup.lua'),$ac,(R 'BunkerCampaignArkMP\42.0\media\lua\client\BunkerCampaignArkMP\Client.lua'),(R 'BunkerCampaignArkMP\42.0\tests\test_client_teleport.lua'))
    New-Suite 'ark.server_entry' @((R 'BunkerCampaignArkMP\42.0\tests\server_entry_setup.lua'),$ac,$agmd,$aserver,(R 'BunkerCampaignArkMP\42.0\tests\test_server_entry.lua'))
    New-Suite 'ark.build_error_latch' @((R 'BunkerCampaignArkMP\42.0\tests\server_entry_setup.lua'),$ac,$agmd,$aserver,(R 'BunkerCampaignArkMP\42.0\tests\test_build_error_latch.lua'))
    New-Suite 'ark.water_pump_repair' @((R 'BunkerCampaignArkMP\42.0\tests\water_pump_repair_setup.lua'),$ac,$aserver,(R 'BunkerCampaignArkMP\42.0\tests\test_water_pump_repair.lua'))
    New-Suite 'ark.water_pump_server' @((R 'BunkerCampaignArkMP\42.0\tests\water_pump_server_setup.lua'),(R 'BunkerCampaignArkMP\42.0\media\lua\shared\BWOABuildTools.lua'),(R 'BunkerCampaignArkMP\42.0\tests\test_water_pump_server.lua'))

    New-Suite 'integration.decontamination_model' @($ic,$idm,(R 'BunkerCampaignIntegration\42.0\tests\test_decontamination_model.lua'))
    New-Suite 'integration.thermal_adapters' @($cc,$cu,$ic,$icl,$iha,(R 'BunkerCampaignIntegration\42.0\tests\test_thermal_adapters.lua'))
    New-Suite 'integration.zone_sampler' @($cc,$cu,$ic,$iz,(R 'BunkerCampaignIntegration\42.0\tests\test_zone_sampler.lua'))
    New-Suite 'integration.waterpipes_adapter' @($cc,$cu,$ic,$iwa,(R 'BunkerCampaignIntegration\42.0\tests\test_waterpipes_adapter.lua'))
    New-Suite 'integration.water_service' @($cc,$cu,(R 'BunkerCampaignIntegration\42.0\tests\water_service_setup.lua'),$ic,$iwa,$iws,(R 'BunkerCampaignIntegration\42.0\tests\test_water_service.lua'))
    New-Suite 'integration.water_take_server_patch' @((R 'BunkerCampaignIntegration\42.0\tests\water_take_action_server_patch_setup.lua'),(R 'BunkerCampaignIntegration\42.0\media\lua\server\BunkerCampaignIntegration\WaterTakeActionServerPatch.lua'),(R 'BunkerCampaignIntegration\42.0\tests\test_water_take_action_server_patch.lua'))
    New-Suite 'integration.waterpipes_client_patch' @((R 'BunkerCampaignIntegration\42.0\tests\waterpipes_client_patch_setup.lua'),(R 'BunkerCampaignIntegration\42.0\media\lua\client\BunkerCampaignIntegration\WaterpipesClientPatch.lua'),(R 'BunkerCampaignIntegration\42.0\tests\test_waterpipes_client_patch.lua'))
    New-Suite 'integration.manual_wash_actions' @((G 'media\lua\shared\ISBaseObject.lua'),(G 'media\lua\shared\TimedActions\ISBaseTimedAction.lua'),(G 'media\lua\shared\TimedActions\ISWashClothing.lua'),(G 'media\lua\shared\TimedActions\ISWashYourself.lua'),$ic,$tc,$imw,(R 'BunkerCampaignIntegration\42.0\tests\test_manual_wash_actions.lua'))
    New-Suite 'integration.server' (@((R 'BunkerCampaign\42.0\tests\test_server_state.lua')) + $coreState + @($campaignState,(R 'BunkerCampaignIntegration\42.0\tests\integration_server_setup.lua'),$ic,$iz,$iwa,$idm,$icl,$iha,$ac,(R 'BunkerCampaignIntegration\42.0\media\lua\server\BunkerCampaignIntegration\IntegrationState.lua'),(R 'BunkerCampaignIntegration\42.0\tests\test_integration_server.lua')))
    New-Suite 'integration.decontamination_server' @($cc,$cu,(R 'BunkerCampaignIntegration\42.0\tests\test_decontamination_server.lua'),$ic,$tc,$iwa,$iws,$idm,$imw,$ids,(R 'BunkerCampaignIntegration\42.0\tests\run_decontamination_server_tests.lua'))

    New-Suite 'toxic.contamination_model' @($tc,$tm,(R 'BunkerCampaignToxicMP\42.0\tests\test_contamination_model.lua'))
    New-Suite 'toxic.recipe' @($tc,(R 'BunkerCampaignToxicMP\42.0\media\lua\shared\BunkerCampaignToxicMP\Recipe.lua'),(R 'BunkerCampaignToxicMP\42.0\tests\test_recipe.lua'))
    New-Suite 'toxic.server_filter' @((R 'BunkerCampaignToxicMP\42.0\tests\server_filter_setup.lua'),$tc,$tm,$tserver,(R 'BunkerCampaignToxicMP\42.0\tests\test_server_filter.lua'))
    New-Suite 'toxic.respawn_reset' @((R 'BunkerCampaignToxicMP\42.0\tests\server_filter_setup.lua'),$tc,$tm,$tserver,(R 'BunkerCampaignToxicMP\42.0\tests\test_respawn_reset.lua'))
    New-Suite 'toxic.world_cleanup' @((R 'BunkerCampaignToxicMP\42.0\tests\server_filter_setup.lua'),$tc,$tm,$tserver,(R 'BunkerCampaignToxicMP\42.0\tests\test_world_cleanup.lua'))
    New-Suite 'toxic.client_cleanup' @((R 'BunkerCampaignToxicMP\42.0\tests\client_cleanup_setup.lua'),$tc,(R 'BunkerCampaignToxicMP\42.0\media\lua\client\BunkerCampaignToxicMP\Client.lua'),(R 'BunkerCampaignToxicMP\42.0\tests\test_client_cleanup.lua'))

    New-Suite 'thermal.adapter' @((R 'BunkerCampaignThermalJava\42.0\media\lua\shared\BunkerCampaignThermalJava\ThermalOverrideAdapter.lua'),(R 'BunkerCampaignThermalJava\42.0\tests\test_thermal_adapter.lua'))
    New-Suite 'thermal.client' @((R 'BunkerCampaignThermalJava\42.0\tests\thermal_client_setup.lua'),(R 'BunkerCampaignThermalJava\42.0\media\lua\shared\BunkerCampaignThermalJava\ThermalOverrideAdapter.lua'),(R 'BunkerCampaignThermalJava\42.0\media\lua\client\BunkerCampaignThermalJava\ThermalClient.lua'),(R 'BunkerCampaignThermalJava\42.0\tests\test_thermal_client.lua'))
    New-Suite 'thermal.server' @((R 'BunkerCampaignThermalJava\42.0\tests\thermal_server_setup.lua'),(R 'BunkerCampaignThermalJava\42.0\media\lua\shared\BunkerCampaignThermalJava\ThermalOverrideAdapter.lua'),(R 'BunkerCampaignThermalJava\42.0\media\lua\server\BunkerCampaignThermalJava\ThermalServer.lua'),(R 'BunkerCampaignThermalJava\42.0\tests\test_thermal_server.lua'))
)

& javac.exe -cp $jar (Join-Path $runnerDirectory 'LuaSyntaxCheck.java') (Join-Path $runnerDirectory 'LuaTestRunner.java')
if ($LASTEXITCODE -ne 0) { throw 'Failed to compile Lua test runners.' }

$luaRoots = @('BunkerCampaign','BunkerCampaignArkMP','BunkerCampaignIntegration','BunkerCampaignToxicMP','BunkerCampaignThermalJava')
$luaFiles = Get-ChildItem ($luaRoots | ForEach-Object { Join-Path $repository $_ }) -Recurse -Filter '*.lua' | Select-Object -ExpandProperty FullName
Push-Location $GameRoot
try {
    $syntaxOutput = & java.exe -cp "$runnerDirectory;$jar" LuaSyntaxCheck $luaFiles 2>&1
    $syntaxExit = $LASTEXITCODE
    $suiteResults = @()
    foreach ($suite in $suites) {
        $output = & java.exe -cp "$runnerDirectory;$jar" LuaTestRunner $suite.Files 2>&1
        $suiteResults += [ordered]@{
            name = $suite.Name
            status = if ($LASTEXITCODE -eq 0) { 'passed' } else { 'failed' }
            exitCode = $LASTEXITCODE
            files = @($suite.Files | ForEach-Object { [IO.Path]::GetFullPath($_) })
            output = @($output | ForEach-Object { [string]$_ })
        }
    }
} finally {
    Pop-Location
}

$thermalJava = [ordered]@{
    status = 'deferred_incompatible'
    reason = 'Installed ZombieBuddy 2.3.2 exposes me.zed_0xff.zombie_buddy.Patch; source targets 3.0.0-alpha annotations.Patch.'
}
if ($IncludeExperimentalThermalJava) {
    $sources = Get-ChildItem (R 'BunkerCampaignThermalJava\42.0\src') -Recurse -Filter '*.java' | Select-Object -ExpandProperty FullName
    $zbJar = Get-ChildItem 'C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\3619862853' -Recurse -Filter ZombieBuddy.jar | Select-Object -First 1
    $output = if ($zbJar) { & javac.exe -cp "$jar;$($zbJar.FullName)" $sources 2>&1 } else { @('ZombieBuddy.jar not found') }
    $thermalJava.attempted = $true
    $thermalJava.exitCode = if ($zbJar) { $LASTEXITCODE } else { 2 }
    $thermalJava.output = @($output | ForEach-Object { [string]$_ })
}

$failedSuites = @($suiteResults | Where-Object status -eq 'failed')
$report = [ordered]@{
    schemaVersion = 1
    createdAt = (Get-Date).ToUniversalTime().ToString('o')
    branch = (& git -C $repository branch --show-current).Trim()
    commit = (& git -C $repository rev-parse HEAD).Trim()
    gameRoot = $GameRoot
    projectZomboidJarSha256 = (Get-FileHash -LiteralPath $jar -Algorithm SHA256).Hash
    syntax = [ordered]@{ status=if ($syntaxExit -eq 0) {'passed'} else {'failed'}; checked=@($luaFiles).Count; output=@($syntaxOutput | ForEach-Object {[string]$_}) }
    suites = $suiteResults
    summary = [ordered]@{ total=@($suiteResults).Count; passed=@($suiteResults | Where-Object status -eq 'passed').Count; failed=$failedSuites.Count }
    thermalJava = $thermalJava
}
New-Item -ItemType Directory -Path (Split-Path -Parent $ReportPath) -Force | Out-Null
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReportPath -Encoding utf8
Write-Host "Lua syntax: $($report.syntax.checked) files, $($report.syntax.status)"
Write-Host "Lua suites: $($report.summary.passed)/$($report.summary.total) passed"
Write-Host "Report: $ReportPath"
if ($syntaxExit -ne 0 -or $failedSuites.Count -gt 0) { exit 1 }
