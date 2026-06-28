<#
.SYNOPSIS
    Writes a build report with image identity metadata and patch inventory.

.DESCRIPTION
    Produces JSON and CSV files in C:\Windows\Temp so the generated image carries
    a point-in-time record of patch state. Also writes an image identity manifest
    to C:\ProgramData\ImageMetadata so future operators can identify provenance.
    A summary is emitted to stdout so details are visible in the Packer host log.
#>

$ErrorActionPreference = 'Stop'

$reportDir = 'C:\Windows\Temp\packer-build-report'
New-Item -Path $reportDir -ItemType Directory -Force | Out-Null

$identityDir = 'C:\ProgramData\ImageMetadata'
New-Item -Path $identityDir -ItemType Directory -Force | Out-Null

$os = Get-CimInstance Win32_OperatingSystem
$buildUtc = (Get-Date).ToUniversalTime()
$buildUtcIso = $buildUtc.ToString('o')

$hotfixes = @(Get-HotFix | Sort-Object InstalledOn)

$imageName = $env:PACKER_IMAGE_NAME
if ([string]::IsNullOrWhiteSpace($imageName)) {
    $imageName = "windows-image-$($buildUtc.ToString('yyyyMMdd'))"
}

$imageAlias = $env:PACKER_IMAGE_ALIAS
if ([string]::IsNullOrWhiteSpace($imageAlias)) {
    $imageAlias = 'windows-latest'
}

$templateName = $env:PACKER_TEMPLATE_NAME
if ([string]::IsNullOrWhiteSpace($templateName)) {
    $templateName = 'unknown-template'
}

$builderType = $env:PACKER_BUILDER_TYPE
if ([string]::IsNullOrWhiteSpace($builderType)) {
    $builderType = 'unknown-builder'
}

$metadata = [ordered]@{
    image_name        = $imageName
    image_alias       = $imageAlias
    built_utc         = $buildUtcIso
    template_name     = $templateName
    builder_type      = $builderType
    computer_name     = $env:COMPUTERNAME
    os_caption        = $os.Caption
    os_version        = $os.Version
    os_build          = $os.BuildNumber
}

$report = [ordered]@{
    metadata       = $metadata
    build_utc      = $buildUtcIso
    computer_name  = $env:COMPUTERNAME
    os_caption     = $os.Caption
    os_version     = $os.Version
    os_build       = $os.BuildNumber
    hotfix_count   = $hotfixes.Count
    hotfixes       = @($hotfixes | Select-Object HotFixID, Description, InstalledOn, InstalledBy)
}

$jsonPath = Join-Path $reportDir 'build-report.json'
$csvPath = Join-Path $reportDir 'hotfixes.csv'
$txtPath = Join-Path $reportDir 'build-report.txt'
$identityPath = Join-Path $identityDir 'image-info.json'

$report | ConvertTo-Json -Depth 6 | Out-File -FilePath $jsonPath -Encoding utf8
$metadata | ConvertTo-Json -Depth 4 | Out-File -FilePath $identityPath -Encoding utf8

$hotfixes |
    Select-Object HotFixID, Description, InstalledOn, InstalledBy |
    Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8

$summaryLines = @(
    "Build UTC : $buildUtcIso",
    "Image    : $imageName",
    "Alias    : $imageAlias",
    "Template : $templateName",
    "Builder  : $builderType",
    "Computer  : $($env:COMPUTERNAME)",
    "OS        : $($os.Caption) $($os.Version) (Build $($os.BuildNumber))",
    "Hotfixes  : $($hotfixes.Count)",
    "JSON      : $jsonPath",
    "CSV       : $csvPath",
    "Identity  : $identityPath"
)
$summaryLines | Out-File -FilePath $txtPath -Encoding utf8

Write-Host '=== Build Report ==='
$summaryLines | ForEach-Object { Write-Host $_ }
Write-Host 'Installed hotfix inventory:'

if ($hotfixes.Count -eq 0) {
    Write-Host '(No hotfixes reported by Get-HotFix)'
}
else {
    foreach ($hf in $hotfixes) {
        Write-Host ("- {0} | {1} | {2}" -f $hf.HotFixID, $hf.Description, $hf.InstalledOn)
    }
}
