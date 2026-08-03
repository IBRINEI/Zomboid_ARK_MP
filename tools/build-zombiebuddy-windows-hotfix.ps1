[CmdletBinding()]
param(
    [string]$GameRoot = "C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid",
    [string]$SourceJar,
    [string]$OutputJar
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceFile = Join-Path $PSScriptRoot "zombiebuddy-2.3.3-windows\JavaStateDumper.java"
$gameJar = Join-Path $GameRoot "projectzomboid.jar"

if (-not $SourceJar) {
    $officialBackup = Join-Path $GameRoot "ZombieBuddy.jar.official-v2.3.3"
    if (Test-Path -LiteralPath $officialBackup -PathType Leaf) {
        $SourceJar = $officialBackup
    } else {
        $SourceJar = Join-Path $GameRoot "ZombieBuddy.jar"
    }
}
if (-not $OutputJar) {
    $OutputJar = Join-Path $repoRoot "artifacts\ZombieBuddy-2.3.3-windows-http-hotfix.jar"
}

$expectedUpstreamHash = "C000C1AB79873314DB73F53B971AE004272AA145C03A0A42F1A61279C54837FE"
$sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $SourceJar).Hash
if ($sourceHash -ne $expectedUpstreamHash) {
    throw "Source JAR is not official ZombieBuddy 2.3.3: $sourceHash"
}

foreach ($required in @($sourceFile, $gameJar)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required file not found: $required"
    }
}

$javac = (Get-Command javac.exe -ErrorAction Stop).Source
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("arkmp-zb-hotfix-" + [guid]::NewGuid().ToString("N"))
$classesRoot = Join-Path $tempRoot "classes"
New-Item -ItemType Directory -Path $classesRoot -Force | Out-Null

try {
    & $javac `
        -cp "$SourceJar;$gameJar" `
        -d $classesRoot `
        $sourceFile
    if ($LASTEXITCODE -ne 0) {
        throw "javac failed with exit code $LASTEXITCODE"
    }

    $relativeClass = "me\zed_0xff\zombie_buddy\patches\experimental\JavaStateDumper.class"
    $compiledClass = Join-Path $classesRoot $relativeClass
    if (-not (Test-Path -LiteralPath $compiledClass -PathType Leaf)) {
        throw "Compiled replacement not found: $compiledClass"
    }

    $outputDirectory = Split-Path -Parent $OutputJar
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    Copy-Item -LiteralPath $SourceJar -Destination $OutputJar -Force

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::Open($OutputJar, [IO.Compression.ZipArchiveMode]::Update)
    try {
        $signatureEntries = @($archive.Entries | Where-Object {
            $_.FullName -match '^META-INF/.*\.(SF|RSA|DSA)$'
        })
        foreach ($entry in $signatureEntries) {
            $entry.Delete()
        }

        $classEntryName = $relativeClass.Replace("\", "/")
        $oldEntry = $archive.GetEntry($classEntryName)
        if ($null -eq $oldEntry) {
            throw "Class entry not found in upstream JAR: $classEntryName"
        }
        $oldEntry.Delete()

        $newEntry = $archive.CreateEntry($classEntryName, [IO.Compression.CompressionLevel]::Optimal)
        $input = [IO.File]::OpenRead($compiledClass)
        $output = $newEntry.Open()
        try {
            $input.CopyTo($output)
        } finally {
            $output.Dispose()
            $input.Dispose()
        }
    } finally {
        $archive.Dispose()
    }

    $resultHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $OutputJar).Hash
    [pscustomobject]@{
        SourceVersion = "2.3.3"
        SourceSha256 = $sourceHash
        Output = $OutputJar
        OutputSha256 = $resultHash
        Fix = "Skip unsupported Unix INFO signal on Windows so experimental HTTP startup continues"
    }
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
