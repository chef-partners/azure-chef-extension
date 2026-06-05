<#
.SYNOPSIS
  Validates the Azure Chef Extension Windows configuration and install flow.

.PARAMETER LicenseKey
  Optional Chef license key to validate licensed download configuration.

.PARAMETER SettingsFile
  Path to a .settings JSON file for validation. Defaults to looking in the current directory.
#>
param(
  [string]$LicenseKey = "",
  [string]$SettingsFile = ""
)

$ErrorActionPreference = "Stop"
$validationPassed = $true

function Write-ValidationResult($check, $passed, $detail = "") {
  $status = if ($passed) { "PASS" } else { "FAIL" }
  $color  = if ($passed) { "Green" } else { "Red" }
  Write-Host "[$status] $check" -ForegroundColor $color
  if ($detail) { Write-Host "       $detail" -ForegroundColor Gray }
}

Write-Host "`n=== Azure Chef Extension Windows Validation ===" -ForegroundColor Cyan

# 1. Verify required files exist
$requiredFiles = @(
  "ChefExtensionHandler\bin\chef-install.psm1",
  "ChefExtensionHandler\bin\shared.ps1"
)
foreach ($f in $requiredFiles) {
  $exists = Test-Path $f
  Write-ValidationResult "Required file exists: $f" $exists
  if (-not $exists) { $validationPassed = $false }
}

# 2. Verify chef_license_key plumbing in shared.ps1
$sharedContent = Get-Content "ChefExtensionHandler\bin\shared.ps1" -Raw
$hasLicenseKeyFn = $sharedContent -match "Get-ChefLicenseKey"
Write-ValidationResult "shared.ps1 contains Get-ChefLicenseKey" $hasLicenseKeyFn
if (-not $hasLicenseKeyFn) { $validationPassed = $false }

$hasSetFn = $sharedContent -match "Set-ChefLicenseKeyEnv"
Write-ValidationResult "shared.ps1 contains Set-ChefLicenseKeyEnv" $hasSetFn
if (-not $hasSetFn) { $validationPassed = $false }

# 3. Verify Install-ChefClient wires the license key
$installContent = Get-Content "ChefExtensionHandler\bin\chef-install.psm1" -Raw
$hasLicenseWire = $installContent -match "Get-ChefLicenseKey"
Write-ValidationResult "chef-install.psm1 reads chef_license_key" $hasLicenseWire
if (-not $hasLicenseWire) { $validationPassed = $false }

# 4. Validate settings file if provided
if ($SettingsFile -and (Test-Path $SettingsFile)) {
  $settings = Get-Content $SettingsFile -Raw | ConvertFrom-Json
  $pubSettings = $settings.runtimeSettings[0].handlerSettings.publicSettings
  $hasChefLicense = $pubSettings.PSObject.Properties.Name -contains "CHEF_LICENSE"
  Write-ValidationResult "Settings file has CHEF_LICENSE" $hasChefLicense $SettingsFile
} elseif ($SettingsFile) {
  Write-ValidationResult "Settings file readable" $false $SettingsFile
  $validationPassed = $false
}

# 5. Validate license key format (if supplied)
if ($LicenseKey) {
  $keyValid = $LicenseKey.Length -ge 10
  Write-ValidationResult "License key length >= 10 chars" $keyValid
  if (-not $keyValid) { $validationPassed = $false }
}

Write-Host ""
if ($validationPassed) {
  Write-Host "All validation checks passed." -ForegroundColor Green
  exit 0
} else {
  Write-Host "One or more validation checks FAILED." -ForegroundColor Red
  exit 1
}
